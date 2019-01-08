/**
 *
 * bp_be_pipe_int.v
 *
 */

`include "bsg_defines.v"
`include "bp_be_internal_if.vh"

module bp_be_pipe_int 
 #(parameter mhartid_p="inv"
   , parameter vaddr_width_p="inv"
   , parameter paddr_width_p="inv"
   , parameter asid_width_p="inv"
   , parameter branch_metadata_fwd_width_p="inv"

   , localparam reg_data_width_lp=RV64_reg_data_width_gp
   , localparam pipe_stage_reg_width_lp=`bp_be_pipe_stage_reg_width(branch_metadata_fwd_width_p)
   , localparam exception_width_lp=`bp_be_exception_width
   )
  (input logic                                clk_i
   , input logic                              reset_i

   , input logic[pipe_stage_reg_width_lp-1:0] stage_i
   , input logic[exception_width_lp-1:0]      exc_i

   , output logic[reg_data_width_lp-1:0]      result_o
   , output logic[reg_data_width_lp-1:0]      br_tgt_o
   );

// Declare parameterizable types
`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   );

// Cast input and output ports 
bp_be_pipe_stage_reg_s stage;
bp_be_exception_s      exc;

assign stage = stage_i;
assign exc   = exc_i;

// Suppress unused signal warnings
wire unused0 = clk_i;
wire unused1 = reset_i;

// Submodule connections
logic [reg_data_width_lp-1:0] pc_plus4;
logic [reg_data_width_lp-1:0] src1;
logic [reg_data_width_lp-1:0] src2;
logic [reg_data_width_lp-1:0] baddr;
logic [reg_data_width_lp-1:0] alu_result;
logic [reg_data_width_lp-1:0] result;
logic [reg_data_width_lp-1:0] addr_calc_result;
logic                         branch_taken;

logic [reg_data_width_lp-1:0] mhartid;

/* TODO: Make hardcored and not parameter */
assign mhartid = mhartid_p;

// Module instantiations
bsg_mux #(.width_p(reg_data_width_lp)
          ,.els_p(2)
          )
 src1_mux(.data_i({stage.instr_metadata.pc, stage.instr_operands.rs1})
          ,.sel_i(stage.decode.src1_sel)
          ,.data_o(src1)
          );

bsg_mux #(.width_p(reg_data_width_lp)
          ,.els_p(2)
          )
 src2_mux(.data_i({stage.instr_operands.imm, stage.instr_operands.rs2})
          ,.sel_i(stage.decode.src2_sel)
          ,.data_o(src2)
          );

bsg_mux #(.width_p(reg_data_width_lp)
          ,.els_p(2)
          )
baddr_mux(.data_i({src1, stage.instr_metadata.pc})
          ,.sel_i(stage.decode.baddr_sel)
          ,.data_o(baddr)
          );

 bsg_mux #(.width_p(reg_data_width_lp)
           ,.els_p(2)
           )
result_mux(.data_i({pc_plus4, alu_result})
           ,.sel_i(stage.decode.result_sel)
           ,.data_o(result)
           );

bsg_mux #(.width_p(reg_data_width_lp)
          ,.els_p(2)
          )
  csr_mux(.data_i({mhartid, result})
          ,.sel_i(stage.decode.mhartid_r_v)
          ,.data_o(result_o)
          );

/* TODO: This mux may be made unnecessary, since we're selecting between btgt and 
 *        pc_plus4 in checker, as well 
 */
bsg_mux #(.width_p(reg_data_width_lp)
          ,.els_p(2)
          )
 btgt_mux(.data_i({addr_calc_result, pc_plus4})
          ,.sel_i(stage.decode.jmp_v || (stage.decode.br_v & alu_result[0]))
          ,.data_o(br_tgt_o)
          );

bp_be_int_alu #()
            alu(.src1_i(src1)
                ,.src2_i(src2)
                ,.op_i(stage.decode.fu_op)
                ,.op32_v_i(stage.decode.op32_v)
                ,.toggle_v_i(stage.decode.toggle_v)

                ,.result_o(alu_result)
                );

bsg_adder_ripple_carry #(.width_p(reg_data_width_lp)
                         )
              addr_calc (.a_i(baddr)
                         ,.b_i(stage.instr_operands.imm)
                         ,.s_o(addr_calc_result)
                         ,.c_o(/* No overflow is detected in RV */)
                         );

bsg_adder_ripple_carry #(.width_p(reg_data_width_lp)
                         )
           pc_plus4_calc(.a_i(stage.instr_metadata.pc)
                         ,.b_i({{(reg_data_width_lp-3){1'b0}},{3'b100}})
                         ,.s_o(pc_plus4)
                         ,.c_o(/* No overflow is detected in RV */)
                        );

endmodule : bp_be_pipe_int

