/*
 * bp_fe_bht.v
 *
 * Branch History Table (BHT) records the information of the branch history, i.e.
 * branch taken or not taken.
 * Each entry consists of 2 bit saturation counter. If the counter value is in
 * the positive regime, the BHT predicts "taken"; if the counter value is in the
 * negative regime, the BHT predicts "not taken". The implementation of BHT is
 * native to this design.
 * 2-bit saturating counter(high_bit:prediction direction,low_bit:strong/weak prediction)
 */
`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"

module bp_fe_bht
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam idx_width_lp = bht_idx_width_p+ghist_width_p
   )
  (input                         clk_i
   , input                       reset_i

   , output logic                init_done_o

   , input                       w_v_i
   , input [idx_width_lp-1:0]    idx_w_i
   , input [1:0]                 val_i
   , input                       correct_i
   , output logic                w_yumi_o

   , input                       r_v_i
   , input [idx_width_lp-1:0]    idx_r_i
   , output logic [1:0]          val_o
   );

  // Initialization state machine
  enum logic [1:0] {e_reset, e_clear, e_run} state_n, state_r;
  wire is_reset = (state_r == e_reset);
  wire is_clear = (state_r == e_clear);
  wire is_run   = (state_r == e_run);

  assign init_done_o = is_run;

  localparam bht_els_lp = 2**idx_width_lp;
  localparam bht_init_lp = 2'b01;
  logic [`BSG_WIDTH(bht_els_lp)-1:0] init_cnt;
  bsg_counter_clear_up
   #(.max_val_p(bht_els_lp), .init_val_p(0))
   init_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(1'b0)
     ,.up_i(is_clear)
     ,.count_o(init_cnt)
     );
  wire finished_init = (init_cnt == bht_els_lp-1'b1);

  always_comb
    case (state_r)
      e_clear: state_n = finished_init ? e_run : e_clear;
      e_run  : state_n = e_run;
      // e_reset
      default: state_n = e_clear;
    endcase

  //synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_reset;
    else
      state_r <= state_n;

  wire rw_same_addr = r_v_i & w_v_i & (idx_r_i == idx_w_i);
  wire                       w_v_li = is_clear | (w_v_i & ~rw_same_addr);
  wire [idx_width_lp-1:0] w_addr_li = is_clear ? init_cnt : idx_w_i;
  wire [1:0]              w_data_li = is_clear ? bht_init_lp : correct_i ? {val_i[1], 1'b0} : {val_i[1]^val_i[0], 1'b1};

  wire                       r_v_li = r_v_i;
  wire [idx_width_lp-1:0] r_addr_li = idx_r_i;
  logic [1:0] r_data_lo;
  bsg_mem_1r1w_sync
   #(.width_p(2), .els_p(bht_els_lp))
   bht_mem
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.w_v_i(w_v_li)
     ,.w_addr_i(w_addr_li)
     ,.w_data_i(w_data_li)

     ,.r_v_i(r_v_li)
     ,.r_addr_i(r_addr_li)
     ,.r_data_o(r_data_lo)
     );
  assign w_yumi_o = is_run & w_v_i & ~rw_same_addr;

  logic r_v_r;
  bsg_dff_reset
   #(.width_p(1))
   r_v_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(r_v_li)
     ,.data_o(r_v_r)
     );

  bsg_dff_reset_en_bypass
   #(.width_p(2))
   bypass_reg
   (.clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(r_v_r)

    ,.data_i(r_data_lo)
    ,.data_o(val_o)
    );

endmodule

