/**
 *
 * Name:
 *   bp_cce_hybrid.sv
 *
 * Description:
 *   This is an experimental hybrid FSM-programmable CCE
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_hybrid
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    // TODO: move into aviary?
    , parameter prog_pipe_en_p             = 0

    , parameter req_arb_fifo_els_p         = 8
    , parameter pending_buffer_els_p       = 2
    , parameter prog_header_fifo_els_p     = 2
    , parameter mem_rev_pending_wbuf_els_p = 2

    // interface width
    , localparam cfg_bus_width_lp          = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)
    `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
  )
  (input                                            clk_i
   , input                                          reset_i

   // Config channel
   , input [cfg_bus_width_lp-1:0]                   cfg_bus_i

   // LCE-CCE Interface
   // BedRock Stream protocol: ready&valid
   , input [lce_req_header_width_lp-1:0]            lce_req_header_i
   , input [bedrock_fill_width_p-1:0]               lce_req_data_i
   , input                                          lce_req_v_i
   , output logic                                   lce_req_ready_and_o

   , input [lce_resp_header_width_lp-1:0]           lce_resp_header_i
   , input [bedrock_fill_width_p-1:0]               lce_resp_data_i
   , input                                          lce_resp_v_i
   , output logic                                   lce_resp_ready_and_o

   , output logic [lce_cmd_header_width_lp-1:0]     lce_cmd_header_o
   , output logic [bedrock_fill_width_p-1:0]        lce_cmd_data_o
   , output logic                                   lce_cmd_v_o
   , input                                          lce_cmd_ready_and_i

   // CCE-MEM Interface
   // BedRock Stream protocol: ready&valid
   , input [mem_rev_header_width_lp-1:0]            mem_rev_header_i
   , input [bedrock_fill_width_p-1:0]               mem_rev_data_i
   , input                                          mem_rev_v_i
   , output logic                                   mem_rev_ready_and_o

   , output logic [mem_fwd_header_width_lp-1:0]     mem_fwd_header_o
   , output logic [bedrock_fill_width_p-1:0]        mem_fwd_data_o
   , output logic                                   mem_fwd_v_o
   , input                                          mem_fwd_ready_and_i
   );

  // parameter checks
  if (lce_sets_p <= 1) $fatal(0,"Number of LCE sets must be greater than 1");
  if (icache_block_width_p != bedrock_block_width_p) $fatal(0,"icache block width must match cce block width");
  if (dcache_block_width_p != bedrock_block_width_p) $fatal(0,"dcache block width must match cce block width");
  if ((num_cacc_p) > 0 && (acache_block_width_p != bedrock_block_width_p)) $fatal(0,"acache block width must match cce block width");
  if (dword_width_gp != 64) $fatal(0,"FSM CCE requires dword width of 64-bits");
  if (!(`BSG_IS_POW2(bedrock_block_width_p) || bedrock_block_width_p < 64 || bedrock_block_width_p > 1024))
    $fatal(0, "invalid CCE block width");

  // LCE-CCE and Mem-CCE Interface
  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);

  // Config Interface
  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);
  `bp_cast_i(bp_cfg_bus_s, cfg_bus);

  // LCE-CCE Interface structs
  `bp_cast_i(bp_bedrock_lce_req_header_s, lce_req_header);
  `bp_cast_o(bp_bedrock_lce_cmd_header_s, lce_cmd_header);
  `bp_cast_i(bp_bedrock_lce_resp_header_s, lce_resp_header);
  `bp_cast_o(bp_bedrock_mem_fwd_header_s, mem_fwd_header);
  `bp_cast_i(bp_bedrock_mem_rev_header_s, mem_rev_header);

  /*
  // TODO: no last signals at this level
  // Memory Network Credits
  logic [`BSG_WIDTH(mem_noc_max_credits_p)-1:0] mem_credit_count_lo;
  wire mem_credits_empty = (mem_credit_count_lo == mem_noc_max_credits_p);
  wire mem_credits_full = (mem_credit_count_lo == 0);
  logic mem_credit_return;
  bsg_flow_counter
    #(.els_p(mem_noc_max_credits_p))
    mem_credit_counter
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // memory commands consume credits - once on last beat per message
      ,.v_i(mem_fwd_v_o & mem_fwd_last_o)
      ,.ready_i(mem_fwd_ready_and_i)
      // memory responses return credits - from memory response pipe
      ,.yumi_i(mem_credit_return)
      ,.count_o(mem_credit_count_lo)
      );
  */
  // memory system can back-pressure, CCE won't overrun itself
  wire mem_credits_full = 1'b1;

  // Control
  logic ctrl_lce_cmd_v_li, ctrl_lce_cmd_ready_and_lo;
  bp_bedrock_lce_cmd_header_s ctrl_lce_cmd_header_li;
  logic [bedrock_fill_width_p-1:0] ctrl_lce_cmd_data_li;

  logic drain_then_stall, req_empty, uc_pipe_empty, coh_pipe_empty, sync_yumi;
  logic inv_yumi, coh_yumi, wb_yumi;
  bp_cce_mode_e cce_mode;
  logic [cce_id_width_p-1:0] cce_id;

  bp_cce_hybrid_ctrl
    #(.bp_params_p(bp_params_p))
    control
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.cfg_bus_i(cfg_bus_cast_i)
      // sync command to arbitration
      ,.lce_cmd_header_o(ctrl_lce_cmd_header_li)
      ,.lce_cmd_data_o(ctrl_lce_cmd_data_li)
      ,.lce_cmd_v_o(ctrl_lce_cmd_v_li)
      ,.lce_cmd_ready_and_i(ctrl_lce_cmd_ready_and_lo)
      ,.sync_yumi_i(sync_yumi)
      ,.cce_mode_o(cce_mode)
      ,.cce_id_o(cce_id)
      ,.drain_then_stall_o(drain_then_stall)
      ,.req_empty_i(req_empty)
      ,.uc_pipe_empty_i(uc_pipe_empty)
      ,.coh_pipe_empty_i(coh_pipe_empty)
      ,.mem_credits_full_i(mem_credits_full)
      );

  // LCE Request Arbiter - splits requests to cacheable/uncacheable streams
  // cacheable memory stream
  logic lce_req_v_li, lce_req_ready_and_lo;
  bp_bedrock_lce_req_header_s lce_req_header_li;
  logic [bedrock_fill_width_p-1:0] lce_req_data_li;
  // uncacheable memory stream
  logic uc_lce_req_v_li, uc_lce_req_ready_and_lo;
  bp_bedrock_lce_req_header_s uc_lce_req_header_li;
  logic [bedrock_fill_width_p-1:0] uc_lce_req_data_li;

  bp_cce_hybrid_req
    #(.bp_params_p(bp_params_p)
      ,.buffer_els_p(req_arb_fifo_els_p)
      )
    request_arbiter
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.cce_mode_i(cce_mode)
      ,.stall_i(drain_then_stall)
      ,.empty_o(req_empty)
      // request input from external
      ,.lce_req_header_i(lce_req_header_cast_i)
      ,.lce_req_data_i(lce_req_data_i)
      ,.lce_req_v_i(lce_req_v_i)
      ,.lce_req_ready_and_o(lce_req_ready_and_o)
      // cacheable memory space requests
      ,.lce_req_header_o(lce_req_header_li)
      ,.lce_req_data_o(lce_req_data_li)
      ,.lce_req_v_o(lce_req_v_li)
      ,.lce_req_ready_and_i(lce_req_ready_and_lo)
      // uncacheable memory space requests
      ,.uc_lce_req_header_o(uc_lce_req_header_li)
      ,.uc_lce_req_data_o(uc_lce_req_data_li)
      ,.uc_lce_req_v_o(uc_lce_req_v_li)
      ,.uc_lce_req_ready_and_i(uc_lce_req_ready_and_lo)
      );

  // Uncacheable memory space pipe
  bp_bedrock_mem_fwd_header_s uc_mem_fwd_header_lo;
  logic [bedrock_fill_width_p-1:0] uc_mem_fwd_data_lo;
  logic uc_mem_fwd_v_lo, uc_mem_fwd_ready_and_li;

  bp_cce_hybrid_uc_pipe
    #(.bp_params_p(bp_params_p))
    uc_pipe
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.empty_o(uc_pipe_empty)
      // request input from arbiter
      ,.lce_req_header_i(uc_lce_req_header_li)
      ,.lce_req_data_i(uc_lce_req_data_li)
      ,.lce_req_v_i(uc_lce_req_v_li)
      ,.lce_req_ready_and_o(uc_lce_req_ready_and_lo)
      // memory command output to arbiter
      ,.mem_fwd_header_o(uc_mem_fwd_header_lo)
      ,.mem_fwd_data_o(uc_mem_fwd_data_lo)
      ,.mem_fwd_v_o(uc_mem_fwd_v_lo)
      ,.mem_fwd_ready_and_i(uc_mem_fwd_ready_and_li)
      );

  // Cacheable memory space pipe
  bp_bedrock_mem_fwd_header_s mem_fwd_header_lo;
  logic [bedrock_fill_width_p-1:0] mem_fwd_data_lo;
  logic mem_fwd_v_lo, mem_fwd_ready_and_li;

  logic spec_w_v, spec_w_addr_bypass_hash, spec_v, spec_squash_v, spec_fwd_mod_v, spec_state_v;
  logic [paddr_width_p-1:0] spec_w_addr;
  bp_cce_spec_s spec_bits;

  logic mem_rev_pending_w_v, mem_rev_pending_w_yumi, mem_rev_pending_w_addr_bypass_hash;
  logic mem_rev_pending_up, mem_rev_pending_down, mem_rev_pending_clear;
  logic [paddr_width_p-1:0] mem_rev_pending_w_addr;

  logic lce_resp_pending_w_v, lce_resp_pending_w_yumi, lce_resp_pending_w_addr_bypass_hash;
  logic lce_resp_pending_up, lce_resp_pending_down, lce_resp_pending_clear;
  logic [paddr_width_p-1:0] lce_resp_pending_w_addr;

  logic lce_cmd_v_li, lce_cmd_ready_and_lo;
  bp_bedrock_lce_cmd_header_s lce_cmd_header_li;
  logic [bedrock_fill_width_p-1:0] lce_cmd_data_li;

  // to programmable pipeline
  bp_bedrock_lce_req_header_s prog_lce_req_header_li;
  logic prog_lce_req_v_li, prog_lce_req_ready_and_lo;
  // from programmable pipeline
  logic prog_v_lo, prog_yumi_li, prog_status_lo;

  bp_cce_hybrid_coh_pipe
    #(.bp_params_p(bp_params_p)
      ,.pending_buffer_els_p(pending_buffer_els_p)
      )
    coh_pipe
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // control
      ,.cce_mode_i(cce_mode)
      ,.cce_id_i(cce_id)
      ,.empty_o(coh_pipe_empty)
      // request input from arbiter
      ,.lce_req_header_i(lce_req_header_li)
      ,.lce_req_data_i(lce_req_data_li)
      ,.lce_req_v_i(lce_req_v_li)
      ,.lce_req_ready_and_o(lce_req_ready_and_lo)
      // LCE Command to arbiter
      ,.lce_cmd_header_o(lce_cmd_header_li)
      ,.lce_cmd_data_o(lce_cmd_data_li)
      ,.lce_cmd_v_o(lce_cmd_v_li)
      ,.lce_cmd_ready_and_i(lce_cmd_ready_and_lo)
      // LCE response signals
      ,.inv_yumi_i(inv_yumi)
      ,.wb_yumi_i(wb_yumi)
      // to programmable pipeline
      ,.lce_req_header_o(prog_lce_req_header_li)
      ,.lce_req_v_o(prog_lce_req_v_li)
      ,.lce_req_ready_and_i(prog_lce_req_ready_and_lo)
      // from programmable pipeline
      ,.prog_v_i(prog_v_lo)
      ,.prog_yumi_o(prog_yumi_li)
      ,.prog_status_i(prog_status_lo)
      // memory command output to arbiter
      ,.mem_fwd_header_o(mem_fwd_header_lo)
      ,.mem_fwd_data_o(mem_fwd_data_lo)
      ,.mem_fwd_v_o(mem_fwd_v_lo)
      ,.mem_fwd_ready_and_i(mem_fwd_ready_and_li)
      // Spec bits write port - to memory response pipe
      ,.spec_w_v_o(spec_w_v)
      ,.spec_w_addr_o(spec_w_addr)
      ,.spec_w_addr_bypass_hash_o(spec_w_addr_bypass_hash)
      ,.spec_v_o(spec_v)
      ,.spec_squash_v_o(spec_squash_v)
      ,.spec_fwd_mod_v_o(spec_fwd_mod_v)
      ,.spec_state_v_o(spec_state_v)
      ,.spec_bits_o(spec_bits)
      // Pending bits write port - from memory response pipe
      ,.mem_rev_pending_w_v_i(mem_rev_pending_w_v)
      ,.mem_rev_pending_w_yumi_o(mem_rev_pending_w_yumi)
      ,.mem_rev_pending_w_addr_i(mem_rev_pending_w_addr)
      ,.mem_rev_pending_w_addr_bypass_hash_i(mem_rev_pending_w_addr_bypass_hash)
      ,.mem_rev_pending_up_i(mem_rev_pending_up)
      ,.mem_rev_pending_down_i(mem_rev_pending_down)
      ,.mem_rev_pending_clear_i(mem_rev_pending_clear)
      // Pending bits write port - from LCE response pipe
      ,.lce_resp_pending_w_v_i(lce_resp_pending_w_v)
      ,.lce_resp_pending_w_yumi_o(lce_resp_pending_w_yumi)
      ,.lce_resp_pending_w_addr_i(lce_resp_pending_w_addr)
      ,.lce_resp_pending_w_addr_bypass_hash_i(lce_resp_pending_w_addr_bypass_hash)
      ,.lce_resp_pending_up_i(lce_resp_pending_up)
      ,.lce_resp_pending_down_i(lce_resp_pending_down)
      ,.lce_resp_pending_clear_i(lce_resp_pending_clear)
      );

  logic prog_pipe_empty;
  if (prog_pipe_en_p == 1) begin
    // Programmable pipe
    bp_cce_hybrid_prog_pipe
      #(.bp_params_p(bp_params_p)
        ,.header_fifo_els_p(prog_header_fifo_els_p)
        )
      prog_pipe
       (.clk_i(clk_i)
        ,.reset_i(reset_i)
        // control
        ,.cce_mode_i(cce_mode)
        ,.cce_id_i(cce_id)
        ,.empty_o(prog_pipe_empty)
        // from coherent pipeline
        ,.lce_req_header_i(prog_lce_req_header_li)
        ,.lce_req_v_i(prog_lce_req_v_li)
        ,.lce_req_ready_and_o(prog_lce_req_ready_and_lo)
        // to coherent pipeline
        ,.prog_v_o(prog_v_lo)
        ,.prog_yumi_i(prog_yumi_li)
        ,.prog_status_o(prog_status_lo)
        );
  end else begin
    assign prog_pipe_empty = 1'b1;
    assign prog_status_lo = 1'b1;
    assign prog_v_lo = 1'b1;
    assign prog_lce_req_ready_and_lo = 1'b1;
  end

  // Memory Response Pipe
  bp_bedrock_lce_cmd_header_s mem_rev_lce_cmd_header_li;
  logic [bedrock_fill_width_p-1:0] mem_rev_lce_cmd_data_li;
  logic mem_rev_lce_cmd_v_li, mem_rev_lce_cmd_ready_and_lo;

  logic mem_credit_return;
  bp_cce_hybrid_mem_rev_pipe
    #(.bp_params_p(bp_params_p)
      ,.pending_wbuf_els_p(mem_rev_pending_wbuf_els_p)
      )
    mem_rev_pipe
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // control
      ,.cce_mode_i(cce_mode)
      ,.cce_id_i(cce_id)
      // Spec bits write port - from coherent pipe
      ,.spec_w_v_i(spec_w_v)
      ,.spec_w_addr_i(spec_w_addr)
      ,.spec_w_addr_bypass_hash_i(spec_w_addr_bypass_hash)
      ,.spec_v_i(spec_v)
      ,.spec_squash_v_i(spec_squash_v)
      ,.spec_fwd_mod_v_i(spec_fwd_mod_v)
      ,.spec_state_v_i(spec_state_v)
      ,.spec_bits_i(spec_bits)
      // Pending bits write port - to coherent pipe
      ,.pending_w_v_o(mem_rev_pending_w_v)
      ,.pending_w_yumi_i(mem_rev_pending_w_yumi)
      ,.pending_w_addr_o(mem_rev_pending_w_addr)
      ,.pending_w_addr_bypass_hash_o(mem_rev_pending_w_addr_bypass_hash)
      ,.pending_up_o(mem_rev_pending_up)
      ,.pending_down_o(mem_rev_pending_down)
      ,.pending_clear_o(mem_rev_pending_clear)
      // LCE Command to arbiter
      ,.lce_cmd_header_o(mem_rev_lce_cmd_header_li)
      ,.lce_cmd_data_o(mem_rev_lce_cmd_data_li)
      ,.lce_cmd_v_o(mem_rev_lce_cmd_v_li)
      ,.lce_cmd_ready_and_i(mem_rev_lce_cmd_ready_and_lo)
      // Memory Response from external
      ,.mem_rev_header_i(mem_rev_header_cast_i)
      ,.mem_rev_data_i(mem_rev_data_i)
      ,.mem_rev_v_i(mem_rev_v_i)
      ,.mem_rev_ready_and_o(mem_rev_ready_and_o)
      // memory credits
      ,.mem_credit_return_o(mem_credit_return)
      );

  // LCE Response pipe
  bp_bedrock_mem_fwd_header_s lce_resp_mem_fwd_header_lo;
  logic [bedrock_fill_width_p-1:0] lce_resp_mem_fwd_data_lo;
  logic lce_resp_mem_fwd_v_lo, lce_resp_mem_fwd_ready_and_li;

  bp_cce_hybrid_lce_resp_pipe
    #(.bp_params_p(bp_params_p))
    lce_resp_pipe
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // LCE Response from external
      ,.lce_resp_header_i(lce_resp_header_cast_i)
      ,.lce_resp_data_i(lce_resp_data_i)
      ,.lce_resp_v_i(lce_resp_v_i)
      ,.lce_resp_ready_and_o(lce_resp_ready_and_o)
      // memory command output to arbiter
      ,.mem_fwd_header_o(lce_resp_mem_fwd_header_lo)
      ,.mem_fwd_data_o(lce_resp_mem_fwd_data_lo)
      ,.mem_fwd_v_o(lce_resp_mem_fwd_v_lo)
      ,.mem_fwd_ready_and_i(lce_resp_mem_fwd_ready_and_li)
      // Pending bits write port - to coherent pipe
      ,.pending_w_v_o(lce_resp_pending_w_v)
      ,.pending_w_yumi_i(lce_resp_pending_w_yumi)
      ,.pending_w_addr_o(lce_resp_pending_w_addr)
      ,.pending_w_addr_bypass_hash_o(lce_resp_pending_w_addr_bypass_hash)
      ,.pending_up_o(lce_resp_pending_up)
      ,.pending_down_o(lce_resp_pending_down)
      ,.pending_clear_o(lce_resp_pending_clear)
      // response signals
      ,.sync_yumi_o(sync_yumi)
      ,.coh_yumi_o(coh_yumi)
      ,.inv_yumi_o(inv_yumi)
      ,.wb_yumi_o(wb_yumi)
      );

  // LCE Command xbar
  bp_bedrock_lce_cmd_header_s [2:0]     lce_cmd_xbar_header_li;
  logic [2:0][bedrock_fill_width_p-1:0] lce_cmd_xbar_data_li;
  logic [2:0]                           lce_cmd_xbar_v_li;
  logic [2:0]                           lce_cmd_xbar_ready_and_lo;

  assign lce_cmd_xbar_header_li[0]     = lce_cmd_header_li;
  assign lce_cmd_xbar_data_li[0]       = lce_cmd_data_li;
  assign lce_cmd_xbar_v_li[0]          = lce_cmd_v_li;
  assign lce_cmd_ready_and_lo          = lce_cmd_xbar_ready_and_lo[0];

  assign lce_cmd_xbar_header_li[1]     = mem_rev_lce_cmd_header_li;
  assign lce_cmd_xbar_data_li[1]       = mem_rev_lce_cmd_data_li;
  assign lce_cmd_xbar_v_li[1]          = mem_rev_lce_cmd_v_li;
  assign mem_rev_lce_cmd_ready_and_lo  = lce_cmd_xbar_ready_and_lo[1];

  assign lce_cmd_xbar_header_li[2]     = ctrl_lce_cmd_header_li;
  assign lce_cmd_xbar_data_li[2]       = ctrl_lce_cmd_data_li;
  assign lce_cmd_xbar_v_li[2]          = ctrl_lce_cmd_v_li;
  assign ctrl_lce_cmd_ready_and_lo     = lce_cmd_xbar_ready_and_lo[2];

  bp_me_xbar_stream
    #(.bp_params_p(bp_params_p)
      ,.payload_width_p(lce_cmd_payload_width_lp)
      ,.num_source_p(3)
      ,.num_sink_p(1)
      ,.stream_mask_p(lce_cmd_stream_mask_gp)
      )
    lce_cmd_xbar
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // source
      ,.msg_header_i(lce_cmd_xbar_header_li)
      ,.msg_data_i(lce_cmd_xbar_data_li)
      ,.msg_v_i(lce_cmd_xbar_v_li)
      ,.msg_ready_and_o(lce_cmd_xbar_ready_and_lo)
      ,.msg_dst_i('0)
      // sink
      ,.msg_header_o(lce_cmd_header_cast_o)
      ,.msg_data_o(lce_cmd_data_o)
      ,.msg_v_o(lce_cmd_v_o)
      ,.msg_ready_and_i(lce_cmd_ready_and_i)
      );

  // memory command xbar
  bp_bedrock_mem_fwd_header_s [2:0]     mem_fwd_xbar_header_li;
  logic [2:0][bedrock_fill_width_p-1:0] mem_fwd_xbar_data_li;
  logic [2:0]                           mem_fwd_xbar_v_li;
  logic [2:0]                           mem_fwd_xbar_ready_and_lo;

  assign mem_fwd_xbar_header_li[0]     = mem_fwd_header_lo;
  assign mem_fwd_xbar_data_li[0]       = mem_fwd_data_lo;
  assign mem_fwd_xbar_v_li[0]          = mem_fwd_v_lo;
  assign mem_fwd_ready_and_li          = mem_fwd_xbar_ready_and_lo[0];

  assign mem_fwd_xbar_header_li[1]     = uc_mem_fwd_header_lo;
  assign mem_fwd_xbar_data_li[1]       = uc_mem_fwd_data_lo;
  assign mem_fwd_xbar_v_li[1]          = uc_mem_fwd_v_lo;
  assign uc_mem_fwd_ready_and_li       = mem_fwd_xbar_ready_and_lo[1];

  assign mem_fwd_xbar_header_li[2]     = lce_resp_mem_fwd_header_lo;
  assign mem_fwd_xbar_data_li[2]       = lce_resp_mem_fwd_data_lo;
  assign mem_fwd_xbar_v_li[2]          = lce_resp_mem_fwd_v_lo;
  assign lce_resp_mem_fwd_ready_and_li = mem_fwd_xbar_ready_and_lo[2];

  bp_me_xbar_stream
    #(.bp_params_p(bp_params_p)
      ,.payload_width_p(mem_fwd_payload_width_lp)
      ,.num_source_p(3)
      ,.num_sink_p(1)
      ,.stream_mask_p(mem_fwd_stream_mask_gp)
      )
    mem_fwd_xbar
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.msg_header_i(mem_fwd_xbar_header_li)
      ,.msg_data_i(mem_fwd_xbar_data_li)
      ,.msg_v_i(mem_fwd_xbar_v_li)
      ,.msg_ready_and_o(mem_fwd_xbar_ready_and_lo)
      ,.msg_dst_i('0)
      ,.msg_header_o(mem_fwd_header_cast_o)
      ,.msg_data_o(mem_fwd_data_o)
      ,.msg_v_o(mem_fwd_v_o)
      ,.msg_ready_and_i(mem_fwd_ready_and_i)
      );

endmodule
