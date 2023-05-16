
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
   , localparam dma_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(dma_noc_flit_width_p)
   )
  (input                                            clk_i
   , input                                          reset_i

   , input [lce_id_width_p-1:0]                     lce_id_i

   // Bedrock Burst: ready&valid
   , input [mem_fwd_header_width_lp-1:0]            io_fwd_header_i
   , input [bedrock_fill_width_p-1:0]               io_fwd_data_i
   , input                                          io_fwd_v_i
   , output logic                                   io_fwd_ready_and_o

   , output logic [mem_rev_header_width_lp-1:0]     io_rev_header_o
   , output logic [bedrock_fill_width_p-1:0]        io_rev_data_o
   , output logic                                   io_rev_v_o
   , input                                          io_rev_ready_and_i

   , output logic [lce_req_header_width_lp-1:0]     lce_req_header_o
   , output logic [bedrock_fill_width_p-1:0]        lce_req_data_o
   , output logic                                   lce_req_v_o
   , input                                          lce_req_ready_and_i

   , input [lce_cmd_header_width_lp-1:0]            lce_cmd_header_i
   , input [bedrock_fill_width_p-1:0]               lce_cmd_data_i
   , input                                          lce_cmd_v_i
   , output logic                                   lce_cmd_ready_and_o
   );

  `declare_bp_bedrock_lce_if(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p);
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `bp_cast_i(bp_bedrock_mem_fwd_header_s, io_fwd_header);
  `bp_cast_o(bp_bedrock_mem_rev_header_s, io_rev_header);
  `bp_cast_o(bp_bedrock_lce_req_header_s, lce_req_header);
  `bp_cast_i(bp_bedrock_lce_cmd_header_s, lce_cmd_header);

  bp_bedrock_mem_fwd_header_s [num_pseudo_cce_p-1:0] fifo_li;
  logic [num_pseudo_cce_p-1:0] fifo_v_li, fifo_ready_and_lo;
  bp_bedrock_mem_fwd_header_s [num_pseudo_cce_p-1:0] fifo_lo;
  logic [num_pseudo_cce_p-1:0] fifo_yumi_li;
  for (genvar i = 0; i < num_pseudo_cce_p; i++)
    begin : return_fifos
      bsg_fifo_1r1w_small
       #(.width_p($bits(bp_bedrock_mem_fwd_header_s)), .els_p(mem_noc_max_credits_p/num_pseudo_cce_p))
       fifo
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.data_i(fifo_li[i])
         ,.v_i(fifo_v_li[i])
         ,.ready_o(fifo_ready_and_lo[i])

         ,.data_o(fifo_lo[i])
         ,.v_o(/* Correct by construction */)
         ,.yumi_i(fifo_yumi_li[i])
         );
      assign fifo_li[i] = io_fwd_header_cast_i;
      assign fifo_v_li[i] = lce_req_ready_and_i & lce_req_v_o & (lce_req_header_cast_o.payload.dst_id == i);

      assign fifo_yumi_li[i] = io_rev_ready_and_i & io_rev_v_o & (lce_cmd_header_cast_i.payload.src_id == i);
    end
  assign io_rev_data_o = lce_cmd_data_i;
  assign io_rev_header_cast_o = fifo_lo[lce_cmd_header_cast_i.payload.src_id];
  assign io_rev_v_o = lce_cmd_v_i;
  assign lce_cmd_ready_and_o = io_rev_ready_and_i;

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
      // Require all payloads to be ready to maintain helpfulness
      io_fwd_ready_and_o                   = &fifo_ready_and_lo & lce_req_ready_and_i;
      lce_req_v_o                          = &fifo_ready_and_lo & io_fwd_v_i;
      lce_req_header_cast_o                = '0;
      lce_req_header_cast_o.size           = io_fwd_header_cast_i.size;
      lce_req_header_cast_o.addr           = io_fwd_header_cast_i.addr;
      lce_req_header_cast_o.msg_type       = io_fwd_wr_not_rd ? e_bedrock_req_uc_wr : e_bedrock_req_uc_rd;
      lce_req_header_cast_o.payload.src_id = lce_id_i;
      lce_req_header_cast_o.payload.dst_id = cce_id_lo;
      lce_req_data_o                       = io_fwd_data_i;
    end

endmodule

