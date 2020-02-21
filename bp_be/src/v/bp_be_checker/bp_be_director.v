/**
 *
 * Name:
 *   bp_be_director.v
 * 
 * Description:
 *   Directs the PC for the FE and the calculator. Keeps track of the next PC
 *     and sends redirect signals to the FE when a misprediction is detected.
 *
 * Notes:
 *   We don't need the entirety of the calc_status structure here, but for simplicity 
 *     we pass it all. If the compiler doesn't flatten and optimize, we can do it ourselves.
 *   Branch_metadata should come from the target instruction, not the branch instruction,
 *     eliminating the need to store this in the BE
 *   We don't currently support MTVAL or EPC, so error muxes are disconnected
 *   FE cmd adapter could be split into a separate module
 */

module bp_be_director 
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 import bp_common_cfg_link_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_fe_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)

   // Generated parameters
   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
   , localparam isd_status_width_lp = `bp_be_isd_status_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam calc_status_width_lp = `bp_be_calc_status_width(vaddr_width_p)
   , localparam tlb_entry_width_lp   = `bp_pte_entry_leaf_width(paddr_width_p)
   , localparam commit_pkt_width_lp  = `bp_be_commit_pkt_width(vaddr_width_p)
   , localparam trap_pkt_width_lp    = `bp_be_trap_pkt_width(vaddr_width_p)
   )
  (input                              clk_i
   , input                            reset_i

   , input [cfg_bus_width_lp-1:0]     cfg_bus_i
   , output [vaddr_width_p-1:0]       cfg_npc_data_o

   // Dependency information
   , input [isd_status_width_lp-1:0]  isd_status_i
   , input [calc_status_width_lp-1:0] calc_status_i
   , output [vaddr_width_p-1:0]       expected_npc_o
   , output logic                     flush_o

   // FE-BE interface
   , output [fe_cmd_width_lp-1:0]     fe_cmd_o
   , output                           fe_cmd_v_o
   , input                            fe_cmd_ready_i
   , input                            fe_cmd_fence_i

   , output                           suppress_iss_o

   , input [commit_pkt_width_lp-1:0]  commit_pkt_i
   , input [trap_pkt_width_lp-1:0]    trap_pkt_i
   
   //iTLB fill interface
   , input                            itlb_fill_v_i
   , input [vaddr_width_p-1:0]        itlb_fill_vaddr_i
   , input [tlb_entry_width_lp-1:0]   itlb_fill_entry_i
  );

// Declare parameterized structures
`declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
`declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
`declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p); 

// Cast input and output ports 
bp_cfg_bus_s                     cfg_bus_cast_i;
bp_be_isd_status_s               isd_status;
bp_be_calc_status_s              calc_status;
bp_fe_cmd_s                      fe_cmd;
logic                            fe_cmd_v;
bp_fe_cmd_pc_redirect_operands_s fe_cmd_pc_redirect_operands;
bp_be_commit_pkt_s               commit_pkt;
bp_be_trap_pkt_s                 trap_pkt;

assign cfg_bus_cast_i = cfg_bus_i;
assign isd_status = isd_status_i;
assign calc_status = calc_status_i;
assign fe_cmd_o    = fe_cmd;
assign fe_cmd_v_o  = fe_cmd_v;
assign commit_pkt  = commit_pkt_i;
assign trap_pkt    = trap_pkt_i;

// Declare intermediate signals
logic [vaddr_width_p-1:0]               npc_plus4;
logic [vaddr_width_p-1:0]               npc_n, npc_r, pc_r;
logic                                   npc_mismatch_v;

// Logic for handling coming out of reset
enum bit [1:0] {e_reset, e_boot, e_run, e_fence} state_n, state_r;

// Control signals
logic npc_w_v, attaboy_pending;

logic [vaddr_width_p-1:0] br_mux_o, roll_mux_o, ret_mux_o, exc_mux_o;

// Module instantiations
// Update the NPC on a valid instruction in ex1 or a cache miss or a tlb miss
assign npc_w_v = cfg_bus_cast_i.npc_w_v
                 | calc_status.ex1_instr_v
                 | (commit_pkt.tlb_miss | commit_pkt.cache_miss)
                 | (trap_pkt.exception | trap_pkt._interrupt | trap_pkt.eret);
bsg_dff_reset_en 
 #(.width_p(vaddr_width_p))
 npc
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(npc_w_v)
  
   ,.data_i(npc_n)
   ,.data_o(npc_r)
   );
assign cfg_npc_data_o = npc_r;

// NPC calculation
bsg_mux 
 #(.width_p(vaddr_width_p)
   ,.els_p(2)   
   )
 init_mux
  (.data_i({cfg_bus_cast_i.npc, exc_mux_o})
   ,.sel_i(cfg_bus_cast_i.npc_w_v)
   ,.data_o(npc_n)
   );

bsg_mux 
 #(.width_p(vaddr_width_p)
   ,.els_p(2)   
   )
 exception_mux
  (.data_i({ret_mux_o, roll_mux_o})
   ,.sel_i(trap_pkt.exception | trap_pkt._interrupt | trap_pkt.eret)
   ,.data_o(exc_mux_o)
   );

bsg_mux 
 #(.width_p(vaddr_width_p)
   ,.els_p(2)
   )
 roll_mux
  (.data_i({commit_pkt.pc, calc_status.ex1_npc})
   ,.sel_i(commit_pkt.tlb_miss | commit_pkt.cache_miss)
   ,.data_o(roll_mux_o)
   );

bsg_mux 
 #(.width_p(vaddr_width_p)
   ,.els_p(2)
   )
 ret_mux
  (.data_i({trap_pkt.epc[0+:vaddr_width_p], {trap_pkt.tvec[0+:vaddr_width_p-2], 2'b00}})
   ,.sel_i(trap_pkt.eret)
   ,.data_o(ret_mux_o)
   );

assign npc_mismatch_v = isd_status.isd_v & (expected_npc_o != isd_status.isd_pc);

// Last operation was branch. Was it successful? Let's find out
// TODO: I think this is wrong, may send extra attaboys
bsg_dff_reset_en
 #(.width_p(1))
 attaboy_pending_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(calc_status.ex1_v | fe_cmd_v_o)

   ,.data_i(calc_status.ex1_br_or_jmp)
   ,.data_o(attaboy_pending)
   );
wire last_instr_was_branch = attaboy_pending | calc_status.ex1_br_or_jmp;

// Generate control signals
// On a cache miss, this is actually the generated pc in ex1. We could use this to redirect during 
//   mispredict-under-cache-miss. However, there's a critical path vs extra speculation argument.
//   Currently, we just don't send pc redirects under a cache miss.
assign expected_npc_o = npc_w_v ? npc_n : npc_r;

wire fe_cmd_nonattaboy_v = fe_cmd_v_o & (fe_cmd.opcode != e_op_attaboy);
// Boot logic 
always_comb
  begin
    unique casez (state_r)
      e_reset : state_n = cfg_bus_cast_i.freeze ? e_reset : e_boot;
      e_boot  : state_n = fe_cmd_v ? e_run : e_boot;
      e_run   : state_n = cfg_bus_cast_i.freeze ? e_reset : fe_cmd_nonattaboy_v ? e_fence : e_run;
      e_fence : state_n = fe_cmd_fence_i ? e_fence : e_run;
      default : state_n = e_reset;
    endcase
  end

//synopsys sync_set_reset "reset_i"
always_ff @(posedge clk_i) 
  if (reset_i)
      state_r <= e_reset;
  else
    begin
      state_r <= state_n;
    end

assign suppress_iss_o = (state_r == e_fence) & fe_cmd_fence_i;

// Flush on FE cmds which are not attaboys.  Also don't flush the entire pipeline on a mispredict.
always_comb 
  begin : fe_cmd_adapter
    fe_cmd = 'b0;
    fe_cmd_v = 1'b0;
    flush_o = 1'b0;

    // Send one reset cmd on boot
    if (state_r == e_boot) 
      begin
        fe_cmd.opcode = e_op_state_reset;
        fe_cmd.vaddr  = npc_r;
        
        fe_cmd_pc_redirect_operands = '0;
        fe_cmd_pc_redirect_operands.priv                = trap_pkt.priv_n;
        fe_cmd_pc_redirect_operands.translation_enabled = trap_pkt.translation_en_n;
        fe_cmd.operands.pc_redirect_operands = fe_cmd_pc_redirect_operands;

        fe_cmd_v = fe_cmd_ready_i;
      end
    else if (itlb_fill_v_i)
      begin
        fe_cmd.opcode                                     = e_op_itlb_fill_response;
        fe_cmd.vaddr                                      = itlb_fill_vaddr_i;
        fe_cmd.operands.itlb_fill_response.pte_entry_leaf = itlb_fill_entry_i;
      
        fe_cmd_v = fe_cmd_ready_i;

        flush_o = 1'b1;
      end
    else if (trap_pkt.sfence)
      begin
        fe_cmd.opcode = e_op_itlb_fence;
        fe_cmd.vaddr  = commit_pkt.npc;
        
        fe_cmd_pc_redirect_operands = '0;
        fe_cmd_pc_redirect_operands.translation_enabled = trap_pkt.translation_en_n;
        fe_cmd.operands.pc_redirect_operands = fe_cmd_pc_redirect_operands;
        
        fe_cmd_v      = fe_cmd_ready_i;

        flush_o = 1'b1;
      end
    else if (trap_pkt.fencei)
      begin
        fe_cmd.opcode = e_op_icache_fence;
        fe_cmd.vaddr  = commit_pkt.npc;

        fe_cmd_v = fe_cmd_ready_i;

        flush_o = 1'b1;
      end
    // Redirect the pc if there's an NPC mismatch
    // Should not lump trap and ret into branch misprediction
    else if (trap_pkt.exception | trap_pkt._interrupt | trap_pkt.eret)
      begin
        fe_cmd_pc_redirect_operands = '0;

        fe_cmd.opcode                                    = e_op_pc_redirection;
        fe_cmd.vaddr                                     = npc_n;
        // TODO: Fill in missing subopcodes.  They're not used by FE yet...
        fe_cmd_pc_redirect_operands.subopcode            = e_subop_trap;
        fe_cmd_pc_redirect_operands.branch_metadata_fwd  = '0; 
        fe_cmd_pc_redirect_operands.misprediction_reason = e_not_a_branch;
        fe_cmd_pc_redirect_operands.priv                 = trap_pkt.priv_n;
        fe_cmd_pc_redirect_operands.translation_enabled  = trap_pkt.translation_en_n;
        fe_cmd.operands.pc_redirect_operands             = fe_cmd_pc_redirect_operands;

        fe_cmd_v = fe_cmd_ready_i;

        flush_o = 1'b1;
      end
    else if (commit_pkt.cache_miss | commit_pkt.tlb_miss)
      begin
        flush_o = 1'b1;
      end
    else if (isd_status.isd_v & npc_mismatch_v)
      begin
        fe_cmd_pc_redirect_operands = '0;

        fe_cmd.opcode                                    = e_op_pc_redirection;
        fe_cmd.vaddr                                     = expected_npc_o;
        fe_cmd_pc_redirect_operands.subopcode            = e_subop_branch_mispredict;
        fe_cmd_pc_redirect_operands.branch_metadata_fwd  = isd_status.isd_branch_metadata_fwd;
        // TODO: Add not a branch case
        fe_cmd_pc_redirect_operands.misprediction_reason = last_instr_was_branch
                                                           ? e_incorrect_prediction
                                                           : e_not_a_branch;
        fe_cmd.operands.pc_redirect_operands             = fe_cmd_pc_redirect_operands;

        fe_cmd_v = fe_cmd_ready_i;
      end 
    // Send an attaboy if there's a correct prediction
    else if (isd_status.isd_v & ~npc_mismatch_v & attaboy_pending) 
      begin
        fe_cmd.opcode                      = e_op_attaboy;
        fe_cmd.vaddr                       = expected_npc_o;
        fe_cmd.operands.attaboy.branch_metadata_fwd = isd_status.isd_branch_metadata_fwd;

        fe_cmd_v = fe_cmd_ready_i;
      end
  end

endmodule

