/*
 * bp_me_cce_to_cache.v
 *
 */
 
module bp_me_cce_to_cache

  import bp_cce_pkg::*;
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_me_pkg::*;
  import bsg_cache_pkg::*;

  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)

    , parameter cache_data_width_p = dword_width_p

    , parameter block_size_in_words_lp=cce_block_width_p/dword_width_p
    , parameter lg_sets_lp=`BSG_SAFE_CLOG2(l2_sets_p)
    , parameter lg_ways_lp=`BSG_SAFE_CLOG2(l2_assoc_p)
    , parameter word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)
    , parameter data_mask_width_lp=(dword_width_p>>3)
    , parameter byte_offset_width_lp=`BSG_SAFE_CLOG2(dword_width_p>>3)
    , parameter block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
    
    , parameter bsg_cache_pkt_width_lp=`bsg_cache_pkt_width(paddr_width_p,dword_width_p)
    , parameter counter_width_lp=`BSG_SAFE_CLOG2(cce_block_width_p/dword_width_p)

    , localparam stream_words_lp = cce_block_width_p/cache_data_width_p
    , localparam data_len_width_lp = `BSG_SAFE_CLOG2(stream_words_lp)
    , localparam stream_offset_width_lp = `BSG_SAFE_CLOG2(cache_data_width_p / 8)
  )
  (
    input clk_i
    , input reset_i

    // Stream interface
    , input  [cce_mem_msg_header_width_lp-1:0] mem_cmd_header_i
    , input  [cache_data_width_p-1:0]          mem_cmd_data_i
    , input                                    mem_cmd_v_i
    , output logic                             mem_cmd_ready_o
    , input                                    mem_cmd_last_i

    , output [cce_mem_msg_header_width_lp-1:0] mem_resp_header_o
    , output [cache_data_width_p-1:0]          mem_resp_data_o
    , output logic                             mem_resp_v_o
    , input                                    mem_resp_yumi_i
    , output logic                             mem_resp_last_o

    // cache-side
    , output [bsg_cache_pkt_width_lp-1:0]            cache_pkt_o
    , output logic                                   cache_pkt_v_o
    , input                                          cache_pkt_ready_i

    , input [cache_data_width_p-1:0]                 cache_data_i
    , input                                          cache_v_i
    , output logic                                   cache_yumi_o
  );

  // at the reset, this module intializes all the tags and valid bits to zero.
  // After all the tags are completedly initialized, this module starts
  // accepting packets from manycore network.
  `declare_bsg_cache_pkt_s(paddr_width_p, dword_width_p);
  
  // cce logics
  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce);

  bsg_cache_pkt_s cache_pkt;
  assign cache_pkt_o = cache_pkt;

  enum logic [1:0] {e_cmd_reset, e_cmd_clear, e_cmd_ready, e_cmd_stream} cmd_state_n, cmd_state_r;

  wire is_reset  = (cmd_state_r == e_cmd_reset);
  wire is_clear  = (cmd_state_r == e_cmd_clear);
  wire is_ready  = (cmd_state_r == e_cmd_ready);
  wire is_stream = (cmd_state_r == e_cmd_stream);

  logic [lg_sets_lp+lg_ways_lp:0] tagst_sent_r, tagst_sent_n;
  logic [lg_sets_lp+lg_ways_lp:0] tagst_recv_r, tagst_recv_n;
  logic [paddr_width_p-1:0] cmd_addr_r, cmd_addr_n;

  bp_bedrock_cce_mem_msg_header_s mem_cmd_header_lo;
  logic [cache_data_width_p-1:0] mem_cmd_data_lo;
  logic mem_cmd_v_lo, mem_cmd_yumi_li;
  logic mem_cmd_stream_new_lo, mem_cmd_done_lo;
  logic [data_len_width_lp-1:0] mem_resp_cnt_lo;
  logic [paddr_width_p-1:0] mem_cmd_stream_addr_lo;
  bp_stream_pump_in
   #(.bp_params_p(bp_params_p)
   ,.stream_data_width_p(dword_width_p)
   ,.block_width_p(cce_block_width_p)
   ,.payload_mask_p(mem_cmd_payload_mask_gp))
   cce_to_cache_pump_in
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.mem_header_i(mem_cmd_header_i)
    ,.mem_data_i(mem_cmd_data_i)
    ,.mem_v_i(mem_cmd_v_i)
    ,.mem_last_i(mem_cmd_last_i)
    ,.mem_ready_and_o(mem_cmd_ready_o)

    ,.fsm_base_header_o(mem_cmd_header_lo)
    ,.fsm_addr_o(mem_cmd_stream_addr_lo)
    ,.fsm_data_o(mem_cmd_data_lo)
    ,.fsm_v_o(mem_cmd_v_lo)
    ,.fsm_ready_and_i(mem_cmd_yumi_li)

    ,.stream_new_o(mem_cmd_stream_new_lo)
    ,.stream_done_o(mem_cmd_done_lo)
    );

  wire is_read  = mem_cmd_header_lo.msg_type inside {e_bedrock_mem_uc_rd, e_bedrock_mem_rd};
  wire is_write = mem_cmd_header_lo.msg_type inside {e_bedrock_mem_uc_wr, e_bedrock_mem_wr};
  wire is_csr   = (mem_cmd_header_lo.addr < dram_base_addr_gp);
  wire is_tagfl = is_csr & ((mem_cmd_header_lo.addr[0+:20] == cache_tagfl_base_addr_gp));
  wire [paddr_width_p-1:0] tagfl_addr = {mem_cmd_data_lo[0+:lg_sets_lp+lg_ways_lp], block_offset_width_lp'(0)};

  bp_bedrock_cce_mem_msg_header_s mem_resp_header_li, mem_resp_header_lo;
  logic mem_resp_v_li, mem_resp_ready_lo;
  logic mem_resp_v_lo, mem_resp_yumi_lo; 
  logic mem_resp_done_lo;
  bsg_fifo_1r1w_small
   #(.width_p($bits(bp_bedrock_cce_mem_msg_header_s)), .els_p(4))
   stream_fifo
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.data_i({mem_resp_header_li})
    ,.v_i(mem_resp_v_li)
    ,.ready_o(mem_resp_ready_lo)

    ,.data_o({mem_resp_header_lo})
    ,.v_o(mem_resp_v_lo)
    ,.yumi_i(mem_resp_done_lo)
    );

  bp_stream_pump_out
   #(.bp_params_p(bp_params_p)
   ,.stream_data_width_p(dword_width_p)
   ,.block_width_p(cce_block_width_p)
   ,.payload_mask_p(mem_resp_payload_mask_gp))
   cce_to_cache_pump_out
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.mem_header_o(mem_resp_header_o)
    ,.mem_data_o(mem_resp_data_o)
    ,.mem_v_o(mem_resp_v_o)
    ,.mem_last_o(mem_resp_last_o)
    ,.mem_ready_and_i(mem_resp_yumi_i)
    
    ,.fsm_base_header_i(mem_resp_header_lo)
    ,.fsm_data_i(cache_data_i)
    ,.fsm_v_i(mem_resp_v_lo & cache_v_i)
    ,.fsm_ready_and_o(mem_resp_yumi_lo)

    ,.stream_cnt_o(mem_resp_cnt_lo)
    ,.stream_done_o(mem_resp_done_lo)
    );
  assign cache_yumi_o = mem_resp_yumi_lo | (is_clear & cache_v_i);
  
  //   At the reset, this module intializes all the tags and valid bits to zero.
  //   After all the tags are completedly initialized, this module starts
  //   accepting incoming commands
  always_comb
    begin
      cache_pkt     = '0;
      cache_pkt_v_o = 1'b0;
     
      mem_cmd_yumi_li = 1'b0;

      mem_resp_header_li = '0;
      mem_resp_v_li      = 1'b0;

      tagst_sent_n = tagst_sent_r;
      tagst_recv_n = tagst_recv_r;

      cmd_state_n  = cmd_state_r;

      case (cmd_state_r)
        e_cmd_reset: begin cmd_state_n = e_cmd_clear; end
        e_cmd_clear:
          begin
            cache_pkt.opcode = TAGST;
            cache_pkt.data = '0;
            cache_pkt.addr = {
              {(paddr_width_p-lg_sets_lp-lg_ways_lp-block_offset_width_lp){1'b0}},
              tagst_sent_r[0+:lg_sets_lp+lg_ways_lp],
              {(block_offset_width_lp){1'b0}}
            };
            cache_pkt.mask = '1;

            cache_pkt_v_o = cache_pkt_ready_i & (tagst_sent_r != (l2_assoc_p*l2_sets_p));
            tagst_sent_n = tagst_sent_r + cache_pkt_v_o;
            tagst_recv_n = tagst_recv_r + cache_yumi_o;
            cmd_state_n = (tagst_recv_r == l2_assoc_p*l2_sets_p) ? e_cmd_ready : e_cmd_clear;
          end 
        e_cmd_ready:
          begin
            casez ({is_tagfl, mem_cmd_header_lo.size})
              {1'b1, 3'b???              }: cache_pkt.opcode = TAGFL;
              {1'b0, e_bedrock_msg_size_1}: cache_pkt.opcode = is_read ? LB : SB;
              {1'b0, e_bedrock_msg_size_2}: cache_pkt.opcode = is_read ? LH : SH;
              {1'b0, e_bedrock_msg_size_4}: cache_pkt.opcode = is_read ? LW : SW;
              {1'b0, 3'b???              }: cache_pkt.opcode = is_read ? LM : SM; // or LD : SD?
              default: cache_pkt.opcode = TAGFL;
            endcase

            cache_pkt.addr = is_tagfl ? tagfl_addr : mem_cmd_header_lo.addr;
            cache_pkt.data = mem_cmd_data_lo;
            // This mask is only used for the LM/SM operations for >64 bit mask operations
            cache_pkt.mask = '1;
            cache_pkt_v_o  = cache_pkt_ready_i & mem_cmd_v_lo;
            // send yumi signal back to pump_out
            mem_cmd_yumi_li = cache_pkt_v_o;

            mem_resp_header_li = mem_cmd_header_lo; // return the same critical addr back to stream_fifo
            mem_resp_v_li      = cache_pkt_v_o;

            cmd_state_n = (mem_cmd_stream_new_lo & mem_cmd_yumi_li) ? e_cmd_stream : e_cmd_ready;
          end
        e_cmd_stream:
          begin
            cache_pkt.opcode = is_read ? LM : SM; // or LD : SD?
            cache_pkt.addr = mem_cmd_stream_addr_lo;
            cache_pkt.mask = '1;
            cache_pkt.data = mem_cmd_data_lo;
            cache_pkt_v_o = cache_pkt_ready_i;
            // send yumi signal back to pump_out
            mem_cmd_yumi_li = cache_pkt_v_o;

            // Transition back to ready once we've completely sent out the stream
            cmd_state_n = mem_cmd_done_lo ? e_cmd_ready : e_cmd_stream;
          end
        default: begin end
      endcase
    end

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      begin
        cmd_state_r      <= e_cmd_reset;
        tagst_sent_r     <= '0;
        tagst_recv_r     <= '0;
      end
    else
      begin
        cmd_state_r      <= cmd_state_n;
        tagst_sent_r     <= tagst_sent_n;
        tagst_recv_r     <= tagst_recv_n;
      end


endmodule

