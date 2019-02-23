/*
 *
 * bp_be_bserial_ctl.v
 *
 */
module bp_be_bserial_ctl
 import bp_be_rv64_pkg::*;
 #(parameter vaddr_width_p                 = "inv"
   , parameter paddr_width_p               = "inv"
   , parameter asid_width_p                = "inv"
   , parameter branch_metadata_fwd_width_p = "inv"

   // Generated parameters
   , localparam fe_queue_width_lp = `bp_fe_queue_width(vaddr_width_p
                                                       , branch_metadata_fwd_width_p
                                                       )
   , localparam fe_cmd_width_lp   = `bp_fe_cmd_width(vaddr_width_p
                                                     , paddr_width_p
                                                     , asid_width_p
                                                     , branch_metadata_fwd_width_p
                                                     )

   // From RISC-V specification
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   , localparam instr_width_lp    = rv64_instr_width_gp
   )
  (input                              clk_i
   , input                            reset_i

   // FE cmd interface
   , output [fe_cmd_width_lp-1:0]     fe_cmd_o
   , output                           fe_cmd_v_o
   , input                            fe_cmd_ready_i

   // FE queue interface
   , input [fe_queue_width_lp-1:0]    fe_queue_i
   , input                            fe_queue_v_i
   , output                           fe_queue_ready_o

   , output                           chk_roll_fe_o
   , output                           chk_flush_fe_o
   , output                           chk_dequeue_fe_o
   );

// Declare parameterizable structs
`declare_bp_common_fe_be_if_structs(vaddr_width_p
                                    , paddr_width_p
                                    , asid_width_p
                                    , branch_metadata_fwd_width_p
                                    );

// Casting
bp_fe_cmd_s   fe_cmd;
bp_fe_queue_s fe_queue;

assign fe_cmd_o = fe_cmd;
assign fe_queue = fe_queue_i;

assign chk_roll_fe_o    = 1'b0;
assign chk_flush_fe_o   = 1'b0;
assign chk_dequeue_fe_o = 1'b0;



assign fe_cmd     = '0;
assign fe_cmd_v_o = '0;

assign fe_queue_ready_o = '0;

// Suppress warnings
wire unused0;
wire unused1;
wire unused2;
wire unused3;

assign unused0 = clk_i;
assign unused1 = reset_i;
assign unused2 = fe_cmd_ready_i;
assign unused3 = fe_queue_v_i;

endmodule : bp_be_bserial_ctl

