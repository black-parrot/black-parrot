module bp_network_serializer 
  //import bp_common_pkg::*;
  #(parameter   num_dest              = "inv"
  , parameter   num_src               = "inv"
  , parameter   source_data_width_p   = "inv"
  , parameter   packet_data_width_p   = "inv"
  , localparam  dest_id_width_p       = `BSG_SAFE_CLOG2(num_dest)
  , localparam  src_id_width_p        = `BSG_SAFE_CLOG2(num_src)
  , localparam  num_packets_p         = (source_data_width_p + packet_data_width_p - 1) / packet_data_width_p
  , localparam  total_data_width      = packet_data_width_p*num_packets_p
  , localparam  total_o_data_width    = packet_data_width_p + dest_id_width_p + src_id_width_p
  )
  ( input                           clk_i
  , input                           reset_i
  // Data Input Channel
  , input                           valid_i
  , input [source_data_width_p-1:0] data_i
  , output                          ready_o
  // Data Output Channel
  , output                          valid_o
  , output [total_o_data_width-1:0] data_o
  , input                           yumi_i
  );


  wire [total_data_width-1:0] corrected_data_in = {{total_data_width-source_data_width_p{1'b0}},data_i};

  reg [dest_id_width_p-1:0] dest_id_r;
  reg [src_id_width_p-1:0] src_id_r;

  always @(posedge clk_i) begin 
    if(reset_i) begin
      dest_id_r <= '0;
      src_id_r  <= '0;
    end // if(reset_i)
    else begin 
      if(valid_i & ready_o) begin
        dest_id_r <= data_i[(source_data_width_p-1)-:dest_id_width_p];
        src_id_r  <= data_i[(source_data_width_p-dest_id_width_p-1)-:src_id_width_p];
      end // if(valid_i & ready_o)
      else begin
        dest_id_r <= dest_id_r;
        src_id_r <= src_id_r;
      end // else
    end // else
  end // always @(posedge clk_i)

  assign data_o[(total_o_data_width-1)-:(dest_id_width_p+src_id_width_p)] = {dest_id_r, src_id_r};

  bsg_parallel_in_serial_out #(.width_p(packet_data_width_p)
                             , .els_p(num_packets_p)
                             ) 
    serial_me
    ( .clk_i(clk_i)
    , .reset_i(reset_i)
    , .valid_i(valid_i)
    , .data_i(corrected_data_in)
    , .ready_o(ready_o)
    , .valid_o(valid_o)
    , .data_o(data_o[0+:packet_data_width_p])
    , .yumi_i(yumi_i)
    );

endmodule