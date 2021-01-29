/*
 * bp_fe_btb.v
 *
 * Branch Target Buffer (BTB) stores the addresses of the branch targets and the
 * corresponding branch sites. Branch happens from the branch sites to the branch
 * targets. In order to save the logic sizes, the BTB is designed to have limited
 * entries for storing the branch sites, branch target pairs. The implementation
 * uses the bsg_mem_1rw_sync_synth RAM design.
 *
 * Notes:
 *   BTB writes are prioritized over BTB reads, since they come on redirections and therefore
 *     the BTB read is most likely for an erroneous instruction, anyway.
 */

`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"

module bp_fe_btb
 import bp_fe_pkg::*;
 #(parameter vaddr_width_p     = "inv"
   , parameter btb_tag_width_p = "inv"
   , parameter btb_idx_width_p = "inv"
   )
  (input                          clk_i
   , input                        reset_i

   // Synchronous read
   , input [vaddr_width_p-1:0]    r_addr_i
   , input                        r_v_i
   , output [vaddr_width_p-1:0]   br_tgt_o
   , output                       br_tgt_v_o
   , output                       br_tgt_jmp_o

   // Synchronous write
   , input                        w_v_i
   , input                        w_clr_i
   , input                        w_jmp_i
   , input [btb_tag_width_p-1:0]  w_tag_i
   , input [btb_idx_width_p-1:0]  w_idx_i
   , input [vaddr_width_p-1:0]    br_tgt_i
   );

  ///////////////////////
  // Initialization state machine
  enum logic [1:0] {e_reset, e_clear, e_run} state_n, state_r;
  wire is_reset = (state_r == e_reset);
  wire is_clear = (state_r == e_clear);
  wire is_run   = (state_r == e_run);

  localparam btb_els_lp = 2**btb_idx_width_p;
  logic [`BSG_WIDTH(btb_els_lp)-1:0] init_cnt;
  bsg_counter_clear_up
   #(.max_val_p(btb_els_lp), .init_val_p(0))
   init_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(1'b0)
     ,.up_i(is_clear)
     ,.count_o(init_cnt)
     );
  wire finished_init = (init_cnt == btb_els_lp-1'b1);

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

  typedef struct packed
  {
    logic                       v;
    logic                       jmp;
    logic [btb_tag_width_p-1:0] tag;
    logic [vaddr_width_p-1:0]   tgt;
  }  bp_btb_entry_s;

  wire [btb_idx_width_p-1:0] r_idx_li = r_addr_i[2+:btb_idx_width_p];
  wire [btb_tag_width_p-1:0] r_tag_li = r_addr_i[2+btb_idx_width_p+:btb_tag_width_p];

  bp_btb_entry_s tag_mem_data_li;
  wire                          tag_mem_w_v_li = is_clear | w_v_i;
  wire [btb_idx_width_p-1:0] tag_mem_w_addr_li = is_clear ? init_cnt : w_idx_i;
  assign tag_mem_data_li = (is_clear | (w_v_i & w_clr_i)) ? '0 : '{v: 1'b1, jmp: w_jmp_i, tag: w_tag_i, tgt: br_tgt_i};

  // We could technically forward, but instead we'll bank the memory in
  //   the future, so won't waste effort here
  wire rw_same_addr = r_v_i & w_v_i & (r_idx_li == w_idx_i);
  bp_btb_entry_s tag_mem_data_lo;
  wire                           tag_mem_r_v_li = r_v_i & ~rw_same_addr;
  wire [btb_idx_width_p-1:0]  tag_mem_r_addr_li = r_idx_li;
  bsg_mem_1r1w_sync
   #(.width_p($bits(bp_btb_entry_s)), .els_p(btb_els_lp))
   tag_mem
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.w_v_i(tag_mem_w_v_li)
     ,.w_addr_i(tag_mem_w_addr_li)
     ,.w_data_i(tag_mem_data_li)

     ,.r_v_i(tag_mem_r_v_li)
     ,.r_addr_i(tag_mem_r_addr_li)
     ,.r_data_o(tag_mem_data_lo)
     );

  logic [btb_tag_width_p-1:0] r_tag_r;
  bsg_dff_reset_en
   #(.width_p(btb_tag_width_p))
   tag_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(tag_mem_r_v_li)

     ,.data_i(r_tag_li)
     ,.data_o(r_tag_r)
     );

  logic r_v_r;
  bsg_dff_reset
   #(.width_p(1))
   r_v_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(tag_mem_r_v_li)
     ,.data_o(r_v_r)
     );

  bp_btb_entry_s tag_mem_data_bypass_lo;
  bsg_dff_reset_en_bypass
   #(.width_p($bits(bp_btb_entry_s)))
   btb_bypass_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(r_v_r)

     ,.data_i(tag_mem_data_lo)
     ,.data_o(tag_mem_data_bypass_lo)
     );

  assign br_tgt_v_o   = r_v_r & tag_mem_data_bypass_lo.v & (tag_mem_data_bypass_lo.tag == r_tag_r);
  assign br_tgt_jmp_o = r_v_r & tag_mem_data_bypass_lo.v & tag_mem_data_bypass_lo.jmp;
  assign br_tgt_o     = tag_mem_data_bypass_lo.tgt;


endmodule

