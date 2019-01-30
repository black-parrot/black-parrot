
package bp_be_pkg;

  import bp_common_pkg::*;
  import bp_be_rv64_pkg::*;

  `include "bp_be_ucode_defines.vh"
  `include "bp_be_internal_if_defines.vh"

  localparam bp_pc_entry_point_gp    = 32'h80000124;
  localparam bp_be_itag_width_gp     = 32;
  localparam bp_be_pipe_stage_els_gp = 5;

  typedef struct packed                         
  {                                             
    bp_be_fu_op_s                     mem_op;   
    logic[rv64_eaddr_width_gp-1:0]    addr;     
    logic[rv64_reg_data_width_gp-1:0] data;     
  }  bp_be_mmu_cmd_s;                           
                                                
  typedef struct packed                         
  {                                             
    logic[rv64_reg_data_width_gp-1:0] data;     
    bp_be_exception_s                 exception;
  }  bp_be_mmu_resp_s;                          

`define bp_be_mmu_cmd_width                                                                        \
  ($bits(bp_be_mmu_cmd_s))

`define bp_be_mmu_resp_width                                                                       \
  ($bits(bp_be_mmu_resp_s))

endpackage : bp_be_pkg

