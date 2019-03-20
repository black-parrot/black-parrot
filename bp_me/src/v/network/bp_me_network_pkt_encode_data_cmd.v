/**
 *  Name:
 *    bp_me_network_pkt_encode_data_cmd.v
 *
 *  Description:
 *    It takes bp_lce_cce_data_cmd_s as a payload, parses, and forms it into a wormhole
 *    packet that goes into the adapter.
 *
 *    packet = {payload, length, y_cord, x_cord}
 */


module bp_me_network_pkt_encode_data_cmd
  import bp_common_pkg::*;
  #(parameter num_lce_p="inv"
    , parameter num_cce_p="inv"
    , parameter lce_assoc_p="inv"
    , parameter block_size_in_bits_p="inv"

    , parameter max_num_flit_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    
    , parameter data_width_p=64

    , localparam lce_data_cmd_width_lp=
      `bp_lce_data_cmd_width(num_lce_p,block_size_in_bits_p,lce_assoc_p)

    , localparam len_width_lp=`BSG_SAFE_CLOG2(max_num_flit_p)
    , localparam max_payload_width_lp=lce_data_cmd_width_lp
    , localparam max_packet_width_lp=
      (x_cord_width_p+y_cord_width_p+len_width_lp+max_payload_width_lp)
    , localparam width_lp=
      (max_packet_width_lp/max_num_flit_p)+((max_packet_width_lp%max_num_flit_p) == 0 ? 0 : 1)

    , localparam nc_packet_width_lp =
      (lce_data_cmd_width_lp-block_size_in_bits_p+data_width_p)
    , localparam data_cmd_len_lp =
      (max_packet_width_lp/width_lp)+(max_packet_width_lp%width_lp==0 ? 0 : 1)-1
    , localparam nc_len_lp = 
      (nc_packet_width_lp/width_lp)+(nc_packet_width_lp%width_lp==0 ? 0 : 1)-1
  )
  (
    input [lce_data_cmd_width_lp-1:0] payload_i
    , output logic [max_packet_width_lp-1:0] packet_o
  );


  `declare_bp_lce_data_cmd_s(num_lce_p,block_size_in_bits_p,lce_assoc_p);
  bp_lce_data_cmd_s data_cmd;
  assign data_cmd = payload_i;


  logic [x_cord_width_p-1:0] x_cord;
  logic [y_cord_width_p-1:0] y_cord;
  logic [len_width_lp-1:0] length;

  always_comb begin
    y_cord = y_cord_width_lp'(1);
    x_cord = x_cord_width_lp'(data_cmd.dst_id);

    case (data_cmd.msg_type)
      e_lce_data_cmd_transfer: begin
        length = len_width_lp'(data_cmd_len_lp);
      end

      e_lce_data_cmd_cce: begin
        length = len_width_lp'(data_cmd_len_lp);
      end

      e_lce_data_cmd_non_cacheable: begin
        length = len_width_lp'(nc_len_lp);
      end

      default: begin
        length = len_width_lp'(0); // this should never happen...
      end
    endcase
  end

  assign packet_o = {data_cmd, length, y_cord, x_cord};

endmodule
