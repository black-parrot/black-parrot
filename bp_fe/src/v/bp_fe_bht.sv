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

   , localparam entry_width_lp = 2*bht_row_els_p
   )
  (input                                  clk_i
   , input                                reset_i

   , output logic                         init_done_o

   , input                                w_v_i
   , input [bht_idx_width_p-1:0]          w_idx_i
   , input [ghist_width_p-1:0]            w_ghist_i
   , input [bht_row_width_p-1:0]          val_i
   , input                                correct_i
   , output logic                         w_yumi_o

   , input                                r_v_i
   , input [vaddr_width_p-1:0]            r_addr_i
   , input [ghist_width_p-1:0]            r_ghist_i
   , output logic [bht_row_width_p-1:0]   val_o
   , output logic                         pred_o
   );

  // Initialization state machine
  enum logic [1:0] {e_reset, e_clear, e_run} state_n, state_r;
  wire is_reset = (state_r == e_reset);
  wire is_clear = (state_r == e_clear);
  wire is_run   = (state_r == e_run);

  assign init_done_o = is_run;

  localparam idx_width_lp = bht_idx_width_p+ghist_width_p;
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

  logic rw_same_addr;

  wire                           w_v_li  = is_clear | (w_v_i & ~rw_same_addr);
  wire [idx_width_lp-1:0]       w_idx_li = is_clear ? init_cnt : {w_idx_i, w_ghist_i};
  logic [bht_row_width_p-1:0] w_data_li;
  for (genvar i = 0; i < bht_row_width_p; i+=2)
    begin : wval
      assign w_data_li[i]   = is_clear ? bht_init_lp[0] : ~correct_i;
      assign w_data_li[i+1] = is_clear ? bht_init_lp[1] : val_i[i+1] ^ (~correct_i & val_i[i]);
    end

  // GSELECT
  wire                            r_v_li = r_v_i;
  wire [idx_width_lp-1:0]       r_idx_li = {r_addr_i[2+:bht_idx_width_p], r_ghist_i};
  logic [bht_row_width_p-1:0] r_data_lo;

  assign rw_same_addr = r_v_i & w_v_i & (r_idx_li == w_idx_li);

  bsg_mem_1r1w_sync
   #(.width_p(bht_row_width_p), .els_p(bht_els_lp), .latch_last_read_p(1))
   bht_mem
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.w_v_i(w_v_li)
     ,.w_addr_i(w_idx_li)
     ,.w_data_i(w_data_li)

     ,.r_v_i(r_v_li)
     ,.r_addr_i(r_idx_li)
     ,.r_data_o(r_data_lo)
     );
  assign w_yumi_o = is_run & w_v_i & ~rw_same_addr;

  logic [`BSG_SAFE_CLOG2(bht_row_width_p)-1:0] pred_idx_r;
  if (bht_row_els_p > 1)
    begin : fold
      wire [`BSG_SAFE_CLOG2(bht_row_width_p)-1:0] pred_idx_n =
        1'b1 + (r_addr_i[2+bht_idx_width_p+:`BSG_SAFE_CLOG2(bht_row_els_p)] << 1'b1);
      bsg_dff
       #(.width_p(`BSG_SAFE_CLOG2(bht_row_width_p)))
       pred_idx_reg
        (.clk_i(clk_i)
         ,.data_i(pred_idx_n)
         ,.data_o(pred_idx_r)
         );
   end
 else
   begin : no_fold
     assign pred_idx_r = 1'b1;
   end

  assign val_o = r_data_lo;
  assign pred_o = val_o[pred_idx_r];

endmodule

