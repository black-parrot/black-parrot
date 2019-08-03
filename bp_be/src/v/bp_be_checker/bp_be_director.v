/**
 *
 * Name:
 *   bp_be_director.v
 * 
 * Description:
 *   Directs the PC for the FE and the calculator. Keeps track of the next PC
 *     and sends redirect signals to the FE when a misprediction is detected.
 *
 * Parameters:
 *   vaddr_width_p               - FE-BE structure sizing parameter
 *   paddr_width_p               - ''
 *   asid_width_p                - ''
 *   branch_metadata_fwd_width_p - ''
 * 
 * Inputs:
 *   clk_i                       -
 *   reset_i                     -
 *
 *   calc_status_i               - Instruction dependency information from the calculator
 *   expected_npc_o              - The expected npc (PC after the instruction in ex1) based on 
 *                                   branching information
 *   
 * Outputs:
 *   fe_cmd_o                    - FE cmd, handling pc redirection and attaboys, 
 *                                   among other things.
 *   fe_cmd_v_o                  - "ready-then-valid"
 *   fe_cmd_ready_i              -
 *  
 *   chk_flush_fe_o              - Command to flush the fe_queue (on mispredict)
 *   chk_dequeue_fe_o            - Increments the fe_queue checkpoint when an instruction commits
 *   chk_roll_fe_o               - Command to rollback the fe_queue to the last checkpoint
 *   
 *
 * Keywords:
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
 import bp_be_rv64_pkg::*;
 import bp_be_pkg::*;
 import bp_cfg_link_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_fe_be_if_widths(vaddr_width_p
                               ,paddr_width_p
                               ,asid_width_p
                               ,branch_metadata_fwd_width_p
                               )

   // Generated parameters
   , localparam calc_status_width_lp = `bp_be_calc_status_width(vaddr_width_p, branch_metadata_fwd_width_p)
   // VM parameters
   , localparam vtag_width_lp     = (vaddr_width_p-bp_page_offset_width_gp)
   , localparam ptag_width_lp     = (paddr_width_p-bp_page_offset_width_gp)
   , localparam tlb_entry_width_lp = `bp_be_tlb_entry_width(ptag_width_lp)

   // CSRs
   , localparam mepc_width_lp  = `bp_mepc_width
   , localparam mtvec_width_lp = `bp_mtvec_width
   )
  (input                               clk_i
   , input                             reset_i
   , input                             freeze_i

   // Config channel
   , input                             cfg_w_v_i
   , input [cfg_addr_width_p-1:0]      cfg_addr_i
   , input [cfg_data_width_p-1:0]      cfg_data_i

   // Dependency information
   , input [calc_status_width_lp-1:0]  calc_status_i
   , output [vaddr_width_p-1:0]        expected_npc_o
   , output                            flush_o

   // FE-BE interface
   , output [fe_cmd_width_lp-1:0]      fe_cmd_o
   , output                            fe_cmd_v_o
   , input                             fe_cmd_ready_i

   // FE cmd queue control signals
   , output                            chk_flush_fe_o
   , output                            chk_dequeue_fe_o
   , output                            chk_roll_fe_o

   // CSR interface
   , input                            trap_v_i
   , input                            ret_v_i
   , output [vaddr_width_p-1:0]       pc_o 
   , input [mepc_width_lp-1:0]        tvec_i
   , input [mtvec_width_lp-1:0]       epc_i
   , input                            tlb_fence_i
   
   //iTLB fill interface
   , input                           itlb_fill_v_i
   , input [vaddr_width_p-1:0]       itlb_fill_vaddr_i
   , input [tlb_entry_width_lp-1:0]  itlb_fill_entry_i
  );

// Declare parameterized structures
`declare_bp_fe_be_if(vaddr_width_p
                     , paddr_width_p
                     , asid_width_p
                     , branch_metadata_fwd_width_p
                     );
`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   ); 

// Cast input and output ports 
bp_be_calc_status_s              calc_status;
bp_fe_cmd_s                      fe_cmd;
logic                            fe_cmd_v;
bp_fe_cmd_pc_redirect_operands_s fe_cmd_pc_redirect_operands;
bp_fe_cmd_reset_operands_s       fe_cmd_reset_operands;
bp_fe_cmd_attaboy_s              fe_cmd_attaboy;
bp_mtvec_s                       tvec;
bp_mepc_s                        epc;

assign calc_status = calc_status_i;
assign fe_cmd_o    = fe_cmd;
assign fe_cmd_v_o  = fe_cmd_v;
assign tvec        = tvec_i;
assign epc         = epc_i;

// Declare intermediate signals
logic [vaddr_width_p-1:0]               npc_plus4;
logic [vaddr_width_p-1:0]               npc_n, npc_r, pc_r;
logic                                   npc_mismatch_v;
logic [branch_metadata_fwd_width_p-1:0] branch_metadata_fwd_r;

// Logic for handling coming out of reset
enum bit [1:0] {e_reset, e_boot, e_run} state_n, state_r;

// Control signals
logic npc_w_v, btaken_v, redirect_pending, attaboy_pending;

logic [vaddr_width_p-1:0] br_mux_o, roll_mux_o, ret_mux_o, exc_mux_o;

logic [vaddr_width_p-1:0] start_pc_part_li;

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
   ,.sel_i(freeze_i)
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

// A redirect is pending until the correct instruction has been fetched. Otherwise, we'll 
//   keep on sending redirects...
assign npc_mismatch_v = (expected_npc_o != calc_status.ex1_pc);
bsg_dff_reset_en
 #(.width_p(1))
 redirect_pending_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(calc_status.ex1_v | trap_v_i)

   ,.data_i(npc_mismatch_v | trap_v_i)
   ,.data_o(redirect_pending)
   );

// Last operation was branch. Was it successful? Let's find out
bsg_dff_reset_en
 #(.width_p(1))
 attaboy_pending_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(calc_status.ex1_instr_v)

   ,.data_i(calc_status.int1_br_or_jmp)
   ,.data_o(attaboy_pending)
   );

// Generate control signals
assign expected_npc_o = npc_r;
// Increment the checkpoint if there's a committing instruction
// The itlb fill is strictly unnecessary, but we would need to work the rollback logic to work
// without it
assign chk_dequeue_fe_o = ~calc_status.mem3_miss_v & calc_status.instr_cmt_v;
// Flush the FE queue if there's a pc redirect
assign chk_flush_fe_o = (fe_cmd_v & (fe_cmd.opcode != e_op_attaboy));

// Rollback the FE queue on a cache miss
assign chk_roll_fe_o  = calc_status.mem3_miss_v;
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
  begin
    if (reset_i)
        state_r <= e_reset;
    else
      begin
        state_r <= state_n;
      end
  end

// Set the fence if we have a cmd which is not an attaboy
// FE fencing is not supported yet
//assign fe_cmd_fence_set_o = fe_cmd_v & ~(fe_cmd.opcode == e_op_attaboy);

// TODO: Simplify assignments
assign flush_o = fe_cmd_v & (fe_cmd.opcode != e_op_attaboy) & ((fe_cmd.opcode != e_op_pc_redirection) | trap_v_i);

always_comb 
  begin : fe_cmd_adapter
    fe_cmd = 'b0;
    fe_cmd_v = 1'b0;
    fe_cmd_pc_redirect_operands = '0;

    // Send one reset cmd on boot
    if (state_r == e_boot) 
      begin : fe_reset
        fe_cmd.opcode = e_op_state_reset;
        fe_cmd_reset_operands.pc = npc_r;

        fe_cmd.operands.reset_operands = fe_cmd_reset_operands;
        fe_cmd_v = fe_cmd_ready_i;
      end
    else if(itlb_fill_v_i)
      begin : itlb_fill
        fe_cmd.opcode = e_op_itlb_fill_response;
        fe_cmd.operands.itlb_fill_response.vaddr = itlb_fill_vaddr_i;
        fe_cmd.operands.itlb_fill_response.pte_entry_leaf = itlb_fill_entry_i;
      
        fe_cmd_v = fe_cmd_ready_i;
      end
    else if(tlb_fence_i)
      begin : tlb_fence
        fe_cmd.opcode = e_op_itlb_fence;
        fe_cmd.operands.icache_fence.pc = calc_status.mem3_pc;
        
        fe_cmd_v = fe_cmd_ready_i;
      end
    else if(calc_status.mem3_fencei_v)
      begin : icache_fence
        fe_cmd.opcode = e_op_icache_fence;
        fe_cmd.operands.icache_fence.pc = calc_status.mem3_pc;

        fe_cmd_v = fe_cmd_ready_i;
      end
    // Redirect the pc if there's an NPC mismatch
    // Should not lump trap and ret into branch misprediction
    else if((calc_status.ex1_v & npc_mismatch_v) | trap_v_i | ret_v_i) 
      begin : pc_redirect
        fe_cmd.opcode                                   = e_op_pc_redirection;
        fe_cmd_pc_redirect_operands.pc                  = (trap_v_i | ret_v_i) ? npc_n : expected_npc_o;
        fe_cmd_pc_redirect_operands.subopcode           = e_subop_branch_mispredict;
        fe_cmd_pc_redirect_operands.branch_metadata_fwd =  calc_status.int1_branch_metadata_fwd;

        fe_cmd_pc_redirect_operands.misprediction_reason = calc_status.int1_br_or_jmp 
                                                           ? e_incorrect_prediction 
                                                           : e_not_a_branch;

        fe_cmd.operands.pc_redirect_operands = fe_cmd_pc_redirect_operands;

        fe_cmd_v = fe_cmd_ready_i & ~chk_roll_fe_o & (~redirect_pending | trap_v_i | ret_v_i);
      end 
    // Send an attaboy if there's a correct prediction
    else if(calc_status.ex1_instr_v & ~npc_mismatch_v & attaboy_pending) 
      begin : attaboy
        fe_cmd.opcode                      = e_op_attaboy;
        fe_cmd_attaboy.pc                  = calc_status.ex1_pc;
        fe_cmd_attaboy.branch_metadata_fwd = calc_status.int1_branch_metadata_fwd;

        fe_cmd.operands.attaboy = fe_cmd_attaboy;

        fe_cmd_v = fe_cmd_ready_i & ~chk_roll_fe_o & ~redirect_pending;
      end
  end
endmodule : bp_be_director

