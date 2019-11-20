
module bp_lce_link_to_io
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
   `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input clk_i
   , input reset_i

   // LCE id width

   , input [mem_noc_ral_link_width_lp-1:0]  io_cmd_link_i
   , output [mem_noc_ral_link_width_lp-1:0] io_cmd_link_o

   , input [mem_noc_ral_link_width_lp-1:0]  io_resp_link_i
   , output [mem_noc_ral_link_width_lp-1:0] io_resp_link_o

   , output [coh_noc_ral_link_width_lp-1:0] lce_req_link_i
   , input [coh_noc_ral_link_width_lp-1:0]  lce_req_link_o

   , input [coh_noc_ral_link_width_lp-1:0]  lce_cmd_link_i
   , output [coh_noc_ral_link_width_lp-1:0] lce_cmd_link_o

   // No lce_resp acknowledgements for I/O (uncached) accesses
   );

  `declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
  `declare_bsg_wormhole_concentrator_packet_s(coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, lce_cce_req_width_lp, lce_req_packet_s);
  `declare_bsg_wormhole_concentrator_packet_s(coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, lce_cmd_width_lp, lce_cmd_packet_s);

  bp_cce_mem_msg_s mem_cmd_li;
  logic mem_cmd_v_li, mem_cmd_yumi_lo;
  bp_cce_mem_msg_s mem_resp_lo;
  logic mem_resp_v_lo, mem_resp_ready_li;

  bp_me_cce_to_wormhole_link_client
   #(.bp_params_p(bp_params_p))
   io_link
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_cmd_o(mem_cmd_li)
     ,.mem_cmd_v_o(mem_cmd_v_li)
     ,.mem_cmd_yumi_i(mem_cmd_yumi_lo)

     ,.mem_resp_i(mem_resp_lo)
     ,.mem_resp_v_i(mem_resp_v_lo)
     ,.mem_resp_ready_o(mem_resp_ready_li)

     ,.cmd_link_i(io_cmd_link_i)
     ,.cmd_link_o(io_cmd_link_o)

     ,.resp_link_i(io_resp_link_i)
     ,.resp_link_o(io_resp_link_o)
     );

  bp_lce_cce_req_s lce_req_lo;
  lce_req_packet_s lce_req_packet_lo;
  logic lce_req_v_lo, lce_req_ready_li;
  bp_me_wormhole_packet_encode_lce_req
   #(.bp_params_p(bp_params_p))
   req_encode
    (.payload_i(lce_req_lo)
     ,.packet_o(lce_req_packet_lo)
     );

  bsg_wormhole_router_adapter_in
   #(.max_payload_width_p($bits(lce_req_packet_s)-coh_noc_cord_width_p-coh_noc_len_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.flit_width_p(coh_noc_flit_width_p)
     )
   lce_req_adapter_in
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.packet_i(lce_req_packet_lo)
     ,.v_i(lce_req_v_lo)
     ,.ready_o(lce_req_ready_li)

     ,.link_i(lce_req_link_i)
     ,.link_o(lce_req_link_o)
     );

  bp_lce_cmd_s lce_cmd_li;
  lce_cmd_packet_s lce_cmd_packet_li;
  logic lce_cmd_v_li, lce_cmd_yumi_lo;
  bsg_wormhole_router_adapter_out
   #(.max_payload_width_p($bits(lce_cmd_packet_s)-coh_noc_cord_width_p-coh_noc_len_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.flit_width_p(coh_noc_flit_width_p)
     )
   lce_cmd_adapter_out
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.link_i(lce_cmd_link_i)
     ,.link_o(lce_cmd_link_o)

     ,.packet_o(lce_cmd_packet_li)
     ,.v_o(lce_cmd_v_li)
     ,.yumi_i(lce_cmd_yumi_lo)
     );

  assign lce_req_v_lo    = lce_req_ready_li & mem_cmd_v_li;
  assign mem_cmd_yumi_lo = lce_req_v_lo;

  assign mem_resp_v_lo   = mem_resp_ready_li & lce_cmd_v_li;
  assign lce_cmd_yumi_lo = mem_resp_v_lo;

  bp_cce_mem_req_size_e mem_cmd_size;
  assign mem_resp_size = (lce_cmd_li.msg.uc_req.uc_size == e_lce_uc_req_1)
                         ? e_mem_size_1
                         : (lce_cmd_li.msg.uc_req.uc_size == e_lce_uc_req_2)
                           ? e_mem_size_2
                           : (lce_cmd_li.msg.uc_req.uc_size == e_lce_uc_req_4)
                             ? e_mem_size_4
                             : e_mem_size_8;

  bp_lce_cce_uc_req_size_e lce_req_size;
  assign lce_req_size = (mem_cmd_li.size == e_mem_size_1)
                        ? e_lce_uc_req_1
                        : (mem_cmd_li.size == e_mem_size_2)
                          ? e_lce_uc_req_2
                          : (mem_cmd_li.size == e_mem_size_4)
                            ? e_lce_uc_req_4
                            : e_lce_uc_req_8;

  wire mem_cmd_wr_not_rd = (mem_cmd_li.msg_type == e_cce_mem_uc_wr);
  wire lce_cmd_wr_not_rd = (lce_cmd_li.msg_type == e_lce_cmd_uc_st_done);
  always_comb
    begin
      lce_req_lo                 = '0;
      lce_req_lo.msg.uc_req.data = mem_cmd_li.data;
      lce_req_lo.msg.uc_req.size = lce_req_size;
      lce_req_lo.addr            = mem_cmd_li.addr;
      lce_req_lo.msg_type        = mem_cmd_wr_not_rd ? e_lce_req_type_uc_wr : e_lce_req_type_uc_rd;
      lce_req_lo.src_id          = '0; // TODO: fake lce_id
      lce_req_lo.dst_id          = '0; // TODO: address->lce_id

      mem_resp_lo                = '0;
      mem_resp_lo.data           = lce_cmd_li.data;
      mem_resp_lo.size           = mem_resp_size;
      mem_resp_lo.addr           = lce_cmd_li.addr;
      mem_resp_lo.msg_type       = lce_cmd_wr_not_rd ? e_cce_mem_uc_wr : e_cce_mem_uc_rd;
    end

endmodule

