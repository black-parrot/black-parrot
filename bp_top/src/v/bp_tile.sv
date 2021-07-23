/**
 *
 * bp_tile.v
 *
 */

`include "bp_common_defines.svh"
`include "bp_top_defines.svh"

module bp_tile
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bsg_cache_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_lce_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, dword_width_gp, lce_id_width_p, lce_assoc_p, cce)

   , localparam cfg_bus_width_lp        = `bp_cfg_bus_width(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)

   // Wormhole parameters
   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)

   // LCE-CCE network wormhole adapter length input/output field size
   , localparam pr_len_width_lp = 8
   )
  (input                                                      clk_i
   , input                                                    reset_i

   // Memory side connection
   , input [io_noc_did_width_p-1:0]                           my_did_i
   , input [io_noc_did_width_p-1:0]                           host_did_i
   , input [coh_noc_cord_width_p-1:0]                         my_cord_i

   , input [coh_noc_ral_link_width_lp-1:0]                    lce_req_link_i
   , output [coh_noc_ral_link_width_lp-1:0]                   lce_req_link_o

   , input [coh_noc_ral_link_width_lp-1:0]                    lce_cmd_link_i
   , output [coh_noc_ral_link_width_lp-1:0]                   lce_cmd_link_o

   , input [coh_noc_ral_link_width_lp-1:0]                    lce_resp_link_i
   , output [coh_noc_ral_link_width_lp-1:0]                   lce_resp_link_o

   , output [mem_noc_ral_link_width_lp-1:0]                   mem_cmd_link_o
   , input [mem_noc_ral_link_width_lp-1:0]                    mem_resp_link_i
   );

  `declare_bp_cfg_bus_s(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `declare_bp_bedrock_lce_if(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce);
  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce);
  `declare_bp_memory_map(paddr_width_p, caddr_width_p);
  `declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_ready_and_link_s);

  // Reset
  logic reset_r;
  always_ff @(posedge clk_i)
    reset_r <= reset_i;

  // Config bus
  bp_cfg_bus_s cfg_bus_lo;

  // LCE-CCE coherence network links
  bp_coh_ready_and_link_s lce_req_link_cast_i, lce_req_link_cast_o;
  bp_coh_ready_and_link_s lce_resp_link_cast_i, lce_resp_link_cast_o;
  bp_coh_ready_and_link_s lce_cmd_link_cast_i, lce_cmd_link_cast_o;
  assign lce_req_link_cast_i  = lce_req_link_i;
  assign lce_cmd_link_cast_i  = lce_cmd_link_i;
  assign lce_resp_link_cast_i = lce_resp_link_i;
  assign lce_req_link_o  = lce_req_link_cast_o;
  assign lce_cmd_link_o  = lce_cmd_link_cast_o;
  assign lce_resp_link_o = lce_resp_link_cast_o;

  // Core-side LCE-CCE network connections
  bp_bedrock_lce_req_msg_s [1:0] lce_req_lo;
  logic [1:0] lce_req_v_lo, lce_req_ready_li;
  bp_bedrock_lce_resp_msg_s [1:0] lce_resp_lo;
  logic [1:0] lce_resp_v_lo, lce_resp_ready_li;
  bp_bedrock_lce_cmd_msg_s [1:0] lce_cmd_li;
  logic [1:0] lce_cmd_v_li, lce_cmd_yumi_lo;
  bp_bedrock_lce_cmd_msg_s [1:0] lce_cmd_lo;
  logic [1:0] lce_cmd_v_lo, lce_cmd_ready_li;

  // CCE-side LCE-CCE network connections
  logic cce_lce_req_header_v, cce_lce_req_header_ready_and;
  logic cce_lce_req_data_v, cce_lce_req_data_ready_and;
  logic cce_lce_req_has_data, cce_lce_req_last;
  logic cce_lce_resp_header_v, cce_lce_resp_header_ready_and;
  logic cce_lce_resp_data_v, cce_lce_resp_data_ready_and;
  logic cce_lce_resp_has_data, cce_lce_resp_last;
  logic cce_lce_cmd_header_v, cce_lce_cmd_header_ready_and;
  logic cce_lce_cmd_data_v, cce_lce_cmd_data_ready_and;
  logic cce_lce_cmd_has_data, cce_lce_cmd_last;
  bp_bedrock_lce_req_msg_header_s cce_lce_req_header;
  bp_bedrock_lce_resp_msg_header_s cce_lce_resp_header;
  bp_bedrock_lce_cmd_msg_header_s cce_lce_cmd_header;
  logic [dword_width_gp-1:0] cce_lce_req_data, cce_lce_resp_data, cce_lce_cmd_data;

  `declare_bp_lce_req_wormhole_packet_s(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, bp_bedrock_lce_req_msg_header_s, cce_block_width_p);
  localparam lce_req_wh_payload_width_lp = `bp_coh_wormhole_payload_width(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, $bits(bp_bedrock_lce_req_msg_header_s), cce_block_width_p);
  bp_lce_req_wormhole_packet_s [1:0] lce_req_packet_lo;
  bp_lce_req_wormhole_header_s [1:0] lce_req_header_lo;

  `declare_bp_lce_cmd_wormhole_packet_s(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, bp_bedrock_lce_cmd_msg_header_s, cce_block_width_p);
  localparam lce_cmd_wh_payload_width_lp = `bp_coh_wormhole_payload_width(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, $bits(bp_bedrock_lce_cmd_msg_header_s), cce_block_width_p);
  localparam lce_cmd_wh_pad_width_lp = `bp_coh_wormhole_packet_pad_width(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, $bits(bp_bedrock_lce_cmd_msg_header_s));
  bp_lce_cmd_wormhole_packet_s [1:0] lce_cmd_packet_lo, lce_cmd_packet_li;
  bp_lce_cmd_wormhole_header_s [1:0] lce_cmd_header_lo, lce_cmd_header_li;

  `declare_bp_lce_resp_wormhole_packet_s(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, bp_bedrock_lce_resp_msg_header_s, cce_block_width_p);
  localparam lce_resp_wh_payload_width_lp = `bp_coh_wormhole_payload_width(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, $bits(bp_bedrock_lce_resp_msg_header_s), cce_block_width_p);
  bp_lce_resp_wormhole_packet_s [1:0] lce_resp_packet_lo;
  bp_lce_resp_wormhole_header_s [1:0] lce_resp_header_lo;

  // LCE-CCE network links - unconcentrated
  bp_coh_ready_and_link_s [1:0] lce_req_link_li, lce_req_link_lo;
  bp_coh_ready_and_link_s [1:0] lce_cmd_link_li, lce_cmd_link_lo;
  bp_coh_ready_and_link_s [1:0] lce_resp_link_li, lce_resp_link_lo;

  bp_coh_ready_and_link_s cce_lce_req_link_lo;
  bp_coh_ready_and_link_s cce_lce_cmd_link_li, cce_lce_cmd_link_lo;
  bp_coh_ready_and_link_s cce_lce_resp_link_lo;

  // stub unused LCE-CCE connections
  assign cce_lce_req_link_lo.v = '0;
  assign cce_lce_req_link_lo.data = '0;
  assign cce_lce_cmd_link_lo.ready_and_rev = '0;
  assign cce_lce_resp_link_lo.v = '0;
  assign cce_lce_resp_link_lo.data = '0;

  for (genvar i = 0; i < 2; i++)
    begin : lce
      // outputs a header with [msg_hdr, cid, len, cord] fields
      bp_me_wormhole_packet_encode_lce_req
       #(.bp_params_p(bp_params_p)
         )
       req_encode
        (.lce_req_header_i(lce_req_lo[i].header)
         ,.wh_header_o(lce_req_header_lo[i])
         );
      assign lce_req_packet_lo[i] = '{header: lce_req_header_lo[i], data: lce_req_lo[i].data};

      bsg_wormhole_router_adapter_in
       #(.max_payload_width_p(lce_req_wh_payload_width_lp)
         ,.len_width_p(coh_noc_len_width_p)
         ,.cord_width_p(coh_noc_cord_width_p)
         ,.flit_width_p(coh_noc_flit_width_p)
         )
       lce_req_adapter_in
        (.clk_i(clk_i)
         ,.reset_i(reset_r)

         ,.packet_i(lce_req_packet_lo[i])
         ,.v_i(lce_req_v_lo[i])
         ,.ready_o(lce_req_ready_li[i])

         ,.link_i(lce_req_link_li[i])
         ,.link_o(lce_req_link_lo[i])
         );

      bp_me_wormhole_packet_encode_lce_cmd
       #(.bp_params_p(bp_params_p))
       cmd_encode
        (.lce_cmd_header_i(lce_cmd_lo[i].header)
         ,.wh_header_o(lce_cmd_header_lo[i])
         );
      assign lce_cmd_packet_lo[i] = '{header: lce_cmd_header_lo[i], data: lce_cmd_lo[i].data};

      bsg_wormhole_router_adapter
       #(.max_payload_width_p(lce_cmd_wh_payload_width_lp)
         ,.len_width_p(coh_noc_len_width_p)
         ,.cord_width_p(coh_noc_cord_width_p)
         ,.flit_width_p(coh_noc_flit_width_p)
         )
       cmd_adapter
        (.clk_i(clk_i)
         ,.reset_i(reset_r)

         ,.packet_i(lce_cmd_packet_lo[i])
         ,.v_i(lce_cmd_v_lo[i])
         ,.ready_o(lce_cmd_ready_li[i])

         ,.link_i(lce_cmd_link_li[i])
         ,.link_o(lce_cmd_link_lo[i])

         ,.packet_o(lce_cmd_packet_li[i])
         ,.v_o(lce_cmd_v_li[i])
         ,.yumi_i(lce_cmd_yumi_lo[i])
         );
      assign lce_cmd_li[i] = '{header: lce_cmd_packet_li[i].header.msg_hdr, data: lce_cmd_packet_li[i].data};

      bp_me_wormhole_packet_encode_lce_resp
       #(.bp_params_p(bp_params_p))
       resp_encode
        (.lce_resp_header_i(lce_resp_lo[i].header)
         ,.wh_header_o(lce_resp_header_lo[i])
         );
      assign lce_resp_packet_lo[i] = '{header: lce_resp_header_lo[i], data: lce_resp_lo[i].data};

      bsg_wormhole_router_adapter_in
       #(.max_payload_width_p(lce_resp_wh_payload_width_lp)
         ,.len_width_p(coh_noc_len_width_p)
         ,.cord_width_p(coh_noc_cord_width_p)
         ,.flit_width_p(coh_noc_flit_width_p)
         )
       lce_resp_adapter_in
        (.clk_i(clk_i)
         ,.reset_i(reset_r)

         ,.packet_i(lce_resp_packet_lo[i])
         ,.v_i(lce_resp_v_lo[i])
         ,.ready_o(lce_resp_ready_li[i])

         ,.link_i(lce_resp_link_li[i])
         ,.link_o(lce_resp_link_lo[i])
         );
    end

  // LCE to CCE request
  logic [pr_len_width_lp-1:0] cce_lce_req_pr_len;
  bp_bedrock_size_to_len
   #(.len_width_p(pr_len_width_lp)
     ,.beat_width_p(dword_width_gp)
     )
   cce_lce_req_size_to_len
   (.size_i(cce_lce_req_header.size)
    ,.len_o(cce_lce_req_pr_len)
   );

  bp_me_wormhole_to_burst
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.pr_hdr_width_p(lce_req_msg_header_width_lp)
     ,.pr_data_width_p(dword_width_gp)
     ,.pr_len_width_p(pr_len_width_lp)
     )
   cce_lce_req_wh_to_burst
   (.clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.link_data_i(lce_req_link_cast_i.data)
    ,.link_v_i(lce_req_link_cast_i.v)
    ,.link_ready_and_o(cce_lce_req_link_lo.ready_and_rev)

    ,.pr_hdr_o(cce_lce_req_header)
    ,.pr_hdr_v_o(cce_lce_req_header_v)
    ,.pr_hdr_ready_and_i(cce_lce_req_header_ready_and)
    ,.pr_has_data_o(cce_lce_req_has_data)
    ,.pr_data_beats_i(cce_lce_req_pr_len)

    ,.pr_data_o(cce_lce_req_data)
    ,.pr_data_v_o(cce_lce_req_data_v)
    ,.pr_data_ready_and_i(cce_lce_req_data_ready_and)
    ,.pr_last_o(cce_lce_req_last)
    );

  // CCE to LCE command
  bp_lce_cmd_wormhole_header_s cce_lce_cmd_wh_header_lo;
  bp_me_wormhole_packet_encode_lce_cmd
   #(.bp_params_p(bp_params_p))
   cmd_encode
    (.lce_cmd_header_i(cce_lce_cmd_header)
     ,.wh_header_o(cce_lce_cmd_wh_header_lo)
     );

  bp_me_burst_to_wormhole
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.pr_hdr_width_p(lce_cmd_msg_header_width_lp)
     ,.pr_data_width_p(dword_width_gp)
     )
   cce_lce_cmd_burst_to_wh
   (.clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.pr_hdr_i(cce_lce_cmd_wh_header_lo[0+:($bits(bp_lce_cmd_wormhole_header_s)-lce_cmd_wh_pad_width_lp)])
    ,.pr_hdr_v_i(cce_lce_cmd_header_v)
    ,.pr_hdr_ready_and_o(cce_lce_cmd_header_ready_and)
    ,.pr_has_data_i(cce_lce_cmd_has_data)

    ,.pr_data_i(cce_lce_cmd_data)
    ,.pr_data_v_i(cce_lce_cmd_data_v)
    ,.pr_data_ready_and_o(cce_lce_cmd_data_ready_and)
    ,.pr_last_i(cce_lce_cmd_last)

    ,.link_data_o(cce_lce_cmd_link_lo.data)
    ,.link_v_o(cce_lce_cmd_link_lo.v)
    ,.link_ready_and_i(cce_lce_cmd_link_li.ready_and_rev)
    );

  // LCE to CCE response
  logic [pr_len_width_lp-1:0] cce_lce_resp_pr_len;
  bp_bedrock_size_to_len
   #(.len_width_p(pr_len_width_lp)
     ,.beat_width_p(dword_width_gp)
     )
   cce_lce_resp_size_to_len
   (.size_i(cce_lce_resp_header.size)
    ,.len_o(cce_lce_resp_pr_len)
   );

  bp_me_wormhole_to_burst
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.pr_hdr_width_p(lce_resp_msg_header_width_lp)
     ,.pr_data_width_p(dword_width_gp)
     ,.pr_len_width_p(pr_len_width_lp)
     )
   cce_lce_resp_wh_to_burst
   (.clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.link_data_i(lce_resp_link_cast_i.data)
    ,.link_v_i(lce_resp_link_cast_i.v)
    ,.link_ready_and_o(cce_lce_resp_link_lo.ready_and_rev)

    ,.pr_hdr_o(cce_lce_resp_header)
    ,.pr_hdr_v_o(cce_lce_resp_header_v)
    ,.pr_hdr_ready_and_i(cce_lce_resp_header_ready_and)
    ,.pr_has_data_o(cce_lce_resp_has_data)
    ,.pr_data_beats_i(cce_lce_resp_pr_len)

    ,.pr_data_o(cce_lce_resp_data)
    ,.pr_data_v_o(cce_lce_resp_data_v)
    ,.pr_data_ready_and_i(cce_lce_resp_data_ready_and)
    ,.pr_last_o(cce_lce_resp_last)
    );

  // LCE-CCE Network Concentrators

  bp_coh_ready_and_link_s req_concentrated_link_li, req_concentrated_link_lo;
  bp_coh_ready_and_link_s cmd_concentrated_link_li, cmd_concentrated_link_lo;
  bp_coh_ready_and_link_s resp_concentrated_link_li, resp_concentrated_link_lo;

  assign req_concentrated_link_li = lce_req_link_cast_i;
  assign lce_req_link_cast_o = '{data          : req_concentrated_link_lo.data
                                 ,v            : req_concentrated_link_lo.v
                                 ,ready_and_rev: cce_lce_req_link_lo.ready_and_rev
                                 };
  bsg_wormhole_concentrator_in
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.num_in_p(2)
     ,.cord_width_p(coh_noc_cord_width_p)
     )
   req_concentrator
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.links_i(lce_req_link_lo)
     ,.links_o(lce_req_link_li)

     ,.concentrated_link_i(req_concentrated_link_li)
     ,.concentrated_link_o(req_concentrated_link_lo)
     );

  assign cmd_concentrated_link_li = lce_cmd_link_cast_i;
  assign lce_cmd_link_cast_o = cmd_concentrated_link_lo;
  bsg_wormhole_concentrator
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.num_in_p(3)
     ,.cord_width_p(coh_noc_cord_width_p)
     )
   cmd_concentrator
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.links_i({cce_lce_cmd_link_lo, lce_cmd_link_lo})
     ,.links_o({cce_lce_cmd_link_li, lce_cmd_link_li})

     ,.concentrated_link_i(cmd_concentrated_link_li)
     ,.concentrated_link_o(cmd_concentrated_link_lo)
     );

  assign resp_concentrated_link_li = lce_resp_link_cast_i;
  assign lce_resp_link_cast_o = '{data          : resp_concentrated_link_lo.data
                                  ,v            : resp_concentrated_link_lo.v
                                  ,ready_and_rev: cce_lce_resp_link_lo.ready_and_rev
                                  };
  bsg_wormhole_concentrator_in
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.num_in_p(2)
     ,.cord_width_p(coh_noc_cord_width_p)
     )
   resp_concentrator
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.links_i(lce_resp_link_lo)
     ,.links_o(lce_resp_link_li)

     ,.concentrated_link_i(resp_concentrated_link_li)
     ,.concentrated_link_o(resp_concentrated_link_lo)
     );

  // Processor
  logic timer_irq_li, software_irq_li, external_irq_li;
  bp_core
   #(.bp_params_p(bp_params_p))
   core
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.cfg_bus_i(cfg_bus_lo)

     ,.lce_req_o(lce_req_lo)
     ,.lce_req_v_o(lce_req_v_lo)
     ,.lce_req_ready_then_i(lce_req_ready_li)

     ,.lce_cmd_i(lce_cmd_li)
     ,.lce_cmd_v_i(lce_cmd_v_li)
     ,.lce_cmd_yumi_o(lce_cmd_yumi_lo)

     ,.lce_cmd_o(lce_cmd_lo)
     ,.lce_cmd_v_o(lce_cmd_v_lo)
     ,.lce_cmd_ready_then_i(lce_cmd_ready_li)

     ,.lce_resp_o(lce_resp_lo)
     ,.lce_resp_v_o(lce_resp_v_lo)
     ,.lce_resp_ready_then_i(lce_resp_ready_li)

     ,.timer_irq_i(timer_irq_li)
     ,.software_irq_i(software_irq_li)
     ,.external_irq_i(external_irq_li)
     );

  // CCE-side CCE-Mem network connections
  bp_bedrock_cce_mem_msg_header_s cce_mem_cmd_header_lo;
  logic [dword_width_gp-1:0] cce_mem_cmd_data_lo;
  logic cce_mem_cmd_v_lo, cce_mem_cmd_last_lo, cce_mem_cmd_yumi_li;
  bp_bedrock_cce_mem_msg_header_s cce_mem_resp_header_li;
  logic [dword_width_gp-1:0] cce_mem_resp_data_li;
  logic cce_mem_resp_v_li, cce_mem_resp_ready_and_lo, cce_mem_resp_last_li;

  // Device-side CCE-Mem network connections
  // dev_cmd[3:0] = {CCE loopback, CLINT, CFG, memory (cache)}
  bp_bedrock_cce_mem_msg_header_s [3:0] dev_cmd_header_li;
  logic [3:0][dword_width_gp-1:0] dev_cmd_data_li;
  logic [3:0] dev_cmd_v_li, dev_cmd_ready_and_lo, dev_cmd_last_li;
  bp_bedrock_cce_mem_msg_header_s [3:0] dev_resp_header_lo;
  logic [3:0][dword_width_gp-1:0] dev_resp_data_lo;
  logic [3:0] dev_resp_v_lo, dev_resp_ready_and_li, dev_resp_last_lo;

  // Config
  logic cce_ucode_v_lo;
  logic cce_ucode_w_lo;
  logic [cce_pc_width_p-1:0] cce_ucode_addr_lo;
  logic [cce_instr_width_gp-1:0] cce_ucode_data_lo, cce_ucode_data_li;
  logic [dword_width_gp-1:0] cfg_data_lo, cfg_data_li;
  bp_me_cfg
   #(.bp_params_p(bp_params_p))
   cfg
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.mem_cmd_header_i(dev_cmd_header_li[1])
     ,.mem_cmd_data_i(dev_cmd_data_li[1])
     ,.mem_cmd_v_i(dev_cmd_v_li[1])
     ,.mem_cmd_ready_and_o(dev_cmd_ready_and_lo[1])
     ,.mem_cmd_last_i(dev_cmd_last_li[1])

     ,.mem_resp_header_o(dev_resp_header_lo[1])
     ,.mem_resp_data_o(dev_resp_data_lo[1])
     ,.mem_resp_v_o(dev_resp_v_lo[1])
     ,.mem_resp_ready_and_i(dev_resp_ready_and_li[1])
     ,.mem_resp_last_o(dev_resp_last_lo[1])

     ,.cfg_bus_o(cfg_bus_lo)
     ,.did_i(my_did_i)
     ,.host_did_i(host_did_i)
     ,.cord_i(my_cord_i)

     ,.cce_ucode_v_o(cce_ucode_v_lo)
     ,.cce_ucode_w_o(cce_ucode_w_lo)
     ,.cce_ucode_addr_o(cce_ucode_addr_lo)
     ,.cce_ucode_data_o(cce_ucode_data_lo)
     ,.cce_ucode_data_i(cce_ucode_data_li)
     );

  // CLINT
  bp_me_clint_slice
   #(.bp_params_p(bp_params_p))
   clint
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.mem_cmd_header_i(dev_cmd_header_li[2])
     ,.mem_cmd_data_i(dev_cmd_data_li[2])
     ,.mem_cmd_v_i(dev_cmd_v_li[2])
     ,.mem_cmd_ready_and_o(dev_cmd_ready_and_lo[2])
     ,.mem_cmd_last_i(dev_cmd_last_li[2])

     ,.mem_resp_header_o(dev_resp_header_lo[2])
     ,.mem_resp_data_o(dev_resp_data_lo[2])
     ,.mem_resp_v_o(dev_resp_v_lo[2])
     ,.mem_resp_ready_and_i(dev_resp_ready_and_li[2])
     ,.mem_resp_last_o(dev_resp_last_lo[2])

     ,.timer_irq_o(timer_irq_li)
     ,.software_irq_o(software_irq_li)
     ,.external_irq_o(external_irq_li)
     );

  // CCE-Mem Loopback
  bp_me_loopback
   #(.bp_params_p(bp_params_p))
   loopback
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.mem_cmd_header_i(dev_cmd_header_li[3])
     ,.mem_cmd_data_i(dev_cmd_data_li[3])
     ,.mem_cmd_v_i(dev_cmd_v_li[3])
     ,.mem_cmd_ready_and_o(dev_cmd_ready_and_lo[3])
     ,.mem_cmd_last_i(dev_cmd_last_li[3])

     ,.mem_resp_header_o(dev_resp_header_lo[3])
     ,.mem_resp_data_o(dev_resp_data_lo[3])
     ,.mem_resp_v_o(dev_resp_v_lo[3])
     ,.mem_resp_ready_and_i(dev_resp_ready_and_li[3])
     ,.mem_resp_last_o(dev_resp_last_lo[3])
     );

  // Select destination of CCE-Mem command from CCE
  logic [`BSG_SAFE_CLOG2(4)-1:0] cce_mem_cmd_dst_lo;
  bp_local_addr_s local_addr;
  assign local_addr = cce_mem_cmd_header_lo.addr;
  wire [dev_id_width_gp-1:0] device_cmd_li = local_addr.dev;
  wire local_cmd_li    = (cce_mem_cmd_header_lo.addr < dram_base_addr_gp);

  wire is_cfg_cmd      = local_cmd_li & (device_cmd_li == cfg_dev_gp);
  wire is_clint_cmd    = local_cmd_li & (device_cmd_li == clint_dev_gp);
  wire is_mem_cmd      = ~local_cmd_li || (local_cmd_li & (device_cmd_li == cache_dev_gp));
  wire is_loopback_cmd = local_cmd_li & ~is_cfg_cmd & ~is_clint_cmd & ~is_mem_cmd;

  bsg_encode_one_hot
   #(.width_p(4), .lo_to_hi_p(1))
   cmd_pe
    (.i({is_loopback_cmd, is_clint_cmd, is_cfg_cmd, is_mem_cmd})
     ,.addr_o(cce_mem_cmd_dst_lo)
     ,.v_o()
     );

  // All CCE-Mem network responses go to the CCE on this tile (id = 0 in xbar)
  logic [3:0] dev_resp_dst_lo = '0;

  bp_me_xbar_stream_bidir
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(dword_width_gp)
     ,.payload_width_p(cce_mem_payload_width_lp)
     ,.num_source_p(1)
     ,.num_sink_p(4)
     )
   stream_arb
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cmd_header_i(cce_mem_cmd_header_lo)
     ,.cmd_data_i(cce_mem_cmd_data_lo)
     ,.cmd_v_i(cce_mem_cmd_v_lo)
     ,.cmd_yumi_o(cce_mem_cmd_yumi_li)
     ,.cmd_last_i(cce_mem_cmd_last_lo)
     ,.cmd_dst_i(cce_mem_cmd_dst_lo)

     ,.resp_header_o(cce_mem_resp_header_li)
     ,.resp_data_o(cce_mem_resp_data_li)
     ,.resp_v_o(cce_mem_resp_v_li)
     ,.resp_ready_and_i(cce_mem_resp_ready_and_lo)
     ,.resp_last_o(cce_mem_resp_last_li)

     ,.cmd_header_o(dev_cmd_header_li)
     ,.cmd_data_o(dev_cmd_data_li)
     ,.cmd_v_o(dev_cmd_v_li)
     ,.cmd_ready_and_i(dev_cmd_ready_and_lo)
     ,.cmd_last_o(dev_cmd_last_li)

     ,.resp_header_i(dev_resp_header_lo)
     ,.resp_data_i(dev_resp_data_lo)
     ,.resp_v_i(dev_resp_v_lo)
     ,.resp_yumi_o(dev_resp_ready_and_li)
     ,.resp_last_i(dev_resp_last_lo)
     ,.resp_dst_i(dev_resp_dst_lo)
     );

  // CCE: Cache Coherence Engine
  bp_cce_wrapper
   #(.bp_params_p(bp_params_p))
   cce
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.cfg_bus_i(cfg_bus_lo)

     ,.ucode_v_i(cce_ucode_v_lo)
     ,.ucode_w_i(cce_ucode_w_lo)
     ,.ucode_addr_i(cce_ucode_addr_lo)
     ,.ucode_data_i(cce_ucode_data_lo)
     ,.ucode_data_o(cce_ucode_data_li)

     // LCE-CCE Interface
     // BedRock Burst protocol: ready&valid
     ,.lce_req_header_i(cce_lce_req_header)
     ,.lce_req_header_v_i(cce_lce_req_header_v)
     ,.lce_req_header_ready_and_o(cce_lce_req_header_ready_and)
     ,.lce_req_has_data_i(cce_lce_req_has_data)
     ,.lce_req_data_i(cce_lce_req_data)
     ,.lce_req_data_v_i(cce_lce_req_data_v)
     ,.lce_req_data_ready_and_o(cce_lce_req_data_ready_and)
     ,.lce_req_last_i(cce_lce_req_last)

     ,.lce_resp_header_i(cce_lce_resp_header)
     ,.lce_resp_header_v_i(cce_lce_resp_header_v)
     ,.lce_resp_header_ready_and_o(cce_lce_resp_header_ready_and)
     ,.lce_resp_has_data_i(cce_lce_resp_has_data)
     ,.lce_resp_data_i(cce_lce_resp_data)
     ,.lce_resp_data_v_i(cce_lce_resp_data_v)
     ,.lce_resp_data_ready_and_o(cce_lce_resp_data_ready_and)
     ,.lce_resp_last_i(cce_lce_resp_last)

     ,.lce_cmd_header_o(cce_lce_cmd_header)
     ,.lce_cmd_header_v_o(cce_lce_cmd_header_v)
     ,.lce_cmd_header_ready_and_i(cce_lce_cmd_header_ready_and)
     ,.lce_cmd_has_data_o(cce_lce_cmd_has_data)
     ,.lce_cmd_data_o(cce_lce_cmd_data)
     ,.lce_cmd_data_v_o(cce_lce_cmd_data_v)
     ,.lce_cmd_data_ready_and_i(cce_lce_cmd_data_ready_and)
     ,.lce_cmd_last_o(cce_lce_cmd_last)

     // CCE-MEM Interface
     // BedRock Burst protocol: ready&valid
     ,.mem_resp_header_i(cce_mem_resp_header_li)
     ,.mem_resp_data_i(cce_mem_resp_data_li)
     ,.mem_resp_v_i(cce_mem_resp_v_li)
     ,.mem_resp_ready_and_o(cce_mem_resp_ready_and_lo)
     ,.mem_resp_last_i(cce_mem_resp_last_li)

     ,.mem_cmd_header_o(cce_mem_cmd_header_lo)
     ,.mem_cmd_data_o(cce_mem_cmd_data_lo)
     ,.mem_cmd_v_o(cce_mem_cmd_v_lo)
     // TODO: should this be fixed?
     ,.mem_cmd_ready_and_i(cce_mem_cmd_yumi_li)
     ,.mem_cmd_last_o(cce_mem_cmd_last_lo)
     );

  // CCE-Mem network to L2 Cache adapter
  `declare_bsg_cache_pkt_s(caddr_width_p, l2_data_width_p);
  bsg_cache_pkt_s cache_pkt_li;
  logic cache_pkt_v_li, cache_pkt_ready_lo;
  logic [l2_data_width_p-1:0] cache_data_lo;
  logic cache_data_v_lo, cache_data_yumi_li;
  bp_me_cce_to_cache
   #(.bp_params_p(bp_params_p))
   cce_to_cache
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.mem_cmd_header_i(dev_cmd_header_li[0])
     ,.mem_cmd_data_i(dev_cmd_data_li[0])
     ,.mem_cmd_v_i(dev_cmd_v_li[0])
     ,.mem_cmd_ready_and_o(dev_cmd_ready_and_lo[0])
     ,.mem_cmd_last_i(dev_cmd_last_li[0])

     ,.mem_resp_header_o(dev_resp_header_lo[0])
     ,.mem_resp_data_o(dev_resp_data_lo[0])
     ,.mem_resp_v_o(dev_resp_v_lo[0])
     ,.mem_resp_ready_and_i(dev_resp_ready_and_li[0])
     ,.mem_resp_last_o(dev_resp_last_lo[0])

     ,.cache_pkt_o(cache_pkt_li)
     ,.cache_pkt_v_o(cache_pkt_v_li)
     ,.cache_pkt_ready_i(cache_pkt_ready_lo)

     ,.cache_data_i(cache_data_lo)
     ,.cache_v_i(cache_data_v_lo)
     ,.cache_yumi_o(cache_data_yumi_li)
     );

  // L2 Cache
  `declare_bsg_cache_dma_pkt_s(caddr_width_p);
  bsg_cache_dma_pkt_s dma_pkt_lo;
  logic dma_pkt_v_lo, dma_pkt_yumi_li;
  logic [l2_fill_width_p-1:0] dma_data_li;
  logic dma_data_v_li, dma_data_ready_and_lo;
  logic [l2_fill_width_p-1:0] dma_data_lo;
  logic dma_data_v_lo, dma_data_yumi_li;
  bsg_cache
   #(.addr_width_p(caddr_width_p)
     ,.data_width_p(l2_data_width_p)
     ,.dma_data_width_p(l2_fill_width_p)
     ,.block_size_in_words_p(l2_block_size_in_words_p)
     ,.sets_p(l2_en_p ? l2_sets_p : 2)
     ,.ways_p(l2_en_p ? l2_assoc_p : 2)
     ,.amo_support_p(((amo_swap_p == e_l2) << e_cache_amo_swap)
                     | ((amo_fetch_logic_p == e_l2) << e_cache_amo_xor)
                     | ((amo_fetch_logic_p == e_l2) << e_cache_amo_and)
                     | ((amo_fetch_logic_p == e_l2) << e_cache_amo_or)
                     | ((amo_fetch_arithmetic_p == e_l2) << e_cache_amo_add)
                     | ((amo_fetch_arithmetic_p == e_l2) << e_cache_amo_min)
                     | ((amo_fetch_arithmetic_p == e_l2) << e_cache_amo_max)
                     | ((amo_fetch_arithmetic_p == e_l2) << e_cache_amo_minu)
                     | ((amo_fetch_arithmetic_p == e_l2) << e_cache_amo_maxu)
                     )
    )
   cache
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.cache_pkt_i(cache_pkt_li)
     ,.v_i(cache_pkt_v_li)
     ,.ready_o(cache_pkt_ready_lo)

     ,.data_o(cache_data_lo)
     ,.v_o(cache_data_v_lo)
     ,.yumi_i(cache_data_yumi_li)

     ,.dma_pkt_o(dma_pkt_lo)
     ,.dma_pkt_v_o(dma_pkt_v_lo)
     ,.dma_pkt_yumi_i(dma_pkt_yumi_li)

     ,.dma_data_i(dma_data_li)
     ,.dma_data_v_i(dma_data_v_li)
     ,.dma_data_ready_o(dma_data_ready_and_lo)

     ,.dma_data_o(dma_data_lo)
     ,.dma_data_v_o(dma_data_v_lo)
     ,.dma_data_yumi_i(dma_data_yumi_li)

     ,.v_we_o()
     );

  // L2 Cache to Memory Links adapter
  bsg_cache_dma_to_wormhole
   #(.dma_addr_width_p(caddr_width_p)
     ,.dma_burst_len_p(l2_block_size_in_fill_p)

     ,.wh_flit_width_p(mem_noc_flit_width_p)
     ,.wh_cid_width_p(mem_noc_cid_width_p)
     ,.wh_len_width_p(mem_noc_len_width_p)
     ,.wh_cord_width_p(mem_noc_cord_width_p)
     )
   bsg_cache_dma_to_wormhole
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.dma_pkt_i(dma_pkt_lo)
     ,.dma_pkt_v_i(dma_pkt_v_lo)
     ,.dma_pkt_yumi_o(dma_pkt_yumi_li)

     ,.dma_data_o(dma_data_li)
     ,.dma_data_v_o(dma_data_v_li)
     ,.dma_data_ready_and_i(dma_data_ready_and_lo)

     ,.dma_data_i(dma_data_lo)
     ,.dma_data_v_i(dma_data_v_lo)
     ,.dma_data_yumi_o(dma_data_yumi_li)

     ,.wh_link_sif_i(mem_resp_link_i)
     ,.wh_link_sif_o(mem_cmd_link_o)

     ,.my_wh_cord_i(my_cord_i[coh_noc_x_cord_width_p+:mem_noc_y_cord_width_p])
     ,.my_wh_cid_i('0)
     ,.dest_wh_cord_i('1)
     ,.dest_wh_cid_i('0)
     );

endmodule

