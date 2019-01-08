/**
 *
 * bp_be_pipe_mul.v
 *
 */

`include "bsg_defines.v"
`include "bp_be_internal_if.vh"

module bp_be_pipe_mul
 #(parameter vaddr_width_p="inv"
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
   );

// Declare parameterizable types
`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   );

// Cast input and output ports 
bp_be_pipe_stage_reg_s stage;

assign stage = stage_i;

// Suppress unused signal warnings
wire unused0 = clk_i;
wire unused1 = reset_i;
wire unused2 = exc_i;

// Submodule connections

// Module instantiations

always_comb begin
    result_o = '0;
end 

endmodule : bp_be_pipe_mul

