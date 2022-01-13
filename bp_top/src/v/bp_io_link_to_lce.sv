
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
   `declare_bp_bedrock_lce_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p, cce)

   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                            clk_i
   , input                                          reset_i

   , input [lce_id_width_p-1:0]                     lce_id_i

   , input [cce_mem_header_width_lp-1:0]            io_cmd_header_i
   , input [cce_block_width_p-1:0]                  io_cmd_data_i
   , input                                          io_cmd_v_i
   , input                                          io_cmd_last_i
   , output logic                                   io_cmd_yumi_o

   , output logic [cce_mem_header_width_lp-1:0]     io_resp_header_o
   , output logic [cce_block_width_p-1:0]           io_resp_data_o
   , output logic                                   io_resp_v_o
   , output logic                                   io_resp_last_o
   , input                                          io_resp_ready_then_i

   , output logic [lce_req_header_width_lp-1:0]     lce_req_header_o
   , output logic [cce_block_width_p-1:0]           lce_req_data_o
   , output logic                                   lce_req_v_o
   , input                                          lce_req_ready_then_i

   , input [lce_cmd_header_width_lp-1:0]            lce_cmd_header_i
   , input [cce_block_width_p-1:0]                  lce_cmd_data_i
   , input                                          lce_cmd_v_i
   , output                                         lce_cmd_yumi_o

   // No lce_resp acknowledgements for I/O (uncached) accesses
   );

  `declare_bp_bedrock_lce_if(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce);
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p, cce);
  `bp_cast_i(bp_bedrock_cce_mem_header_s, io_cmd_header);
  `bp_cast_o(bp_bedrock_cce_mem_header_s, io_resp_header);
  `bp_cast_o(bp_bedrock_lce_req_header_s, lce_req_header);
  `bp_cast_i(bp_bedrock_lce_req_header_s, lce_cmd_header);

  // TODO: This implementation only works for burst length == 1, like the
  //   rest of this module
  bp_bedrock_cce_mem_payload_s io_resp_payload, io_resp_size;
  logic payload_ready_lo, payload_v_lo;
  bsg_fifo_1r1w_small
   #(.width_p($bits(bp_bedrock_cce_mem_payload_s)), .els_p(io_noc_max_credits_p))
   payload_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(io_cmd_header_cast_i.payload)
     ,.v_i(io_cmd_yumi_o)
     ,.ready_o(payload_ready_lo)

     ,.data_o(io_resp_payload)
     ,.v_o(payload_v_lo)
     ,.yumi_i(io_resp_v_o)
     );

  assign lce_req_v_o    = lce_req_ready_then_i & io_cmd_v_i & payload_ready_lo;
  assign io_cmd_yumi_o  = lce_req_v_o;

  assign io_resp_v_o    = io_resp_ready_then_i & lce_cmd_v_i & payload_v_lo;
  assign lce_cmd_yumi_o = io_resp_v_o;
  assign io_resp_last_o = io_resp_v_o; // stub

  logic [cce_id_width_p-1:0] cce_id_lo;
  bp_me_addr_to_cce_id
   #(.bp_params_p(bp_params_p))
   addr_map
    (.paddr_i(io_cmd_header_cast_i.addr)

     ,.cce_id_o(cce_id_lo)
     );

  wire io_cmd_wr_not_rd = (io_cmd_header_cast_i.msg_type == e_bedrock_mem_uc_wr);
  wire lce_cmd_wr_not_rd = (lce_cmd_header_cast_i.msg_type == e_bedrock_cmd_uc_st_done);
  always_comb
    begin
      lce_req_header_cast_o                = '0;
      lce_req_data_o                       = io_cmd_data_i;
      lce_req_header_cast_o.size           = io_cmd_header_cast_i.size;
      lce_req_header_cast_o.addr           = io_cmd_header_cast_i.addr;
      lce_req_header_cast_o.msg_type       = io_cmd_wr_not_rd ? e_bedrock_req_uc_wr : e_bedrock_req_uc_rd;
      lce_req_header_cast_o.payload.src_id = lce_id_i;
      lce_req_header_cast_o.payload.dst_id = cce_id_lo;

      io_resp_header_cast_o          = '0;
      io_resp_data_o                 = lce_cmd_data_i;
      io_resp_header_cast_o.size     = lce_cmd_header_cast_i.size;
      io_resp_header_cast_o.addr     = lce_cmd_header_cast_i.addr;
      io_resp_header_cast_o.msg_type = lce_cmd_wr_not_rd ? e_bedrock_mem_uc_wr : e_bedrock_mem_uc_rd;
      io_resp_header_cast_o.payload  = io_resp_payload;
    end

endmodule

