/*
 * Name:
 *   bp_me_cce_to_cache.sv
 *
 * Description:
 *   This module converts an arriving BedRock Stream message into a bsg_cache message, and
 *   converts bsg_cache responses to outgoing BedRock Stream messages.
 *
 *   After reset lowers, this module initializes all of the connected cache's tags and valid bits
 *   by clearing them and making all lines invalid.
 *
 *   The data width is l2_data_width_p on both the BedRock Stream and cache interfaces.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"
`include "bsg_cache.vh"

module bp_me_cce_to_cache
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 import bsg_cache_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

   // L2 organization and interface
   , localparam cache_pkt_width_lp = `bsg_cache_pkt_width(daddr_width_p, l2_data_width_p)
   )
  (input                                                   clk_i
   , input                                                 reset_i

   // BedRock Stream interface
   , input [mem_fwd_header_width_lp-1:0]                   mem_fwd_header_i
   , input [l2_data_width_p-1:0]                           mem_fwd_data_i
   , input                                                 mem_fwd_v_i
   , output logic                                          mem_fwd_ready_and_o
   , input                                                 mem_fwd_last_i

   , output logic [mem_rev_header_width_lp-1:0]            mem_rev_header_o
   , output logic [l2_data_width_p-1:0]                    mem_rev_data_o
   , output logic                                          mem_rev_v_o
   , input                                                 mem_rev_ready_and_i
   , output logic                                          mem_rev_last_o

   // cache-side
   , output logic [l2_banks_p-1:0][cache_pkt_width_lp-1:0] cache_pkt_o
   , output logic [l2_banks_p-1:0]                         cache_pkt_v_o
   , input [l2_banks_p-1:0]                                cache_pkt_ready_and_i

   , input [l2_banks_p-1:0][l2_data_width_p-1:0]           cache_data_i
   , input [l2_banks_p-1:0]                                cache_data_v_i
   , output logic [l2_banks_p-1:0]                         cache_data_yumi_o
   );

  // L2 derived params
  localparam l2_blocks_lp              = (l2_banks_p*l2_assoc_p*l2_sets_p);
  localparam lg_l2_banks_lp            = `BSG_SAFE_CLOG2(l2_banks_p);
  localparam lg_l2_sets_lp             = `BSG_SAFE_CLOG2(l2_sets_p);
  localparam lg_l2_assoc_lp            = `BSG_SAFE_CLOG2(l2_assoc_p);
  localparam lg_l2_blocks_lp           = `BSG_SAFE_CLOG2(l2_blocks_lp);
  localparam l2_block_offset_width_lp  = `BSG_SAFE_CLOG2(l2_block_width_p/8);
  localparam data_bytes_lp             = (l2_data_width_p/8);
  localparam data_byte_offset_width_lp = `BSG_SAFE_CLOG2(data_bytes_lp);

  `declare_bsg_cache_pkt_s(daddr_width_p, l2_data_width_p);
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_memory_map(paddr_width_p, daddr_width_p);

  bsg_cache_pkt_s cache_pkt;
  assign cache_pkt_o = {l2_banks_p{cache_pkt}};

  enum logic [1:0] {e_reset, e_clear_tag, e_ready} state_n, state_r;
  wire is_reset  = (state_r == e_reset);
  wire is_clear  = (state_r == e_clear_tag);
  wire is_ready  = (state_r == e_ready);

  logic [lg_l2_blocks_lp:0] tagst_sent_r, tagst_sent_n;
  logic [lg_l2_blocks_lp:0] tagst_received_r, tagst_received_n;

  bp_bedrock_mem_fwd_header_s fsm_fwd_header_li;
  logic [l2_data_width_p-1:0] fsm_fwd_data_li;
  logic fsm_fwd_v_li, fsm_fwd_yumi_lo;
  logic fsm_fwd_new_li, fsm_fwd_last_li;
  logic [paddr_width_p-1:0] fsm_fwd_stream_addr_li;
  bp_me_stream_pump_in
   #(.bp_params_p(bp_params_p)
     ,.stream_data_width_p(l2_data_width_p)
     ,.block_width_p(cce_block_width_p)
     ,.payload_width_p(mem_fwd_payload_width_lp)
     ,.msg_stream_mask_p(mem_fwd_payload_mask_gp)
     ,.fsm_stream_mask_p(mem_fwd_payload_mask_gp | mem_rev_payload_mask_gp)
     ,.header_els_p(2)
     ,.data_els_p(`BSG_MAX(2, cce_block_width_p/l2_data_width_p))
     )
   fwd_pump_in
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(mem_fwd_header_i)
     ,.msg_data_i(mem_fwd_data_i)
     ,.msg_v_i(mem_fwd_v_i)
     ,.msg_last_i(mem_fwd_last_i)
     ,.msg_ready_and_o(mem_fwd_ready_and_o)

     ,.fsm_header_o(fsm_fwd_header_li)
     ,.fsm_addr_o(fsm_fwd_stream_addr_li)
     ,.fsm_data_o(fsm_fwd_data_li)
     ,.fsm_v_o(fsm_fwd_v_li)
     ,.fsm_yumi_i(fsm_fwd_yumi_lo)
     ,.fsm_cnt_o()
     ,.fsm_new_o(fsm_fwd_new_li)
     ,.fsm_last_o(fsm_fwd_last_li)
     );

  bp_local_addr_s local_addr_cast;
  assign local_addr_cast = fsm_fwd_header_li.addr;

  wire is_word_op = (fsm_fwd_header_li.size == e_bedrock_msg_size_4);
  wire is_csr     = (fsm_fwd_header_li.addr < dram_base_addr_gp);
  wire is_tagfl   = is_csr && (local_addr_cast.addr == cache_tagfl_addr_gp);
  wire [daddr_width_p-1:0] tagfl_addr = fsm_fwd_data_li[0+:lg_l2_sets_lp+lg_l2_assoc_lp] << l2_block_offset_width_lp;

  // cache packet data and mask mux elements
  // each mux has one element per power of 2 in [1, N] where N is log2(L2 data width bytes)
  // e.g.: 64-bit data width = 8B = 2^3 -> 4 muxes for 1B, 2B, 4B, 8B
  // e.g.: 128-bit data width = 16B = 2^4 -> 5 muxes for 1B, 2B, 4B, 8B, 16B
  // e.g.: 256-bit data width = 32B = 2^5 -> 6 muxes for 1B, 2B, 4B, 8B, 16B, 32B
  // e.g.: 512-bit data width = 64B = 2^6 -> 7 muxes for 1B, 2B, 4B, 8B, 16B, 32B, 64B
  // e.g.: 1024-bit data width = 128B = 2^7 -> 8 muxes for 1B, 2B, 4B, 8B, 16B, 32B, 64B, 128B
  localparam mux_els_lp = data_byte_offset_width_lp+1;
  localparam lg_mux_els_lp = `BSG_SAFE_CLOG2(mux_els_lp);
  logic [mux_els_lp-1:0][data_bytes_lp-1:0] cache_pkt_mask_mux_li;
  logic [daddr_width_p-1:0] cache_pkt_addr_lo;
  logic [lg_l2_banks_lp-1:0] cache_fwd_bank_lo;

  for (genvar i = 0; i < mux_els_lp; i++)
    begin : cache_pkt_sel
      // width of slice, in bits
      // smallest granularity is 1 byte = 8 bits
      localparam slice_width_bytes_lp = (2**i);
      localparam slice_width_lp = (slice_width_bytes_lp << 3);
      // number of slice_width_lp parts that comprise in/out data
      localparam num_slices_lp = (l2_data_width_p/slice_width_lp);
      localparam lg_num_slices_lp = `BSG_SAFE_CLOG2(num_slices_lp);

      // Mask
      if (i == mux_els_lp-1)
        begin: max_size
          assign cache_pkt_mask_mux_li[i] = {data_bytes_lp{1'b1}};
        end
      else
        begin: non_max_size

          // determine which slice being used based on the mem_fwd address
          // i = 0, slices are 1B wide
          // i = 1, slices are 2B wide
          // i = 2, slices are 4B wide
          // etc.
          wire [lg_num_slices_lp-1:0] slice_index = cache_pkt_addr_lo[i+:lg_num_slices_lp];
          // one-hot decoded slice index - bit n is set when targeting slice n
          wire [num_slices_lp-1:0] decoded_slice_index = (1'b1 << slice_index);

          // expand the one-hot decoded slice index into a bit-mask for the cache packet
          bsg_expand_bitmask
           #(.in_width_p(num_slices_lp)
             ,.expand_p(slice_width_bytes_lp))
           mask_expand
            (.i(decoded_slice_index)
            ,.o(cache_pkt_mask_mux_li[i])
          );
        end
    end

  // cache mask has one entry per byte in l2_data_width_p
  logic [data_bytes_lp-1:0] cache_pkt_mask_lo;

  // mem_fwd size field is 3-bits
  // There will always be between 4 and 8 muxes, since l2_data_width_p must be between 64 and
  // 512 bits, thus mux select bits will always be 2 or 3.
  // If mem_fwd size is larger than data channel width, select the full mask and data, else
  // use the size field to pick correct slice of data and its mask.
  wire [lg_mux_els_lp-1:0] cache_pkt_sel_li = (1'b1 << fsm_fwd_header_li.size) > data_bytes_lp
                                              ? lg_mux_els_lp'(mux_els_lp-1)
                                              : fsm_fwd_header_li.size[0+:lg_mux_els_lp];
  bsg_mux
   #(.width_p(data_bytes_lp), .els_p(mux_els_lp)) 
   cache_pkt_mask_mux
    (.data_i(cache_pkt_mask_mux_li)
     ,.sel_i(cache_pkt_sel_li)
     ,.data_o(cache_pkt_mask_lo)
     );

  // Swizzle address bits for L2 cache command
  bp_me_dram_hash_encode
   #(.bp_params_p(bp_params_p))
   fsm_fwd_hash
    (.daddr_i(fsm_fwd_stream_addr_li[0+:daddr_width_p])
     ,.daddr_o(cache_pkt_addr_lo)
     ,.bank_o(cache_fwd_bank_lo)
     );

  bp_bedrock_mem_rev_header_s fsm_rev_header_lo;
  logic [l2_data_width_p-1:0] fsm_rev_data_lo;
  logic [lg_l2_banks_lp-1:0] cache_rev_bank_lo;
  logic stream_header_v_lo, fsm_rev_ready_and_li, fsm_rev_v_lo;
  logic fsm_rev_last_lo;
  logic stream_fifo_ready_lo;
  bsg_fifo_1r1w_small
   #(.width_p(lg_l2_banks_lp+$bits(bp_bedrock_mem_fwd_header_s))
     ,.els_p(l2_outstanding_reqs_p)
     ,.ready_THEN_valid_p(1)
     )
   stream_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({cache_fwd_bank_lo, fsm_fwd_header_li})
     ,.v_i(fsm_fwd_yumi_lo & fsm_fwd_new_li)
     ,.ready_o(stream_fifo_ready_lo)

     ,.data_o({cache_rev_bank_lo, fsm_rev_header_lo})
     ,.v_o(stream_header_v_lo)
     ,.yumi_i(fsm_rev_ready_and_li & fsm_rev_v_lo & fsm_rev_last_lo)
     );

  bp_me_stream_pump_out
   #(.bp_params_p(bp_params_p)
     ,.stream_data_width_p(l2_data_width_p)
     ,.block_width_p(cce_block_width_p)
     ,.payload_width_p(mem_rev_payload_width_lp)
     ,.msg_stream_mask_p(mem_rev_payload_mask_gp)
     ,.fsm_stream_mask_p(mem_fwd_payload_mask_gp | mem_rev_payload_mask_gp)
     )
   rev_pump_out
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_o(mem_rev_header_o)
     ,.msg_data_o(mem_rev_data_o)
     ,.msg_v_o(mem_rev_v_o)
     ,.msg_last_o(mem_rev_last_o)
     ,.msg_ready_and_i(mem_rev_ready_and_i)

     ,.fsm_header_i(fsm_rev_header_lo)
     ,.fsm_data_i(fsm_rev_data_lo)
     ,.fsm_addr_o()
     ,.fsm_v_i(fsm_rev_v_lo)
     ,.fsm_ready_and_o(fsm_rev_ready_and_li)
     ,.fsm_cnt_o(/* unused */)
     ,.fsm_new_o(/* unused */)
     ,.fsm_last_o(fsm_rev_last_lo)
     );

  // mem_rev data selection
  // For B/H/W/D ops, data returned from cache is at the LSB, but it may not for M ops
  // on bsg_bus_pack:
  // sel_i = which unit (byte) to start selection at from cache_data_i
  // size_i = log2(size in bytes) of selection to make
  // bus pack has log2(l2_data_width_p/8) = log2(l2 data width bytes) mux elements
  //   == data_byte_offset_width_lp
  localparam bus_pack_size_width_lp = `BSG_WIDTH(data_byte_offset_width_lp);
  logic [bus_pack_size_width_lp-1:0] fsm_rev_size_li;
  wire [bus_pack_size_width_lp-1:0] fsm_rev_max_size_li = bus_pack_size_width_lp'(data_byte_offset_width_lp);
  logic [data_byte_offset_width_lp-1:0] fsm_rev_data_sel_li;

  always_comb begin
    // size to use is set to max size if response is larger than data width (indicating a multi-beat
    // message will be sent and therefore each data beat will be full and valid),
    // otherwise extract size from memory response header
    fsm_rev_size_li = (1'b1 << fsm_rev_header_lo.size) > data_bytes_lp
                       ? fsm_rev_max_size_li
                       : fsm_rev_header_lo.size[0+:bus_pack_size_width_lp];
    // B/H/W/D response data is at LSB, but larger responses should use byte offset bits of
    // address to pick correct data
    fsm_rev_data_sel_li = '0;
    case (fsm_rev_header_lo.size)
      e_bedrock_msg_size_1
      ,e_bedrock_msg_size_2
      ,e_bedrock_msg_size_4
      ,e_bedrock_msg_size_8:
        fsm_rev_data_sel_li = '0;
      default:
        fsm_rev_data_sel_li = fsm_rev_header_lo.addr[0+:data_byte_offset_width_lp];
    endcase
  end

  logic [l2_data_width_p-1:0] cache_data_li;
  bsg_mux
   #(.width_p(l2_data_width_p), .els_p(l2_banks_p))
   resp_bank_sel
    (.data_i(cache_data_i)
     ,.sel_i(cache_rev_bank_lo)
     ,.data_o(cache_data_li)
     );

  bsg_bus_pack
   #(.in_width_p(l2_data_width_p))
   mem_rev_data_bus_pack
    (.data_i(cache_data_li)
    ,.sel_i(fsm_rev_data_sel_li)
    ,.size_i(fsm_rev_size_li)
    ,.data_o(fsm_rev_data_lo)
    );

  // FSM
  always_comb
    begin
      cache_pkt     = '0;
      cache_pkt_v_o = '0;
      cache_data_yumi_o = '0;

      fsm_fwd_yumi_lo = 1'b0;

      fsm_rev_v_lo = 1'b0;

      tagst_sent_n     = tagst_sent_r;
      tagst_received_n = tagst_received_r;

      state_n  = state_r;

      case (state_r)
        e_reset:
          begin
            state_n = e_clear_tag;
          end
        e_clear_tag: begin
          cache_pkt_v_o = (tagst_sent_r != l2_blocks_lp) << (tagst_sent_r / (l2_sets_p*l2_assoc_p));
          cache_pkt.opcode = TAGST;
          cache_pkt.data = '0;
          cache_pkt.addr = tagst_sent_r[0+:lg_l2_sets_lp+lg_l2_assoc_lp] << l2_block_offset_width_lp;

          cache_data_yumi_o = cache_data_v_i;

          tagst_sent_n = |{cache_pkt_v_o & cache_pkt_ready_and_i}
            ? tagst_sent_r + 1'b1
            : tagst_sent_r;
          tagst_received_n = |{cache_data_yumi_o}
            ? tagst_received_r + 1'b1
            : tagst_received_r;

          state_n = (tagst_sent_r == l2_blocks_lp) & (tagst_received_r == l2_blocks_lp)
            ? e_ready
            : e_clear_tag;
        end
        e_ready:
          begin
            case (fsm_fwd_header_li.msg_type)
              e_bedrock_mem_rd
              ,e_bedrock_mem_uc_rd:
                case (fsm_fwd_header_li.size)
                  e_bedrock_msg_size_1: cache_pkt.opcode = LB;
                  e_bedrock_msg_size_2: cache_pkt.opcode = LH;
                  e_bedrock_msg_size_4: cache_pkt.opcode = LW;
                  e_bedrock_msg_size_8: cache_pkt.opcode = LD;
                  e_bedrock_msg_size_16
                  ,e_bedrock_msg_size_32
                  ,e_bedrock_msg_size_64: cache_pkt.opcode = LM;
                  default: cache_pkt.opcode = LB;
                endcase
              e_bedrock_mem_uc_wr
              ,e_bedrock_mem_wr
              ,e_bedrock_mem_amo:
                case (fsm_fwd_header_li.size)
                  e_bedrock_msg_size_1: cache_pkt.opcode = SB;
                  e_bedrock_msg_size_2: cache_pkt.opcode = SH;
                  e_bedrock_msg_size_4, e_bedrock_msg_size_8:
                    case (fsm_fwd_header_li.subop)
                      e_bedrock_store  : cache_pkt.opcode = is_word_op ? SW : SD;
                      e_bedrock_amoswap: cache_pkt.opcode = is_word_op ? AMOSWAP_W : AMOSWAP_D;
                      e_bedrock_amoadd : cache_pkt.opcode = is_word_op ? AMOADD_W : AMOADD_D;
                      e_bedrock_amoxor : cache_pkt.opcode = is_word_op ? AMOXOR_W : AMOXOR_D;
                      e_bedrock_amoand : cache_pkt.opcode = is_word_op ? AMOAND_W : AMOAND_D;
                      e_bedrock_amoor  : cache_pkt.opcode = is_word_op ? AMOOR_W : AMOOR_D;
                      e_bedrock_amomin : cache_pkt.opcode = is_word_op ? AMOMIN_W : AMOMIN_D;
                      e_bedrock_amomax : cache_pkt.opcode = is_word_op ? AMOMAX_W : AMOMAX_D;
                      e_bedrock_amominu: cache_pkt.opcode = is_word_op ? AMOMINU_W : AMOMINU_D;
                      e_bedrock_amomaxu: cache_pkt.opcode = is_word_op ? AMOMAXU_W : AMOMAXU_D;
                      default : begin end
                    endcase
                  e_bedrock_msg_size_16
                  ,e_bedrock_msg_size_32
                  ,e_bedrock_msg_size_64: cache_pkt.opcode = SM;
                  default: cache_pkt.opcode = LB;
                endcase
              default: cache_pkt.opcode = LB;
            endcase

            if (is_tagfl)
              begin
                cache_pkt.opcode = TAGFL;
                cache_pkt.addr = tagfl_addr;
              end
            else
              begin
                cache_pkt.addr = cache_pkt_addr_lo;
                cache_pkt.data = fsm_fwd_data_li;
                // This mask is only used for the LM/SM operations for >64 bit mask operations,
                // but it gets set regardless of operation
                cache_pkt.mask = cache_pkt_mask_lo;
              end
            cache_pkt_v_o[cache_fwd_bank_lo] = stream_fifo_ready_lo & fsm_fwd_v_li;
            fsm_fwd_yumi_lo = fsm_fwd_v_li & stream_fifo_ready_lo & cache_pkt_ready_and_i[cache_fwd_bank_lo];

            fsm_rev_v_lo = stream_header_v_lo & cache_data_v_i[cache_rev_bank_lo];
            cache_data_yumi_o[cache_rev_bank_lo] = fsm_rev_v_lo & fsm_rev_ready_and_li;
          end
        default: begin end
      endcase
    end

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      begin
        state_r          <= e_reset;
        tagst_sent_r     <= '0;
        tagst_received_r <= '0;
      end
    else
      begin
        state_r          <= state_n;
        tagst_sent_r     <= tagst_sent_n;
        tagst_received_r <= tagst_received_n;
      end

  //synopsys translate_off
  always_ff @(negedge clk_i)
    begin
      assert(reset_i !== '0
             || ~(fsm_fwd_v_li & fsm_fwd_header_li.msg_type inside {e_bedrock_mem_wr, e_bedrock_mem_uc_wr})
             || ~(fsm_fwd_header_li.subop inside {e_bedrock_amolr, e_bedrock_amosc})
             )
          else $error("LR/SC not supported in bsg_cache");
    end
  //synopsys translate_on

  // requirement from BedRock Stream interface
  if (!(`BSG_IS_POW2(l2_data_width_p) || l2_data_width_p < 64 || l2_data_width_p > 512))
    $error("L2 data width must be 64, 128, 256, or 512");

endmodule

