
  typedef struct packed
  {
    logic fe_queue_full;
    logic fe_wait;
    logic itlb_miss;
    logic icache_miss;
    logic icache_rollback;
    logic branch_override;
    logic ret_override;
    logic fe_cmd;
    logic fe_cmd_fence;
    logic mispredict;
    logic control_haz;
    logic long_haz;
    logic data_haz;
    logic aux_dep;
    logic load_dep;
    logic mul_dep;
    logic fma_dep;
    logic sb_iraw_dep;
    logic sb_fraw_dep;
    logic sb_iwaw_dep;
    logic sb_fwaw_dep;
    logic struct_haz;
    logic ilong_busy;
    logic flong_busy;
    logic long_wb;
    logic dtlb_miss;
    logic dcache_miss;
    logic dcache_rollback;
    logic dcache_fail;
    logic eret;
    logic exception;
    logic _interrupt;
    logic unknown;
  }  stall_reason_s;

  typedef enum logic [5:0]
  {
    fe_queue_full        = 6'd32
    ,fe_wait             = 6'd31
    ,itlb_miss           = 6'd30
    ,icache_miss         = 6'd29
    ,icache_rollback     = 6'd28
    ,branch_override     = 6'd27
    ,ret_override        = 6'd26
    ,fe_cmd              = 6'd25
    ,fe_cmd_fence        = 6'd24
    ,mispredict          = 6'd23
    ,control_haz         = 6'd22
    ,long_haz            = 6'd21
    ,data_haz            = 6'd20
    ,aux_dep             = 6'd19
    ,load_dep            = 6'd18
    ,mul_dep             = 6'd17
    ,fma_dep             = 6'd16
    ,sb_iraw_dep         = 6'd15
    ,sb_fraw_dep         = 6'd14
    ,sb_iwaw_dep         = 6'd13
    ,sb_fwaw_dep         = 6'd12
    ,struct_haz          = 6'd11
    ,ilong_busy          = 6'd10
    ,flong_busy          = 6'd9
    ,long_wb             = 6'd8
    ,dtlb_miss           = 6'd7
    ,dcache_miss         = 6'd6
    ,dcache_rollback     = 6'd5
    ,dcache_fail         = 6'd4
    ,eret                = 6'd3
    ,exception           = 6'd2
    ,_interrupt          = 6'd1
    ,unknown             = 6'd0
  } stall_reason_e;

// The BlackParrot core pipeline is a mostly non-stalling pipeline, decoupled between the front-end
// and back-end.
`include "bp_common_defines.svh"
`include "bp_top_defines.svh"
`include "bp_be_defines.svh"

module bp_nonsynth_core_profiler
  import bp_common_pkg::*;
  import bp_be_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter stall_trace_file_p = "stall"

    , localparam dispatch_pkt_width_lp = `bp_be_dispatch_pkt_width(vaddr_width_p)
    , localparam commit_pkt_width_lp = `bp_be_commit_pkt_width(vaddr_width_p, paddr_width_p)
    )
   (input clk_i
    , input reset_i
    , input freeze_i

    , input [`BSG_SAFE_CLOG2(num_core_p)-1:0] mhartid_i

    // FE events
    , input [1:0] fe_state_n_i
    , input fe_queue_ready_i
    , input fe_icache_ready_i

    , input if2_v_i
    , input br_ovr_i
    , input ret_ovr_i
    , input itlb_miss_r_i
    , input icache_data_v_i

    // Backwards ISS events
    // TODO: Differentiate between different FE cmds
    , input fe_cmd_nonattaboy_i
    , input fe_cmd_fence_i
    , input fe_queue_empty_i

    // ISD events
    , input mispredict_i
    , input long_haz_i
    , input control_haz_i
    , input data_haz_i
    , input aux_dep_i
    , input load_dep_i
    , input mul_dep_i
    , input fma_dep_i
    , input sb_iraw_dep_i
    , input sb_fraw_dep_i
    , input sb_iwaw_dep_i
    , input sb_fwaw_dep_i
    , input struct_haz_i
    , input long_busy_i
    , input ilong_ready_i
    , input flong_ready_i

    // ALU events

    // MUL events

    // MEM events
    , input dcache_miss_i
    , input dcache_fail_i

    // Trap packet
    , input [commit_pkt_width_lp-1:0] commit_pkt_i
    );

  typedef enum logic [1:0] {fe_e_wait=2'd0, fe_e_run, fe_e_stall} fe_state_e;

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  localparam num_stages_p = 7;
  stall_reason_s [num_stages_p-1:0] stall_stage_n, stall_stage_r;
  bsg_dff_reset
   #(.width_p($bits(stall_reason_s)*num_stages_p))
   stall_pipe
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(stall_stage_n)
     ,.data_o(stall_stage_r)
     );

  bp_be_commit_pkt_s commit_pkt;
  assign commit_pkt = commit_pkt_i;

  logic [29:0] cycle_cnt;
  bsg_counter_clear_up
   #(.max_val_p(2**30-1), .init_val_p(0))
   cycle_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(1'b0)
     ,.up_i(1'b1)
     ,.count_o(cycle_cnt)
     );

  always_comb
    begin
      // IF0
      stall_stage_n[0]                    = '0;
      stall_stage_n[0].fe_wait           |= (fe_state_n_i == fe_e_wait);
      stall_stage_n[0].fe_queue_full     |= (fe_state_n_i == fe_e_stall) & ~fe_queue_ready_i;
      stall_stage_n[0].icache_miss       |= (fe_state_n_i == fe_e_stall) & ~fe_icache_ready_i;
      stall_stage_n[0].fe_cmd            |= (fe_state_n_i == fe_e_stall) & fe_cmd_nonattaboy_i;
      stall_stage_n[0].icache_rollback   |= if2_v_i & ~icache_data_v_i;

      // IF1
      stall_stage_n[1]                    = stall_stage_r[0];
      stall_stage_n[1].fe_queue_full     |= if2_v_i & ~fe_queue_ready_i;
      stall_stage_n[1].fe_cmd            |= fe_cmd_nonattaboy_i;
      stall_stage_n[1].branch_override   |= br_ovr_i;
      stall_stage_n[1].ret_override      |= ret_ovr_i;
      stall_stage_n[1].itlb_miss         |= if2_v_i & itlb_miss_r_i;
      stall_stage_n[1].icache_rollback   |= if2_v_i & ~icache_data_v_i;

      // IF2
      stall_stage_n[2]                    = stall_stage_r[1];
      stall_stage_n[2].fe_queue_full     |= if2_v_i & ~fe_queue_ready_i;
      stall_stage_n[2].fe_cmd            |= fe_cmd_nonattaboy_i;
      stall_stage_n[2].itlb_miss         |= if2_v_i & itlb_miss_r_i;
      stall_stage_n[2].icache_rollback   |= if2_v_i & ~icache_data_v_i;

      // ISD
      stall_stage_n[3]                    = fe_queue_empty_i ? stall_stage_r[2] : '0;
      stall_stage_n[3].fe_cmd_fence      |= fe_cmd_fence_i;
      stall_stage_n[3].mispredict        |= mispredict_i;
      stall_stage_n[3].dcache_miss       |= dcache_miss_i;
      stall_stage_n[3].data_haz          |= data_haz_i;
      stall_stage_n[3].aux_dep           |= aux_dep_i;
      stall_stage_n[3].load_dep          |= load_dep_i;
      stall_stage_n[3].mul_dep           |= mul_dep_i;
      stall_stage_n[3].fma_dep           |= fma_dep_i;
      stall_stage_n[3].sb_iraw_dep       |= sb_iraw_dep_i;
      stall_stage_n[3].sb_fraw_dep       |= sb_fraw_dep_i;
      stall_stage_n[3].sb_iwaw_dep       |= sb_iwaw_dep_i;
      stall_stage_n[3].sb_fwaw_dep       |= sb_fwaw_dep_i;
      stall_stage_n[3].struct_haz        |= struct_haz_i;
      stall_stage_n[3].ilong_busy        |= long_busy_i & ~ilong_ready_i;
      stall_stage_n[3].flong_busy        |= long_busy_i & ~flong_ready_i;
      stall_stage_n[3].long_wb           |= long_busy_i & ilong_ready_i & flong_ready_i;
      stall_stage_n[3].control_haz       |= control_haz_i;
      stall_stage_n[3].long_haz          |= long_haz_i;
      stall_stage_n[3].dtlb_miss         |= commit_pkt.dtlb_load_miss | commit_pkt.dtlb_store_miss;
      stall_stage_n[3].dcache_rollback   |= commit_pkt.dcache_miss;
      stall_stage_n[3].dcache_fail       |= dcache_fail_i;
      stall_stage_n[3].exception         |= commit_pkt.exception;
      stall_stage_n[3].eret              |= commit_pkt.eret;
      stall_stage_n[3]._interrupt        |= commit_pkt._interrupt;

      // EX1
      stall_stage_n[4]                    = stall_stage_r[3];
      stall_stage_n[4].dtlb_miss         |= commit_pkt.dtlb_load_miss | commit_pkt.dtlb_store_miss;
      stall_stage_n[4].dcache_rollback   |= commit_pkt.dcache_miss;
      stall_stage_n[4].dcache_fail       |= dcache_fail_i;
      stall_stage_n[4].exception         |= commit_pkt.exception;
      stall_stage_n[4].eret              |= commit_pkt.eret;
      stall_stage_n[4]._interrupt        |= commit_pkt._interrupt;

      // EX2
      stall_stage_n[5]                    = stall_stage_r[4];
      stall_stage_n[5].dtlb_miss         |= commit_pkt.dtlb_load_miss | commit_pkt.dtlb_store_miss;
      stall_stage_n[5].dcache_rollback   |= commit_pkt.dcache_miss;
      stall_stage_n[5].dcache_fail       |= dcache_fail_i;
      stall_stage_n[5].exception         |= commit_pkt.exception;
      stall_stage_n[5].eret              |= commit_pkt.eret;
      stall_stage_n[5]._interrupt        |= commit_pkt._interrupt;

      // EX3
      stall_stage_n[6]                    = stall_stage_r[5];
      stall_stage_n[6].dtlb_miss         |= commit_pkt.dtlb_load_miss | commit_pkt.dtlb_store_miss;
      stall_stage_n[6].dcache_rollback   |= commit_pkt.dcache_miss;
      stall_stage_n[6].dcache_fail       |= dcache_fail_i;
      stall_stage_n[6].exception         |= commit_pkt.exception;
      stall_stage_n[6].eret              |= commit_pkt.eret;
      stall_stage_n[6]._interrupt        |= commit_pkt._interrupt;

    end

  stall_reason_s stall_reason_dec;
  assign stall_reason_dec = stall_stage_n[num_stages_p-1];
  logic [$bits(stall_reason_e)-1:0] stall_reason_lo;
  stall_reason_e stall_reason_enum;
  logic stall_reason_v;
  bsg_priority_encode
   #(.width_p($bits(stall_reason_s)), .lo_to_hi_p(1))
   stall_encode
    (.i(stall_reason_dec)
     ,.addr_o(stall_reason_lo)
     ,.v_o(stall_reason_v)
     );
  assign stall_reason_enum = stall_reason_e'(stall_reason_lo);

  // synopsys translate_off
  int stall_hist [stall_reason_e];
  always_ff @(posedge clk_i)
    if (~reset_i & ~freeze_i & ~commit_pkt.instret)
      stall_hist[stall_reason_enum] <= stall_hist[stall_reason_enum] + 1'b1;

  integer file;
  string file_name;
  wire reset_li = reset_i | freeze_i;
  always_ff @(negedge reset_li)
    begin
      file_name = $sformatf("%s_%x.trace", stall_trace_file_p, mhartid_i);
      file      = $fopen(file_name, "w");
      $fwrite(file, "%s,%s,%s,%s,%s\n", "cycle", "x", "y", "pc", "operation");
    end

  wire x_cord_li = '0;
  wire y_cord_li = '0;

  always_ff @(negedge clk_i)
    begin
      if (~reset_i & ~freeze_i & commit_pkt.instret)
        $fwrite(file, "%0d,%x,%x,%x,%s", cycle_cnt, x_cord_li, y_cord_li, commit_pkt.pc, "instr");
      else if (~reset_i & ~freeze_i)
        $fwrite(file, "%0d,%x,%x,%x,%s", cycle_cnt, x_cord_li, y_cord_li, commit_pkt.pc, stall_reason_enum.name());

      if (~reset_i & ~freeze_i)
        $fwrite(file, "\n");
    end

  `ifndef VERILATOR
  final
    begin
      $fwrite(file, "=============================\n");
      $fwrite(file, "Total Stalls:\n");
      foreach (stall_hist[i])
        $fwrite(file, "%s: %0d\n", i.name(), stall_hist[i]);
    end
  `endif
  // synopsys translate_on

endmodule

