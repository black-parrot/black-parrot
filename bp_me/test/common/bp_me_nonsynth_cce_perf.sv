/**
 *
 * Name:
 *   bp_me_nonsynth_cce_perf.sv
 *
 * Description:
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_nonsynth_cce_perf
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    `declare_bp_bedrock_lce_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

    , localparam cnt_max_lp = 64'h0FFF_FFFF_FFFF_FFFF
    , localparam cce_trace_file_p = "cce_perf"
    , localparam cnt_ptr_width_lp = `BSG_SAFE_CLOG2(cnt_max_lp+1)
  )
  (input                                            clk_i
   , input                                          reset_i
   , input [cce_id_width_p-1:0]                     cce_id_i
   , input                                          req_start_i
   , input [lce_req_header_width_lp-1:0]            lce_req_header_i
   , input                                          req_end_i
   , input                                          cmd_send_i
   , input [lce_cmd_header_width_lp-1:0]            lce_cmd_header_i
   , input                                          resp_receive_i
   , input [lce_resp_header_width_lp-1:0]           lce_resp_header_i
   , input                                          mem_rev_receive_i
   , input                                          mem_rev_squash_i
   , input [mem_rev_header_width_lp-1:0]            mem_rev_header_i
   , input                                          mem_fwd_send_i
   , input [mem_fwd_header_width_lp-1:0]            mem_fwd_header_i
  );

  `declare_bp_bedrock_lce_if(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p);
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  bp_bedrock_lce_req_header_s  lce_req;

  integer file;
  string file_name;

  always_ff @(negedge reset_i) begin
    file_name = $sformatf("%s_%x.trace", cce_trace_file_p, cce_id_i);
    file      = $fopen(file_name, "w");
    $fdisplay(file, "Time |: Cycle,CCE,Op,Latency");
  end

  logic req_started_r;

  logic cnt_up;
  wire cnt_clr = ~req_started_r & req_start_i;
  logic [cnt_ptr_width_lp-1:0] cnt;
  bsg_counter_clear_up
    #(.max_val_p(cnt_max_lp)
      ,.init_val_p('0)
      )
  req_latency_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.clear_i(cnt_clr)
     ,.up_i(cnt_up)
     ,.count_o(cnt)
     );

  logic [cnt_ptr_width_lp-1:0] total_cycles, idle_cycles;

  bsg_counter_clear_up
    #(.max_val_p(cnt_max_lp)
      ,.init_val_p('0)
      )
  cycles_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.clear_i(reset_i)
     ,.up_i(1'b1)
     ,.count_o(total_cycles)
     );

  // idle when not actively processing a request
  bsg_counter_clear_up
    #(.max_val_p(cnt_max_lp)
      ,.init_val_p('0)
      )
  idle_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.clear_i(reset_i)
     ,.up_i(~cnt_up)
     ,.count_o(idle_cycles)
     );

  bsg_dff_reset_en
    #(.width_p($bits(bp_bedrock_lce_req_header_s)))
  lce_req_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(cnt_clr)
     ,.data_i(lce_req_header_i)
     ,.data_o(lce_req)
     );

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      req_started_r <= 1'b0;
      cnt_up <= 1'b0;
    end else begin
      if (~req_started_r & req_start_i) begin
        req_started_r <= 1'b1;
        cnt_up <= 1'b1;
      end
      if (req_started_r & req_end_i) begin
        cnt_up <= 1'b0;
        req_started_r <= 1'b0;
      end
    end
  end

  string op;
  always_comb begin
    case (lce_req.msg_type.req)
      e_bedrock_req_rd_miss: op = "RD";
      e_bedrock_req_wr_miss: op = "WR";
      e_bedrock_req_uc_rd: op = "UC_RD";
      e_bedrock_req_uc_wr: op = "UC_WR";
      default: op = "BAD";
    endcase
  end

  // Tracer
  always_ff @(negedge clk_i) begin
    if (~reset_i) begin
      if (req_started_r & req_end_i) begin
        $fdisplay(file, "%12t |: %0d,%0d,%s,%0d", $time, total_cycles, cce_id_i, op, cnt+'d1);
      end
    end // reset
  end // always_ff

  final begin
    $fdisplay(file, "%12t |: total: %0d", $time, total_cycles);
    $fdisplay(file, "%12t |: busy: %0d", $time, total_cycles - idle_cycles);
    $fdisplay(file, "%12t |: idle: %0d", $time, idle_cycles);
  end

endmodule
