
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
   `declare_bp_bedrock_lce_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                            clk_i
   , input                                          reset_i

   , input [lce_id_width_p-1:0]                     lce_id_i

   // Bedrock Burst: ready&valid
   , input [mem_fwd_header_width_lp-1:0]            io_fwd_header_i
   , input                                          io_fwd_header_v_i
   , output logic                                   io_fwd_header_ready_and_o
   , input                                          io_fwd_has_data_i
   , input [bedrock_data_width_p-1:0]               io_fwd_data_i
   , input                                          io_fwd_data_v_i
   , output logic                                   io_fwd_data_ready_and_o
   , input                                          io_fwd_last_i

   , output logic [mem_rev_header_width_lp-1:0]     io_rev_header_o
   , output logic                                   io_rev_header_v_o
   , input                                          io_rev_header_ready_and_i
   , output logic                                   io_rev_has_data_o
   , output logic [bedrock_data_width_p-1:0]        io_rev_data_o
   , output logic                                   io_rev_data_v_o
   , input                                          io_rev_data_ready_and_i
   , output logic                                   io_rev_last_o

   , output logic [lce_req_header_width_lp-1:0]     lce_req_header_o
   , output logic                                   lce_req_header_v_o
   , input                                          lce_req_header_ready_and_i
   , output logic                                   lce_req_has_data_o
   , output logic [bedrock_data_width_p-1:0]        lce_req_data_o
   , output logic                                   lce_req_data_v_o
   , input                                          lce_req_data_ready_and_i
   , output logic                                   lce_req_last_o

   , input [lce_cmd_header_width_lp-1:0]            lce_cmd_header_i
   , input                                          lce_cmd_header_v_i
   , output logic                                   lce_cmd_header_ready_and_o
   , input                                          lce_cmd_has_data_i
   , input [bedrock_data_width_p-1:0]               lce_cmd_data_i
   , input                                          lce_cmd_data_v_i
   , output logic                                   lce_cmd_data_ready_and_o
   , input                                          lce_cmd_last_i
   );

  `declare_bp_bedrock_lce_if(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p);
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `bp_cast_i(bp_bedrock_mem_fwd_header_s, io_fwd_header);
  `bp_cast_o(bp_bedrock_mem_rev_header_s, io_rev_header);
  `bp_cast_o(bp_bedrock_lce_req_header_s, lce_req_header);
  `bp_cast_i(bp_bedrock_lce_cmd_header_s, lce_cmd_header);

  // Payload buffer
  // consumed with header handshake
  // ready THEN valid on input
  bp_bedrock_mem_rev_payload_s io_rev_payload;
  logic payload_v_li, payload_ready_lo, payload_v_lo, payload_yumi_li;
  bsg_fifo_1r1w_small
   #(.width_p($bits(io_fwd_header_cast_i.payload))
     ,.els_p(io_noc_max_credits_p)
     ,.ready_THEN_valid_p(1)
     )
   payload_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(io_fwd_header_cast_i.payload)
     ,.v_i(payload_v_li)
     ,.ready_o(payload_ready_lo)

     ,.data_o(io_rev_payload)
     ,.v_o(payload_v_lo)
     ,.yumi_i(payload_yumi_li)
     );

  // IO Cmd to LCE Req and payload buffer input
  // header transaction only occurs if buffer has space for a payload
  assign lce_req_header_v_o        = io_fwd_header_v_i & payload_ready_lo;
  assign io_fwd_header_ready_and_o = lce_req_header_ready_and_i & payload_ready_lo;
  assign payload_v_li              = lce_req_header_v_o & io_fwd_header_ready_and_o;
  // data connected directly
  assign lce_req_data_v_o          = io_fwd_data_v_i;
  assign io_fwd_data_ready_and_o   = lce_req_data_ready_and_i;

  // LCE cmd to IO Resp and payload buffer output
  // header handshake consumes payload from buffer
  assign io_rev_header_v_o          = lce_cmd_header_v_i & payload_v_lo;
  assign lce_cmd_header_ready_and_o  = io_rev_header_ready_and_i & payload_v_lo;
  assign payload_yumi_li             = io_rev_header_v_o & io_rev_header_ready_and_i;
  // data connected directly
  assign io_rev_data_v_o            = lce_cmd_data_v_i;
  assign lce_cmd_data_ready_and_o    = io_rev_data_ready_and_i;

  logic [cce_id_width_p-1:0] cce_id_lo;
  bp_me_addr_to_cce_id
   #(.bp_params_p(bp_params_p))
   addr_map
    (.paddr_i(io_fwd_header_cast_i.addr)
     ,.cce_id_o(cce_id_lo)
     );

  wire io_fwd_wr_not_rd = (io_fwd_header_cast_i.msg_type == e_bedrock_mem_uc_wr);
  wire lce_cmd_wr_not_rd = (lce_cmd_header_cast_i.msg_type == e_bedrock_cmd_uc_st_done);
  always_comb
    begin
      lce_req_header_cast_o                = '0;
      lce_req_header_cast_o.size           = io_fwd_header_cast_i.size;
      lce_req_header_cast_o.addr           = io_fwd_header_cast_i.addr;
      lce_req_header_cast_o.msg_type       = io_fwd_wr_not_rd ? e_bedrock_req_uc_wr : e_bedrock_req_uc_rd;
      lce_req_header_cast_o.payload.src_id = lce_id_i;
      lce_req_header_cast_o.payload.dst_id = cce_id_lo;
      lce_req_has_data_o                   = io_fwd_has_data_i;
      lce_req_data_o                       = io_fwd_data_i;
      lce_req_last_o                       = io_fwd_last_i;

      io_rev_header_cast_o          = '0;
      io_rev_header_cast_o.size     = lce_cmd_header_cast_i.size;
      io_rev_header_cast_o.addr     = lce_cmd_header_cast_i.addr;
      io_rev_header_cast_o.msg_type = lce_cmd_wr_not_rd ? e_bedrock_mem_uc_wr : e_bedrock_mem_uc_rd;
      io_rev_header_cast_o.payload  = io_rev_payload;
      io_rev_has_data_o             = lce_cmd_has_data_i;
      io_rev_data_o                 = lce_cmd_data_i;
      io_rev_last_o                 = lce_cmd_last_i;
    end

endmodule

