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
 *   fe_cmd_rdy_i                -
 *  
 *   chk_flush_fe_o              - Command to flush the fe_queue (on mispredict)
 *   chk_ckpt_fe_o               - Increments the fe_queue checkpoint when an instruction commits
 *   chk_roll_fe_o               - Command to rollback the fe_queue to the last checkpoint
 *   
 *
 * Keywords:
 * 
 * Notes:
 *   We don't need the entirety of the calc_status structure here, but for simplicity 
 *     we pass it all. If the compiler doesn't flatten and optimize, we can do it ourselves.
 */

module bp_be_director 
 import bp_common_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter vaddr_width_p                 = "inv"
   , parameter paddr_width_p               = "inv"
   , parameter asid_width_p                = "inv"
   , parameter branch_metadata_fwd_width_p = "inv"

   // Generated parameters
   , localparam calc_status_width_lp = `bp_be_calc_status_width(branch_metadata_fwd_width_p)
   , localparam fe_cmd_width_lp      = `bp_fe_cmd_width(vaddr_width_p
                                                        , paddr_width_p
                                                        , asid_width_p
                                                        , branch_metadata_fwd_width_p
                                                        )
   // From BE specifications
   , localparam pc_entry_point_lp = bp_pc_entry_point_gp
   // From RISC-V specifications
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   , localparam reg_addr_width_lp = rv64_reg_addr_width_gp
   , localparam eaddr_width_lp    = rv64_eaddr_width_gp
   )
  (input logic                              clk_i
   , input logic                            reset_i

   // Dependency information
   , input logic[calc_status_width_lp-1:0]  calc_status_i
   , output logic[eaddr_width_lp-1:0]       expected_npc_o

   // FE-BE interface
   , output logic[fe_cmd_width_lp-1:0]      fe_cmd_o
   , output logic                           fe_cmd_v_o
   , input logic                            fe_cmd_rdy_i

   // FE cmd queue control signals
   , output logic                           chk_flush_fe_o
   , output logic                           chk_ckpt_fe_o
   , output logic                           chk_roll_fe_o
  );

// Declare parameterized structures
`declare_bp_common_fe_be_if_structs(vaddr_width_p
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
bp_fe_cmd_pc_redirect_operands_s fe_cmd_pc_redirect_operands;
bp_fe_cmd_attaboy_s              fe_cmd_attaboy;

assign calc_status = calc_status_i;
assign fe_cmd_o    = fe_cmd;

// Declare intermediate signals
logic[eaddr_width_lp-1:0]              npc_plus4, npc_expected;
logic[eaddr_width_lp-1:0]              npc_n, npc_r;
logic[branch_metadata_fwd_width_p-1:0] branch_metadata_fwd_r;

// Control signals
logic npc_w_v, btaken_v, redirect_pending;
logic[eaddr_width_lp-1:0] br_mux_o, miss_mux_o, exception_mux_o, ret_mux_o;

// Module instantiations
// Update the NPC on a valid instruction in ex1 or a cache miss
assign npc_w_v = calc_status.ex1_v | (calc_status.mem3_cache_miss_v);
bsg_dff_reset_en 
 #(.width_p(eaddr_width_lp)
   ,.reset_val_p(pc_entry_point_lp)     
   ) 
 npc
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(npc_w_v)
  
   ,.data_i(npc_n)
   ,.data_o(npc_r)
   );

// NPC calculation
bsg_mux 
 #(.width_p(eaddr_width_lp)
   ,.els_p(2)   
   )
 exception_mux
  (.data_i({ret_mux_o, miss_mux_o})
   ,.sel_i(calc_status.mem3_exception_v)
   ,.data_o(npc_n)
   );

bsg_mux 
 #(.width_p(eaddr_width_lp)
   ,.els_p(2)
   )
 miss_mux
  (.data_i({calc_status.mem3_pc, br_mux_o})
   ,.sel_i(calc_status.mem3_cache_miss_v)
   ,.data_o(miss_mux_o)
   );

assign npc_plus4 = npc_r + eaddr_width_lp'(4);
assign btaken_v  = calc_status.int1_v & calc_status.int1_btaken;
bsg_mux 
 #(.width_p(eaddr_width_lp)
   ,.els_p(2)
   )
 br_mux
  (.data_i({calc_status.int1_br_tgt, npc_plus4})
   ,.sel_i(btaken_v)
   ,.data_o(br_mux_o)
   );

bsg_mux 
 #(.width_p(eaddr_width_lp)
   ,.els_p(2)
   )
 ret_mux
  (.data_i(/* TODO: {MTVAL, EPC} */)
   ,.sel_i(calc_status.mem3_ret_v)
   ,.data_o(ret_mux_o)
   );

// Save branch prediction metadata for forwarding on the next (mis)predicted instruction
bsg_dff 
 #(.width_p(branch_metadata_fwd_width_p)
   ) 
 branch_metadata_fwd_reg
  (.clk_i(clk_i)
   ,.data_i(calc_status.int1_branch_metadata_fwd)
   ,.data_o(branch_metadata_fwd_r)
   );

// A redirect is pending until the correct instruction has been fetched. Otherwise, we'll 
//   keep on sending redirects...
assign npc_mismatch_v = (expected_npc_o != calc_status.isd_pc);
bsg_dff_reset_en
 #(.width_p(1)
   )
 redirect_pending_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(calc_status.isd_v)

   ,.data_i(npc_mismatch_v)
   ,.data_o(redirect_pending)
   );

always_comb begin : control_signals
  // Expected npc updates in the same cycle as it's updated. But if a new instruction is 
  //   not being executed, then we're still waiting for the previous npc
  expected_npc_o = npc_w_v ? npc_n : npc_r;
  // Increment the checkpoint if there's a committing instruction
  chk_ckpt_fe_o = ~calc_status.mem3_cache_miss_v & calc_status.instr_ckpt_v;
  // Flush the FE queue if there's a pc redirect
  chk_flush_fe_o = fe_cmd_v_o & (fe_cmd.opcode == e_op_pc_redirection);
  // Rollback the FE queue on a cache miss
  chk_roll_fe_o  = calc_status.mem3_cache_miss_v;
end

always_comb begin : fe_cmd_adapter
  fe_cmd = 'b0;
  fe_cmd_v_o = 1'b0;

  // Redirect the pc if there's an NPC mismatch
  if(calc_status.isd_v & npc_mismatch_v) begin : pc_redirect
    fe_cmd.opcode                                   = e_op_pc_redirection;
    fe_cmd_pc_redirect_operands.pc                  = expected_npc_o;
    fe_cmd_pc_redirect_operands.subopcode           = e_subop_branch_mispredict;
    fe_cmd_pc_redirect_operands.branch_metadata_fwd = calc_status.ex1_v 
                                                      ? calc_status.int1_branch_metadata_fwd
                                                      : branch_metadata_fwd_r;

    fe_cmd_pc_redirect_operands.misprediction_reason = calc_status.int1_br_or_jmp 
                                                       ? e_incorrect_prediction 
                                                       : e_not_a_branch;

    fe_cmd.operands.pc_redirect_operands = fe_cmd_pc_redirect_operands;

    fe_cmd_v_o = fe_cmd_rdy_i & ~chk_roll_fe_o & ~redirect_pending;
  // Send an attaboy if there's a correct prediction
  end 
  /* TODO: When attaboys are enabled, the FE sends junk instructions in XOR and OR tests
  else if(calc_status.isd_v & ~npc_mismatch_v & calc_status.int1_br_or_jmp) begin : attaboy
    fe_cmd.opcode                      = e_op_attaboy;
    fe_cmd_attaboy.pc                  = calc_status.isd_pc;
    fe_cmd_attaboy.branch_metadata_fwd = calc_status.ex1_v 
                                         ? calc_status.int1_branch_metadata_fwd
                                         : branch_metadata_fwd_r;

    fe_cmd.operands.attaboy = fe_cmd_attaboy;

    fe_cmd_v_o = fe_cmd_rdy_i & ~chk_roll_fe_o & ~redirect_pending;
  end
  */
end

endmodule : bp_be_director
