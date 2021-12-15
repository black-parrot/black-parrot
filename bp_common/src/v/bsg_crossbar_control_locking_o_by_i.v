/**
 *    bsg_crossbar_control_locking_o_by_i.v
 *
 *    This module generates the control signals for bsg_router_crossbar_o_by_i.
 *    In addition to bsg_crossbar_control_basic_o_by_i.v, it also "locks" the
 *      outputs so that streams of data will not be interleaved if multiple
 *      sources attempt to send to the same sink.
 */


`include "bsg_defines.v"

module bsg_crossbar_control_locking_o_by_i
  #(parameter `BSG_INV_PARAM(i_els_p)
    , parameter `BSG_INV_PARAM(o_els_p)
    , parameter lg_o_els_lp=`BSG_SAFE_CLOG2(o_els_p)
  )
  (
    input clk_i
    , input reset_i

    , input [i_els_p-1:0] valid_i
    , input [i_els_p-1:0][lg_o_els_lp-1:0] sel_io_i
    , output [i_els_p-1:0] yumi_o

    // crossbar outputs (ready & valid interface)
    , input [o_els_p-1:0] unlock_i
    , input [o_els_p-1:0] ready_and_i
    , output [o_els_p-1:0] valid_o
    , output [o_els_p-1:0][i_els_p-1:0] grants_oi_one_hot_o
  );

  
  // select logic
  logic [i_els_p-1:0][o_els_p-1:0] o_select;
  logic [o_els_p-1:0][i_els_p-1:0] o_select_t;

  for (genvar i = 0; i < i_els_p; i++) begin: dv
    bsg_decode_with_v #(
      .num_out_p(o_els_p)
    ) dv0 (
      .i(sel_io_i[i])
      ,.v_i(valid_i[i])
      ,.o(o_select[i])
    );
  end

  bsg_transpose #(
    .width_p(o_els_p)
    ,.els_p(i_els_p)
  ) trans0 (
    .i(o_select)
    ,.o(o_select_t)
  );


  // round robin
  logic [o_els_p-1:0] rr_yumi_li;
  logic [o_els_p-1:0][i_els_p-1:0] rr_yumi_lo;
  logic [i_els_p-1:0][o_els_p-1:0] rr_yumi_lo_t;
  
  for (genvar i = 0 ; i < o_els_p; i++) begin: rr

    logic [i_els_p-1:0] not_req_mask_r, req_mask_r;

    bsg_dff_reset_en #( .width_p(i_els_p) )
      req_words_reg
        ( .clk_i  ( clk_i )
        , .reset_i( reset_i || unlock_i[i] )
        , .en_i   ( (&req_mask_r) & (|grants_oi_one_hot_o[i]) )
        , .data_i ( ~grants_oi_one_hot_o[i] )
        , .data_o ( not_req_mask_r )
        );

    assign req_mask_r = ~not_req_mask_r;

    assign valid_o[i] = |o_select_t[i];
    assign rr_yumi_li[i] = valid_o[i] & ready_and_i[i];

    bsg_arb_round_robin #(
      .width_p(i_els_p)
    ) rr0 (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
    
      ,.reqs_i(o_select_t[i] & req_mask_r)
      ,.grants_o(grants_oi_one_hot_o[i])
      ,.yumi_i(rr_yumi_li[i])
    );

    assign rr_yumi_lo[i] = grants_oi_one_hot_o[i] & {i_els_p{rr_yumi_li[i]}};

  end 


  bsg_transpose #(
    .width_p(i_els_p)
    ,.els_p(o_els_p)
  ) trans1 (
    .i(rr_yumi_lo)
    ,.o(rr_yumi_lo_t)
  );


  for (genvar i = 0; i < i_els_p; i++) begin
    assign yumi_o[i] = |rr_yumi_lo_t[i];
  end



endmodule

`BSG_ABSTRACT_MODULE(bsg_crossbar_control_basic_o_by_i)
