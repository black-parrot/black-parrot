/**
 *
 * Name:
 *   bp_be_pipe_mul.v
 * 
 * Description:
 *   Pipeline for RISC-V multiplication instructions.
 *
 * Notes:
 *   Does not handle high-half multiplication. These operations take up more than half
 *     of the area of a 64x64->128-bit multiplier, but are used rarely
 *   Must use retiming for good QoR.
 */
module bp_be_pipe_mul
  import bp_be_pkg::*;
  import bp_common_rv64_pkg::*;
 #(localparam latency_p = 4
   // Generated parameters
   , localparam decode_width_lp      = `bp_be_decode_width
   // From RISC-V specifications
   , localparam word_width_lp = rv64_word_width_gp
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   )
  (input                            clk_i
   , input                          reset_i

   , input [decode_width_lp-1:0]    decode_i
   , input [reg_data_width_lp-1:0]  rs1_i
   , input [reg_data_width_lp-1:0]  rs2_i

   // Pipeline result
   , output logic [reg_data_width_lp-1:0] data_o
   );

// Cast input and output ports 
bp_be_decode_s decode;
assign decode = decode_i;

wire opw_li = decode.opw_v;

// TODO: Gate FU with pipe_mul_v

wire [reg_data_width_lp-1:0] src1_w_sgn = reg_data_width_lp'($signed(rs1_i[0+:word_width_lp]));
wire [reg_data_width_lp-1:0] src2_w_sgn = reg_data_width_lp'($signed(rs2_i[0+:word_width_lp]));

wire [reg_data_width_lp-1:0] op_a = opw_li ? src1_w_sgn : rs1_i;
wire [reg_data_width_lp-1:0] op_b = opw_li ? src2_w_sgn : rs2_i;

wire [reg_data_width_lp-1:0] full_result = op_a * op_b;

wire [reg_data_width_lp-1:0] mul_lo = opw_li ? reg_data_width_lp'($signed(full_result[0+:word_width_lp])) : full_result;

bsg_dff_chain
 #(.width_p(reg_data_width_lp)
   ,.num_stages_p(latency_p-1)
   )
 retime_chain
  (.clk_i(clk_i)

   ,.data_i(mul_lo)
   ,.data_o(data_o)
   );

endmodule
