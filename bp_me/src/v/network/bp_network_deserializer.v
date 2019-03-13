module bp_network_deserializer 
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
  ( input                                   clk_i
  , input                                   reset_i
  
  , input                                   v_i
  , output logic                            ready_o
  , input [total_o_data_width-1:0]          data_i

  , output logic [source_data_width_p-1:0]  data_o
  , output logic                            v_o
  , input                                   yumi_i
  );

  assign ready_o = 1'b1;

  logic [`BSG_SAFE_CLOG2(num_packets_p)-1:0] count [num_src-1:0];
  logic fifo_en;
  logic [src_id_width_p-1:0] p_addr;  

  wire [src_id_width_p-1:0]                 curr_addr = data_i[(total_o_data_width-dest_id_width_p-1)-:src_id_width_p];

  wire [packet_data_width_p-1:0]            curr_data = data_i[0+:packet_data_width_p];

  wire [`BSG_SAFE_CLOG2(num_packets_p)-1:0] count_p1 = count[curr_addr] + 1'b1;

  wire                                      fifo_en_r = v_i & (count_p1 == num_packets_p-1);

  wire [num_packets_p-1:0]                  curr_mask = 1'b1 << count[curr_addr];


  wire [`BSG_SAFE_CLOG2(num_packets_p)-1:0] count_n = ( v_i ? ((count_p1 == num_packets_p) ? '0 : count_p1) : count[curr_addr] );


  always_ff @ (posedge clk_i) begin
    if(reset_i) begin
      integer i;
      for(i = 0; i < num_src; i = i + 1) begin
        count[i] <= '0;
      end // for(i = 0; i < num_src; i = i + 1)
    end // if(reset_i)
    else begin
      count[curr_addr] <= count_n;  
    end // else
  end // always_ff @ (posedge clk_i)

  wire fifo_vo;
  wire [src_id_width_p-1:0] data_addr_fifo;

  bsg_fifo_1r1w_small #(.width_p(src_id_width_p)
                      , .els_p(num_src)
                      , .ready_THEN_valid_p(0)
                      )
    queue
    ( .clk_i(clk_i)
    , .reset_i(reset_i)

    , .v_i(fifo_en)
    , .ready_o()
    , .data_i(p_addr)

    , .v_o(fifo_vo)
    , .data_o(data_addr_fifo)
    , .yumi_i(yumi_i & fifo_vo)
    );

  wire [total_data_width-1:0] ram_data_out;

  bsg_mem_1r1w_sync_mask_write_var #(.width_p(total_data_width)
                                   , .mask_width_p(packet_data_width_p)
                                   , .els_p(2**`BSG_SAFE_CLOG2(num_src))
                                   , .harden_p(1'b0)
                                   )
    scratch_pad
    ( .clk_i(clk_i)
    , .reset_i(reset_i)
    , .w_v_i(v_i)
    , .w_mask_i(curr_mask)
    , .w_addr_i(curr_addr)
    , .w_data_i({num_packets_p{curr_data}})
    , .r_v_i(1'b1)
    , .r_addr_i(data_addr_fifo)
    , .r_data_o(ram_data_out)
    );

  always_ff @(posedge clk_i) begin
    v_o <= fifo_vo;
    fifo_en <= fifo_en_r;
    p_addr <= curr_addr;
  end

  assign data_o = ram_data_out[source_data_width_p-1:0];

endmodule




  // bsg_mem_1r1w_sync_mask_write_byte scratch_pad 
  //   #(.els_p(2**source_data_width_p)
  //   , .data_width_p(total_data_width)
  //   )
  //   ( .clk_i()
  //   , .reset_i()
  //   , .v_i()
  //   , .w_i()
  //   , .addr_i()
  //   , .data_i()
  //   , .write_mask_i()
  //   , .data_o()
  //   );