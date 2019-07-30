/**
 *  Name:
 *    bp_me_network_pkt_encode_cmd.v
 *
 *  Description:
 *    It takes bp_lce_cce_data_cmd_s as a payload, parses, and forms it into a wormhole
 *    packet that goes into the adapter.
 *
 *    packet = {payload, length, y_cord, x_cord}
 */


module bp_me_network_pkt_encode_cmd
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
    `declare_bp_proc_params(cfg_p)

    , parameter max_num_flit_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    
    , localparam lce_cmd_width_lp=
      `bp_lce_cmd_width(num_lce_p, lce_assoc_p, cce_block_width_p)

    , localparam len_width_lp=`BSG_SAFE_CLOG2(max_num_flit_p)

    , localparam max_packet_width_lp=
      (x_cord_width_p+y_cord_width_p+len_width_lp+lce_cmd_width_lp)

    , localparam width_lp=
      (max_packet_width_lp/max_num_flit_p)+((max_packet_width_lp%max_num_flit_p) == 0 ? 0 : 1)

    , localparam uc_packet_width_lp =
      (lce_cmd_width_lp-cce_block_width_p+dword_width_p)
    , localparam cmd_packet_width_lp =
      (lce_cmd_width_lp-`bp_lce_cmd_pad(num_cce_p, num_lce_p, lce_assoc_p, paddr_width_p, cce_block_width_p))

    , localparam data_cmd_len_lp =
      (max_packet_width_lp/width_lp)+(max_packet_width_lp%width_lp==0 ? 0 : 1)-1
    , localparam uc_cmd_len_lp = 
      (uc_packet_width_lp/width_lp)+(uc_packet_width_lp%width_lp==0 ? 0 : 1)-1
    , localparam cmd_len_lp =
      (cmd_packet_width_lp/width_lp)+(cmd_packet_width_lp%width_lp==0 ? 0 : 1)-1
  )
  (
    input [lce_cmd_width_lp-1:0] payload_i
    , output logic [max_packet_width_lp-1:0] packet_o
  );


  `declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p);

  bp_lce_cmd_s cmd;
  assign cmd = payload_i;

  logic [x_cord_width_p-1:0] x_cord;
  logic [y_cord_width_p-1:0] y_cord;
  logic [len_width_lp-1:0] length;

  always_comb begin
    y_cord = y_cord_width_p'(0);
    x_cord = x_cord_width_p'(cmd.dst_id);

    case (cmd.msg_type)
      e_lce_cmd_data: begin
        length = len_width_lp'(data_cmd_len_lp);
      end

      e_lce_cmd_uc_data: begin
        length = len_width_lp'(uc_cmd_len_lp);
      end

      default: begin
        length = len_width_lp'(cmd_len_lp);
      end
    endcase
  end

  assign packet_o = {cmd, length, y_cord, x_cord};

endmodule
