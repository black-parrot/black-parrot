/**
 * Directed regression for uncached I/O AMO bridging.
 *
 * This test wires bp_io_link_to_lce and bp_io_cce back-to-back and checks
 * that AMO msg_type/subop are preserved in both directions.
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"
`include "bp_top_defines.svh"

module bp_io_amo_bridge_regression_tb
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 import bp_top_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
   )
  ();

  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);

  logic clk, reset;
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  initial begin
    reset = 1'b1;
    repeat (5) @(posedge clk);
    reset = 1'b0;
  end

  localparam [lce_id_width_p-1:0] lce_id_lp = '0;
  localparam [cce_id_width_p-1:0] cce_id_lp = '0;

  // External IO link side
  logic [mem_fwd_header_width_lp-1:0] io_mem_fwd_header_i;
  logic [bedrock_fill_width_p-1:0]    io_mem_fwd_data_i;
  logic                               io_mem_fwd_v_i;
  logic                               io_mem_fwd_ready_and_o;

  logic [mem_rev_header_width_lp-1:0] io_mem_rev_header_o;
  logic [bedrock_fill_width_p-1:0]    io_mem_rev_data_o;
  logic                               io_mem_rev_v_o;
  logic                               io_mem_rev_ready_and_i;

  // Interconnect between io_link and io_cce
  logic [lce_req_header_width_lp-1:0] lce_req_header_li;
  logic [bedrock_fill_width_p-1:0]    lce_req_data_li;
  logic                               lce_req_v_li;
  logic                               lce_req_ready_and_lo;

  logic [lce_cmd_header_width_lp-1:0] lce_cmd_header_li;
  logic [bedrock_fill_width_p-1:0]    lce_cmd_data_li;
  logic                               lce_cmd_v_li;
  logic                               lce_cmd_ready_and_lo;

  // External memory side of io_cce
  logic [mem_fwd_header_width_lp-1:0] mem_fwd_header_lo;
  logic [bedrock_fill_width_p-1:0]    mem_fwd_data_lo;
  logic                               mem_fwd_v_lo;
  logic                               mem_fwd_ready_and_li;

  logic [mem_rev_header_width_lp-1:0] mem_rev_header_li;
  logic [bedrock_fill_width_p-1:0]    mem_rev_data_li;
  logic                               mem_rev_v_li;
  logic                               mem_rev_ready_and_lo;

  // Structured views for easier field checks
  bp_bedrock_mem_fwd_header_s io_mem_fwd_header_cast_i;
  bp_bedrock_mem_fwd_header_s mem_fwd_header_cast_lo;
  bp_bedrock_mem_rev_header_s mem_rev_header_cast_li;
  bp_bedrock_mem_rev_header_s io_mem_rev_header_cast_o;

  assign io_mem_fwd_header_i      = io_mem_fwd_header_cast_i;
  assign mem_fwd_header_cast_lo   = mem_fwd_header_lo;
  assign mem_rev_header_li        = mem_rev_header_cast_li;
  assign io_mem_rev_header_cast_o = io_mem_rev_header_o;

  bp_io_link_to_lce
   #(.bp_params_p(bp_params_p))
   io_link
    (.clk_i(clk)
     ,.reset_i(reset)
     ,.lce_id_i(lce_id_lp)

     ,.mem_fwd_header_i(io_mem_fwd_header_i)
     ,.mem_fwd_data_i(io_mem_fwd_data_i)
     ,.mem_fwd_v_i(io_mem_fwd_v_i)
     ,.mem_fwd_ready_and_o(io_mem_fwd_ready_and_o)

     ,.mem_rev_header_o(io_mem_rev_header_o)
     ,.mem_rev_data_o(io_mem_rev_data_o)
     ,.mem_rev_v_o(io_mem_rev_v_o)
     ,.mem_rev_ready_and_i(io_mem_rev_ready_and_i)

     ,.lce_req_header_o(lce_req_header_li)
     ,.lce_req_data_o(lce_req_data_li)
     ,.lce_req_v_o(lce_req_v_li)
     ,.lce_req_ready_and_i(lce_req_ready_and_lo)

     ,.lce_cmd_header_i(lce_cmd_header_li)
     ,.lce_cmd_data_i(lce_cmd_data_li)
     ,.lce_cmd_v_i(lce_cmd_v_li)
     ,.lce_cmd_ready_and_o(lce_cmd_ready_and_lo)
     );

  bp_io_cce
   #(.bp_params_p(bp_params_p))
   io_cce
    (.clk_i(clk)
     ,.reset_i(reset)
     ,.cce_id_i(cce_id_lp)

     ,.lce_req_header_i(lce_req_header_li)
     ,.lce_req_data_i(lce_req_data_li)
     ,.lce_req_v_i(lce_req_v_li)
     ,.lce_req_ready_and_o(lce_req_ready_and_lo)

     ,.lce_cmd_header_o(lce_cmd_header_li)
     ,.lce_cmd_data_o(lce_cmd_data_li)
     ,.lce_cmd_v_o(lce_cmd_v_li)
     ,.lce_cmd_ready_and_i(lce_cmd_ready_and_lo)

     ,.mem_rev_header_i(mem_rev_header_li)
     ,.mem_rev_data_i(mem_rev_data_li)
     ,.mem_rev_v_i(mem_rev_v_li)
     ,.mem_rev_ready_and_o(mem_rev_ready_and_lo)

     ,.mem_fwd_header_o(mem_fwd_header_lo)
     ,.mem_fwd_data_o(mem_fwd_data_lo)
     ,.mem_fwd_v_o(mem_fwd_v_lo)
     ,.mem_fwd_ready_and_i(mem_fwd_ready_and_li)
     );

  initial begin
    io_mem_fwd_v_i        = 1'b0;
    io_mem_fwd_data_i     = '0;
    io_mem_fwd_header_cast_i = '0;
    io_mem_rev_ready_and_i = 1'b1;

    mem_fwd_ready_and_li  = 1'b1;
    mem_rev_v_li          = 1'b0;
    mem_rev_data_li       = '0;
    mem_rev_header_cast_li = '0;

    wait (!reset);
    @(posedge clk);

    // Launch AMO request from the IO link side.
    io_mem_fwd_header_cast_i.msg_type = e_bedrock_mem_amo;
    io_mem_fwd_header_cast_i.subop    = e_bedrock_amoadd;
    io_mem_fwd_header_cast_i.addr     = paddr_width_p'(64'h0000_1000);
    io_mem_fwd_header_cast_i.size     = e_bedrock_msg_size_8;
    io_mem_fwd_header_cast_i.payload  = '0;
    io_mem_fwd_header_cast_i.payload.src_did = did_width_p'(1);
    io_mem_fwd_data_i = {bedrock_fill_width_p/dword_width_gp{64'h1234_5678_9ABC_DEF0}};
    io_mem_fwd_v_i = 1'b1;
    do @(posedge clk); while (!io_mem_fwd_ready_and_o);
    io_mem_fwd_v_i = 1'b0;

    // Verify AMO made it through io_cce memory-fwd side without being downgraded.
    do @(posedge clk); while (!mem_fwd_v_lo);
    if (mem_fwd_header_cast_lo.msg_type != e_bedrock_mem_amo)
      $fatal(1, "FAIL: AMO msg_type downgraded before memory side");
    if (mem_fwd_header_cast_lo.subop != e_bedrock_amoadd)
      $fatal(1, "FAIL: AMO subop not preserved before memory side");

    // Return AMO response from memory side.
    mem_rev_header_cast_li.msg_type = e_bedrock_mem_amo;
    mem_rev_header_cast_li.subop    = e_bedrock_amoadd;
    mem_rev_header_cast_li.addr     = mem_fwd_header_cast_lo.addr;
    mem_rev_header_cast_li.size     = e_bedrock_msg_size_8;
    mem_rev_header_cast_li.payload  = '0;
    mem_rev_header_cast_li.payload.lce_id  = mem_fwd_header_cast_lo.payload.lce_id;
    mem_rev_header_cast_li.payload.src_did = mem_fwd_header_cast_lo.payload.src_did;
    mem_rev_data_li = {bedrock_fill_width_p/dword_width_gp{64'hDEAD_BEEF_F00D_CAFE}};
    mem_rev_v_li = 1'b1;
    do @(posedge clk); while (!mem_rev_ready_and_lo);
    mem_rev_v_li = 1'b0;

    // Verify AMO response is preserved back on io link side.
    do @(posedge clk); while (!io_mem_rev_v_o);
    if (io_mem_rev_header_cast_o.msg_type != e_bedrock_mem_amo)
      $fatal(1, "FAIL: AMO response msg_type downgraded on return path");
    if (io_mem_rev_header_cast_o.subop != e_bedrock_amoadd)
      $fatal(1, "FAIL: AMO response subop not preserved on return path");

    $display("PASS: io bridge AMO msg_type/subop preserved end-to-end");
    $finish;
  end

  initial begin
    repeat (2000) @(posedge clk);
    $fatal(1, "TIMEOUT: io bridge AMO regression did not complete");
  end

endmodule
