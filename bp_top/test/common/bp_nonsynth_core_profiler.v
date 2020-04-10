
  typedef struct packed
  {
    logic freeze;
    logic fe_queue_stall;
    logic fe_wait_stall;
    logic itlb_miss;
    logic icache_miss;
    logic icache_fence;
    logic branch_override;
    logic fe_cmd;
    logic cmd_fence;
    logic target_mispredict;
    logic dir_mispredict;
    logic control_haz;
    logic data_haz;
    logic load_dep;
    logic mul_dep;
    logic struct_haz;
    logic dtlb_miss;
    logic dcache_miss;
    logic long_haz;
    logic eret;
    logic exception;
    logic _interrupt;
  }  bp_stall_reason_s;

  typedef enum logic [4:0]
  {
    freeze               = 5'd21
    ,fe_queue_stall      = 5'd20
    ,fe_wait_stall       = 5'd19
    ,itlb_miss           = 5'd18
    ,icache_miss         = 5'd17
    ,icache_fence        = 5'd16
    ,branch_override     = 5'd15
    ,fe_cmd              = 5'd14
    ,cmd_fence           = 5'd13
    ,target_mispredict   = 5'd12
    ,dir_mispredict      = 5'd11
    ,control_haz         = 5'd10
    ,data_haz            = 5'd9
    ,load_dep            = 5'd8
    ,mul_dep             = 5'd7
    ,struct_haz          = 5'd6
    ,dtlb_miss           = 5'd5
    ,dcache_miss         = 5'd4
    ,long_haz            = 5'd3
    ,eret                = 5'd2
    ,exception           = 5'd1
    ,_interrupt           = 5'd0
  } bp_stall_reason_e;

// The BlackParrot core pipeline is a mostly non-stalling pipeline, decoupled between the front-end
// and back-end.
module bp_nonsynth_core_profiler
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_common_rv64_pkg::*;
  import bp_be_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter stall_trace_file_p = "stall"

    , localparam dispatch_pkt_width_lp = `bp_be_dispatch_pkt_width(vaddr_width_p)
    , localparam commit_pkt_width_lp = `bp_be_commit_pkt_width(vaddr_width_p)
    , localparam trap_pkt_width_lp = `bp_be_trap_pkt_width(vaddr_width_p)
    )
   (input clk_i
    , input reset_i
    , input freeze_i

    , input [`BSG_SAFE_CLOG2(num_core_p)-1:0] mhartid_i

    // IF1 events
    , input fe_wait_stall
    , input fe_queue_stall

    // IF2 events
    , input itlb_miss
    , input icache_miss
    , input icache_fence
    , input branch_override
 
    // Backwards ISS events
    // TODO: Differentiate between different FE cmds
    , input fe_cmd

    // ISS Stalls
    , input cmd_fence

    // ISD events
    , input target_mispredict
    , input dir_mispredict
    , input long_haz
    , input control_haz
    , input data_haz
    , input load_dep
    , input mul_dep
    , input struct_haz

    // ALU events

    // MUL events

    // MEM events
    , input dtlb_miss
    , input dcache_miss
    , input eret
    , input exception
    , input _interrupt

    // Reservation packet
    , input [dispatch_pkt_width_lp-1:0] reservation

    // Commit packet
    , input [commit_pkt_width_lp-1:0] commit_pkt
    // Trap packet
    , input [trap_pkt_width_lp-1:0] trap_pkt
    );

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  localparam num_stages_p = 8;
  bp_stall_reason_s [num_stages_p-1:0] stall_stage_n, stall_stage_r;
  bsg_dff_reset
   #(.width_p($bits(bp_stall_reason_s)*num_stages_p))
   stall_pipe
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(stall_stage_n)
     ,.data_o(stall_stage_r)
     );

  bp_be_dispatch_pkt_s reservation_r;
  bsg_dff_chain
   #(.width_p($bits(bp_be_dispatch_pkt_s))
     ,.num_stages_p(4)
     )
   reservation_pipe
    (.clk_i(clk_i)
     ,.data_i(reservation)
     ,.data_o(reservation_r)
     );

  bp_be_commit_pkt_s commit_pkt_r;
  bsg_dff_reset
   #(.width_p($bits(bp_be_commit_pkt_s)))
   commit_pipe
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.data_i(commit_pkt)
     ,.data_o(commit_pkt_r)
     );

  bp_be_trap_pkt_s trap_pkt_r;
  bsg_dff_reset
   #(.width_p($bits(bp_be_trap_pkt_s)))
   trap_pipe
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.data_i(trap_pkt)
     ,.data_o(trap_pkt_r)
     );

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
      // By default, move down the pipe
      for (integer i = 0; i < num_stages_p; i++)
        stall_stage_n[i] = (i == '0) ? '0 : stall_stage_r[i-1];

      // IF1
      stall_stage_n[0].freeze            |= freeze_i;
      stall_stage_n[0].fe_wait_stall     |= fe_wait_stall;
      stall_stage_n[0].fe_queue_stall    |= fe_queue_stall;
      stall_stage_n[0].itlb_miss         |= itlb_miss;
      stall_stage_n[0].icache_miss       |= icache_miss;
      stall_stage_n[0].icache_fence      |= icache_fence;
      // Only some FE cmds affect IF1
      stall_stage_n[0].fe_cmd            |= fe_cmd;

      // IF2
      stall_stage_n[1].itlb_miss         |= itlb_miss;
      stall_stage_n[1].icache_miss       |= icache_miss;
      stall_stage_n[1].icache_fence      |= icache_fence;
      stall_stage_n[1].branch_override   |= branch_override;
      stall_stage_n[1].fe_cmd            |= fe_cmd;
      stall_stage_n[1].dir_mispredict    |= dir_mispredict;
      stall_stage_n[1].target_mispredict |= target_mispredict;

      // ISS
      stall_stage_n[2].itlb_miss         |= itlb_miss;
      stall_stage_n[2].icache_miss       |= icache_miss;
      stall_stage_n[2].icache_fence      |= icache_fence;
      stall_stage_n[2].cmd_fence         |= cmd_fence;
      stall_stage_n[2].dir_mispredict    |= dir_mispredict;
      stall_stage_n[2].target_mispredict |= target_mispredict;
      stall_stage_n[2].exception         |= exception;
      stall_stage_n[2].eret              |= eret;
      stall_stage_n[2]._interrupt         |= _interrupt;

      // ISD
      stall_stage_n[3].dir_mispredict    |= dir_mispredict;
      stall_stage_n[3].target_mispredict |= target_mispredict;
      stall_stage_n[3].dtlb_miss         |= dtlb_miss;
      stall_stage_n[3].dcache_miss       |= dcache_miss;
      stall_stage_n[3].exception         |= exception;
      stall_stage_n[3].eret              |= eret;
      stall_stage_n[3]._interrupt         |= _interrupt;

      // EX1
      stall_stage_n[4].dir_mispredict    |= dir_mispredict;
      stall_stage_n[4].target_mispredict |= target_mispredict;
      stall_stage_n[4].dtlb_miss         |= dtlb_miss;
      stall_stage_n[4].dcache_miss       |= dcache_miss;
      stall_stage_n[4].long_haz          |= long_haz;
      stall_stage_n[4].exception         |= exception;
      stall_stage_n[4].eret              |= eret;
      stall_stage_n[4]._interrupt         |= _interrupt;
      stall_stage_n[4].control_haz       |= control_haz;
      stall_stage_n[4].load_dep          |= load_dep;
      stall_stage_n[4].mul_dep           |= mul_dep;
      stall_stage_n[4].data_haz          |= data_haz;
      stall_stage_n[4].struct_haz        |= struct_haz;

      // EX2
      stall_stage_n[5].dtlb_miss         |= dtlb_miss;
      stall_stage_n[5].dcache_miss       |= dcache_miss;
      stall_stage_n[5].exception         |= exception;
      stall_stage_n[5].eret              |= eret;
      stall_stage_n[5]._interrupt        |= _interrupt;

      // EX3
      stall_stage_n[6].dtlb_miss         |= dtlb_miss;
      stall_stage_n[6].dcache_miss       |= dcache_miss;
      stall_stage_n[6].exception         |= exception;
      stall_stage_n[6].eret              |= eret;
      stall_stage_n[6]._interrupt        |= _interrupt;

      // EX4
      stall_stage_n[7].dtlb_miss         |= dtlb_miss;
      stall_stage_n[7].dcache_miss       |= dcache_miss;
      stall_stage_n[7].exception         |= exception;
      stall_stage_n[7].eret              |= eret;
      stall_stage_n[7]._interrupt        |= _interrupt;
    end

  bp_stall_reason_s stall_reason_dec;
  assign stall_reason_dec = stall_stage_r[num_stages_p-1];
  logic [$bits(bp_stall_reason_e)-1:0] stall_reason_lo;
  bp_stall_reason_e stall_reason_enum;
  logic stall_reason_v;
  bsg_priority_encode
   #(.width_p($bits(bp_stall_reason_s)), .lo_to_hi_p(1))
   stall_encode
    (.i(stall_reason_dec)
     ,.addr_o(stall_reason_lo)
     ,.v_o(stall_reason_v)
     );
  assign stall_reason_enum = bp_stall_reason_e'(stall_reason_lo);

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
    if (~reset_i & ~freeze_i & commit_pkt_r.v)
      $fwrite(file, "%0d,%x,%x,%x,%s\n", cycle_cnt, x_cord_li, y_cord_li, commit_pkt_r.pc, "instr");
    else if (~reset_i & ~freeze_i & ~commit_pkt_r.v & stall_reason_v)
      $fwrite(file, "%0d,%x,%x,%x,%s\n", cycle_cnt, x_cord_li, y_cord_li, commit_pkt_r.pc, stall_reason_enum.name());
    else
      $fwrite(file, "%0d,%x,%x,%x,%s\n", cycle_cnt, x_cord_li, y_cord_li, commit_pkt_r.pc, "unknown");

endmodule

