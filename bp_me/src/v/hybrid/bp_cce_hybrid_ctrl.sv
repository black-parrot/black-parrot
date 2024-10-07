/**
 *
 * Name:
 *   bp_cce_hybrid_ctrl.sv
 *
 * Description:
 *   This is the global control module for the hybrid CCE. It monitors the config bus to detect
 *   operating mode transitions.
 *
 *   When transitioning modes the CCE is drained and then the switch occurs. From uncached only
 *   to normal mode, the CCE then sends sync commands to every LCE in the system and waits for
 *   a sync ack from each LCE. After all sync acks are received, the CCE sets the mode to normal
 *   and lowers the drain_then_stall_o signal to resume operating.
 *
 *   When transitioning from normal to uncached only mode the CCE simply waits for the pipelines
 *   to drain and then switches modes. This also requires the external configuration module to
 *   reset all LCEs to uncached only mode and synchronize these events within the system.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_hybrid_ctrl
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter lce_data_width_p           = dword_width_gp

    , localparam lg_num_lce_lp             = `BSG_SAFE_CLOG2(num_lce_p)
    , localparam cfg_bus_width_lp          = `bp_cfg_bus_width(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)

    // interface widths
    `declare_bp_bedrock_lce_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce)
  )
  (input                                            clk_i
   , input                                          reset_i

   // Config channel
   , input [cfg_bus_width_lp-1:0]                   cfg_bus_i

   // LCE-CCE Interface
   // BedRock Burst protocol: ready&valid
   , output logic [lce_cmd_header_width_lp-1:0]     lce_cmd_header_o
   , output logic                                   lce_cmd_header_v_o
   , input                                          lce_cmd_header_ready_and_i
   , output logic                                   lce_cmd_has_data_o
   , output logic [lce_data_width_p-1:0]            lce_cmd_data_o
   , output logic                                   lce_cmd_data_v_o
   , input                                          lce_cmd_data_ready_and_i
   , output logic                                   lce_cmd_last_o

   // Sync response - from LCE Response pipe
   , input                                          sync_yumi_i

   // CCE control signals
   , output bp_cce_mode_e                           cce_mode_o
   , output [cce_id_width_p-1:0]                    cce_id_o
   , output logic                                   drain_then_stall_o
   , input                                          req_empty_i
   , input                                          uc_pipe_empty_i
   , input                                          coh_pipe_empty_i
   , input                                          mem_credits_full_i
   );

  // control module sends header only commands
  wire unused = lce_cmd_data_ready_and_i;

  // Define structure variables for output queues
  `declare_bp_bedrock_lce_if(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce);
  `bp_cast_o(bp_bedrock_lce_cmd_header_s, lce_cmd_header);

  // Config bus
  `declare_bp_cfg_bus_s(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `bp_cast_i(bp_cfg_bus_s, cfg_bus);
  assign cce_id_o = cfg_bus_cast_i.cce_id;

  // Mode register
  // 0 = uncached only
  // 1 = cacheable / normal
  logic cce_mode_en;
  logic [$bits(bp_cce_mode_e)-1:0] cce_mode_lo;
  bsg_dff_reset_en
    #(.width_p($bits(bp_cce_mode_e))
      ,.reset_val_p(0)
      )
    mode_reg
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.en_i(cce_mode_en)
      ,.data_i(cfg_bus_cast_i.cce_mode)
      ,.data_o(cce_mode_lo)
      );
  assign cce_mode_o = bp_cce_mode_e'(cce_mode_lo);

  wire normal_mode_li = (cfg_bus_cast_i.cce_mode == e_cce_mode_normal);
  wire uncached_mode_li = (cfg_bus_cast_i.cce_mode == e_cce_mode_uncached);

  logic drain_then_stall_set, drain_then_stall_clear;
  bsg_dff_reset_set_clear
    #(.width_p(1))
    drain_then_stall_reg
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.set_i(drain_then_stall_set)
      ,.clear_i(drain_then_stall_clear)
      ,.data_o(drain_then_stall_o)
      );

  // CCE is fully drained when all pipelines are empty and there are no outstanding memory accesses
  // Signal is also gated with drain_then_stall register to prevent spurious signals
  wire drain_complete = drain_then_stall_o & req_empty_i & uc_pipe_empty_i & coh_pipe_empty_i
                        & mem_credits_full_i;

  logic detect_normal_transition;
  bsg_edge_detect
    #(.falling_not_rising_p(0))
    normal_mode_edge
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.sig_i(cfg_bus_cast_i.cce_mode)
      ,.detect_o(detect_normal_transition)
      );

  logic detect_uncached_transition;
  bsg_edge_detect
    #(.falling_not_rising_p(1))
    uncached_mode_edge
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.sig_i(cfg_bus_cast_i.cce_mode)
      ,.detect_o(detect_uncached_transition)
      );

  // Sync cmd/ack counters
  localparam counter_max_lp = num_lce_p;
  localparam counter_ptr_width_lp = `BSG_SAFE_CLOG2(counter_max_lp+1);
  // cmd counter increments on command header send
  logic [counter_ptr_width_lp-1:0] cmd_cnt;
  bsg_counter_clear_up
    #(.max_val_p(counter_max_lp)
      ,.init_val_p(0)
      )
    cmd_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.up_i(lce_cmd_header_v_o & lce_cmd_header_ready_and_i)
     ,.clear_i(1'b0)
     ,.count_o(cmd_cnt)
     );

  // ack counter increments on sync ack received
  logic [counter_ptr_width_lp-1:0] ack_cnt;
  bsg_counter_clear_up
    #(.max_val_p(counter_max_lp)
      ,.init_val_p(0)
      )
    ack_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.up_i(sync_yumi_i)
     ,.clear_i(1'b0)
     ,.count_o(ack_cnt)
     );

  typedef enum logic [2:0]
  {
    e_ready
    ,e_wait_drain
    ,e_send_sync
    ,e_sync_ack
  } state_e;
  state_e state_r, state_n;

  always_comb begin
    state_n = state_r;

    // mode transition
    cce_mode_en = 1'b0;

    // drain and stall register control
    drain_then_stall_set = 1'b0;
    drain_then_stall_clear = 1'b0;

    // LCE command output control
    lce_cmd_header_cast_o = '0;
    lce_cmd_header_cast_o.payload.src_id = cfg_bus_cast_i.cce_id;
    lce_cmd_header_cast_o.msg_type.cmd = e_bedrock_cmd_sync;
    lce_cmd_header_cast_o.payload.dst_id[0+:lg_num_lce_lp] = cmd_cnt[0+:lg_num_lce_lp];
    lce_cmd_header_v_o = '0;
    lce_cmd_has_data_o = '0;
    lce_cmd_data_o = '0;
    lce_cmd_data_v_o = '0;
    lce_cmd_last_o = '0;

    // FSM
    unique case (state_r)
      // wait for transition signal detection
      e_ready: begin
        if (detect_normal_transition | detect_uncached_transition) begin
          state_n = e_wait_drain;
          // activate pipeline flush
          drain_then_stall_set = 1'b1;
        end
      end // e_ready

      // wait for all CCE pipes to drain requests
      e_wait_drain: begin
        state_n = drain_complete
                  ? normal_mode_li
                    ? e_send_sync
                    : e_ready
                  : e_wait_drain;
        // register the CCE mode switch
        cce_mode_en = drain_complete & uncached_mode_li;
        // release the CCE pipelines for execution next cycle
        drain_then_stall_clear = drain_complete & uncached_mode_li;
      end // e_wait_drain

      e_send_sync: begin
        // send command
        lce_cmd_header_v_o = 1'b1;
        // wait for remaining acks after sending last sync
        state_n = (cmd_cnt == num_lce_p-1) & lce_cmd_header_v_o & lce_cmd_header_ready_and_i
                  ? e_sync_ack : e_send_sync;
      end // e_send_sync

      // wait for all syncs acks to return
      e_sync_ack: begin
        if (ack_cnt == cmd_cnt) begin
          state_n = e_ready;
          // release the CCE pipelines for execution next cycle
          drain_then_stall_clear = 1'b1;
          // register the CCE mode switch
          cce_mode_en = 1'b1;
        end
      end // e_sync_ack

      default: begin
        // use defaults above
      end

    endcase
  end // always_comb

  // Sequential Logic
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      state_r <= e_ready;
    end else begin
      state_r <= state_n;
    end
  end

endmodule
