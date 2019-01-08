/**
 *
 * bp_be_pipe_mem.v
 *
 */

`include "bsg_defines.v"
`include "bp_be_internal_if.vh"

module bp_be_pipe_mem 
 #(parameter vaddr_width_p="inv"
   , parameter paddr_width_p="inv"
   , parameter asid_width_p="inv"
   , parameter branch_metadata_fwd_width_p="inv"

   , localparam pipe_stage_reg_width_lp=`bp_be_pipe_stage_reg_width(branch_metadata_fwd_width_p)
   , localparam exception_width_lp=`bp_be_exception_width

   , localparam mmu_cmd_width_lp=`bp_be_mmu_cmd_width
   , localparam mmu_resp_width_lp=`bp_be_mmu_resp_width

   , localparam reg_data_width_lp=RV64_reg_data_width_gp
   )
  (input logic                                clk_i
   , input logic                              reset_i

   , input logic[pipe_stage_reg_width_lp-1:0] stage_i
   , input logic[exception_width_lp-1:0]      exc_i

   , output logic[reg_data_width_lp-1:0]      result_o

   , output logic[mmu_cmd_width_lp-1:0]       mmu_cmd_o
   , output logic                             mmu_cmd_v_o
   , input logic                              mmu_cmd_rdy_i

   , input logic[mmu_resp_width_lp-1:0]       mmu_resp_i
   , input logic                              mmu_resp_v_i
   , output logic                             mmu_resp_rdy_o

   , output logic                             cache_miss_o
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
bp_be_mmu_cmd_s        mmu_cmd;
bp_be_mmu_resp_s       mmu_resp;

assign stage     = stage_i;
assign exc       = exc_i;
assign mmu_cmd_o = mmu_cmd;
assign mmu_resp  = mmu_resp_i;

// Suppress unused signal warnings
wire unused0 = clk_i;
wire unused1 = reset_i;
wire unused2 = mmu_cmd_rdy_i;

// Submodule connections
logic[reg_data_width_lp-1:0] addr_calc_result;

// Module instantiations
bsg_adder_ripple_carry #(.width_p(reg_data_width_lp)
                         )
            daddr_calc (.a_i(stage.instr_operands.rs1)
                         ,.b_i(stage.instr_operands.imm)
                         ,.s_o(addr_calc_result)
                         ,.c_o(/* No overflow is detected in RV */)
                         );

always_comb begin
    mmu_cmd.mem_op = stage.decode.fu_op;
    mmu_cmd.data   = stage.instr_operands.rs2;
    mmu_cmd.addr   = addr_calc_result;
    mmu_cmd_v_o    = (stage.decode.dcache_r_v | stage.decode.dcache_w_v)
                     & ~|exc;

    mmu_resp_rdy_o = 1'b1;
    result_o       = mmu_resp.data;

    cache_miss_o   = mmu_resp.exception.cache_miss_v;
end 

endmodule : bp_be_pipe_mem

