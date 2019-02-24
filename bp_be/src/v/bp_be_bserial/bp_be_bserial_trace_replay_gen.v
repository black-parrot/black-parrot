/*
 *
 * bp_be_bserial_trace_replay_gen.v
 *
 */

module bp_be_bserial_trace_replay_gen
 import bp_be_rv64_pkg::*;
 #(parameter trace_ring_width_p = "inv"
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   , localparam reg_addr_width_lp = rv64_reg_addr_width_gp

   , parameter en_p = 1
   )
  (input                             clk_i
   , input                           reset_i

   , input                           pc_i
   , input                           pc_w_v_i
   , input                           npc_i
   , input                           npc_w_v_i
   , input                           rd_data_i
   , input [reg_addr_width_lp-1:0]   rd_addr_i
   , input                           rd_w_v_i
   , input                           commit_v_i
   , input                           recover_v_i
   , input                           shex_dir_i

   , input                           skip_commit_i
   , input [trace_ring_width_p-1:0]  data_i

   , output [trace_ring_width_p-1:0] data_o
   , output                          v_o
   , input                           ready_i
   );

logic [reg_data_width_lp-1:0] rd_data_r, rd_data_rev_r;
logic [reg_addr_width_lp-1:0] rd_addr_r;
logic [reg_data_width_lp-1:0] pc_r;
logic [reg_data_width_lp-1:0] npc_r;
logic                         commit_v_r;
logic                         recover_v_r;
logic                         shex_dir_r;

// Suppress warnings
wire unused0;
assign unused0 = ready_i;

always_ff @(posedge clk_i)
  begin
    commit_v_r  <= commit_v_i;
    recover_v_r <= recover_v_i;
    shex_dir_r  <= shex_dir_i;
  end

  bsg_serial_in_parallel_out
   #(.width_p(1)
     ,.els_p(reg_data_width_lp)
     ,.consume_all_p(1)
     )
   rd_data_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(rd_data_i)
     ,.valid_i(rd_w_v_i)
     ,.ready_o(/* We rely on state machine for ready_o */)

     ,.data_o(rd_data_r)
     ,.valid_o(/* We rely on state machine for valid_o */)
     ,.yumi_cnt_i(commit_v_r)
     );

  bsg_serial_in_parallel_out
   #(.width_p(1)
     ,.els_p(reg_data_width_lp)
     ,.consume_all_p(1)
     )
   npc_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(npc_i)
     ,.valid_i(npc_w_v_i)
     ,.ready_o(/* We rely on state machine for ready_o */)

     ,.data_o(npc_r)
     ,.valid_o(/* We rely on state machine for valid_o */)
     ,.yumi_cnt_i(commit_v_r)
     );

  bsg_serial_in_parallel_out
   #(.width_p(1)
     ,.els_p(reg_data_width_lp)
     ,.consume_all_p(1)
     )
   pc_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(pc_i)
     ,.valid_i(pc_w_v_i)
     ,.ready_o(/* We rely on state machine for ready_o */)

     ,.data_o(pc_r)
     ,.valid_o(/* We rely on state machine for valid_o */)
     ,.yumi_cnt_i(commit_v_r)
     );

  bsg_dff_en
   #(.width_p(reg_addr_width_lp))
   rd_addr_reg
    (.clk_i(clk_i)

     ,.en_i(rd_w_v_i)
     ,.data_i(rd_addr_i)
     ,.data_o(rd_addr_r)
     );

assign rd_data_rev_r = {<<{rd_data_r}};
assign v_o    = commit_v_i & rd_w_v_i;

assign data_o = skip_commit_i
                ? data_i
                : shex_dir_i
                  ? {60'b0, rd_addr_r, rd_data_rev_r}
                  : {60'b0, rd_addr_r, rd_data_r};

always_ff @(posedge clk_i)
  begin
    if (en_p)
      begin
        if (commit_v_i)
          begin
            $display("[CMT] PC: %x NPC: %x RD_ADDR: %d RD_DATA: %x"
                     , pc_r
                     , npc_r
                     , rd_addr_r
                     , rd_data_r
                     );
          end
        if (recover_v_i)
          begin
            $display("[REC] PC: %x NPC: %x"
                     , pc_r
                     , npc_r
                     );
          end
      end
  end

endmodule : bp_be_bserial_trace_replay_gen

