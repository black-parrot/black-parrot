/**
 *  Name:
 *    bp_me_wormhole_packet_encode_mem_cmd.v
 *
 *  Description:
 *    It takes bp_mem_cmd_s as a payload, parses, and forms it into a wormhole
 *    packet that goes into the adapter.
 *
 *    packet = {payload, length, cord}
 */

`include "bp_mem_wormhole.vh"

module bp_me_wormhole_packet_encode_mem_cmd
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

    , parameter flit_width_p = "inv"
    , parameter cord_width_p = "inv"
    , parameter cid_width_p = "inv"
    , parameter len_width_p = "inv"

    , localparam mem_cmd_packet_width_lp = 
        `bp_mem_wormhole_packet_width(flit_width_p, cord_width_p, len_width_p, cid_width_p, cce_mem_msg_width_lp-cce_block_width_p, cce_block_width_p)
    )
   (input [cce_mem_msg_width_lp-1:0]       mem_cmd_i
   
    , input [cord_width_p-1:0]             src_cord_i
    , input [cid_width_p-1:0]              src_cid_i
    , input [cord_width_p-1:0]             dst_cord_i
    , input [cid_width_p-1:0]              dst_cid_i

    , output [mem_cmd_packet_width_lp-1:0] packet_o
    );

  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_mem_wormhole_packet_s(flit_width_p, cord_width_p, len_width_p, cid_width_p, cce_mem_msg_width_lp-cce_block_width_p, cce_block_width_p, bp_cmd_wormhole_packet_s);

  bp_cce_mem_msg_s mem_cmd_cast_i;
  bp_cmd_wormhole_packet_s packet_cast_o;

  assign mem_cmd_cast_i = mem_cmd_i;
  assign packet_o       = packet_cast_o;

  localparam mem_cmd_req_len_lp =
    `BSG_CDIV(mem_cmd_packet_width_lp-$bits(mem_cmd_cast_i.data), mem_noc_flit_width_p) - 1;
  localparam mem_cmd_data_len_1_lp =
    `BSG_CDIV(mem_cmd_packet_width_lp-$bits(mem_cmd_cast_i.data) + 8*1, mem_noc_flit_width_p) - 1;
  localparam mem_cmd_data_len_2_lp =
    `BSG_CDIV(mem_cmd_packet_width_lp-$bits(mem_cmd_cast_i.data) + 8*2, mem_noc_flit_width_p) - 1;
  localparam mem_cmd_data_len_4_lp =
    `BSG_CDIV(mem_cmd_packet_width_lp-$bits(mem_cmd_cast_i.data) + 8*4, mem_noc_flit_width_p) - 1;
  localparam mem_cmd_data_len_8_lp =
    `BSG_CDIV(mem_cmd_packet_width_lp-$bits(mem_cmd_cast_i.data) + 8*8, mem_noc_flit_width_p) - 1;
  localparam mem_cmd_data_len_16_lp =
    `BSG_CDIV(mem_cmd_packet_width_lp-$bits(mem_cmd_cast_i.data) + 8*16, mem_noc_flit_width_p) - 1;
  localparam mem_cmd_data_len_32_lp =
    `BSG_CDIV(mem_cmd_packet_width_lp-$bits(mem_cmd_cast_i.data) + 8*32, mem_noc_flit_width_p) - 1;
  localparam mem_cmd_data_len_64_lp =
    `BSG_CDIV(mem_cmd_packet_width_lp-$bits(mem_cmd_cast_i.data) + 8*64, mem_noc_flit_width_p) - 1;

  logic [len_width_p-1:0] data_cmd_len_li;

  always_comb begin
    packet_cast_o.data       = mem_cmd_cast_i.data;
    packet_cast_o.msg        = mem_cmd_cast_i[0+:cce_mem_msg_width_lp-cce_block_width_p];
    packet_cast_o.src_cord   = src_cord_i;
    packet_cast_o.src_cid    = src_cid_i;

    packet_cast_o.cord    = dst_cord_i;
    packet_cast_o.cid     = dst_cid_i;

    case (mem_cmd_cast_i.size)
      e_mem_size_1 : data_cmd_len_li = len_width_p'(mem_cmd_data_len_1_lp);
      e_mem_size_2 : data_cmd_len_li = len_width_p'(mem_cmd_data_len_2_lp);
      e_mem_size_4 : data_cmd_len_li = len_width_p'(mem_cmd_data_len_4_lp);
      e_mem_size_8 : data_cmd_len_li = len_width_p'(mem_cmd_data_len_8_lp);
      e_mem_size_16: data_cmd_len_li = len_width_p'(mem_cmd_data_len_16_lp);
      e_mem_size_32: data_cmd_len_li = len_width_p'(mem_cmd_data_len_32_lp);
      e_mem_size_64: data_cmd_len_li = len_width_p'(mem_cmd_data_len_64_lp);
      default: data_cmd_len_li = '0;
    endcase

    case (mem_cmd_cast_i.msg_type)
      e_cce_mem_rd
      ,e_cce_mem_wr
      ,e_cce_mem_uc_rd: packet_cast_o.len = len_width_p'(mem_cmd_req_len_lp);
      e_cce_mem_uc_wr
      ,e_cce_mem_wb   : packet_cast_o.len = data_cmd_len_li;
      default: packet_cast_o = '0;
    endcase
  end

endmodule

