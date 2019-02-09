/**
 *
 * bp_be_nonsynth_mock_top_wrapper_tb.v
 *
 */

`include "bsg_defines.v"

`include "bp_common_fe_be_if.vh"
`include "bp_common_me_if.vh"

`include "bp_be_internal_if.vh"

/* TODO: replace hardcored values in the build system. */

`define HC_VADDR_WIDTH 39
`define HC_PADDR_WIDTH 56
`define HC_ASID_WIDTH 10
`define HC_BRANCH_METADATA_FWD_WIDTH 10
`define HC_COH_STATES 2
`define HC_NUM_LCE 1
`define HC_NUM_CCE 1
`define HC_LCE_ASSOC 1
`define HC_LCE_ADDR_WIDTH 56
`define HC_LCE_DATA_WIDTH 256
`define HC_MOCK_MEM_FILE "../isa/rv64ui-p-addi.hex"
`define HC_MOCK_MEM_ELS 8192

module bp_be_nonsynth_mock_top_wrapper_tb
 #(parameter vaddr_width_p=`HC_VADDR_WIDTH
   ,parameter paddr_width_p=`HC_PADDR_WIDTH
   ,parameter asid_width_p=`HC_ASID_WIDTH
   ,parameter branch_metadata_fwd_width_p=`HC_BRANCH_METADATA_FWD_WIDTH
   ,parameter num_cce_p=`HC_NUM_CCE
   ,parameter num_lce_p=`HC_NUM_LCE
   ,parameter lce_assoc_p=`HC_LCE_ASSOC
   ,parameter lce_addr_width_p=`HC_LCE_ADDR_WIDTH
   ,parameter lce_data_width_p=`HC_LCE_DATA_WIDTH
 
   ,parameter mock_mem_file_p=`HC_MOCK_MEM_FILE
   ,parameter mock_mem_els_p=`HC_MOCK_MEM_ELS
 );

logic clk, reset;

bsg_nonsynth_clock_gen #(.cycle_time_p(10)
                         )
              clock_gen (.o(clk)
                         );

bsg_nonsynth_reset_gen #(.num_clocks_p(1)
                         ,.reset_cycles_lo_p(1)
                         ,.reset_cycles_hi_p(9)
                         )
               reset_gen(.clk_i(clk)
                         ,.async_reset_o(reset)
                         );

bp_be_nonsynth_mock_top_wrapper #(.vaddr_width_p(vaddr_width_p)
                                  ,.paddr_width_p(paddr_width_p)
                                  ,.asid_width_p(asid_width_p)
                                  ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
                                  ,.num_cce_p(num_cce_p)
                                  ,.num_lce_p(num_lce_p)
                                  ,.lce_assoc_p(lce_assoc_p)
                                  ,.lce_addr_width_p(lce_addr_width_p)
                                  ,.lce_data_width_p(lce_data_width_p)

                                  ,.mock_mem_file_p(mock_mem_file_p)
                                  ,.mock_mem_els_p(mock_mem_els_p)
                                  )
                              DUT(.clk_i(clk)
                                  ,.reset_i(reset)
                                  );


endmodule : bp_be_nonsynth_mock_top_wrapper_tb

