/**
 *
 * Name:
 *   bp_cce_hybrid_mem_rev_pipe.sv
 *
 * Description:
 *   This is the memory response pipeline for the hybrid CCE.
 *   It contains the speculative bits that track outstanding speculative memory accesses.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_hybrid_mem_rev_pipe
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    // pending bits write buffer elements
    , parameter pending_wbuf_els_p         = 2

    // Derived parameters
    , localparam block_size_in_bytes_lp    = (bedrock_block_width_p/8)
    , localparam lg_num_lce_lp             = `BSG_SAFE_CLOG2(num_lce_p)
    , localparam lg_num_cce_lp             = `BSG_SAFE_CLOG2(num_cce_p)
    , localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp)
    , localparam lg_lce_assoc_lp           = `BSG_SAFE_CLOG2(lce_assoc_p)
    , localparam lg_lce_sets_lp            = `BSG_SAFE_CLOG2(lce_sets_p)
    , localparam num_way_groups_lp         = `BSG_CDIV(cce_way_groups_p, num_cce_p)
    , localparam lg_num_way_groups_lp      = `BSG_SAFE_CLOG2(num_way_groups_lp)
    , localparam inst_ram_addr_width_lp    = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)
    , localparam cfg_bus_width_lp          = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)

    // maximal number of tag sets stored in the directory for all LCE types
    , localparam max_tag_sets_lp           = `BSG_CDIV(lce_sets_p, num_cce_p)
    , localparam lg_max_tag_sets_lp        = `BSG_SAFE_CLOG2(max_tag_sets_lp)

    , localparam counter_max_lp            = 256
    , localparam hash_index_width_lp       = $clog2((2**lg_lce_sets_lp+num_cce_p-1)/num_cce_p)

    , localparam counter_width_lp          = `BSG_SAFE_CLOG2(counter_max_lp+1)

    // log2 of dword width bytes
    , localparam lg_dword_width_bytes_lp   = `BSG_SAFE_CLOG2(dword_width_gp/8)

    // interface width
    `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
  )
  (input                                            clk_i
   , input                                          reset_i

   // control
   , input bp_cce_mode_e                            cce_mode_i
   , input [cce_id_width_p-1:0]                     cce_id_i

   // Spec bits write port - from coherent pipe
   , input                                          spec_w_v_i
   , input [paddr_width_p-1:0]                      spec_w_addr_i
   , input                                          spec_w_addr_bypass_hash_i
   , input                                          spec_v_i
   , input                                          spec_squash_v_i
   , input                                          spec_fwd_mod_v_i
   , input                                          spec_state_v_i
   , input bp_cce_spec_s                            spec_bits_i

   // Pending bits write port
   , output logic                                   pending_w_v_o
   , input                                          pending_w_yumi_i
   , output logic [paddr_width_p-1:0]               pending_w_addr_o
   , output logic                                   pending_w_addr_bypass_hash_o
   , output logic                                   pending_up_o
   , output logic                                   pending_down_o
   , output logic                                   pending_clear_o

   // LCE-CCE Interface
   // BedRock Stream protocol: ready&valid
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

   // memory credit return
   , output logic                                   mem_credit_return_o
   );

  // Define structure variables for output queues
  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);

  `bp_cast_i(bp_bedrock_mem_rev_header_s, mem_rev_header);
  `bp_cast_o(bp_bedrock_lce_cmd_header_s, lce_cmd_header);

  // Memory Rev Stream Pump
  bp_bedrock_mem_rev_header_s fsm_rev_header_li;
  logic [bedrock_fill_width_p-1:0] fsm_rev_data_li;
  logic fsm_rev_v_li, fsm_rev_yumi_lo;
  logic [paddr_width_p-1:0] fsm_rev_addr_li;
  logic fsm_rev_new_li, fsm_rev_critical_li, fsm_rev_last_li;
  bp_me_stream_pump_in
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(bedrock_fill_width_p)
     ,.payload_width_p(mem_rev_payload_width_lp)
     ,.msg_stream_mask_p(mem_rev_stream_mask_gp)
     ,.fsm_stream_mask_p(mem_rev_stream_mask_gp)
     )
   rev_stream_pump
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     // from memory response input
     ,.msg_header_i(mem_rev_header_cast_i)
     ,.msg_data_i(mem_rev_data_i)
     ,.msg_v_i(mem_rev_v_i)
     ,.msg_ready_and_o(mem_rev_ready_and_o)
     // to FSM CCE
     ,.fsm_header_o(fsm_rev_header_li)
     ,.fsm_data_o(fsm_rev_data_li)
     ,.fsm_v_o(fsm_rev_v_li)
     ,.fsm_yumi_i(fsm_rev_yumi_lo)
     ,.fsm_addr_o(fsm_rev_addr_li)
     ,.fsm_new_o(fsm_rev_new_li)
     ,.fsm_critical_o(fsm_rev_critical_li)
     ,.fsm_last_o(fsm_rev_last_li)
     );

  // return memory credit when last beat of mem_rev is consumed
  // by the FSM logic in this module
  assign mem_credit_return_o = fsm_rev_yumi_lo & fsm_rev_last_li;

  // LCE Command Stream Pump
  bp_bedrock_lce_cmd_header_s fsm_cmd_header_lo;
  logic [bedrock_fill_width_p-1:0] fsm_cmd_data_lo;
  logic fsm_cmd_v_lo, fsm_cmd_ready_then_li;
  logic [paddr_width_p-1:0] fsm_cmd_addr_li;
  logic fsm_cmd_new_li, fsm_cmd_critical_li, fsm_cmd_last_li;
  bp_me_stream_pump_out
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(bedrock_fill_width_p)
     ,.payload_width_p(lce_cmd_payload_width_lp)
     ,.msg_stream_mask_p(lce_cmd_stream_mask_gp)
     ,.fsm_stream_mask_p(lce_cmd_stream_mask_gp)
     )
   lce_cmd_pump_out
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_o(lce_cmd_header_cast_o)
     ,.msg_data_o(lce_cmd_data_o)
     ,.msg_v_o(lce_cmd_v_o)
     ,.msg_ready_and_i(lce_cmd_ready_and_i)

     ,.fsm_header_i(fsm_cmd_header_lo)
     ,.fsm_addr_o(fsm_cmd_addr_li)
     ,.fsm_data_i(fsm_cmd_data_lo)
     ,.fsm_v_i(fsm_cmd_v_lo)
     ,.fsm_ready_then_o(fsm_cmd_ready_then_li)
     ,.fsm_new_o(fsm_cmd_new_li)
     ,.fsm_critical_o(fsm_cmd_critical_li)
     ,.fsm_last_o(fsm_cmd_last_li)
     );

  // Speculative memory access management
  bp_cce_spec_s spec_bits_lo;
  bp_cce_spec_bits
    #(.num_way_groups_p(num_way_groups_lp)
      ,.cce_way_groups_p(cce_way_groups_p)
      ,.num_cce_p(num_cce_p)
      ,.paddr_width_p(paddr_width_p)
      ,.block_width_p(bedrock_block_width_p)
      )
    spec_bits
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       // write-port
       ,.w_v_i(spec_w_v_i)
       ,.w_addr_i(spec_w_addr_i)
       ,.w_addr_bypass_hash_i(spec_w_addr_bypass_hash_i)
       ,.spec_v_i(spec_v_i)
       ,.squash_v_i(spec_squash_v_i)
       ,.fwd_mod_v_i(spec_fwd_mod_v_i)
       ,.state_v_i(spec_state_v_i)
       ,.spec_i(spec_bits_i)
       // read-port
       ,.r_v_i(fsm_rev_v_li)
       ,.r_addr_i(fsm_rev_header_li.addr)
       ,.r_addr_bypass_hash_i('0)
       // output
       ,.spec_o(spec_bits_lo)
       );

  // CCE PMA - Mem responses
  logic rev_pma_cacheable_addr_li;
  bp_cce_pma
    #(.bp_params_p(bp_params_p)
      )
    rev_pma
      (.paddr_i(fsm_rev_header_li.addr)
       ,.cacheable_addr_o(rev_pma_cacheable_addr_li)
       );
  wire cce_normal_mode = (cce_mode_i == e_cce_mode_normal);
  wire rev_pma_cacheable_addr = rev_pma_cacheable_addr_li & cce_normal_mode;

  // Pending Bits write buffer
  logic pending_w_v, pending_w_ready_and, pending_w_addr_bypass_hash;
  logic pending_up, pending_down, pending_clear;
  logic [paddr_width_p-1:0] pending_w_addr;

  bsg_fifo_1r1w_small
    #(.width_p(paddr_width_p+4)
      ,.els_p(pending_wbuf_els_p)
      ,.ready_THEN_valid_p(0)
      )
    pending_bits_wbuf
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // input - from FSM
      ,.v_i(pending_w_v)
      ,.ready_param_o(pending_w_ready_and)
      ,.data_i({pending_up, pending_down, pending_clear, pending_w_addr_bypass_hash, pending_w_addr})
      // output - to pending module
      ,.v_o(pending_w_v_o)
      ,.yumi_i(pending_w_yumi_i)
      ,.data_o({pending_up_o, pending_down_o, pending_clear_o, pending_w_addr_bypass_hash_o, pending_w_addr_o})
      );

  // pending write tracker
  // set on pending bit buffer write, clear when last beat of memory message processed
  // clear over set since write hopefully occurs same cycle as last memory message beat
  logic pending_w_done;
  bsg_dff_reset_set_clear
    #(.width_p(1)
      ,.clear_over_set_p(1)
      )
    pending_w_reg
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.set_i(pending_w_v & pending_w_ready_and)
      ,.clear_i(fsm_rev_yumi_lo & fsm_rev_last_li)
      ,.data_o(pending_w_done)
      );

  // compute fsm_rev_valid signal for response FSM, which gates the FSM's processing
  // of fsm_rev messages if pending bit write port is needed but not available
  // only write pending on last beat, and only for cacheable access in normal mode
  // last beat of cacheable response requires pending write port to be available
  wire not_last_beat_valid = fsm_rev_v_li & ~fsm_rev_last_li;
  wire last_beat_valid = fsm_rev_v_li & fsm_rev_last_li
                         & (~rev_pma_cacheable_addr | (rev_pma_cacheable_addr & pending_w_ready_and));
  wire fsm_rev_valid = not_last_beat_valid | last_beat_valid;

  // pending bit defaults
  // pending bit is decremented when mem_rev is consumed out of stream pump
  assign pending_up = 1'b0;
  assign pending_down = 1'b1;
  assign pending_clear = 1'b0;
  assign pending_w_addr_bypass_hash = 1'b0;
  assign pending_w_addr = fsm_rev_header_li.addr;
  // write pending bit if last beat and cacheable access
  assign pending_w_v = fsm_rev_yumi_lo & fsm_rev_last_li & rev_pma_cacheable_addr & ~pending_w_done;

  always_comb begin

    // LCE command defaults
    fsm_cmd_header_lo = '0;
    fsm_cmd_header_lo.msg_type.cmd = e_bedrock_cmd_data;
    fsm_cmd_header_lo.addr = fsm_rev_header_li.addr;
    fsm_cmd_header_lo.size = fsm_rev_header_li.size;
    fsm_cmd_header_lo.payload.dst_id = fsm_rev_header_li.payload.lce_id;
    fsm_cmd_header_lo.payload.way_id = fsm_rev_header_li.payload.way_id;
    fsm_cmd_header_lo.payload.src_did = fsm_rev_header_li.payload.src_did;
    fsm_cmd_header_lo.payload.src_id = cce_id_i;
    fsm_cmd_header_lo.payload.state = fsm_rev_header_li.payload.state;
    fsm_cmd_data_lo = fsm_rev_data_li;
    fsm_cmd_v_lo = 1'b0;

    // Memory rev defaults
    fsm_rev_yumi_lo = 1'b0;

    // Mem Response auto-processing and forwarding to LCE Command logic
    // The pending bit is written when the LCE Command header sends.
    // The main FSM will stall if it wants to write to the pending bits in the same cycle.
    if (fsm_rev_valid) begin

      // Speculative access response
      // Note: speculative access is only supported for cached read requests
      if (fsm_rev_header_li.payload.speculative && fsm_rev_header_li.msg_type == e_bedrock_mem_rd) begin

        if (spec_bits_lo.spec) begin // speculation not resolved yet
          // do nothing, wait for speculation to be resolved
          // Note: this blocks memory responses behind the speculative response from being
          // forwarded. However, the CCE will not move on to a new LCE request until it
          // resolves the speculation for the current request.
        end // speculative bit sill set

        else if (spec_bits_lo.squash) begin // speculation resolved, squash
          fsm_rev_yumi_lo = fsm_rev_v_li;

        end // squash

        else if (spec_bits_lo.fwd_mod) begin // speculation resolved, forward with modified state
          fsm_cmd_v_lo = fsm_cmd_ready_then_li & fsm_rev_v_li;
          fsm_rev_yumi_lo = fsm_cmd_v_lo;

          // command header
          fsm_cmd_header_lo.msg_type.cmd = e_bedrock_cmd_data;
          // modify the coherence state
          fsm_cmd_header_lo.payload.state = bp_coh_states_e'(spec_bits_lo.state);
        end // fwd_mod

        else begin // speculation resolved, forward unmodified
          fsm_cmd_v_lo = fsm_cmd_ready_then_li & fsm_rev_v_li;
          fsm_rev_yumi_lo = fsm_cmd_v_lo;

          // command header
          fsm_cmd_header_lo.msg_type.cmd = e_bedrock_cmd_data;
        end // forward unmodified

      end // speculative response

      // non-speculative memory access, forward directly to LCE
      else if (fsm_rev_header_li.msg_type == e_bedrock_mem_rd) begin
        fsm_cmd_v_lo = fsm_cmd_ready_then_li & fsm_rev_v_li;
        fsm_rev_yumi_lo = fsm_cmd_v_lo;

        // command header
        fsm_cmd_header_lo.msg_type.cmd = fsm_rev_header_li.payload.uncached ? e_bedrock_cmd_uc_data : e_bedrock_cmd_data;
      end // rd

      // non-speculative store response from memory
      else if (fsm_rev_header_li.msg_type == e_bedrock_mem_wr) begin
        // If the uncached bit is set, this response is to an uncached store
        // and we need to forward an uc_st_done to the LCE.
        // Otherwise, this response came from a writeback and is sunk at the CCE.
        if (fsm_rev_header_li.payload.uncached) begin
          fsm_cmd_v_lo = fsm_cmd_ready_then_li & fsm_rev_v_li;
          fsm_rev_yumi_lo = fsm_cmd_v_lo;

          // command header
          fsm_cmd_header_lo.msg_type.cmd = e_bedrock_cmd_uc_st_done;
        end else begin
          fsm_rev_yumi_lo = fsm_rev_v_li;
        end
      end // wr
    end // mem_rev handling
  end // always_comb

  //synopsys translate_off
  wire spec_resp_v = fsm_rev_v_li & fsm_rev_header_li.payload.speculative;
  always @(negedge clk_i) begin
  if (~reset_i) begin
    assert(~fsm_rev_v_li
           || !(spec_resp_v & !(fsm_rev_header_li.msg_type.rev == e_bedrock_mem_rd))
           ) else
      $error("Speculative memory access not allowed for message type other than read");
    assert(!(~cce_normal_mode & spec_resp_v)) else
      $error("Speculative memory access not allowed in uncached mode");
    end
  end
  //synopsys translate_on

endmodule
