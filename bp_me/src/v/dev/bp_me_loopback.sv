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
    , parameter `BSG_INV_PARAM(data_width_p)
    )
   (input                                            clk_i
    , input                                          reset_i

    , input [mem_fwd_header_width_lp-1:0]            mem_fwd_header_i
    , input [data_width_p-1:0]                       mem_fwd_data_i
    , input                                          mem_fwd_v_i
    , output logic                                   mem_fwd_ready_and_o

    , output logic [mem_rev_header_width_lp-1:0]     mem_rev_header_o
    , output logic [data_width_p-1:0]                mem_rev_data_o
    , output logic                                   mem_rev_v_o
    , input                                          mem_rev_ready_and_i
    );

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `bp_cast_i(bp_bedrock_mem_fwd_header_s, mem_fwd_header);
  `bp_cast_o(bp_bedrock_mem_rev_header_s, mem_rev_header);

  bp_bedrock_mem_fwd_header_s fsm_fwd_header_li;
  logic [data_width_p-1:0] fsm_fwd_data_li;
  logic fsm_fwd_v_li, fsm_fwd_yumi_lo;
  bp_me_stream_pump_in
   #(.bp_params_p(bp_params_p)
     ,.stream_data_width_p(data_width_p)
     ,.block_width_p(bedrock_block_width_p)
     ,.payload_width_p(mem_fwd_payload_width_lp)
     ,.msg_stream_mask_p(mem_fwd_payload_mask_gp)
     ,.fsm_stream_mask_p(mem_fwd_payload_mask_gp | mem_rev_payload_mask_gp)
     )
   fwd_pump_in
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(mem_fwd_header_cast_i)
     ,.msg_data_i(mem_fwd_data_i)
     ,.msg_v_i(mem_fwd_v_i)
     ,.msg_ready_and_o(mem_fwd_ready_and_o)

     ,.fsm_header_o(fsm_fwd_header_li)
     ,.fsm_data_o(fsm_fwd_data_li)
     ,.fsm_v_o(fsm_fwd_v_li)
     ,.fsm_yumi_i(fsm_fwd_yumi_lo)
     ,.fsm_addr_o()
     ,.fsm_cnt_o()
     ,.fsm_new_o()
     ,.fsm_last_o()
     );

  bp_bedrock_mem_rev_header_s fsm_rev_header_lo;
  logic [data_width_p-1:0] fsm_rev_data_lo;
  logic fsm_rev_yumi_li, fsm_rev_v_lo;
  bp_me_stream_pump_out
   #(.bp_params_p(bp_params_p)
     ,.stream_data_width_p(data_width_p)
     ,.block_width_p(bedrock_block_width_p)
     ,.payload_width_p(mem_rev_payload_width_lp)
     ,.msg_stream_mask_p(mem_rev_payload_mask_gp)
     ,.fsm_stream_mask_p(mem_fwd_payload_mask_gp | mem_rev_payload_mask_gp)
     )
   rev_pump_out
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_o(mem_rev_header_cast_o)
     ,.msg_data_o(mem_rev_data_o)
     ,.msg_v_o(mem_rev_v_o)
     ,.msg_ready_and_i(mem_rev_ready_and_i)

     ,.fsm_header_i(fsm_fwd_header_li)
     ,.fsm_data_i(fsm_fwd_data_li)
     ,.fsm_v_i(fsm_fwd_v_li)
     ,.fsm_yumi_o(fsm_fwd_yumi_lo)
     ,.fsm_addr_o()
     ,.fsm_cnt_o()
     ,.fsm_new_o()
     ,.fsm_last_o()
     );

endmodule

