
module bp_halting_solver
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_common_rv64_pkg::*;
  import bp_be_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)

    , localparam timeout_p = 100000
    )
   (input                                     clk_i
    , input                                   reset_i

    , input                                   freeze_i

    , input [`BSG_SAFE_CLOG2(num_core_p)-1:0] mhartid_i

    , input [vaddr_width_p-1:0]               npc_i
    );

  logic [vaddr_width_p-1:0] npc_r;
  bsg_dff_reset
   #(.width_p(vaddr_width_p))
   npc_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i | freeze_i)

     ,.data_i(npc_i)
     ,.data_o(npc_r)
     );
  wire npc_change = (npc_i != npc_r);

  logic [`BSG_SAFE_CLOG2(timeout_p)-1:0] stall_cnt;
  bsg_counter_clear_up
   #(.max_val_p(timeout_p), .init_val_p(0))
   stall_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i | freeze_i)

     ,.clear_i(npc_change)
     ,.up_i(1'b1)
     ,.count_o(stall_cnt)
     );

  always_ff @(negedge clk_i)
    if (reset_i === '0 && stall_cnt >= timeout_p)
      begin
        $display("FAIL! Core %x stalled for %d cycles!", mhartid_i, stall_cnt);
        $finish();
      end
    else if (reset_i === '0 && npc_r === 'X)
      begin
        $display("FAIL! Core %x PC has become X!", mhartid_i);
        $finish();
      end

endmodule

