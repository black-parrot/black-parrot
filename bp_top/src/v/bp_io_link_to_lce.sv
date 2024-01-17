
/*
 * Name:
 *   bp_io_link_to_lce.sv
 *
 * Description:
 *   This module converts IO Command messages to LCE Requests and IO Response
 *   messages to LCE Commands. This module only supports uncached accesses.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"
`include "bp_top_defines.svh"

module bp_io_link_to_lce
 import bp_common_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)

   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam dma_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(dma_noc_flit_width_p)
   )
  (input                                            clk_i
   , input                                          reset_i

   , input [lce_id_width_p-1:0]                     lce_id_i

   // Bedrock Burst: ready&valid
   , input [mem_fwd_header_width_lp-1:0]            mem_fwd_header_i
   , input [bedrock_fill_width_p-1:0]               mem_fwd_data_i
   , input                                          mem_fwd_v_i
   , output logic                                   mem_fwd_ready_and_o

   , output logic [mem_rev_header_width_lp-1:0]     mem_rev_header_o
   , output logic [bedrock_fill_width_p-1:0]        mem_rev_data_o
   , output logic                                   mem_rev_v_o
   , input                                          mem_rev_ready_and_i

   , output logic [lce_req_header_width_lp-1:0]     lce_req_header_o
   , output logic [bedrock_fill_width_p-1:0]        lce_req_data_o
   , output logic                                   lce_req_v_o
   , input                                          lce_req_ready_and_i

   , input [lce_cmd_header_width_lp-1:0]            lce_cmd_header_i
   , input [bedrock_fill_width_p-1:0]               lce_cmd_data_i
   , input                                          lce_cmd_v_i
   , output logic                                   lce_cmd_ready_and_o
   );

  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);
  `bp_cast_i(bp_bedrock_mem_fwd_header_s, mem_fwd_header);
  `bp_cast_o(bp_bedrock_mem_rev_header_s, mem_rev_header);
  `bp_cast_o(bp_bedrock_lce_req_header_s, lce_req_header);
  `bp_cast_i(bp_bedrock_lce_cmd_header_s, lce_cmd_header);

  bp_bedrock_mem_fwd_header_s fsm_fwd_header_lo;
  logic [bedrock_fill_width_p-1:0] fsm_fwd_data_lo;
  logic fsm_fwd_v_lo, fsm_fwd_yumi_li;
  logic [paddr_width_p-1:0] fsm_fwd_addr_lo;
  logic fsm_fwd_new_lo, fsm_fwd_critical_lo, fsm_fwd_last_lo;
  bp_me_stream_pump_in
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(bedrock_fill_width_p)
     ,.payload_width_p(mem_fwd_payload_width_lp)
     ,.msg_stream_mask_p(mem_fwd_stream_mask_gp)
     ,.fsm_stream_mask_p(mem_fwd_stream_mask_gp)
     )
   fwd_pump_in
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(mem_fwd_header_cast_i)
     ,.msg_data_i(mem_fwd_data_i)
     ,.msg_v_i(mem_fwd_v_i)
     ,.msg_ready_and_o(mem_fwd_ready_and_o)

     ,.fsm_header_o(fsm_fwd_header_lo)
     ,.fsm_data_o(fsm_fwd_data_lo)
     ,.fsm_v_o(fsm_fwd_v_lo)
     ,.fsm_yumi_i(fsm_fwd_yumi_li)
     ,.fsm_addr_o(fsm_fwd_addr_lo)
     ,.fsm_new_o(fsm_fwd_new_lo)
     ,.fsm_critical_o(fsm_fwd_critical_lo)
     ,.fsm_last_o(fsm_fwd_last_lo)
     );

  bp_bedrock_lce_req_header_s fsm_req_header_li;
  logic [bedrock_fill_width_p-1:0] fsm_req_data_li;
  logic fsm_req_v_li, fsm_req_ready_then_lo;
  logic [paddr_width_p-1:0] fsm_req_addr_lo;
  logic fsm_req_new_lo, fsm_req_critical_lo, fsm_req_last_lo;
  bp_me_stream_pump_out
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(bedrock_fill_width_p)
     ,.payload_width_p(lce_req_payload_width_lp)
     ,.msg_stream_mask_p(lce_req_stream_mask_gp)
     ,.fsm_stream_mask_p(lce_req_stream_mask_gp)
     )
   req_pump_out
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_o(lce_req_header_cast_o)
     ,.msg_data_o(lce_req_data_o)
     ,.msg_v_o(lce_req_v_o)
     ,.msg_ready_and_i(lce_req_ready_and_i)

     ,.fsm_header_i(fsm_req_header_li)
     ,.fsm_data_i(fsm_req_data_li)
     ,.fsm_v_i(fsm_req_v_li)
     ,.fsm_ready_then_o(fsm_req_ready_then_lo)
     ,.fsm_addr_o(fsm_req_addr_lo)
     ,.fsm_new_o(fsm_req_new_lo)
     ,.fsm_critical_o(fsm_req_critical_lo)
     ,.fsm_last_o(fsm_req_last_lo)
     );

  bp_bedrock_lce_cmd_header_s fsm_cmd_header_lo;
  logic [bedrock_fill_width_p-1:0] fsm_cmd_data_lo;
  logic fsm_cmd_v_lo, fsm_cmd_yumi_li;
  logic [paddr_width_p-1:0] fsm_cmd_addr_lo;
  logic fsm_cmd_new_lo, fsm_cmd_critical_lo, fsm_cmd_last_lo;
  bp_me_stream_pump_in
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(bedrock_fill_width_p)
     ,.payload_width_p(lce_cmd_payload_width_lp)
     ,.msg_stream_mask_p(lce_cmd_stream_mask_gp)
     ,.fsm_stream_mask_p(lce_cmd_stream_mask_gp)
     )
   cmd_pump_in
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(lce_cmd_header_cast_i)
     ,.msg_data_i(lce_cmd_data_i)
     ,.msg_v_i(lce_cmd_v_i)
     ,.msg_ready_and_o(lce_cmd_ready_and_o)

     ,.fsm_header_o(fsm_cmd_header_lo)
     ,.fsm_data_o(fsm_cmd_data_lo)
     ,.fsm_v_o(fsm_cmd_v_lo)
     ,.fsm_yumi_i(fsm_cmd_yumi_li)
     ,.fsm_addr_o(fsm_cmd_addr_lo)
     ,.fsm_new_o(fsm_cmd_new_lo)
     ,.fsm_critical_o(fsm_cmd_critical_lo)
     ,.fsm_last_o(fsm_cmd_last_lo)
     );

  bp_bedrock_mem_rev_header_s fsm_rev_header_li;
  logic [bedrock_fill_width_p-1:0] fsm_rev_data_li;
  logic fsm_rev_v_li, fsm_rev_ready_then_lo;
  logic [paddr_width_p-1:0] fsm_rev_addr_lo;
  logic fsm_rev_new_lo, fsm_rev_critical_lo, fsm_rev_last_lo;
  bp_me_stream_pump_out
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(bedrock_fill_width_p)
     ,.payload_width_p(mem_rev_payload_width_lp)
     ,.msg_stream_mask_p(mem_rev_stream_mask_gp)
     ,.fsm_stream_mask_p(mem_rev_stream_mask_gp)
     )
   rev_pump_out
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_o(mem_rev_header_cast_o)
     ,.msg_data_o(mem_rev_data_o)
     ,.msg_v_o(mem_rev_v_o)
     ,.msg_ready_and_i(mem_rev_ready_and_i)

     ,.fsm_header_i(fsm_rev_header_li)
     ,.fsm_data_i(fsm_rev_data_li)
     ,.fsm_v_i(fsm_rev_v_li)
     ,.fsm_ready_then_o(fsm_rev_ready_then_lo)
     ,.fsm_addr_o(fsm_rev_addr_lo)
     ,.fsm_new_o(fsm_rev_new_lo)
     ,.fsm_critical_o(fsm_rev_critical_lo)
     ,.fsm_last_o(fsm_rev_last_lo)
     );

  logic [cce_id_width_p-1:0] cce_id_lo;
  bp_me_addr_to_cce_id
   #(.bp_params_p(bp_params_p))
   addr_map
    (.paddr_i(fsm_fwd_header_lo.addr)
     ,.cce_id_o(cce_id_lo)
     );

  wire mem_fwd_wr_not_rd = (fsm_fwd_header_lo.msg_type == e_bedrock_mem_wr);
  wire lce_cmd_wr_not_rd = (fsm_cmd_header_lo.msg_type == e_bedrock_cmd_uc_st_done);
  always_comb
    begin
      fsm_req_header_li.msg_type        = mem_fwd_wr_not_rd ? e_bedrock_req_uc_wr : e_bedrock_req_uc_rd;
      fsm_req_header_li.subop           = e_bedrock_store; // TODO: support I/O AMOs
      fsm_req_header_li.addr            = fsm_fwd_header_lo.addr;
      fsm_req_header_li.size            = fsm_fwd_header_lo.size;
      fsm_req_header_li.payload         = '0;
      fsm_req_header_li.payload.src_id  = lce_id_i;
      fsm_req_header_li.payload.dst_id  = cce_id_lo;
      fsm_req_header_li.payload.src_did = fsm_fwd_header_lo.payload.src_did;
      fsm_req_data_li                   = fsm_fwd_data_lo;
      fsm_req_v_li                      = fsm_req_ready_then_lo & fsm_fwd_v_lo;
      fsm_fwd_yumi_li                   = fsm_req_v_li;

      fsm_rev_header_li.msg_type        = lce_cmd_wr_not_rd ? e_bedrock_mem_wr : e_bedrock_mem_rd;
      fsm_rev_header_li.subop           = e_bedrock_store; // TODO: support I/O AMOs
      fsm_rev_header_li.addr            = fsm_cmd_header_lo.addr;
      fsm_rev_header_li.size            = fsm_cmd_header_lo.size;
      fsm_rev_header_li.payload         = '0;
      fsm_rev_header_li.payload.src_did = fsm_cmd_header_lo.payload.src_did;
      fsm_rev_data_li                   = fsm_cmd_data_lo;
      fsm_rev_v_li                      = fsm_rev_ready_then_lo & fsm_cmd_v_lo;
      fsm_cmd_yumi_li                   = fsm_rev_v_li;
    end

endmodule

