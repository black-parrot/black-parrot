// channel_test2
//
// Simple test, 3 sources with 5 destinations, and resource contention for data flow
//
// bsg_two_fifo already tested so can tie ready high and route valid out to yumi in

module channel_test2;

localparam cycle_time_lp = 50;
localparam packet_width_lp = 3;
localparam num_src_lp = 3;
localparam num_dst_lp = 5;


//the clock and reset
logic clk_li, reset_li;
logic [2:0] src_ready_o_lo;
logic [14:0] dst_data_o_lo;
logic [4:0] dst_v_o_lo;

bsg_nonsynth_clock_gen #( .cycle_time_p(cycle_time_lp)
         ) clock_gen
        ( .o(clk_li)
        );

bsg_nonsynth_reset_gen #(  .num_clocks_p     (1)
                         , .reset_cycles_lo_p(1)
                         , .reset_cycles_hi_p(10)
                         )  reset_gen
                         (  .clk_i        (clk_li)
                          , .async_reset_o(reset_li)
                         );

bp_transfer_network_channel #(.packet_width_p(packet_width_lp)
    ,.num_src_p(num_src_lp)
    ,.num_dst_p(num_dst_lp)
  ) test_channel
  (
    .clk_i(clk_li)
    ,.reset_i(reset_li)
    //South port
    ,.src_data_i({3'b011,3'b100,3'b101}) // Data format(src2, src1, src0)
    ,.src_v_i(3'b111)
    ,.src_ready_o(src_ready_o_lo)
    //Proc port
    ,.dst_data_o(dst_data_o_lo)
    ,.dst_v_o(dst_v_o_lo)
    ,.dst_yumi_i(dst_v_o_lo)
    //Each message type has its own packet structure, and the router has its own format
    ,.dst_id_i({3'b001,3'b100,3'b011}) // Data format(dest2, dest1, dest0)
  );


endmodule