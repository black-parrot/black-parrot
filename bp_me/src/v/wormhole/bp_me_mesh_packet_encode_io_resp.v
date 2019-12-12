
`include "bp_io_mesh.vh"

module bp_me_mesh_packet_encode_io_resp
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

    , localparam io_resp_payload_width_lp = `bp_io_mesh_payload_width(io_noc_cord_width_p, cce_mem_msg_width_lp)
    , localparam io_resp_packet_width_lp = `bsg_mesh_packet_width(io_noc_cord_width_p, io_resp_payload_width_lp)
    )
   (input [cce_mem_msg_width_lp-1:0]       io_resp_i

    , input [io_noc_cord_width_p-1:0]      src_cord_i
    , input [io_noc_cord_width_p-1:0]      dst_cord_i

    , output [io_resp_packet_width_lp-1:0] packet_o
    );

  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_io_mesh_payload_s(io_noc_cord_width_p, $bits(bp_cce_mem_msg_s), bp_io_resp_payload_s);
  `declare_bsg_mesh_packet_s(io_noc_cord_width_p, $bits(bp_io_resp_payload_s), bp_io_resp_packet_s);
  
  bp_cce_mem_msg_s    io_resp_cast_i;
  bp_io_resp_packet_s packet_cast_o;

  assign io_resp_cast_i = io_resp_i;
  assign packet_o       = packet_cast_o;

  bp_io_resp_payload_s payload_li;

  always_comb
    begin
      payload_li.data     = io_resp_i;
      payload_li.src_cord = src_cord_i;

      packet_cast_o.payload  = payload_li;
      packet_cast_o.dst_cord = dst_cord_i;
    end

endmodule

