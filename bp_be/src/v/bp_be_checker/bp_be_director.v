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
 import bp_cfg_link_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_fe_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)

   // Generated parameters
   , localparam calc_status_width_lp = `bp_be_calc_status_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam tlb_entry_width_lp   = `bp_pte_entry_leaf_width(paddr_width_p)
   )
  (input                              clk_i
   , input                            reset_i
   , input                            freeze_i

   // Config channel
   , input                            cfg_w_v_i
   , input [cfg_addr_width_p-1:0]     cfg_addr_i
   , input [cfg_data_width_p-1:0]     cfg_data_i

   // Dependency information
   , input [calc_status_width_lp-1:0] calc_status_i
   , output [vaddr_width_p-1:0]       expected_npc_o
   , output                           flush_o

   // FE-BE interface
   , output [fe_cmd_width_lp-1:0]     fe_cmd_o
   , output                           fe_cmd_v_o
   , input                            fe_cmd_ready_i

   // CSR interface
   , input                            trap_v_i
   , input                            ret_v_i
   , output [vaddr_width_p-1:0]       pc_o 
   , input [vaddr_width_p-1:0]        tvec_i
   , input [vaddr_width_p-1:0]        epc_i
   , input                            tlb_fence_i
   
   //iTLB fill interface
   , input                            itlb_fill_v_i
   , input [vaddr_width_p-1:0]        itlb_fill_vaddr_i
   , input [tlb_entry_width_lp-1:0]   itlb_fill_entry_i
  );

// Declare parameterized structures
`declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
`declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p); 

// Cast input and output ports 
bp_be_calc_status_s              calc_status;
bp_fe_cmd_s                      fe_cmd;
logic                            fe_cmd_v;
bp_fe_cmd_pc_redirect_operands_s fe_cmd_pc_redirect_operands;
bp_mtvec_s                       tvec;

assign calc_status = calc_status_i;
assign fe_cmd_o    = fe_cmd;
assign fe_cmd_v_o  = fe_cmd_v;
assign tvec        = tvec_i;

// Declare intermediate signals
logic [vaddr_width_p-1:0]               npc_plus4;
logic [vaddr_width_p-1:0]               npc_n, npc_r, pc_r;
logic                                   npc_mismatch_v;

// Logic for handling coming out of reset
enum bit [1:0] {e_reset, e_boot, e_run} state_n, state_r;

// Control signals
logic npc_w_v, btaken_v, attaboy_pending;

logic [vaddr_width_p-1:0] br_mux_o, roll_mux_o, ret_mux_o, exc_mux_o;

wire cfg_pc_lo_w_v = cfg_w_v_i & (cfg_addr_i == bp_cfg_reg_start_pc_lo_gp);
wire cfg_pc_hi_w_v = cfg_w_v_i & (cfg_addr_i == bp_cfg_reg_start_pc_hi_gp);
wire [vaddr_width_p-1:0] cfg_pc_part_li = 
  cfg_pc_hi_w_v
  ? {cfg_data_i[0+:vaddr_width_p-cfg_data_width_p], npc_r[0+:cfg_data_width_p]}
  : {npc_r[vaddr_width_p-1:cfg_data_width_p], cfg_data_i[0+:cfg_data_width_p]};

// Module instantiations
// Update the NPC on a valid instruction in ex1 or a cache miss or a tlb miss
assign npc_w_v = (cfg_pc_lo_w_v | cfg_pc_hi_w_v)
                 |(calc_status.ex1_instr_v & ~npc_mismatch_v) 
                 | calc_status.mem3_miss_v
                 | trap_v_i
                 | ret_v_i;
bsg_dff_en 
 #(.width_p(vaddr_width_p)
   ) 
 npc
  (.clk_i(clk_i)
   ,.en_i(npc_w_v)
  
   ,.data_i(npc_n)
   ,.data_o(npc_r)
   );

bsg_dff_reset_en
 #(.width_p(vaddr_width_p))
 pc
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(npc_w_v)

   ,.data_i(npc_r)
   ,.data_o(pc_r)
   );

// NPC calculation
bsg_mux 
 #(.width_p(vaddr_width_p)
   ,.els_p(2)   
   )
 init_mux
  (.data_i({cfg_pc_part_li, exc_mux_o})
   ,.sel_i(cfg_w_v_i)
   ,.data_o(npc_n)
   );

bsg_mux 
 #(.width_p(vaddr_width_p)
   ,.els_p(2)   
   )
 exception_mux
  (.data_i({ret_mux_o, roll_mux_o})
   ,.sel_i(trap_v_i | ret_v_i)
   ,.data_o(exc_mux_o)
   );

bsg_mux 
 #(.width_p(vaddr_width_p)
   ,.els_p(2)
   )
 roll_mux
  (.data_i({calc_status.mem3_pc, br_mux_o})
   ,.sel_i(calc_status.mem3_miss_v)
   ,.data_o(roll_mux_o)
   );

assign npc_plus4 = npc_r + vaddr_width_p'(4);
assign btaken_v  = calc_status.int1_v & calc_status.int1_btaken;
bsg_mux 
 #(.width_p(vaddr_width_p)
   ,.els_p(2)
   )
 br_mux
  (.data_i({calc_status.int1_br_tgt, npc_plus4})
   ,.sel_i(btaken_v)
   ,.data_o(br_mux_o)
   );

bsg_mux 
 #(.width_p(vaddr_width_p)
   ,.els_p(2)
   )
 ret_mux
  (.data_i({epc_i[0+:vaddr_width_p], {tvec.base[0+:vaddr_width_p-2], 2'b00}})
   ,.sel_i(ret_v_i)
   ,.data_o(ret_mux_o)
   );

assign npc_mismatch_v = (expected_npc_o != calc_status.ex1_pc);

// Last operation was branch. Was it successful? Let's find out
bsg_dff_reset_en
 #(.width_p(1))
 attaboy_pending_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(calc_status.ex1_v)

   ,.data_i(calc_status.int1_br_or_jmp)
   ,.data_o(attaboy_pending)
   );

// Generate control signals
assign expected_npc_o = npc_r;
// The current PC, used for interrupts
assign pc_o = pc_r;

// Boot logic 
always_comb
  begin
    unique casez (state_r)
      e_reset : state_n = freeze_i ? e_reset : e_boot;
      e_boot  : state_n = fe_cmd_v ? e_run : e_boot;
      e_run   : state_n = e_run;
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

// Flush on FE cmds which are not attaboys.  Also don't flush the entire pipeline on a mispredict.
assign flush_o = fe_cmd_v & ((fe_cmd.opcode != e_op_attaboy) & (fe_cmd.opcode != e_op_pc_redirection)) | trap_v_i;

always_comb 
  begin : fe_cmd_adapter
    fe_cmd = 'b0;
    fe_cmd_v = 1'b0;

    // Send one reset cmd on boot
    if (state_r == e_boot) 
      begin
        fe_cmd.opcode = e_op_state_reset;
        fe_cmd.vaddr  = npc_r;

        fe_cmd_v = fe_cmd_ready_i;
      end
    else if (itlb_fill_v_i)
      begin
        fe_cmd.opcode                                     = e_op_itlb_fill_response;
        fe_cmd.vaddr                                      = itlb_fill_vaddr_i;
        fe_cmd.operands.itlb_fill_response.pte_entry_leaf = itlb_fill_entry_i;
      
        fe_cmd_v = fe_cmd_ready_i;
      end
    else if (tlb_fence_i)
      begin
        fe_cmd.opcode = e_op_itlb_fence;
        fe_cmd.vaddr  = calc_status.mem3_pc;
        
        fe_cmd_v      = fe_cmd_ready_i;
      end
    else if (calc_status.mem1_fencei_v)
      begin
        fe_cmd.opcode = e_op_icache_fence;
        fe_cmd.vaddr  = expected_npc_o;

        fe_cmd_v = fe_cmd_ready_i;
      end
    // Redirect the pc if there's an NPC mismatch
    // Should not lump trap and ret into branch misprediction
    else if (trap_v_i | ret_v_i)
      begin
        fe_cmd_pc_redirect_operands = '0;

        fe_cmd.opcode                                    = e_op_pc_redirection;
        fe_cmd.vaddr                                     = npc_n;
        // TODO: Fill in missing subopcodes.  They're not used by FE yet...
        fe_cmd_pc_redirect_operands.subopcode            = e_subop_trap;
        fe_cmd_pc_redirect_operands.branch_metadata_fwd  =  calc_status.int1_branch_metadata_fwd;
        fe_cmd_pc_redirect_operands.misprediction_reason = e_not_a_branch;
        fe_cmd.operands.pc_redirect_operands             = fe_cmd_pc_redirect_operands;

        fe_cmd_v = fe_cmd_ready_i;

      end
    else if (calc_status.ex1_v & npc_mismatch_v)
      begin
        fe_cmd_pc_redirect_operands = '0;

        fe_cmd.opcode                                    = e_op_pc_redirection;
        fe_cmd.vaddr                                     = expected_npc_o;
        fe_cmd_pc_redirect_operands.subopcode            = e_subop_branch_mispredict;
        fe_cmd_pc_redirect_operands.branch_metadata_fwd  =  calc_status.int1_branch_metadata_fwd;
        fe_cmd_pc_redirect_operands.misprediction_reason = calc_status.int1_br_or_jmp 
                                                           ? e_incorrect_prediction 
                                                           : e_not_a_branch;
        fe_cmd.operands.pc_redirect_operands             = fe_cmd_pc_redirect_operands;

        fe_cmd_v = fe_cmd_ready_i;
      end 
    // Send an attaboy if there's a correct prediction
    else if (calc_status.ex1_v & ~npc_mismatch_v & attaboy_pending) 
      begin
        fe_cmd.opcode                      = e_op_attaboy;
        fe_cmd.vaddr                       = calc_status.ex1_pc;
        fe_cmd.operands.attaboy            = '{branch_metadata_fwd: calc_status.int1_branch_metadata_fwd
                                               ,default: '0
                                               };
        fe_cmd_v = fe_cmd_ready_i;
      end
  end
endmodule

