/**
 *  Name:
 *    bp_me_network_pkt_encode_resp.v
 *
 *  Description:
 *    It takes bp_lce_cce_data_resp_s as a payload, parses, and forms it into a wormhole
 *    packet that goes into the adapter.
 *
 *    packet = {payload, length, y_cord, x_cord}
 */


module bp_me_network_pkt_encode_resp
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
    `declare_bp_proc_params(cfg_p)

    , parameter max_num_flit_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    
    , localparam lce_cce_resp_width_lp=
      `bp_lce_cce_resp_width(num_cce_p, num_lce_p, paddr_width_p, cce_block_width_p)

    , localparam len_width_lp=`BSG_SAFE_CLOG2(max_num_flit_p)

    , localparam max_packet_width_lp=
      (x_cord_width_p+y_cord_width_p+len_width_lp+lce_cce_resp_width_lp)

    , localparam width_lp=
      (max_packet_width_lp/max_num_flit_p)+((max_packet_width_lp%max_num_flit_p) == 0 ? 0 : 1)

    , localparam wb_packet_width_lp = lce_cce_resp_width_lp
    , localparam resp_packet_width_lp = (lce_cce_resp_width_lp-cce_block_width_p)

    , localparam wb_len_lp =
      (wb_packet_width_lp/width_lp)+(wb_packet_width_lp%width_lp==0 ? 0 : 1)-1
    , localparam resp_len_lp = 
      (resp_packet_width_lp/width_lp)+(resp_packet_width_lp%width_lp==0 ? 0 : 1)-1
  )
  (
    input [lce_cce_resp_width_lp-1:0] payload_i
    , output logic [max_packet_width_lp-1:0] packet_o
  );

  `declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p);

  bp_lce_cce_resp_s resp;
  assign resp = payload_i;

  logic [x_cord_width_p-1:0] x_cord;
  logic [y_cord_width_p-1:0] y_cord;
  logic [len_width_lp-1:0] length;

  always_comb begin
    y_cord = y_cord_width_p'(0);
    x_cord = x_cord_width_p'(resp.dst_id << 1);

    case (data_resp.msg_type)
      e_lce_cce_resp_wb: begin
        length = len_width_lp'(wb_len_lp);
      end

      default: begin
        length = len_width_lp'(resp_len_lp);
      end
    endcase
  end

  assign packet_o = {resp, length, y_cord, x_cord};

endmodule
