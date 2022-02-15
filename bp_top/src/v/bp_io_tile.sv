
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"
`include "bp_top_defines.svh"

module bp_io_tile
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_lce_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam io_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(io_noc_flit_width_p)
   )
  (input                                          clk_i
   , input                                        reset_i

   , input [io_noc_did_width_p-1:0]               my_did_i
   , input [io_noc_did_width_p-1:0]               host_did_i
   , input [coh_noc_cord_width_p-1:0]             my_cord_i

   , input [coh_noc_ral_link_width_lp-1:0]        lce_req_link_i
   , output logic [coh_noc_ral_link_width_lp-1:0] lce_req_link_o

   , input [coh_noc_ral_link_width_lp-1:0]        lce_cmd_link_i
   , output logic [coh_noc_ral_link_width_lp-1:0] lce_cmd_link_o

   , input [io_noc_ral_link_width_lp-1:0]         io_cmd_link_i
   , output logic [io_noc_ral_link_width_lp-1:0]  io_cmd_link_o

   , input [io_noc_ral_link_width_lp-1:0]         io_resp_link_i
   , output logic [io_noc_ral_link_width_lp-1:0]  io_resp_link_o
   );

  `declare_bp_bedrock_lce_if(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p);
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_memory_map(paddr_width_p, daddr_width_p);

  `declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_noc_ready_and_link_sif_s);
  `bp_cast_i(bp_coh_noc_ready_and_link_sif_s, lce_req_link);
  `bp_cast_o(bp_coh_noc_ready_and_link_sif_s, lce_req_link);
  `bp_cast_i(bp_coh_noc_ready_and_link_sif_s, lce_cmd_link);
  `bp_cast_o(bp_coh_noc_ready_and_link_sif_s, lce_cmd_link);

  // I/O Link to LCE connections
  bp_bedrock_mem_header_s lce_io_cmd_header_li;
  logic [bedrock_data_width_p-1:0] lce_io_cmd_data_li;
  logic lce_io_cmd_header_v_li, lce_io_cmd_has_data_li, lce_io_cmd_header_ready_and_lo;
  logic lce_io_cmd_data_v_li, lce_io_cmd_last_li, lce_io_cmd_data_ready_and_lo;

  bp_bedrock_mem_header_s lce_io_resp_header_lo;
  logic [bedrock_data_width_p-1:0] lce_io_resp_data_lo;
  logic lce_io_resp_header_v_lo, lce_io_resp_has_data_lo, lce_io_resp_header_ready_and_li;
  logic lce_io_resp_data_v_lo, lce_io_resp_last_lo, lce_io_resp_data_ready_and_li;

  bp_bedrock_lce_req_header_s lce_lce_req_header_lo;
  logic [bedrock_data_width_p-1:0] lce_lce_req_data_lo;
  logic lce_lce_req_header_v_lo, lce_lce_req_has_data_lo, lce_lce_req_header_ready_and_li;
  logic lce_lce_req_data_v_lo, lce_lce_req_last_lo, lce_lce_req_data_ready_and_li;

  bp_bedrock_lce_cmd_header_s lce_lce_cmd_header_li;
  logic [bedrock_data_width_p-1:0] lce_lce_cmd_data_li;
  logic lce_lce_cmd_header_v_li, lce_lce_cmd_has_data_li, lce_lce_cmd_header_ready_and_lo;
  logic lce_lce_cmd_data_v_li, lce_lce_cmd_last_li, lce_lce_cmd_data_ready_and_lo;

  // I/O CCE connections
  bp_bedrock_lce_cmd_header_s cce_lce_cmd_header_lo;
  logic [bedrock_data_width_p-1:0] cce_lce_cmd_data_lo;
  logic cce_lce_cmd_header_v_lo, cce_lce_cmd_has_data_lo, cce_lce_cmd_header_ready_and_li;
  logic cce_lce_cmd_data_v_lo, cce_lce_cmd_last_lo, cce_lce_cmd_data_ready_and_li;

  bp_bedrock_lce_req_header_s cce_lce_req_header_li;
  logic [bedrock_data_width_p-1:0] cce_lce_req_data_li;
  logic cce_lce_req_header_v_li, cce_lce_req_has_data_li, cce_lce_req_header_ready_and_lo;
  logic cce_lce_req_data_v_li, cce_lce_req_last_li, cce_lce_req_data_ready_and_lo;

  bp_bedrock_mem_header_s cce_io_cmd_header_lo;
  logic [bedrock_data_width_p-1:0] cce_io_cmd_data_lo;
  logic cce_io_cmd_header_v_lo, cce_io_cmd_has_data_lo, cce_io_cmd_header_ready_and_li;
  logic cce_io_cmd_data_v_lo, cce_io_cmd_last_lo, cce_io_cmd_data_ready_and_li;

  bp_bedrock_mem_header_s cce_io_resp_header_li;
  logic [bedrock_data_width_p-1:0] cce_io_resp_data_li;
  logic cce_io_resp_header_v_li, cce_io_resp_has_data_li, cce_io_resp_header_ready_and_lo;
  logic cce_io_resp_data_v_li, cce_io_resp_last_li, cce_io_resp_data_ready_and_lo;

  logic reset_r;
  always_ff @(posedge clk_i)
    reset_r <= reset_i;

  logic [cce_id_width_p-1:0]  cce_id_li;
  logic [lce_id_width_p-1:0]  lce_id_li;
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

     ,.io_cmd_header_i(lce_io_cmd_header_li)
     ,.io_cmd_header_v_i(lce_io_cmd_header_v_li)
     ,.io_cmd_header_ready_and_o(lce_io_cmd_header_ready_and_lo)
     ,.io_cmd_has_data_i(lce_io_cmd_has_data_li)
     ,.io_cmd_data_i(lce_io_cmd_data_li)
     ,.io_cmd_data_v_i(lce_io_cmd_data_v_li)
     ,.io_cmd_data_ready_and_o(lce_io_cmd_data_ready_and_lo)
     ,.io_cmd_last_i(lce_io_cmd_last_li)

     ,.io_resp_header_o(lce_io_resp_header_lo)
     ,.io_resp_header_v_o(lce_io_resp_header_v_lo)
     ,.io_resp_header_ready_and_i(lce_io_resp_header_ready_and_li)
     ,.io_resp_has_data_o(lce_io_resp_has_data_lo)
     ,.io_resp_data_o(lce_io_resp_data_lo)
     ,.io_resp_data_v_o(lce_io_resp_data_v_lo)
     ,.io_resp_data_ready_and_i(lce_io_resp_data_ready_and_li)
     ,.io_resp_last_o(lce_io_resp_last_lo)

     ,.lce_req_header_o(lce_lce_req_header_lo)
     ,.lce_req_header_v_o(lce_lce_req_header_v_lo)
     ,.lce_req_header_ready_and_i(lce_lce_req_header_ready_and_li)
     ,.lce_req_has_data_o(lce_lce_req_has_data_lo)
     ,.lce_req_data_o(lce_lce_req_data_lo)
     ,.lce_req_data_v_o(lce_lce_req_data_v_lo)
     ,.lce_req_data_ready_and_i(lce_lce_req_data_ready_and_li)
     ,.lce_req_last_o(lce_lce_req_last_lo)

     ,.lce_cmd_header_i(lce_lce_cmd_header_li)
     ,.lce_cmd_header_v_i(lce_lce_cmd_header_v_li)
     ,.lce_cmd_header_ready_and_o(lce_lce_cmd_header_ready_and_lo)
     ,.lce_cmd_has_data_i(lce_lce_cmd_has_data_li)
     ,.lce_cmd_data_i(lce_lce_cmd_data_li)
     ,.lce_cmd_data_v_i(lce_lce_cmd_data_v_li)
     ,.lce_cmd_data_ready_and_o(lce_lce_cmd_data_ready_and_lo)
     ,.lce_cmd_last_i(lce_lce_cmd_last_li)
     );

  bp_io_cce
   #(.bp_params_p(bp_params_p))
   io_cce
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.cce_id_i(cce_id_li)
     ,.did_i(my_did_i)

     ,.lce_req_header_i(cce_lce_req_header_li)
     ,.lce_req_header_v_i(cce_lce_req_header_v_li)
     ,.lce_req_header_ready_and_o(cce_lce_req_header_ready_and_lo)
     ,.lce_req_has_data_i(cce_lce_req_has_data_li)
     ,.lce_req_data_i(cce_lce_req_data_li)
     ,.lce_req_data_v_i(cce_lce_req_data_v_li)
     ,.lce_req_data_ready_and_o(cce_lce_req_data_ready_and_lo)
     ,.lce_req_last_i(cce_lce_req_last_li)

     ,.lce_cmd_header_o(cce_lce_cmd_header_lo)
     ,.lce_cmd_header_v_o(cce_lce_cmd_header_v_lo)
     ,.lce_cmd_header_ready_and_i(cce_lce_cmd_header_ready_and_li)
     ,.lce_cmd_has_data_o(cce_lce_cmd_has_data_lo)
     ,.lce_cmd_data_o(cce_lce_cmd_data_lo)
     ,.lce_cmd_data_v_o(cce_lce_cmd_data_v_lo)
     ,.lce_cmd_data_ready_and_i(cce_lce_cmd_data_ready_and_li)
     ,.lce_cmd_last_o(cce_lce_cmd_last_lo)

     ,.io_cmd_header_o(cce_io_cmd_header_lo)
     ,.io_cmd_header_v_o(cce_io_cmd_header_v_lo)
     ,.io_cmd_header_ready_and_i(cce_io_cmd_header_ready_and_li)
     ,.io_cmd_has_data_o(cce_io_cmd_has_data_lo)
     ,.io_cmd_data_o(cce_io_cmd_data_lo)
     ,.io_cmd_data_v_o(cce_io_cmd_data_v_lo)
     ,.io_cmd_data_ready_and_i(cce_io_cmd_data_ready_and_li)
     ,.io_cmd_last_o(cce_io_cmd_last_lo)

     ,.io_resp_header_i(cce_io_resp_header_li)
     ,.io_resp_header_v_i(cce_io_resp_header_v_li)
     ,.io_resp_header_ready_and_o(cce_io_resp_header_ready_and_lo)
     ,.io_resp_has_data_i(cce_io_resp_has_data_li)
     ,.io_resp_data_i(cce_io_resp_data_li)
     ,.io_resp_data_v_i(cce_io_resp_data_v_li)
     ,.io_resp_data_ready_and_o(cce_io_resp_data_ready_and_lo)
     ,.io_resp_last_i(cce_io_resp_last_li)
     );


  localparam bedrock_len_width_lp = `BSG_SAFE_CLOG2(`BSG_CDIV((1<<e_bedrock_msg_size_128)*8,bedrock_data_width_p));

  // LCE Req Link WH-Burst conversion
  `declare_bp_lce_req_wormhole_header_s(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, bp_bedrock_lce_req_header_s);
  localparam lce_req_wh_pad_width_lp = `bp_bedrock_wormhole_packet_pad_width(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, $bits(bp_bedrock_lce_req_header_s));
  bp_lce_req_wormhole_header_s lce_req_wh_header_lo;

  // Burst to WH (lce_lce_req_header_lo)
  bp_me_wormhole_packet_encode_lce_req
   #(.bp_params_p(bp_params_p)
     )
   lce_lce_req_encode
    (.lce_req_header_i(lce_lce_req_header_lo)
     ,.wh_header_o(lce_req_wh_header_lo)
     );

  bp_me_burst_to_wormhole
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.pr_hdr_width_p(lce_req_header_width_lp)
     ,.pr_data_width_p(bedrock_data_width_p)
     )
   lce_lce_req_burst_to_wh
   (.clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.pr_hdr_i(lce_req_wh_header_lo[0+:($bits(bp_lce_req_wormhole_header_s)-lce_req_wh_pad_width_lp)])
    ,.pr_hdr_v_i(lce_lce_req_header_v_lo)
    ,.pr_hdr_ready_and_o(lce_lce_req_header_ready_and_li)
    ,.pr_has_data_i(lce_lce_req_has_data_lo)

    ,.pr_data_i(lce_lce_req_data_lo)
    ,.pr_data_v_i(lce_lce_req_data_v_lo)
    ,.pr_data_ready_and_o(lce_lce_req_data_ready_and_li)
    ,.pr_last_i(lce_lce_req_last_lo)

    ,.link_data_o(lce_req_link_cast_o.data)
    ,.link_v_o(lce_req_link_cast_o.v)
    ,.link_ready_and_i(lce_req_link_cast_i.ready_and_rev)
    );

  // WH to Burst (cce_lce_req_header_li)
  logic [bedrock_len_width_lp-1:0] cce_lce_req_pr_len;
  bp_bedrock_size_to_len
   #(.len_width_p(bedrock_len_width_lp)
     ,.beat_width_p(bedrock_data_width_p)
     )
   cce_lce_req_size_to_len
   (.size_i(cce_lce_req_header_li.size)
    ,.len_o(cce_lce_req_pr_len)
   );

  bp_me_wormhole_to_burst
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.pr_hdr_width_p(lce_req_header_width_lp)
     ,.pr_data_width_p(bedrock_data_width_p)
     ,.pr_len_width_p(bedrock_len_width_lp)
     )
   cce_lce_req_wh_to_burst
   (.clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.link_data_i(lce_req_link_cast_i.data)
    ,.link_v_i(lce_req_link_cast_i.v)
    ,.link_ready_and_o(lce_req_link_cast_o.ready_and_rev)

    ,.pr_hdr_o(cce_lce_req_header_li)
    ,.pr_hdr_v_o(cce_lce_req_header_v_li)
    ,.pr_hdr_ready_and_i(cce_lce_req_header_ready_and_lo)
    ,.pr_has_data_o(cce_lce_req_has_data_li)
    ,.pr_data_beats_i(cce_lce_req_pr_len)

    ,.pr_data_o(cce_lce_req_data_li)
    ,.pr_data_v_o(cce_lce_req_data_v_li)
    ,.pr_data_ready_and_i(cce_lce_req_data_ready_and_lo)
    ,.pr_last_o(cce_lce_req_last_li)
    );

  // LCE cmd Link WH-Burst conversion
  `declare_bp_lce_cmd_wormhole_header_s(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, bp_bedrock_lce_cmd_header_s);
  localparam cce_lce_cmd_wh_pad_width_lp = `bp_bedrock_wormhole_packet_pad_width(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, $bits(bp_bedrock_lce_cmd_header_s));
  bp_lce_cmd_wormhole_header_s cce_lce_cmd_wh_header_lo;

  // Burst to WH (cce_lce_cmd_header_lo)
  bp_me_wormhole_packet_encode_lce_cmd
   #(.bp_params_p(bp_params_p))
   cce_lce_cmd_encode
    (.lce_cmd_header_i(cce_lce_cmd_header_lo)
     ,.wh_header_o(cce_lce_cmd_wh_header_lo)
     );

  bp_me_burst_to_wormhole
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.pr_hdr_width_p(lce_cmd_header_width_lp)
     ,.pr_data_width_p(bedrock_data_width_p)
     )
   cce_lce_cmd_burst_to_wh
   (.clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.pr_hdr_i(cce_lce_cmd_wh_header_lo[0+:($bits(bp_lce_cmd_wormhole_header_s)-cce_lce_cmd_wh_pad_width_lp)])
    ,.pr_hdr_v_i(cce_lce_cmd_header_v_lo)
    ,.pr_hdr_ready_and_o(cce_lce_cmd_header_ready_and_li)
    ,.pr_has_data_i(cce_lce_cmd_has_data_lo)

    ,.pr_data_i(cce_lce_cmd_data_lo)
    ,.pr_data_v_i(cce_lce_cmd_data_v_lo)
    ,.pr_data_ready_and_o(cce_lce_cmd_data_ready_and_li)
    ,.pr_last_i(cce_lce_cmd_last_lo)

    ,.link_data_o(lce_cmd_link_cast_o.data)
    ,.link_v_o(lce_cmd_link_cast_o.v)
    ,.link_ready_and_i(lce_cmd_link_cast_i.ready_and_rev)
    );

  // WH to Burst (lce_lce_cmd_header_li)
  logic [bedrock_len_width_lp-1:0] lce_lce_cmd_pr_len;
  bp_bedrock_size_to_len
   #(.len_width_p(bedrock_len_width_lp)
     ,.beat_width_p(bedrock_data_width_p)
     )
   lce_lce_cmd_size_to_len
   (.size_i(lce_lce_cmd_header_li.size)
    ,.len_o(lce_lce_cmd_pr_len)
   );

  bp_me_wormhole_to_burst
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.pr_hdr_width_p(lce_cmd_header_width_lp)
     ,.pr_data_width_p(bedrock_data_width_p)
     ,.pr_len_width_p(bedrock_len_width_lp)
     )
   lce_lce_cmd_wh_to_burst
   (.clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.link_data_i(lce_cmd_link_cast_i.data)
    ,.link_v_i(lce_cmd_link_cast_i.v)
    ,.link_ready_and_o(lce_cmd_link_cast_o.ready_and_rev)

    ,.pr_hdr_o(lce_lce_cmd_header_li)
    ,.pr_hdr_v_o(lce_lce_cmd_header_v_li)
    ,.pr_hdr_ready_and_i(lce_lce_cmd_header_ready_and_lo)
    ,.pr_has_data_o(lce_lce_cmd_has_data_li)
    ,.pr_data_beats_i(lce_lce_cmd_pr_len)

    ,.pr_data_o(lce_lce_cmd_data_li)
    ,.pr_data_v_o(lce_lce_cmd_data_v_li)
    ,.pr_data_ready_and_i(lce_lce_cmd_data_ready_and_lo)
    ,.pr_last_o(lce_lce_cmd_last_li)
    );

  // I/O Link Send and Receive
  logic [io_noc_did_width_p-1:0]  dst_did_lo;
  logic [io_noc_cord_width_p-1:0] dst_cord_lo;

  bp_global_addr_s global_addr_lo;
  bp_local_addr_s  local_addr_lo;

  assign global_addr_lo = cce_io_cmd_header_lo.addr;
  assign local_addr_lo  = cce_io_cmd_header_lo.addr;

  wire is_host_addr  = (~local_addr_lo.nonlocal && (local_addr_lo.dev inside {boot_dev_gp, host_dev_gp}));
  assign dst_did_lo  = is_host_addr ? host_did_i : global_addr_lo.hio;
  assign dst_cord_lo = dst_did_lo;

  `declare_bsg_ready_and_link_sif_s(io_noc_flit_width_p, bsg_ready_and_link_sif_s);
  `bp_cast_i(bsg_ready_and_link_sif_s, io_cmd_link);
  `bp_cast_o(bsg_ready_and_link_sif_s, io_resp_link);
  `bp_cast_o(bsg_ready_and_link_sif_s, io_cmd_link);
  `bp_cast_i(bsg_ready_and_link_sif_s, io_resp_link);
  bsg_ready_and_link_sif_s send_cmd_link_lo, send_resp_link_li;
  bsg_ready_and_link_sif_s recv_cmd_link_li, recv_resp_link_lo;
  assign recv_cmd_link_li     = '{data          : io_cmd_link_cast_i.data
                                  ,v            : io_cmd_link_cast_i.v
                                  ,ready_and_rev: io_resp_link_cast_i.ready_and_rev
                                  };
  assign io_cmd_link_cast_o   = '{data          : send_cmd_link_lo.data
                                  ,v            : send_cmd_link_lo.v
                                  ,ready_and_rev: recv_resp_link_lo.ready_and_rev
                                  };

  assign send_resp_link_li    = '{data          : io_resp_link_cast_i.data
                                  ,v            : io_resp_link_cast_i.v
                                  ,ready_and_rev: io_cmd_link_cast_i.ready_and_rev
                                  };
  assign io_resp_link_cast_o  = '{data          : recv_resp_link_lo.data
                                  ,v            : recv_resp_link_lo.v
                                  ,ready_and_rev: send_cmd_link_lo.ready_and_rev
                                  };

  bp_me_bedrock_mem_to_link
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(io_noc_flit_width_p)
     ,.cord_width_p(io_noc_cord_width_p)
     ,.cid_width_p(io_noc_cid_width_p)
     ,.len_width_p(io_noc_len_width_p)
     ,.payload_mask_p(mem_cmd_payload_mask_gp)
     )
   send_link
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.dst_cord_i(dst_cord_lo)
     ,.dst_cid_i('0)

     ,.mem_header_i(cce_io_cmd_header_lo)
     ,.mem_header_v_i(cce_io_cmd_header_v_lo)
     ,.mem_header_ready_and_o(cce_io_cmd_header_ready_and_li)
     ,.mem_has_data_i(cce_io_cmd_has_data_lo)
     ,.mem_data_i(cce_io_cmd_data_lo)
     ,.mem_data_v_i(cce_io_cmd_data_v_lo)
     ,.mem_data_ready_and_o(cce_io_cmd_data_ready_and_li)
     ,.mem_last_i(cce_io_cmd_last_lo)

     ,.mem_header_o(cce_io_resp_header_li)
     ,.mem_header_v_o(cce_io_resp_header_v_li)
     ,.mem_header_ready_and_i(cce_io_resp_header_ready_and_lo)
     ,.mem_has_data_o(cce_io_resp_has_data_li)
     ,.mem_data_o(cce_io_resp_data_li)
     ,.mem_data_v_o(cce_io_resp_data_v_li)
     ,.mem_data_ready_and_i(cce_io_resp_data_ready_and_lo)
     ,.mem_last_o(cce_io_resp_last_li)

     ,.link_o(send_cmd_link_lo)
     ,.link_i(send_resp_link_li)
     );

  bp_me_bedrock_mem_to_link
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(io_noc_flit_width_p)
     ,.cord_width_p(io_noc_cord_width_p)
     ,.cid_width_p(io_noc_cid_width_p)
     ,.len_width_p(io_noc_len_width_p)
     ,.payload_mask_p(mem_resp_payload_mask_gp)
     )
   recv_link
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.dst_cord_i(lce_io_resp_header_lo.payload.did)
     ,.dst_cid_i('0)

     ,.mem_header_o(lce_io_cmd_header_li)
     ,.mem_header_v_o(lce_io_cmd_header_v_li)
     ,.mem_header_ready_and_i(lce_io_cmd_header_ready_and_lo)
     ,.mem_has_data_o(lce_io_cmd_has_data_li)
     ,.mem_data_o(lce_io_cmd_data_li)
     ,.mem_data_v_o(lce_io_cmd_data_v_li)
     ,.mem_data_ready_and_i(lce_io_cmd_data_ready_and_lo)
     ,.mem_last_o(lce_io_cmd_last_li)

     ,.mem_header_i(lce_io_resp_header_lo)
     ,.mem_header_v_i(lce_io_resp_header_v_lo)
     ,.mem_header_ready_and_o(lce_io_resp_header_ready_and_li)
     ,.mem_has_data_i(lce_io_resp_has_data_lo)
     ,.mem_data_i(lce_io_resp_data_lo)
     ,.mem_data_v_i(lce_io_resp_data_v_lo)
     ,.mem_data_ready_and_o(lce_io_resp_data_ready_and_li)
     ,.mem_last_i(lce_io_resp_last_lo)

     ,.link_i(recv_cmd_link_li)
     ,.link_o(recv_resp_link_lo)
     );

endmodule

