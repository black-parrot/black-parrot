
module bp_nonsynth_watchdog
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_common_rv64_pkg::*;
  import bp_be_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter timeout_cycles_p   = "inv"
    , parameter heartbeat_instr_p  = "inv"

    // Something super big
    , parameter max_instr_lp = 2**30
    )
   (input                                     clk_i
    , input                                   reset_i

    , input                                   freeze_i

    , input [`BSG_SAFE_CLOG2(num_core_p)-1:0] mhartid_i

    , input [vaddr_width_p-1:0]               npc_i
    , input                                   instret_i
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

  logic [`BSG_SAFE_CLOG2(timeout_cycles_p)-1:0] stall_cnt;
  bsg_counter_clear_up
   #(.max_val_p(timeout_cycles_p), .init_val_p(0))
   stall_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i | freeze_i)

     ,.clear_i(npc_change)
     ,.up_i(1'b1)
     ,.count_o(stall_cnt)
     );

  logic [`BSG_SAFE_CLOG2(max_instr_lp+1)-1:0] instr_cnt;
  bsg_counter_clear_up
   #(.max_val_p(max_instr_lp), .init_val_p(0))
   instr_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i | freeze_i)

     ,.clear_i(1'b0)
     ,.up_i(instret_i)
     ,.count_o(instr_cnt)
     );

  always_ff @(negedge clk_i)
    if (reset_i === '0 && (stall_cnt >= timeout_cycles_p))
      begin
        $display("FAIL! Core %x stalled for %d cycles!", mhartid_i, stall_cnt);
        $finish();
      end
    else if (reset_i === '0 && (npc_r === 'X))
      begin
        $display("FAIL! Core %x PC has become X!", mhartid_i);
        $finish();
      end

  always_ff @(negedge clk_i)
    begin
      if (reset_i === '0 && (instr_cnt > '0) && (instr_cnt % heartbeat_instr_p == '0))
        begin
          $display("BEAT: %d instructions completed (%d total)", heartbeat_instr_p, instr_cnt);
        end
    end

endmodule

