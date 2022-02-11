/**
 *  Name:
 *    bp_lce_fill.sv
 *
 *  Description:
 *    LCE fill handler
 *
 *    The LCE Fill module process arriving Fill commands and sends coherence ack responses.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_lce_fill
  import bp_common_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

    // parameters specific to this LCE
    , parameter `BSG_INV_PARAM(assoc_p)
    , parameter `BSG_INV_PARAM(sets_p)
    , parameter `BSG_INV_PARAM(block_width_p)
    , parameter fill_width_p = block_width_p
    , parameter data_mem_invert_clk_p = 0
    , parameter tag_mem_invert_clk_p = 0

    , parameter timeout_max_limit_p=4

    , localparam block_size_in_bytes_lp = (block_width_p/8)
    , localparam lg_assoc_lp = `BSG_SAFE_CLOG2(assoc_p)
    , localparam lg_sets_lp = `BSG_SAFE_CLOG2(sets_p)
    , localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp)

   `declare_bp_bedrock_lce_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p)
   `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, cache)

    // width for counter used during initiliazation and for sync messages
    , localparam cnt_width_lp = `BSG_MAX(cce_id_width_p+1, `BSG_SAFE_CLOG2(sets_p)+1)
    , localparam cnt_max_val_lp = ((2**cnt_width_lp)-1)

    // coherence request size for cached requests
    // block size smaller than 8-bytes not supported
    , localparam bp_bedrock_msg_size_e cmd_block_size_lp =
      (block_size_in_bytes_lp == 128)
      ? e_bedrock_msg_size_128
      : (block_size_in_bytes_lp == 64)
        ? e_bedrock_msg_size_64
        : (block_size_in_bytes_lp == 32)
          ? e_bedrock_msg_size_32
          : (block_size_in_bytes_lp == 16)
            ? e_bedrock_msg_size_16
            : e_bedrock_msg_size_8

    , localparam block_size_in_fill_lp = block_width_p/fill_width_p
  )
  (
    input                                            clk_i
    , input                                          reset_i

    // LCE Configuration
    , input [lce_id_width_p-1:0]                     lce_id_i

    , output logic                                   ready_o

    // LCE-Cache Interface
    // valid->yumi
    // commands issued that read and return data have data returned the cycle after
    // the valid->yumi command handshake occurs
    , output logic                                   tag_mem_pkt_v_o
    , output logic [cache_tag_mem_pkt_width_lp-1:0]  tag_mem_pkt_o
    , input                                          tag_mem_pkt_yumi_i

    , output logic                                   data_mem_pkt_v_o
    , output logic [cache_data_mem_pkt_width_lp-1:0] data_mem_pkt_o
    , input                                          data_mem_pkt_yumi_i

    // request complete signals
    // cached requests and uncached loads block in the caches, but uncached stores do not
    // cache_req_complete_o is routed to the cache to indicate a blocking request is complete
    , output logic                                   cache_req_critical_tag_o
    , output logic                                   cache_req_critical_data_o
    , output logic                                   cache_req_complete_o

    // CCE-LCE interface
    // fill_i: valid->yumi
    , input [lce_fill_header_width_lp-1:0]           lce_fill_header_i
    , input [cce_block_width_p-1:0]                  lce_fill_data_i
    , input                                          lce_fill_v_i
    , output logic                                   lce_fill_yumi_o

    // LCE-CCE interface
    // Resp: ready->valid
    , output logic [lce_resp_header_width_lp-1:0]    lce_resp_header_o
    , output logic                                   lce_resp_v_o
    , input                                          lce_resp_ready_then_i
    );

  `declare_bp_bedrock_lce_if(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p);
  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, cache);
  `bp_cast_i(bp_bedrock_lce_fill_header_s, lce_fill_header);
  `bp_cast_o(bp_bedrock_lce_resp_header_s, lce_resp_header);

  `bp_cast_o(bp_cache_data_mem_pkt_s, data_mem_pkt);
  `bp_cast_o(bp_cache_tag_mem_pkt_s, tag_mem_pkt);

  // FSM states
  enum logic [1:0] {
    e_reset
    ,e_ready
    ,e_coh_ack
  } state_n, state_r;

  // common fields from LCE Fill used in many states for responses or pkt fields
  logic [lg_sets_lp-1:0] lce_fill_addr_index;
  logic [ptag_width_p-1:0] lce_fill_addr_tag;
  logic [lg_assoc_lp-1:0] lce_fill_way_id;

  assign lce_fill_addr_index = lce_fill_header_cast_i.addr[lg_block_size_in_bytes_lp+:lg_sets_lp];
  assign lce_fill_addr_tag = lce_fill_header_cast_i.addr[(paddr_width_p-1) -: ptag_width_p];
  assign lce_fill_way_id = lce_fill_header_cast_i.payload.way_id[0+:lg_assoc_lp];

  // LCE Fill module is ready after reset lowers
  assign ready_o = (state_r != e_reset);

  always_comb begin

    state_n = state_r;

    cache_req_complete_o = 1'b0;
    cache_req_critical_tag_o = 1'b0;
    cache_req_critical_data_o = 1'b0;

    // LCE-CCE Interface signals
    lce_fill_yumi_o = 1'b0;

    lce_resp_header_cast_o = '0;
    lce_resp_v_o = 1'b0;

    // LCE-Cache Interface signals
    data_mem_pkt_cast_o = '0;
    data_mem_pkt_v_o = 1'b0;
    tag_mem_pkt_cast_o = '0;
    tag_mem_pkt_v_o = 1'b0;

    unique case (state_r)

      e_reset: begin
        state_n = e_ready;
      end

      // Ready for LCE Commands
      // A command is dequeued when the command module finishes processing the command.
      e_ready: begin
        if (lce_fill_v_i) begin
          unique case (lce_fill_header_cast_i.msg_type.fill)

            // Data and Tag - completes cache miss
            // Set Tag and State, write Data
            e_bedrock_fill_data: begin
              data_mem_pkt_cast_o.index = lce_fill_addr_index;
              data_mem_pkt_cast_o.way_id = lce_fill_way_id;
              data_mem_pkt_cast_o.data = lce_fill_data_i;
              data_mem_pkt_cast_o.fill_index = {block_size_in_fill_lp{1'b1}};
              data_mem_pkt_cast_o.opcode = e_cache_data_mem_write;
              data_mem_pkt_v_o = lce_fill_v_i;

              tag_mem_pkt_cast_o.index = lce_fill_addr_index;
              tag_mem_pkt_cast_o.way_id = lce_fill_way_id;
              tag_mem_pkt_cast_o.state = lce_fill_header_cast_i.payload.state;
              tag_mem_pkt_cast_o.tag = lce_fill_addr_tag;
              tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_tag;
              tag_mem_pkt_v_o = lce_fill_v_i;

              cache_req_critical_tag_o = tag_mem_pkt_yumi_i;
              cache_req_critical_data_o = data_mem_pkt_yumi_i;

              // send coherence ack after updating tag and data memories
              state_n = (tag_mem_pkt_yumi_i & data_mem_pkt_yumi_i)
                        ? e_coh_ack
                        : e_ready;

            end

            // for other message types in this state, use default as defined at top.
            default: begin
              state_n = e_ready;
            end

          endcase // fill.msg_type case
        end // lce_fill_v
      end // e_ready

      // Send Coherence Ack message and raise request complete for one cycle
      e_coh_ack: begin
        lce_resp_header_cast_o.addr = lce_fill_header_cast_i.addr;
        lce_resp_header_cast_o.msg_type.resp = e_bedrock_resp_coh_ack;
        lce_resp_header_cast_o.payload.src_id = lce_id_i;
        lce_resp_header_cast_o.payload.dst_id = lce_fill_header_cast_i.payload.src_id;
        lce_resp_v_o = lce_fill_v_i & lce_resp_ready_then_i;

        lce_fill_yumi_o = lce_resp_v_o;

        cache_req_complete_o = lce_fill_yumi_o;

        state_n = lce_fill_yumi_o
          ? e_ready
          : e_coh_ack;

      end

      // we should never get in this state, but if we do, return to reset
      default: begin
        state_n = e_reset;
      end
    endcase // state
  end

  //synopsys sync_set_reset "reset_i"
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      state_r <= e_reset;
    end
    else begin
      state_r <= state_n;
    end
  end

endmodule

`BSG_ABSTRACT_MODULE(bp_lce_fill)
