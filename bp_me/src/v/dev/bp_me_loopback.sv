/**
 *
 * Name:
 *   bp_me_loopback.sv
 *
 * Description:
 *   This module is an active tie-off. That is, requests to this module will return the header
 *   with a zero payload. This is useful to not stall the network in the case of an erroneous
 *   address, or prevent deadlock at network boundaries
 *
 */
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_loopback
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)
    )
   (input                                            clk_i
    , input                                          reset_i

    , input [mem_fwd_header_width_lp-1:0]            mem_fwd_header_i
    , input [dword_width_gp-1:0]                     mem_fwd_data_i
    , input                                          mem_fwd_v_i
    , output logic                                   mem_fwd_ready_and_o
    , input logic                                    mem_fwd_last_i

    , output logic [mem_rev_header_width_lp-1:0]     mem_rev_header_o
    , output logic [dword_width_gp-1:0]              mem_rev_data_o
    , output logic                                   mem_rev_v_o
    , input                                          mem_rev_ready_and_i
    , output logic                                   mem_rev_last_o
    );

  wire unused = &{mem_fwd_data_i};

  // Used to decouple to help prevent deadlock
  logic mem_rev_last_lo;
  bsg_one_fifo
   #(.width_p(1+mem_fwd_header_width_lp))
   loopback_buffer
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({mem_fwd_last_i, mem_fwd_header_i})
     ,.v_i(mem_fwd_v_i)
     ,.ready_o(mem_fwd_ready_and_o)

     ,.data_o({mem_rev_last_lo, mem_rev_header_o})
     ,.v_o(mem_rev_v_o)
     ,.yumi_i(mem_rev_ready_and_i & mem_rev_v_o)
     );
  assign mem_rev_data_o = '0;
  assign mem_rev_last_o = mem_rev_v_o & mem_rev_last_lo;

endmodule

