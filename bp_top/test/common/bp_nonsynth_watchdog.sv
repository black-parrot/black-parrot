
`include "bp_common_defines.svh"
`include "bp_top_defines.svh"

module bp_nonsynth_watchdog
  import bp_common_pkg::*;
  import bp_be_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter `BSG_INV_PARAM(stall_cycles_p)
    , parameter `BSG_INV_PARAM(halt_cycles_p)
    , parameter `BSG_INV_PARAM(heartbeat_instr_p)

    // Something super big
    , parameter max_instr_lp = 2**30
    )
   (input                                     clk_i
    , input                                   reset_i

    , input                                   wfi_i

    , input [`BSG_SAFE_CLOG2(num_core_p)-1:0] mhartid_i

    , input [vaddr_width_p-1:0]               npc_i
    , input                                   instret_i
    );

  enum logic {e_run, e_halt} state_n, state_r;
  wire is_run = (state_r == e_run);
  wire is_halt = (state_r == e_halt);

  logic [vaddr_width_p-1:0] npc_r;
  bsg_dff_reset
   #(.width_p(vaddr_width_p))
   npc_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i | is_halt)

     ,.data_i(npc_i)
     ,.data_o(npc_r)
     );
  wire npc_change = (npc_i != npc_r);

  logic [`BSG_SAFE_CLOG2(stall_cycles_p)-1:0] stall_cnt;
  bsg_counter_clear_up
   #(.max_val_p(stall_cycles_p), .init_val_p(0))
   stall_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i | wfi_i | is_halt)

     ,.clear_i(npc_change)
     ,.up_i(1'b1)
     ,.count_o(stall_cnt)
     );

  logic [`BSG_SAFE_CLOG2(stall_cycles_p)-1:0] halt_cnt;
  bsg_counter_clear_up
   #(.max_val_p(stall_cycles_p), .init_val_p(0))
   halt_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i | wfi_i | is_halt)

     ,.clear_i(npc_change)
     ,.up_i(instret_i)
     ,.count_o(halt_cnt)
     );

  logic [`BSG_SAFE_CLOG2(max_instr_lp+1)-1:0] instr_cnt;
  bsg_counter_clear_up
   #(.max_val_p(max_instr_lp), .init_val_p(0))
   instr_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i | is_halt)

     ,.clear_i(1'b0)
     ,.up_i(instret_i)
     ,.count_o(instr_cnt)
     );

  always_comb
    case (state_r)
      e_run: state_n = (halt_cnt == halt_cycles_p) ? e_halt : e_run;
      default: state_n = state_r;
    endcase

  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_run;
    else
      state_r <= state_n;

  always_ff @(negedge clk_i)
    begin
      if (reset_i === '0 && is_halt && halt_cnt >= halt_cycles_p)
        begin
          $display("[BSG-INFO]: Core %x halt detected!", mhartid_i);
        end
      assert(reset_i !== '0 || (stall_cnt < stall_cycles_p)) else
        begin
          $display("[BSG-FAIL]: Core %x stalled for %d cycles!", mhartid_i, stall_cnt);
          $finish();
        end
      assert(reset_i !== '0 || (npc_r !== 'X)) else
        begin
          $display("[BSG-FAIL]: Core %x PC has become X!", mhartid_i);
          $finish();
        end
    end

  always_ff @(negedge clk_i)
    begin
      if (reset_i === '0 && (instr_cnt > '0) && (instr_cnt % heartbeat_instr_p == '0) & instret_i)
        begin
          $display("[BSG-INFO]: %d instructions completed (%d total)", heartbeat_instr_p, instr_cnt);
        end
    end

endmodule

