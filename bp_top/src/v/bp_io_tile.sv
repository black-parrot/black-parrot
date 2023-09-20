
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"
`include "bp_top_defines.svh"

module bp_io_tile
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)

   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                          clk_i
   , input                                        reset_i

   , input [mem_noc_did_width_p-1:0]              my_did_i
   , input [mem_noc_did_width_p-1:0]              host_did_i
   , input [coh_noc_cord_width_p-1:0]             my_cord_i

   , input [coh_noc_ral_link_width_lp-1:0]        lce_req_link_i
   , output logic [coh_noc_ral_link_width_lp-1:0] lce_req_link_o

   , input [coh_noc_ral_link_width_lp-1:0]        lce_cmd_link_i
   , output logic [coh_noc_ral_link_width_lp-1:0] lce_cmd_link_o

   , input [mem_noc_ral_link_width_lp-1:0]         mem_fwd_link_i
   , output logic [mem_noc_ral_link_width_lp-1:0]  mem_fwd_link_o

   , input [mem_noc_ral_link_width_lp-1:0]         mem_rev_link_i
   , output logic [mem_noc_ral_link_width_lp-1:0]  mem_rev_link_o
   );

  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);
  `declare_bp_memory_map(paddr_width_p, daddr_width_p);

  `declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_noc_ready_and_link_sif_s);
  `bp_cast_i(bp_coh_noc_ready_and_link_sif_s, lce_req_link);
  `bp_cast_o(bp_coh_noc_ready_and_link_sif_s, lce_req_link);
  `bp_cast_i(bp_coh_noc_ready_and_link_sif_s, lce_cmd_link);
  `bp_cast_o(bp_coh_noc_ready_and_link_sif_s, lce_cmd_link);

  // I/O Link to LCE connections
  bp_bedrock_mem_fwd_header_s mem_fwd_header_li;
  logic [bedrock_fill_width_p-1:0] mem_fwd_data_li;
  logic mem_fwd_v_li, mem_fwd_ready_and_lo;

  bp_bedrock_mem_rev_header_s mem_rev_header_lo;
  logic [bedrock_fill_width_p-1:0] mem_rev_data_lo;
  logic mem_rev_v_lo, mem_rev_ready_and_li;

  bp_bedrock_lce_req_header_s lce_req_header_lo;
  logic [bedrock_fill_width_p-1:0] lce_req_data_lo;
  logic lce_req_v_lo, lce_req_ready_and_li;
  logic [coh_noc_cord_width_p-1:0] lce_req_dst_cord_lo;
  logic [coh_noc_cid_width_p-1:0] lce_req_dst_cid_lo;

  bp_bedrock_lce_cmd_header_s lce_cmd_header_li;
  logic [bedrock_fill_width_p-1:0] lce_cmd_data_li;
  logic lce_cmd_v_li, lce_cmd_ready_and_lo;

  // I/O CCE connections
  bp_bedrock_lce_cmd_header_s lce_cmd_header_lo;
  logic [bedrock_fill_width_p-1:0] lce_cmd_data_lo;
  logic lce_cmd_v_lo, lce_cmd_ready_and_li;
  logic [coh_noc_cord_width_p-1:0] lce_cmd_dst_cord_lo;
  logic [coh_noc_cid_width_p-1:0] lce_cmd_dst_cid_lo;

  bp_bedrock_lce_req_header_s lce_req_header_li;
  logic [bedrock_fill_width_p-1:0] lce_req_data_li;
  logic lce_req_v_li, lce_req_ready_and_lo;

  bp_bedrock_mem_fwd_header_s mem_fwd_header_lo;
  logic [bedrock_fill_width_p-1:0] mem_fwd_data_lo;
  logic mem_fwd_v_lo, mem_fwd_ready_and_li;

  bp_bedrock_mem_rev_header_s mem_rev_header_li;
  logic [bedrock_fill_width_p-1:0] mem_rev_data_li;
  logic mem_rev_v_li, mem_rev_ready_and_lo;

  logic reset_r;
  always_ff @(posedge clk_i)
    reset_r <= reset_i;

  logic [cce_id_width_p-1:0] cce_id_li;
  logic [lce_id_width_p-1:0] lce_id_li;
  bp_me_cord_to_id
   #(.bp_params_p(bp_params_p))
   id_map
    (.cord_i(my_cord_i)
     ,.core_id_o()
     ,.cce_id_o(cce_id_li)
     ,.lce_id0_o(lce_id_li)
     ,.lce_id1_o()
     );

  bp_io_link_to_lce
   #(.bp_params_p(bp_params_p))
   lce_link
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.lce_id_i(lce_id_li)

     ,.mem_fwd_header_i(mem_fwd_header_li)
     ,.mem_fwd_data_i(mem_fwd_data_li)
     ,.mem_fwd_v_i(mem_fwd_v_li)
     ,.mem_fwd_ready_and_o(mem_fwd_ready_and_lo)

     ,.mem_rev_header_o(mem_rev_header_lo)
     ,.mem_rev_data_o(mem_rev_data_lo)
     ,.mem_rev_v_o(mem_rev_v_lo)
     ,.mem_rev_ready_and_i(mem_rev_ready_and_li)

     ,.lce_req_header_o(lce_req_header_lo)
     ,.lce_req_data_o(lce_req_data_lo)
     ,.lce_req_v_o(lce_req_v_lo)
     ,.lce_req_ready_and_i(lce_req_ready_and_li)

     ,.lce_cmd_header_i(lce_cmd_header_li)
     ,.lce_cmd_data_i(lce_cmd_data_li)
     ,.lce_cmd_v_i(lce_cmd_v_li)
     ,.lce_cmd_ready_and_o(lce_cmd_ready_and_lo)
     );

  bp_io_cce
   #(.bp_params_p(bp_params_p))
   io_cce
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.cce_id_i(cce_id_li)

     ,.lce_req_header_i(lce_req_header_li)
     ,.lce_req_data_i(lce_req_data_li)
     ,.lce_req_v_i(lce_req_v_li)
     ,.lce_req_ready_and_o(lce_req_ready_and_lo)

     ,.lce_cmd_header_o(lce_cmd_header_lo)
     ,.lce_cmd_data_o(lce_cmd_data_lo)
     ,.lce_cmd_v_o(lce_cmd_v_lo)
     ,.lce_cmd_ready_and_i(lce_cmd_ready_and_li)

     ,.mem_fwd_header_o(mem_fwd_header_lo)
     ,.mem_fwd_data_o(mem_fwd_data_lo)
     ,.mem_fwd_v_o(mem_fwd_v_lo)
     ,.mem_fwd_ready_and_i(mem_fwd_ready_and_li)

     ,.mem_rev_header_i(mem_rev_header_li)
     ,.mem_rev_data_i(mem_rev_data_li)
     ,.mem_rev_v_i(mem_rev_v_li)
     ,.mem_rev_ready_and_o(mem_rev_ready_and_lo)
     );

  // LCE Req Link WH-Burst conversion
  bp_me_cce_id_to_cord
   #(.bp_params_p(bp_params_p))
   req_router_cord
    (.cce_id_i(lce_req_header_lo.payload.dst_id)
     ,.cce_cord_o(lce_req_dst_cord_lo)
     ,.cce_cid_o(lce_req_dst_cid_lo)
     );

  bp_me_stream_to_wormhole
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(coh_noc_flit_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.pr_hdr_width_p(lce_req_header_width_lp)
     ,.pr_payload_width_p(lce_req_payload_width_lp)
     ,.pr_stream_mask_p(lce_req_stream_mask_gp)
     ,.pr_data_width_p(bedrock_fill_width_p)
     )
   lce_req_stream_to_wh
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.pr_hdr_i(lce_req_header_lo)
     ,.pr_data_i(lce_req_data_lo)
     ,.pr_v_i(lce_req_v_lo)
     ,.pr_ready_and_o(lce_req_ready_and_li)
     ,.dst_cord_i(lce_req_dst_cord_lo)
     ,.dst_cid_i(lce_req_dst_cid_lo)

     ,.link_data_o(lce_req_link_cast_o.data)
     ,.link_v_o(lce_req_link_cast_o.v)
     ,.link_ready_and_i(lce_req_link_cast_i.ready_and_rev)
     );

  // WH to Burst (lce_req_header_li)
  bp_me_wormhole_to_stream
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(coh_noc_flit_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.pr_hdr_width_p(lce_req_header_width_lp)
     ,.pr_payload_width_p(lce_req_payload_width_lp)
     ,.pr_stream_mask_p(lce_req_stream_mask_gp)
     ,.pr_data_width_p(bedrock_fill_width_p)
     )
   lce_req_wh_to_stream
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.link_data_i(lce_req_link_cast_i.data)
     ,.link_v_i(lce_req_link_cast_i.v)
     ,.link_ready_and_o(lce_req_link_cast_o.ready_and_rev)

     ,.pr_hdr_o(lce_req_header_li)
     ,.pr_data_o(lce_req_data_li)
     ,.pr_v_o(lce_req_v_li)
     ,.pr_ready_and_i(lce_req_ready_and_lo)
     );

  // LCE cmd Link WH-Burst conversion
  bp_me_lce_id_to_cord
   #(.bp_params_p(bp_params_p))
   cmd_router_cord
    (.lce_id_i(lce_cmd_header_lo.payload.dst_id)
     ,.lce_cord_o(lce_cmd_dst_cord_lo)
     ,.lce_cid_o(lce_cmd_dst_cid_lo)
     );

  bp_me_stream_to_wormhole
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(coh_noc_flit_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.pr_hdr_width_p(lce_cmd_header_width_lp)
     ,.pr_payload_width_p(lce_cmd_payload_width_lp)
     ,.pr_stream_mask_p(lce_cmd_stream_mask_gp)
     ,.pr_data_width_p(bedrock_fill_width_p)
     )
   lce_cmd_stream_to_wh
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.pr_hdr_i(lce_cmd_header_lo)
     ,.pr_data_i(lce_cmd_data_lo)
     ,.pr_v_i(lce_cmd_v_lo)
     ,.pr_ready_and_o(lce_cmd_ready_and_li)
     ,.dst_cord_i(lce_cmd_dst_cord_lo)
     ,.dst_cid_i(lce_cmd_dst_cid_lo)

     ,.link_data_o(lce_cmd_link_cast_o.data)
     ,.link_v_o(lce_cmd_link_cast_o.v)
     ,.link_ready_and_i(lce_cmd_link_cast_i.ready_and_rev)
     );

  // WH to Burst (lce_cmd_header_li)
  bp_me_wormhole_to_stream
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(coh_noc_flit_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.pr_hdr_width_p(lce_cmd_header_width_lp)
     ,.pr_payload_width_p(lce_cmd_payload_width_lp)
     ,.pr_stream_mask_p(lce_cmd_stream_mask_gp)
     ,.pr_data_width_p(bedrock_fill_width_p)
     )
   lce_cmd_wh_to_stream
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.link_data_i(lce_cmd_link_cast_i.data)
     ,.link_v_i(lce_cmd_link_cast_i.v)
     ,.link_ready_and_o(lce_cmd_link_cast_o.ready_and_rev)

     ,.pr_hdr_o(lce_cmd_header_li)
     ,.pr_data_o(lce_cmd_data_li)
     ,.pr_v_o(lce_cmd_v_li)
     ,.pr_ready_and_i(lce_cmd_ready_and_lo)
     );

  // I/O Link Send and Receive
  bp_global_addr_s global_addr_lo;
  bp_local_addr_s  local_addr_lo;

  assign global_addr_lo = mem_fwd_header_lo.addr;
  assign local_addr_lo  = mem_fwd_header_lo.addr;

  wire is_host_addr = (~local_addr_lo.nonlocal && (local_addr_lo.dev inside {host_dev_gp}));
  wire [mem_noc_did_width_p-1:0] dst_did_lo = is_host_addr ? host_did_i : global_addr_lo.hio;

  `declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bsg_ready_and_link_sif_s);
  `bp_cast_i(bsg_ready_and_link_sif_s, mem_fwd_link);
  `bp_cast_o(bsg_ready_and_link_sif_s, mem_rev_link);
  `bp_cast_o(bsg_ready_and_link_sif_s, mem_fwd_link);
  `bp_cast_i(bsg_ready_and_link_sif_s, mem_rev_link);

  wire [mem_noc_cord_width_p-1:0] mem_fwd_dst_cord_lo = dst_did_lo;
  wire [mem_noc_cid_width_p-1:0] mem_fwd_dst_cid_lo = '0;
  bp_me_stream_to_wormhole
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(mem_noc_flit_width_p)
     ,.cord_width_p(mem_noc_cord_width_p)
     ,.len_width_p(mem_noc_len_width_p)
     ,.cid_width_p(mem_noc_cid_width_p)
     ,.pr_hdr_width_p(mem_fwd_header_width_lp)
     ,.pr_payload_width_p(mem_fwd_payload_width_lp)
     ,.pr_stream_mask_p(mem_fwd_stream_mask_gp)
     ,.pr_data_width_p(bedrock_fill_width_p)
     )
   mem_fwd_stream_to_wormhole
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.pr_hdr_i(mem_fwd_header_lo)
     ,.pr_data_i(mem_fwd_data_lo)
     ,.pr_v_i(mem_fwd_v_lo)
     ,.pr_ready_and_o(mem_fwd_ready_and_li)
     ,.dst_cord_i(mem_fwd_dst_cord_lo)
     ,.dst_cid_i(mem_fwd_dst_cid_lo)

     ,.link_data_o(mem_fwd_link_cast_o.data)
     ,.link_v_o(mem_fwd_link_cast_o.v)
     ,.link_ready_and_i(mem_fwd_link_cast_i.ready_and_rev)
     );

  wire [mem_noc_cord_width_p-1:0] mem_rev_dst_cord_lo = mem_rev_header_lo.payload.src_did;
  wire [mem_noc_cid_width_p-1:0] mem_rev_dst_cid_lo = '0;
  bp_me_stream_to_wormhole
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(mem_noc_flit_width_p)
     ,.cord_width_p(mem_noc_cord_width_p)
     ,.len_width_p(mem_noc_len_width_p)
     ,.cid_width_p(mem_noc_cid_width_p)
     ,.pr_hdr_width_p(mem_rev_header_width_lp)
     ,.pr_payload_width_p(mem_rev_payload_width_lp)
     ,.pr_stream_mask_p(mem_rev_stream_mask_gp)
     ,.pr_data_width_p(bedrock_fill_width_p)
     )
   mem_rev_stream_to_wormhole
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.pr_hdr_i(mem_rev_header_lo)
     ,.pr_data_i(mem_rev_data_lo)
     ,.pr_v_i(mem_rev_v_lo)
     ,.pr_ready_and_o(mem_rev_ready_and_li)
     ,.dst_cord_i(mem_rev_dst_cord_lo)
     ,.dst_cid_i(mem_rev_dst_cid_lo)

     ,.link_data_o(mem_rev_link_cast_o.data)
     ,.link_v_o(mem_rev_link_cast_o.v)
     ,.link_ready_and_i(mem_rev_link_cast_i.ready_and_rev)
     );

  bp_me_wormhole_to_stream
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(mem_noc_flit_width_p)
     ,.cord_width_p(mem_noc_cord_width_p)
     ,.len_width_p(mem_noc_len_width_p)
     ,.cid_width_p(mem_noc_cid_width_p)
     ,.pr_hdr_width_p(mem_fwd_header_width_lp)
     ,.pr_payload_width_p(mem_fwd_payload_width_lp)
     ,.pr_stream_mask_p(mem_fwd_stream_mask_gp)
     ,.pr_data_width_p(bedrock_fill_width_p)
     )
   mem_fwd_wormhole_to_stream
   (.clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.link_data_i(mem_fwd_link_cast_i.data)
    ,.link_v_i(mem_fwd_link_cast_i.v)
    ,.link_ready_and_o(mem_fwd_link_cast_o.ready_and_rev)

    ,.pr_hdr_o(mem_fwd_header_li)
    ,.pr_data_o(mem_fwd_data_li)
    ,.pr_v_o(mem_fwd_v_li)
    ,.pr_ready_and_i(mem_fwd_ready_and_lo)
    );

  bp_me_wormhole_to_stream
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(mem_noc_flit_width_p)
     ,.cord_width_p(mem_noc_cord_width_p)
     ,.len_width_p(mem_noc_len_width_p)
     ,.cid_width_p(mem_noc_cid_width_p)
     ,.pr_hdr_width_p(mem_rev_header_width_lp)
     ,.pr_payload_width_p(mem_rev_payload_width_lp)
     ,.pr_stream_mask_p(mem_rev_stream_mask_gp)
     ,.pr_data_width_p(bedrock_fill_width_p)
     )
   mem_rev_wormhole_to_stream
   (.clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.link_data_i(mem_rev_link_cast_i.data)
    ,.link_v_i(mem_rev_link_cast_i.v)
    ,.link_ready_and_o(mem_rev_link_cast_o.ready_and_rev)

    ,.pr_hdr_o(mem_rev_header_li)
    ,.pr_data_o(mem_rev_data_li)
    ,.pr_v_o(mem_rev_v_li)
    ,.pr_ready_and_i(mem_rev_ready_and_lo)
    );

endmodule

