/**
 *
 * Name:
 *   bp_cce_hybrid_mem_resp_pipe.sv
 *
 * Description:
 *   This is the memory response pipeline for the hybrid CCE.
 *   It contains the speculative bits that track outstanding speculative memory accesses.
 *
 *   TODO: re-evaluate buffering requirements with new CCE design
 *   Buffer space is provided for two memory response messages with full cache block of data each.
 *   This is required for the specific implementation of the BedRock coherence protocol to prevent
 *   livelock.
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_hybrid_mem_resp_pipe
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter lce_data_width_p           = dword_width_gp
    , parameter mem_data_width_p           = dword_width_gp
    // provide buffer space for two stream messages with data (for coherence protocol)
    , parameter header_els_p               = 2
    , parameter pending_wbuf_els_p         = 2

    // Derived parameters
    , localparam block_size_in_bytes_lp    = (cce_block_width_p/8)
    , localparam lg_num_lce_lp             = `BSG_SAFE_CLOG2(num_lce_p)
    , localparam lg_num_cce_lp             = `BSG_SAFE_CLOG2(num_cce_p)
    , localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp)
    , localparam lg_lce_assoc_lp           = `BSG_SAFE_CLOG2(lce_assoc_p)
    , localparam lg_lce_sets_lp            = `BSG_SAFE_CLOG2(lce_sets_p)
    , localparam num_way_groups_lp         = `BSG_CDIV(cce_way_groups_p, num_cce_p)
    , localparam lg_num_way_groups_lp      = `BSG_SAFE_CLOG2(num_way_groups_lp)
    , localparam inst_ram_addr_width_lp    = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)
    , localparam cfg_bus_width_lp          = `bp_cfg_bus_width(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)

    // maximal number of tag sets stored in the directory for all LCE types
    , localparam max_tag_sets_lp           = `BSG_CDIV(lce_sets_p, num_cce_p)
    , localparam lg_max_tag_sets_lp        = `BSG_SAFE_CLOG2(max_tag_sets_lp)

    , localparam counter_max_lp            = 256
    , localparam hash_index_width_lp       = $clog2((2**lg_lce_sets_lp+num_cce_p-1)/num_cce_p)

    , localparam counter_width_lp          = `BSG_SAFE_CLOG2(counter_max_lp+1)

    // log2 of dword width bytes
    , localparam lg_dword_width_bytes_lp   = `BSG_SAFE_CLOG2(dword_width_gp/8)

    // interface widths
    `declare_bp_bedrock_lce_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p, cce)
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
   // BedRock Burst protocol: ready&valid
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

   // memory credit return
   , output logic                                   mem_credit_return_o
   );

  // Define structure variables for output queues
  `declare_bp_bedrock_lce_if(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce);
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p, cce);

  `bp_cast_o(bp_bedrock_lce_cmd_header_s, lce_cmd_header);
  `bp_cast_i(bp_bedrock_cce_mem_header_s, mem_resp_header);

  // Memory Response Stream Pump
  bp_bedrock_cce_mem_header_s mem_resp_base_header_li;
  logic mem_resp_v_li, mem_resp_yumi_lo;
  logic mem_resp_stream_new_li, mem_resp_stream_last_li, mem_resp_stream_done_li;
  logic [paddr_width_p-1:0] mem_resp_addr_li;
  logic [mem_data_width_p-1:0] mem_resp_data_li;
  bp_me_stream_pump_in
    #(.bp_params_p(bp_params_p)
      ,.stream_data_width_p(mem_data_width_p)
      ,.block_width_p(cce_block_width_p)
      ,.payload_width_p(cce_mem_payload_width_lp)
      ,.msg_stream_mask_p(mem_resp_payload_mask_gp)
      ,.fsm_stream_mask_p(mem_resp_payload_mask_gp)
      ,.header_els_p(header_els_p)
      )
    mem_resp_stream_pump
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // from memory response input
      ,.msg_header_i(mem_resp_header_cast_i)
      ,.msg_data_i(mem_resp_data_i)
      ,.msg_v_i(mem_resp_v_i)
      ,.msg_last_i(mem_resp_last_i)
      ,.msg_ready_and_o(mem_resp_ready_and_o)
      // to FSM
      ,.fsm_base_header_o(mem_resp_base_header_li)
      ,.fsm_addr_o(mem_resp_addr_li)
      ,.fsm_data_o(mem_resp_data_li)
      ,.fsm_v_o(mem_resp_v_li)
      ,.fsm_ready_and_i(mem_resp_yumi_lo)
      ,.fsm_new_o(mem_resp_stream_new_li)
      ,.fsm_last_o(mem_resp_stream_last_li)
      ,.fsm_done_o(mem_resp_stream_done_li)
      );

  // stream pump logic done signal will be raised when memory response is fully consumed
  // by the FSM logic in this module
  assign mem_credit_return_o = mem_resp_stream_done_li;

  // Speculative memory access management
  bp_cce_spec_s spec_bits_lo;
  bp_cce_spec_bits
    #(.num_way_groups_p(num_way_groups_lp)
      ,.cce_way_groups_p(cce_way_groups_p)
      ,.num_cce_p(num_cce_p)
      ,.paddr_width_p(paddr_width_p)
      ,.addr_offset_p(lg_block_size_in_bytes_lp)
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
       ,.r_v_i(mem_resp_v_li)
       ,.r_addr_i(mem_resp_base_header_li.addr)
       ,.r_addr_bypass_hash_i('0)
       // output
       ,.spec_o(spec_bits_lo)
       );

  // CCE PMA - Mem responses
  logic cacheable_resp_li;
  bp_cce_pma
    #(.bp_params_p(bp_params_p)
      )
    resp_pma
      (.paddr_i(mem_resp_base_header_li.addr)
       ,.paddr_v_i(mem_resp_v_li)
       ,.cacheable_addr_o(cacheable_resp_li)
       );
  wire cce_normal_mode = (cce_mode_i == e_cce_mode_normal);
  wire cacheable_resp = cacheable_resp_li & cce_normal_mode;

  // Pending Bits write buffer
  logic pending_w_v, pending_w_ready_and, pending_w_addr_bypass_hash;
  logic pending_up, pending_down, pending_clear;
  logic [paddr_width_p-1:0] pending_w_addr;

  bsg_fifo_1r1w_small
    #(.width_p(paddr_width_p+4)
      ,.els_p(pending_wbuf_els_p)
      )
    pending_bits_wbuf
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // input - from FSM
      ,.v_i(pending_w_v)
      ,.ready_o(pending_w_ready_and)
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
      ,.clear_i(mem_resp_stream_done_li)
      ,.data_o(pending_w_done)
      );


  // only write pending on last beat, and only for cacheable access in normal mode
  // last beat of cacheable response requires pending write port to be available
  wire not_last_beat_valid = mem_resp_v_li & ~mem_resp_stream_last_li;
  wire last_beat_valid = mem_resp_v_li & mem_resp_stream_last_li
                         & (~cacheable_resp | (cacheable_resp & pending_w_ready_and));
  wire mem_resp_valid = not_last_beat_valid | last_beat_valid;
  // write pending bit if last beat and cacheable access
  assign pending_w_v = mem_resp_v_li & mem_resp_stream_last_li & cacheable_resp & ~pending_w_done;

  typedef enum logic [2:0] {
    e_ready
    ,e_send_data
    ,e_drain_data
  } state_e;
  state_e state_r, state_n;

  always_comb begin
    // state
    state_n = state_r;

    // memory response stream pump
    mem_resp_yumi_lo = '0;

    // LCE command output control and defaults
    lce_cmd_header_cast_o = '0;
    lce_cmd_header_cast_o.addr = mem_resp_base_header_li.addr;
    lce_cmd_header_cast_o.size = mem_resp_base_header_li.size;
    lce_cmd_header_cast_o.subop = mem_resp_base_header_li.subop;
    lce_cmd_header_cast_o.payload.src_id = cce_id_i;
    lce_cmd_header_cast_o.payload.dst_id = mem_resp_base_header_li.payload.lce_id;
    lce_cmd_header_cast_o.payload.way_id = mem_resp_base_header_li.payload.way_id;
    lce_cmd_header_cast_o.payload.state = mem_resp_base_header_li.payload.state;
    lce_cmd_data_o = mem_resp_data_li;
    lce_cmd_last_o = mem_resp_stream_last_li;
    lce_cmd_header_v_o = 1'b0;
    lce_cmd_data_v_o = '0;
    lce_cmd_has_data_o = 1'b0;

    // pending write port
    pending_w_addr = mem_resp_base_header_li.addr;
    pending_w_addr_bypass_hash = 1'b0;
    pending_up = 1'b0;
    // memory responses decrement pending bit
    pending_down = 1'b1;
    pending_clear = 1'b0;

    unique case (state_r)
      e_ready: begin
        unique case (mem_resp_base_header_li.msg_type)
          e_bedrock_mem_rd: begin
            // read responses may be speculative
            unique if (mem_resp_base_header_li.payload.speculative) begin
              if (spec_bits_lo.spec) begin // speculation not resolved yet
                // do nothing, wait for speculation to be resolved
                // Note: this blocks memory responses behind the speculative response from being
                // forwarded. However, the CCE will not move on to a new LCE request until it
                // resolves the speculation for the current request.
              end // speculative bit sill set
              // speculation resolved
              else begin
                // speculation resolved, squash
                if (spec_bits_lo.squash) begin
                  // ack beat - mem_resp_valid examines pending_w_ready_and if last beat
                  mem_resp_yumi_lo = mem_resp_valid;
                  // if first beat is not last, drain remaining beats
                  state_n = (mem_resp_yumi_lo & ~mem_resp_stream_last_li)
                            ? e_drain_data
                            : e_ready;
                end // squash

                // speculation resolved, forward with modified state
                else if (spec_bits_lo.fwd_mod) begin
                  // forward the header this cycle
                  // forward data next cycle(s)
                  // send LCE command header, but don't ack the mem response beat since its data
                  // will send after the header sends.
                  lce_cmd_header_v_o = mem_resp_valid;
                  lce_cmd_has_data_o = 1'b1;
                  // command header
                  lce_cmd_header_cast_o.msg_type = e_bedrock_cmd_data;
                  lce_cmd_header_cast_o.payload.state = bp_coh_states_e'(spec_bits_lo.state);
                  // send data next cycle, after header sends
                  state_n = (lce_cmd_header_v_o & lce_cmd_header_ready_and_i)
                            ? e_send_data
                            : e_ready;
                end // fwd_mod

                // speculation resolved, forward unmodified
                else begin
                  // forward the header this cycle
                  // forward data next cycle(s)
                  // send LCE command header, but don't ack the mem response beat since its data
                  // will send after the header sends.
                  lce_cmd_header_v_o = mem_resp_valid;
                  lce_cmd_has_data_o = 1'b1;
                  // command header
                  lce_cmd_header_cast_o.msg_type = e_bedrock_cmd_data;
                  // send data next cycle, after header sends
                  state_n = (lce_cmd_header_v_o & lce_cmd_header_ready_and_i)
                            ? e_send_data
                            : e_ready;
                end // forward unmodified
              end // speculation resolved
            end // speculative read response
            // non-speculative read response
            else begin
              // forward the header this cycle and data next cycle(s)
              // dequeue first mem_resp beat with first data beat
              lce_cmd_header_v_o = mem_resp_valid;
              lce_cmd_has_data_o = 1'b1;
              lce_cmd_header_cast_o.msg_type = e_bedrock_cmd_data;
              // send data next cycle, after header sends
              state_n = (lce_cmd_header_v_o & lce_cmd_header_ready_and_i)
                        ? e_send_data
                        : e_ready;
            end // non-speculative read response
          end // e_bedrock_mem_rd
          e_bedrock_mem_wr: begin
            // writeback - dequeue single beat and write pending bit
            mem_resp_yumi_lo = mem_resp_valid;
          end
          e_bedrock_mem_uc_rd: begin
            // forward the header this cycle and data next cycle(s)
            // dequeue first mem_resp beat with first data beat
            lce_cmd_header_v_o = mem_resp_valid;
            lce_cmd_has_data_o = 1'b1;
            lce_cmd_header_cast_o.msg_type = mem_resp_base_header_li.payload.uncached
                                         ? e_bedrock_cmd_uc_data
                                         : e_bedrock_cmd_data;
            // send data next cycle, after header sends
            state_n = (lce_cmd_header_v_o & lce_cmd_header_ready_and_i)
                      ? e_send_data
                      : e_ready;
          end
          // Uncached Store response - send UC Store Done to LCE
          e_bedrock_mem_uc_wr: begin
            // UC Store Done is header only
            lce_cmd_header_v_o = mem_resp_valid;
            lce_cmd_header_cast_o.msg_type = e_bedrock_cmd_uc_st_done;
            lce_cmd_header_cast_o.size = e_bedrock_msg_size_1;
            // dequeue memory response when LCE command header sends
            mem_resp_yumi_lo = mem_resp_valid & lce_cmd_header_ready_and_i;
          end
          e_bedrock_mem_amo: begin
            // TODO: support atomics
          end
          default: begin
            // do nothing
          end
        endcase
      end // e_ready
      e_send_data: begin
        // send data
        lce_cmd_data_v_o = mem_resp_valid;
        lce_cmd_last_o = mem_resp_stream_last_li;
        // consume beat when data sends on LCE command
        mem_resp_yumi_lo = mem_resp_valid & lce_cmd_data_v_o & lce_cmd_data_ready_and_i;
        state_n = (mem_resp_stream_done_li)
                  ? e_ready
                  : e_send_data;
      end
      e_drain_data: begin
        // when a speculative read is squashed, its data must be drained
        mem_resp_yumi_lo = mem_resp_valid;
        state_n = (mem_resp_stream_done_li)
                  ? e_ready
                  : e_drain_data;
      end
      default: begin
        // do nothing
      end
    endcase // memory response auto forwarding
  end // always_comb

  // Sequential Logic
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      state_r <= e_ready;
    end else begin
      state_r <= state_n;
    end
  end

  //synopsys translate_off
  wire spec_resp_v = mem_resp_v_li & mem_resp_base_header_li.payload.speculative;
  always @(negedge clk_i) begin
  if (~reset_i) begin
    assert(~mem_resp_v_li
           || !(spec_resp_v & !(mem_resp_base_header_li.msg_type.mem == e_bedrock_mem_rd))
           ) else
      $error("Speculative memory access not allowed for message type other than read");
    assert(!(~cce_normal_mode & spec_resp_v)) else
      $error("Speculative memory access not allowed in uncached mode");
    end
  end
  //synopsys translate_on

endmodule
