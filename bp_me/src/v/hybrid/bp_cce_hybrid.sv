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
    , parameter prog_pipe_en_p             = 1

    , parameter lce_data_width_p           = dword_width_gp
    , parameter mem_data_width_p           = dword_width_gp
    , parameter req_header_fifo_els_p      = 2
    , parameter req_data_ctrl_els_p        = 2
    , parameter coh_header_fifo_els_p      = 2
    , parameter coh_data_fifo_els_p        = 2
    , parameter uc_header_fifo_els_p       = 2
    , parameter uc_data_fifo_els_p         = 2
    , parameter prog_header_fifo_els_p     = 2
    , parameter mem_resp_header_els_p      = 2
    , parameter lce_resp_header_els_p      = 2
    , parameter mem_cmd_pending_wbuf_els_p = 2

    , localparam cfg_bus_width_lp          = `bp_cfg_bus_width(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)

    // interface widths
    `declare_bp_bedrock_lce_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p, cce)
  )
  (input                                            clk_i
   , input                                          reset_i

   // Config channel
   , input [cfg_bus_width_lp-1:0]                   cfg_bus_i

   // LCE-CCE Interface
   // BedRock Burst protocol: ready&valid
   , input [lce_req_header_width_lp-1:0]            lce_req_header_i
   , input                                          lce_req_header_v_i
   , output logic                                   lce_req_header_ready_and_o
   , input                                          lce_req_has_data_i
   , input [lce_data_width_p-1:0]                   lce_req_data_i
   , input                                          lce_req_data_v_i
   , output logic                                   lce_req_data_ready_and_o
   , input                                          lce_req_last_i

   , input [lce_resp_header_width_lp-1:0]           lce_resp_header_i
   , input                                          lce_resp_header_v_i
   , output logic                                   lce_resp_header_ready_and_o
   , input                                          lce_resp_has_data_i
   , input [lce_data_width_p-1:0]                   lce_resp_data_i
   , input                                          lce_resp_data_v_i
   , output logic                                   lce_resp_data_ready_and_o
   , input                                          lce_resp_last_i

   , output logic [lce_cmd_header_width_lp-1:0]     lce_cmd_header_o
   , output logic                                   lce_cmd_header_v_o
   , input                                          lce_cmd_header_ready_and_i
   , output logic                                   lce_cmd_has_data_o
   , output logic [lce_data_width_p-1:0]            lce_cmd_data_o
   , output logic                                   lce_cmd_data_v_o
   , input                                          lce_cmd_data_ready_and_i
   , output logic                                   lce_cmd_last_o

   // CCE-MEM Interface
   // BedRock Stream protocol: ready&valid
   , input [cce_mem_header_width_lp-1:0]            mem_resp_header_i
   , input [mem_data_width_p-1:0]                   mem_resp_data_i
   , input                                          mem_resp_v_i
   , output logic                                   mem_resp_ready_and_o
   , input                                          mem_resp_last_i

   , output logic [cce_mem_header_width_lp-1:0]     mem_cmd_header_o
   , output logic [mem_data_width_p-1:0]            mem_cmd_data_o
   , output logic                                   mem_cmd_v_o
   , input                                          mem_cmd_ready_and_i
   , output logic                                   mem_cmd_last_o
   );

  // parameter checks
  if (lce_sets_p <= 1) $fatal(0,"Number of LCE sets must be greater than 1");
  if (icache_block_width_p != cce_block_width_p) $fatal(0,"icache block width must match cce block width");
  if (dcache_block_width_p != cce_block_width_p) $fatal(0,"dcache block width must match cce block width");
  if ((num_cacc_p) > 0 && (acache_block_width_p != cce_block_width_p)) $fatal(0,"acache block width must match cce block width");
  if (dword_width_gp != 64) $fatal(0,"FSM CCE requires dword width of 64-bits");
  if (!(`BSG_IS_POW2(cce_block_width_p) || cce_block_width_p < 64 || cce_block_width_p > 1024))
    $fatal(0, "invalid CCE block width");

  // Define structure variables for output queues
  `declare_bp_bedrock_lce_if(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce);
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p, cce);

  // Config bus
  `declare_bp_cfg_bus_s(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `bp_cast_i(bp_cfg_bus_s, cfg_bus);

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
      ,.v_i(mem_cmd_v_o & mem_cmd_last_o)
      ,.ready_i(mem_cmd_ready_and_i)
      // memory responses return credits - from memory response pipe
      ,.yumi_i(mem_credit_return)
      ,.count_o(mem_credit_count_lo)
      );

  // Control
  logic ctrl_lce_cmd_header_v_li, ctrl_lce_cmd_header_ready_and_lo, ctrl_lce_cmd_has_data_li;
  logic ctrl_lce_cmd_data_v_li, ctrl_lce_cmd_data_ready_and_lo, ctrl_lce_cmd_last_li;
  bp_bedrock_lce_cmd_header_s ctrl_lce_cmd_header_li;
  logic [lce_data_width_p-1:0] ctrl_lce_cmd_data_li;

  logic drain_then_stall, req_empty, uc_pipe_empty, coh_pipe_empty, sync_yumi;
  logic inv_yumi, coh_yumi, wb_yumi;
  bp_cce_mode_e cce_mode;
  logic [cce_id_width_p-1:0] cce_id;

  bp_cce_hybrid_ctrl
    #(.bp_params_p(bp_params_p)
      ,.lce_data_width_p(lce_data_width_p)
      )
    control
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.cfg_bus_i(cfg_bus_cast_i)
      // sync command to arbitration
      ,.lce_cmd_header_o(ctrl_lce_cmd_header_li)
      ,.lce_cmd_header_v_o(ctrl_lce_cmd_header_v_li)
      ,.lce_cmd_header_ready_and_i(ctrl_lce_cmd_header_ready_and_lo)
      ,.lce_cmd_has_data_o(ctrl_lce_cmd_has_data_li)
      ,.lce_cmd_data_o(ctrl_lce_cmd_data_li)
      ,.lce_cmd_data_v_o(ctrl_lce_cmd_data_v_li)
      ,.lce_cmd_data_ready_and_i(ctrl_lce_cmd_data_ready_and_lo)
      ,.lce_cmd_last_o(ctrl_lce_cmd_last_li)
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
  // input
  `bp_cast_i(bp_bedrock_lce_req_header_s, lce_req_header);
  // cacheable memory stream
  logic lce_req_header_v_li, lce_req_header_ready_and_lo, lce_req_has_data_li;
  logic lce_req_data_v_li, lce_req_data_ready_and_lo, lce_req_last_li;
  bp_bedrock_lce_req_header_s lce_req_header_li;
  logic [lce_data_width_p-1:0] lce_req_data_li;
  // uncacheable memory stream
  logic uc_lce_req_header_v_li, uc_lce_req_header_ready_and_lo, uc_lce_req_has_data_li;
  logic uc_lce_req_data_v_li, uc_lce_req_data_ready_and_lo, uc_lce_req_last_li;
  bp_bedrock_lce_req_header_s uc_lce_req_header_li;
  logic [lce_data_width_p-1:0] uc_lce_req_data_li;

  bp_cce_hybrid_req
    #(.bp_params_p(bp_params_p)
      ,.lce_data_width_p(lce_data_width_p)
      ,.header_fifo_els_p(req_header_fifo_els_p)
      ,.data_ctrl_els_p(req_data_ctrl_els_p)
      )
    request_arbiter
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.cce_mode_i(cce_mode)
      ,.stall_i(drain_then_stall)
      ,.empty_o(req_empty)
      // request input from external
      ,.lce_req_header_i(lce_req_header_cast_i)
      ,.lce_req_header_v_i(lce_req_header_v_i)
      ,.lce_req_header_ready_and_o(lce_req_header_ready_and_o)
      ,.lce_req_has_data_i(lce_req_has_data_i)
      ,.lce_req_data_i(lce_req_data_i)
      ,.lce_req_data_v_i(lce_req_data_v_i)
      ,.lce_req_data_ready_and_o(lce_req_data_ready_and_o)
      ,.lce_req_last_i(lce_req_last_i)
      // cacheable memory space requests
      ,.lce_req_header_o(lce_req_header_li)
      ,.lce_req_header_v_o(lce_req_header_v_li)
      ,.lce_req_header_ready_and_i(lce_req_header_ready_and_lo)
      ,.lce_req_has_data_o(lce_req_has_data_li)
      ,.lce_req_data_o(lce_req_data_li)
      ,.lce_req_data_v_o(lce_req_data_v_li)
      ,.lce_req_data_ready_and_i(lce_req_data_ready_and_lo)
      ,.lce_req_last_o(lce_req_last_li)
      // uncacheable memory space requests
      ,.uc_lce_req_header_o(uc_lce_req_header_li)
      ,.uc_lce_req_header_v_o(uc_lce_req_header_v_li)
      ,.uc_lce_req_header_ready_and_i(uc_lce_req_header_ready_and_lo)
      ,.uc_lce_req_has_data_o(uc_lce_req_has_data_li)
      ,.uc_lce_req_data_o(uc_lce_req_data_li)
      ,.uc_lce_req_data_v_o(uc_lce_req_data_v_li)
      ,.uc_lce_req_data_ready_and_i(uc_lce_req_data_ready_and_lo)
      ,.uc_lce_req_last_o(uc_lce_req_last_li)
      );

  // Uncacheable memory space pipe
  bp_bedrock_cce_mem_header_s uc_mem_cmd_header_lo;
  logic [mem_data_width_p-1:0] uc_mem_cmd_data_lo;
  logic uc_mem_cmd_v_lo, uc_mem_cmd_ready_and_li, uc_mem_cmd_last_lo;

  bp_cce_hybrid_uc_pipe
    #(.bp_params_p(bp_params_p)
      ,.lce_data_width_p(lce_data_width_p)
      ,.mem_data_width_p(mem_data_width_p)
      ,.header_fifo_els_p(uc_header_fifo_els_p)
      ,.data_fifo_els_p(uc_data_fifo_els_p)
      )
    uc_pipe
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.empty_o(uc_pipe_empty)
      // request input from arbiter
      ,.lce_req_header_i(uc_lce_req_header_li)
      ,.lce_req_header_v_i(uc_lce_req_header_v_li)
      ,.lce_req_header_ready_and_o(uc_lce_req_header_ready_and_lo)
      ,.lce_req_has_data_i(uc_lce_req_has_data_li)
      ,.lce_req_data_i(uc_lce_req_data_li)
      ,.lce_req_data_v_i(uc_lce_req_data_v_li)
      ,.lce_req_data_ready_and_o(uc_lce_req_data_ready_and_lo)
      ,.lce_req_last_i(uc_lce_req_last_li)
      // memory command output to arbiter
      ,.mem_cmd_header_o(uc_mem_cmd_header_lo)
      ,.mem_cmd_data_o(uc_mem_cmd_data_lo)
      ,.mem_cmd_v_o(uc_mem_cmd_v_lo)
      ,.mem_cmd_ready_and_i(uc_mem_cmd_ready_and_li)
      ,.mem_cmd_last_o(uc_mem_cmd_last_lo)
      );

  // Cacheable memory space pipe
  bp_bedrock_cce_mem_header_s mem_cmd_header_lo;
  logic [mem_data_width_p-1:0] mem_cmd_data_lo;
  logic mem_cmd_v_lo, mem_cmd_ready_and_li, mem_cmd_last_lo;

  logic spec_w_v, spec_w_addr_bypass_hash, spec_v, spec_squash_v, spec_fwd_mod_v, spec_state_v;
  logic [paddr_width_p-1:0] spec_w_addr;
  bp_cce_spec_s spec_bits;

  logic mem_resp_pending_w_v, mem_resp_pending_w_yumi, mem_resp_pending_w_addr_bypass_hash;
  logic mem_resp_pending_up, mem_resp_pending_down, mem_resp_pending_clear;
  logic [paddr_width_p-1:0] mem_resp_pending_w_addr;

  logic lce_resp_pending_w_v, lce_resp_pending_w_yumi, lce_resp_pending_w_addr_bypass_hash;
  logic lce_resp_pending_up, lce_resp_pending_down, lce_resp_pending_clear;
  logic [paddr_width_p-1:0] lce_resp_pending_w_addr;

  logic lce_cmd_header_v_li, lce_cmd_header_ready_and_lo, lce_cmd_has_data_li;
  logic lce_cmd_data_v_li, lce_cmd_data_ready_and_lo, lce_cmd_last_li;
  bp_bedrock_lce_cmd_header_s lce_cmd_header_li;
  logic [lce_data_width_p-1:0] lce_cmd_data_li;

  // to programmable pipeline
  bp_bedrock_lce_req_header_s prog_lce_req_header_li;
  logic prog_lce_req_header_v_li, prog_lce_req_header_ready_and_lo;
  // from programmable pipeline
  logic prog_v_lo, prog_yumi_li, prog_status_lo;

  bp_cce_hybrid_coh_pipe
    #(.bp_params_p(bp_params_p)
      ,.lce_data_width_p(lce_data_width_p)
      ,.mem_data_width_p(mem_data_width_p)
      ,.header_fifo_els_p(coh_header_fifo_els_p)
      ,.data_fifo_els_p(coh_data_fifo_els_p)
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
      ,.lce_req_header_v_i(lce_req_header_v_li)
      ,.lce_req_header_ready_and_o(lce_req_header_ready_and_lo)
      ,.lce_req_has_data_i(lce_req_has_data_li)
      ,.lce_req_data_i(lce_req_data_li)
      ,.lce_req_data_v_i(lce_req_data_v_li)
      ,.lce_req_data_ready_and_o(lce_req_data_ready_and_lo)
      ,.lce_req_last_i(lce_req_last_li)
      // LCE Command to arbiter
      ,.lce_cmd_header_o(lce_cmd_header_li)
      ,.lce_cmd_header_v_o(lce_cmd_header_v_li)
      ,.lce_cmd_header_ready_and_i(lce_cmd_header_ready_and_lo)
      ,.lce_cmd_has_data_o(lce_cmd_has_data_li)
      ,.lce_cmd_data_o(lce_cmd_data_li)
      ,.lce_cmd_data_v_o(lce_cmd_data_v_li)
      ,.lce_cmd_data_ready_and_i(lce_cmd_data_ready_and_lo)
      ,.lce_cmd_last_o(lce_cmd_last_li)
      // LCE response signals
      ,.inv_yumi_i(inv_yumi)
      ,.wb_yumi_i(wb_yumi)
      // to programmable pipeline
      ,.lce_req_header_o(prog_lce_req_header_li)
      ,.lce_req_header_v_o(prog_lce_req_header_v_li)
      ,.lce_req_header_ready_and_i(prog_lce_req_header_ready_and_lo)
      // from programmable pipeline
      ,.prog_v_i(prog_v_lo)
      ,.prog_yumi_o(prog_yumi_li)
      ,.prog_status_i(prog_status_lo)
      // memory command output to arbiter
      ,.mem_cmd_header_o(mem_cmd_header_lo)
      ,.mem_cmd_data_o(mem_cmd_data_lo)
      ,.mem_cmd_v_o(mem_cmd_v_lo)
      ,.mem_cmd_ready_and_i(mem_cmd_ready_and_li)
      ,.mem_cmd_last_o(mem_cmd_last_lo)
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
      ,.mem_resp_pending_w_v_i(mem_resp_pending_w_v)
      ,.mem_resp_pending_w_yumi_o(mem_resp_pending_w_yumi)
      ,.mem_resp_pending_w_addr_i(mem_resp_pending_w_addr)
      ,.mem_resp_pending_w_addr_bypass_hash_i(mem_resp_pending_w_addr_bypass_hash)
      ,.mem_resp_pending_up_i(mem_resp_pending_up)
      ,.mem_resp_pending_down_i(mem_resp_pending_down)
      ,.mem_resp_pending_clear_i(mem_resp_pending_clear)
      // Pending bits write port - from LCE response pipe
      ,.lce_resp_pending_w_v_i(lce_resp_pending_w_v)
      ,.lce_resp_pending_w_yumi_o(lce_resp_pending_w_yumi)
      ,.lce_resp_pending_w_addr_i(lce_resp_pending_w_addr)
      ,.lce_resp_pending_w_addr_bypass_hash_i(lce_resp_pending_w_addr_bypass_hash)
      ,.lce_resp_pending_up_i(lce_resp_pending_up)
      ,.lce_resp_pending_down_i(lce_resp_pending_down)
      ,.lce_resp_pending_clear_i(lce_resp_pending_clear)
      );

  if (prog_pipe_en_p) begin
  // Programmable pipe
  logic prog_pipe_empty;
  bp_cce_hybrid_prog_pipe
    #(.bp_params_p(bp_params_p)
      ,.lce_data_width_p(lce_data_width_p)
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
      ,.lce_req_header_v_i(prog_lce_req_header_v_li)
      ,.lce_req_header_ready_and_o(prog_lce_req_header_ready_and_lo)
      // to coherent pipeline
      ,.prog_v_o(prog_v_lo)
      ,.prog_yumi_i(prog_yumi_li)
      ,.prog_status_o(prog_status_lo)
      );
  end else begin
    wire prop_pipe_empty = 1'b1;
    assign prog_status_lo = 1'b1;
    assign prog_v_lo = 1'b1;
    assign unused = prog_yumi_li;
  end

  // Memory Response pipe
  `bp_cast_i(bp_bedrock_cce_mem_header_s, mem_resp_header);

  logic mem_resp_lce_cmd_header_v_li, mem_resp_lce_cmd_header_ready_and_lo, mem_resp_lce_cmd_has_data_li;
  logic mem_resp_lce_cmd_data_v_li, mem_resp_lce_cmd_data_ready_and_lo, mem_resp_lce_cmd_last_li;
  bp_bedrock_lce_cmd_header_s mem_resp_lce_cmd_header_li;
  logic [lce_data_width_p-1:0] mem_resp_lce_cmd_data_li;

  bp_cce_hybrid_mem_resp_pipe
    #(.bp_params_p(bp_params_p)
      ,.lce_data_width_p(lce_data_width_p)
      ,.mem_data_width_p(mem_data_width_p)
      ,.header_els_p(mem_resp_header_els_p)
      )
    mem_resp_pipe
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
      ,.pending_w_v_o(mem_resp_pending_w_v)
      ,.pending_w_yumi_i(mem_resp_pending_w_yumi)
      ,.pending_w_addr_o(mem_resp_pending_w_addr)
      ,.pending_w_addr_bypass_hash_o(mem_resp_pending_w_addr_bypass_hash)
      ,.pending_up_o(mem_resp_pending_up)
      ,.pending_down_o(mem_resp_pending_down)
      ,.pending_clear_o(mem_resp_pending_clear)
      // LCE Command to arbiter
      ,.lce_cmd_header_o(mem_resp_lce_cmd_header_li)
      ,.lce_cmd_header_v_o(mem_resp_lce_cmd_header_v_li)
      ,.lce_cmd_header_ready_and_i(mem_resp_lce_cmd_header_ready_and_lo)
      ,.lce_cmd_has_data_o(mem_resp_lce_cmd_has_data_li)
      ,.lce_cmd_data_o(mem_resp_lce_cmd_data_li)
      ,.lce_cmd_data_v_o(mem_resp_lce_cmd_data_v_li)
      ,.lce_cmd_data_ready_and_i(mem_resp_lce_cmd_data_ready_and_lo)
      ,.lce_cmd_last_o(mem_resp_lce_cmd_last_li)
      // Memory Response from external
      ,.mem_resp_header_i(mem_resp_header_cast_i)
      ,.mem_resp_data_i(mem_resp_data_i)
      ,.mem_resp_v_i(mem_resp_v_i)
      ,.mem_resp_ready_and_o(mem_resp_ready_and_o)
      ,.mem_resp_last_i(mem_resp_last_i)
      // memory credits
      ,.mem_credit_return_o(mem_credit_return)
      );

  // LCE Response pipe
  `bp_cast_i(bp_bedrock_lce_resp_header_s, lce_resp_header);

  bp_bedrock_cce_mem_header_s lce_resp_mem_cmd_header_lo;
  logic [mem_data_width_p-1:0] lce_resp_mem_cmd_data_lo;
  logic lce_resp_mem_cmd_v_lo, lce_resp_mem_cmd_ready_and_li, lce_resp_mem_cmd_last_lo;

  bp_cce_hybrid_lce_resp_pipe
    #(.bp_params_p(bp_params_p)
      ,.lce_data_width_p(lce_data_width_p)
      ,.mem_data_width_p(mem_data_width_p)
      ,.header_els_p(lce_resp_header_els_p)
      )
    lce_resp_pipe
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // LCE Response from external
      ,.lce_resp_header_i(lce_resp_header_cast_i)
      ,.lce_resp_header_v_i(lce_resp_header_v_i)
      ,.lce_resp_header_ready_and_o(lce_resp_header_ready_and_o)
      ,.lce_resp_has_data_i(lce_resp_has_data_i)
      ,.lce_resp_data_i(lce_resp_data_i)
      ,.lce_resp_data_v_i(lce_resp_data_v_i)
      ,.lce_resp_data_ready_and_o(lce_resp_data_ready_and_o)
      ,.lce_resp_last_i(lce_resp_last_i)
      // memory command output to arbiter
      ,.mem_cmd_header_o(lce_resp_mem_cmd_header_lo)
      ,.mem_cmd_data_o(lce_resp_mem_cmd_data_lo)
      ,.mem_cmd_v_o(lce_resp_mem_cmd_v_lo)
      ,.mem_cmd_ready_and_i(lce_resp_mem_cmd_ready_and_li)
      ,.mem_cmd_last_o(lce_resp_mem_cmd_last_lo)
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
  logic [2:0]                           lce_cmd_xbar_header_v_li;
  logic [2:0]                           lce_cmd_xbar_header_yumi_lo;
  logic [2:0]                           lce_cmd_xbar_has_data_li;
  logic [2:0][lce_data_width_p-1:0]     lce_cmd_xbar_data_li;
  logic [2:0]                           lce_cmd_xbar_data_v_li;
  logic [2:0]                           lce_cmd_xbar_data_yumi_lo;
  logic [2:0]                           lce_cmd_xbar_last_li;

  assign lce_cmd_xbar_header_li[0]     = lce_cmd_header_li;
  assign lce_cmd_xbar_header_v_li[0]   = lce_cmd_header_v_li;
  assign lce_cmd_xbar_has_data_li[0]   = lce_cmd_has_data_li;
  assign lce_cmd_xbar_data_li[0]       = lce_cmd_data_li;
  assign lce_cmd_xbar_data_v_li[0]     = lce_cmd_data_v_li;
  assign lce_cmd_xbar_last_li[0]       = lce_cmd_last_li;
  assign lce_cmd_header_ready_and_lo   = lce_cmd_xbar_header_yumi_lo[0];
  assign lce_cmd_data_ready_and_lo     = lce_cmd_xbar_data_yumi_lo[0];

  assign lce_cmd_xbar_header_li[1]     = mem_resp_lce_cmd_header_li;
  assign lce_cmd_xbar_header_v_li[1]   = mem_resp_lce_cmd_header_v_li;
  assign lce_cmd_xbar_has_data_li[1]   = mem_resp_lce_cmd_has_data_li;
  assign lce_cmd_xbar_data_li[1]       = mem_resp_lce_cmd_data_li;
  assign lce_cmd_xbar_data_v_li[1]     = mem_resp_lce_cmd_data_v_li;
  assign lce_cmd_xbar_last_li[1]       = mem_resp_lce_cmd_last_li;
  assign mem_resp_lce_cmd_header_ready_and_lo   = lce_cmd_xbar_header_yumi_lo[1];
  assign mem_resp_lce_cmd_data_ready_and_lo     = lce_cmd_xbar_data_yumi_lo[1];

  assign lce_cmd_xbar_header_li[2]     = ctrl_lce_cmd_header_li;
  assign lce_cmd_xbar_header_v_li[2]   = ctrl_lce_cmd_header_v_li;
  assign lce_cmd_xbar_has_data_li[2]   = ctrl_lce_cmd_has_data_li;
  assign lce_cmd_xbar_data_li[2]       = ctrl_lce_cmd_data_li;
  assign lce_cmd_xbar_data_v_li[2]     = ctrl_lce_cmd_data_v_li;
  assign lce_cmd_xbar_last_li[2]       = ctrl_lce_cmd_last_li;
  assign ctrl_lce_cmd_header_ready_and_lo   = lce_cmd_xbar_header_yumi_lo[2];
  assign ctrl_lce_cmd_data_ready_and_lo     = lce_cmd_xbar_data_yumi_lo[2];

  `bp_cast_o(bp_bedrock_lce_cmd_header_s, lce_cmd_header);

  bp_me_xbar_burst
    #(.bp_params_p(bp_params_p)
      ,.data_width_p(lce_data_width_p)
      ,.payload_width_p(lce_cmd_payload_width_lp)
      ,.num_source_p(3)
      ,.num_sink_p(1)
      )
    lce_cmd_xbar
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // source
      // TODO: handshake mismatch (yumi consumer to r&v producer - works fine)
      ,.msg_header_i(lce_cmd_xbar_header_li)
      ,.msg_header_v_i(lce_cmd_xbar_header_v_li)
      ,.msg_header_yumi_o(lce_cmd_xbar_header_yumi_lo)
      ,.msg_has_data_i(lce_cmd_xbar_has_data_li)
      ,.msg_data_i(lce_cmd_xbar_data_li)
      ,.msg_data_v_i(lce_cmd_xbar_data_v_li)
      ,.msg_data_yumi_o(lce_cmd_xbar_data_yumi_lo)
      ,.msg_last_i(lce_cmd_xbar_last_li)
      ,.msg_dst_i('0)
      // sink
      ,.msg_header_o(lce_cmd_header_cast_o)
      ,.msg_header_v_o(lce_cmd_header_v_o)
      ,.msg_header_ready_and_i(lce_cmd_header_ready_and_i)
      ,.msg_has_data_o(lce_cmd_has_data_o)
      ,.msg_data_o(lce_cmd_data_o)
      ,.msg_data_v_o(lce_cmd_data_v_o)
      ,.msg_data_ready_and_i(lce_cmd_data_ready_and_i)
      ,.msg_last_o(lce_cmd_last_o)
      );

  // memory command xbar
  bp_bedrock_cce_mem_header_s [2:0]     mem_cmd_xbar_header_li;
  logic [2:0][mem_data_width_p-1:0]     mem_cmd_xbar_data_li;
  logic [2:0]                           mem_cmd_xbar_v_li;
  logic [2:0]                           mem_cmd_xbar_ready_and_lo;
  logic [2:0]                           mem_cmd_xbar_last_li;

  assign mem_cmd_xbar_header_li[0]     = mem_cmd_header_lo;
  assign mem_cmd_xbar_data_li[0]       = mem_cmd_data_lo;
  assign mem_cmd_xbar_v_li[0]          = mem_cmd_v_lo;
  assign mem_cmd_xbar_last_li[0]       = mem_cmd_last_lo;
  assign mem_cmd_ready_and_li          = mem_cmd_xbar_ready_and_lo[0];

  assign mem_cmd_xbar_header_li[1]     = uc_mem_cmd_header_lo;
  assign mem_cmd_xbar_data_li[1]       = uc_mem_cmd_data_lo;
  assign mem_cmd_xbar_v_li[1]          = uc_mem_cmd_v_lo;
  assign mem_cmd_xbar_last_li[1]       = uc_mem_cmd_last_lo;
  assign uc_mem_cmd_ready_and_li       = mem_cmd_xbar_ready_and_lo[1];

  assign mem_cmd_xbar_header_li[2]     = lce_resp_mem_cmd_header_lo;
  assign mem_cmd_xbar_data_li[2]       = lce_resp_mem_cmd_data_lo;
  assign mem_cmd_xbar_v_li[2]          = lce_resp_mem_cmd_v_lo;
  assign mem_cmd_xbar_last_li[2]       = lce_resp_mem_cmd_last_lo;
  assign lce_resp_mem_cmd_ready_and_li = mem_cmd_xbar_ready_and_lo[2];

  `bp_cast_o(bp_bedrock_cce_mem_header_s, mem_cmd_header);

  bp_me_xbar_stream_buffered
    #(.bp_params_p(bp_params_p)
      ,.data_width_p(mem_data_width_p)
      ,.payload_width_p(cce_mem_payload_width_lp)
      ,.num_source_p(3)
      ,.num_sink_p(1)
      )
    mem_cmd_xbar
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.msg_header_i(mem_cmd_xbar_header_li)
      ,.msg_data_i(mem_cmd_xbar_data_li)
      ,.msg_v_i(mem_cmd_xbar_v_li)
      ,.msg_ready_and_o(mem_cmd_xbar_ready_and_lo)
      ,.msg_last_i(mem_cmd_xbar_last_li)
      ,.msg_dst_i('0)
      ,.msg_header_o(mem_cmd_header_cast_o)
      ,.msg_data_o(mem_cmd_data_o)
      ,.msg_v_o(mem_cmd_v_o)
      ,.msg_ready_and_i(mem_cmd_ready_and_i)
      ,.msg_last_o(mem_cmd_last_o)
      );


endmodule
