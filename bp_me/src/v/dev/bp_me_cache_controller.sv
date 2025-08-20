/*
 * Name:
 *   bp_me_cache_controller.sv
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
`include "bsg_cache.svh"

module bp_me_cache_controller
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 import bsg_cache_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)

   // L2 organization and interface
   , localparam cache_pkt_width_lp = `bsg_cache_pkt_width(daddr_width_p, l2_data_width_p)
   )
  (input                                                   clk_i
   , input                                                 reset_i

   // BedRock Stream interface
   , input [mem_fwd_header_width_lp-1:0]                   mem_fwd_header_i
   , input [bedrock_fill_width_p-1:0]                      mem_fwd_data_i
   , input                                                 mem_fwd_v_i
   , output logic                                          mem_fwd_ready_and_o

   , output logic [mem_rev_header_width_lp-1:0]            mem_rev_header_o
   , output logic [bedrock_fill_width_p-1:0]               mem_rev_data_o
   , output logic                                          mem_rev_v_o
   , input                                                 mem_rev_ready_and_i

   // cache-side
   , output logic [l2_banks_p-1:0][cache_pkt_width_lp-1:0] cache_pkt_o
   , output logic [l2_banks_p-1:0]                         cache_pkt_v_o
   , input [l2_banks_p-1:0]                                cache_pkt_yumi_i

   , input [l2_banks_p-1:0][l2_data_width_p-1:0]           cache_data_i
   , input [l2_banks_p-1:0]                                cache_data_v_i
   , output logic [l2_banks_p-1:0]                         cache_data_yumi_o
   );

  // L2 derived params
  localparam l2_blocks_per_bank_lp     = (l2_assoc_p*l2_sets_p);
  localparam l2_blocks_lp              = l2_banks_p * l2_blocks_per_bank_lp;
  localparam lg_l2_banks_lp            = `BSG_SAFE_CLOG2(l2_banks_p);
  localparam lg_l2_sets_lp             = `BSG_SAFE_CLOG2(l2_sets_p);
  localparam lg_l2_assoc_lp            = `BSG_SAFE_CLOG2(l2_assoc_p);
  localparam lg_l2_blocks_per_bank_lp  = `BSG_SAFE_CLOG2(l2_blocks_per_bank_lp);
  localparam lg_l2_blocks_lp           = `BSG_SAFE_CLOG2(l2_blocks_lp);
  localparam l2_block_offset_width_lp  = `BSG_SAFE_CLOG2(l2_block_width_p/8);
  localparam data_bytes_lp             = (l2_data_width_p/8);
  localparam data_byte_offset_width_lp = `BSG_SAFE_CLOG2(data_bytes_lp);

  `declare_bsg_cache_pkt_s(daddr_width_p, l2_data_width_p);
  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);
  `declare_bp_memory_map(paddr_width_p, daddr_width_p);

  bsg_cache_pkt_s cache_pkt;
  assign cache_pkt_o = {l2_banks_p{cache_pkt}};

  enum logic [2:0] {e_reset, e_clear, e_drain, e_ready, e_uc_flush} state_n, state_r;
  wire is_reset  = (state_r == e_reset);
  wire is_flush  = (state_r == e_uc_flush);
  wire is_clear  = (state_r == e_clear);
  wire is_drain  = (state_r == e_drain);
  wire is_ready  = (state_r == e_ready);

  bp_bedrock_mem_fwd_header_s fsm_fwd_header_li;
  logic [l2_data_width_p-1:0] fsm_fwd_data_li;
  logic fsm_fwd_v_li, fsm_fwd_yumi_lo;
  logic [paddr_width_p-1:0] fsm_fwd_addr_li;
  logic fsm_fwd_new_li, fsm_fwd_critical_li, fsm_fwd_last_li;

  bp_bedrock_mem_rev_header_s fsm_rev_header_lo;
  logic [l2_data_width_p-1:0] fsm_rev_data_lo;
  logic fsm_rev_v_lo, fsm_rev_ready_then_li;
  logic [paddr_width_p-1:0] fsm_rev_addr_lo;
  logic fsm_rev_new_lo, fsm_rev_critical_lo, fsm_rev_last_lo;

  // Enough to saturate l2 banks, may be overprovisioned
  localparam cache_metadata_fifo_els_lp = 3*l2_banks_p;
  localparam cache_metadata_fifo_width_lp = $bits(bp_bedrock_mem_rev_header_s)+lg_l2_banks_lp;

  // Hack because the bsg_cache does not have introspection
  logic [l2_banks_p-1:0] op_v_lo, op_data_lo;
  for (genvar i = 0; i < l2_banks_p; i++)
    begin : tag
      bsg_fifo_1r1w_small
       #(.width_p(1), .ready_THEN_valid_p(1) ,.els_p(3))
       fifo
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.data_i(is_ready)
         ,.v_i(cache_pkt_yumi_i[i])
         ,.ready_param_o()

         ,.data_o(op_data_lo[i])
         ,.v_o(op_v_lo[i])
         ,.yumi_i(cache_data_yumi_o[i])
         );
    end

  logic [cache_metadata_fifo_width_lp-1:0] fsm_fwd_metadata_li, fsm_rev_metadata_lo;
  bp_me_stream_pump
   #(.bp_params_p(bp_params_p)
     ,.in_data_width_p(l2_data_width_p)
     ,.in_payload_width_p(mem_fwd_payload_width_lp)
     ,.in_msg_stream_mask_p(mem_fwd_stream_mask_gp)
     ,.in_fsm_stream_mask_p(mem_fwd_stream_mask_gp | mem_rev_stream_mask_gp)
     ,.out_data_width_p(l2_data_width_p)
     ,.out_payload_width_p(mem_rev_payload_width_lp)
     ,.out_msg_stream_mask_p(mem_rev_stream_mask_gp)
     ,.out_fsm_stream_mask_p(mem_fwd_stream_mask_gp | mem_rev_stream_mask_gp)
     ,.metadata_fifo_width_p(cache_metadata_fifo_width_lp)
     ,.metadata_fifo_els_p(cache_metadata_fifo_els_lp)
     )
   stream_pump
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.in_msg_header_i(mem_fwd_header_i)
     ,.in_msg_data_i(mem_fwd_data_i)
     ,.in_msg_v_i(mem_fwd_v_i)
     ,.in_msg_ready_and_o(mem_fwd_ready_and_o)

     ,.in_fsm_header_o(fsm_fwd_header_li)
     ,.in_fsm_data_o(fsm_fwd_data_li)
     ,.in_fsm_v_o(fsm_fwd_v_li)
     ,.in_fsm_yumi_i(fsm_fwd_yumi_lo)

     ,.in_fsm_metadata_i(fsm_fwd_metadata_li)
     ,.in_fsm_addr_o(fsm_fwd_addr_li)
     ,.in_fsm_new_o(fsm_fwd_new_li)
     ,.in_fsm_critical_o(fsm_fwd_critical_li)
     ,.in_fsm_last_o(fsm_fwd_last_li)

     ,.out_msg_header_o(mem_rev_header_o)
     ,.out_msg_data_o(mem_rev_data_o)
     ,.out_msg_v_o(mem_rev_v_o)
     ,.out_msg_ready_and_i(mem_rev_ready_and_i)

     ,.out_fsm_header_i(fsm_rev_header_lo)
     ,.out_fsm_data_i(fsm_rev_data_lo)
     ,.out_fsm_v_i(fsm_rev_v_lo)
     ,.out_fsm_ready_then_o(fsm_rev_ready_then_li)

     ,.out_fsm_metadata_o(fsm_rev_metadata_lo)
     ,.out_fsm_addr_o(fsm_rev_addr_lo)
     ,.out_fsm_new_o(fsm_rev_new_lo)
     ,.out_fsm_critical_o(fsm_rev_critical_lo)
     ,.out_fsm_last_o(fsm_rev_last_lo)
     );

  bp_local_addr_s local_addr_li;
  assign local_addr_li = fsm_fwd_addr_li;
  localparam l1c_l2c_base_lp = paddr_width_p'(dram_base_addr_gp);
  localparam l1uc_l2c_base_lp = paddr_width_p'(1'b1 << caddr_width_p);
  localparam l1uc_l2uc_base_lp = l1c_l2c_base_lp | l1uc_l2c_base_lp;
  wire is_uc_op   = (local_addr_li >= l1uc_l2c_base_lp) && (local_addr_li < l1uc_l2uc_base_lp);
  wire is_word_op = (fsm_fwd_header_li.size == e_bedrock_msg_size_4);

  logic [lg_l2_blocks_lp-1:0] set_cnt;
  logic set_clear, set_up;
  bsg_counter_clear_up
   #(.max_val_p(l2_blocks_lp-1), .init_val_p(0))
   set_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(set_clear)
     ,.up_i(set_up)
     ,.count_o(set_cnt)
     );
  wire set_done = (set_cnt == l2_blocks_lp-1);
  wire [lg_l2_banks_lp-1:0] cnt_bank_lo = set_cnt / l2_blocks_per_bank_lp;

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
          wire [lg_num_slices_lp-1:0] slice_index = fsm_fwd_addr_li[i+:lg_num_slices_lp];
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
  logic fwd_pkt_dram_lo;
  logic [daddr_width_p-1:0] fwd_pkt_daddr_lo;
  logic [l2_data_width_p-1:0] fwd_pkt_data_lo;
  logic [lg_l2_banks_lp-1:0] fwd_pkt_bank_lo;
  bp_me_dram_hash_encode
   #(.bp_params_p(bp_params_p))
   bank_select
    (.paddr_i(fsm_fwd_addr_li)
     ,.data_i(fsm_fwd_data_li)

     ,.dram_o(fwd_pkt_dram_lo)
     ,.daddr_o(fwd_pkt_daddr_lo)
     ,.bank_o(fwd_pkt_bank_lo)
     ,.data_o(fwd_pkt_data_lo)
     ,.slice_o()
     );

  logic cache_pkt_v_lo;
  wire [lg_l2_banks_lp-1:0] cache_fwd_bank_lo = is_clear ? cnt_bank_lo : fwd_pkt_bank_lo;
  bsg_decode_with_v
   #(.num_out_p(l2_banks_p))
   decode
    (.i(cache_fwd_bank_lo)
     ,.v_i(cache_pkt_v_lo)
     ,.o(cache_pkt_v_o)
     );
  wire cache_pkt_yumi_li = fsm_fwd_v_li & cache_pkt_yumi_i[cache_fwd_bank_lo];

  logic [lg_l2_banks_lp-1:0] cache_rev_bank_lo;
  assign fsm_fwd_metadata_li = {fwd_pkt_bank_lo, fsm_fwd_header_li};
  assign {cache_rev_bank_lo, fsm_rev_header_lo} = fsm_rev_metadata_lo;

  // mem_rev data selection
  // For B/H/W/D ops, data returned from cache is at the LSB, but it may not for M ops
  // on bsg_bus_pack:
  // sel_i = which unit (byte) to start selection at from cache_data_i
  // size_i = log2(size in bytes) of selection to make
  // bus pack has log2(l2_data_width_p/8) = log2(l2 data width bytes) mux elements
  //   == data_byte_offset_width_lp
  localparam bus_pack_size_width_lp = `BSG_WIDTH(data_byte_offset_width_lp);

  // size to use is set to max size if response is larger than data width (indicating a multi-beat
  // message will be sent and therefore each data beat will be full and valid),
  // otherwise extract size from memory response header
  wire [bus_pack_size_width_lp-1:0] fsm_rev_size_li =
    ((1'b1 << fsm_rev_header_lo.size) > data_bytes_lp)
    ? data_byte_offset_width_lp
    : fsm_rev_header_lo.size[0+:bus_pack_size_width_lp];

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
    ,.sel_i('0) // Data is always aligned
    ,.size_i(fsm_rev_size_li)
    ,.data_o(fsm_rev_data_lo)
    );

  // FSM
  always_comb
    begin
      cache_pkt     = '0;
      cache_pkt_v_lo = '0;
      cache_data_yumi_o = '0;

      fsm_fwd_yumi_lo = 1'b0;

      fsm_rev_v_lo = 1'b0;

      set_clear = 1'b0;
      set_up = 1'b0;

      state_n = state_r;

      unique case (state_r)
        e_reset:
          begin
            state_n = e_clear;
          end
        e_clear:
          begin
            cache_pkt_v_lo = 1'b1;
            cache_pkt.opcode = TAGST;
            cache_pkt.addr   = set_cnt << l2_block_offset_width_lp;
            cache_pkt.data   = '0;
            cache_pkt.mask   = '0;

            set_up = ~set_done;
            set_clear = set_done & |cache_pkt_yumi_i;

            cache_data_yumi_o = cache_data_v_i;

            state_n = set_clear ? e_drain : e_clear;
          end
        e_drain:
          begin
            cache_data_yumi_o = cache_data_v_i;

            state_n = (fsm_rev_ready_then_li | cache_data_v_i) ? e_drain : e_ready;
          end
        e_ready:
          begin
            if (!fwd_pkt_dram_lo)
              unique casez (local_addr_li.addr)
                // Tag ops
                cache_tagfl_match_addr_gp  : cache_pkt.opcode = TAGFL;
                cache_taglv_match_addr_gp  : cache_pkt.opcode = TAGLV;
                cache_tagla_match_addr_gp  : cache_pkt.opcode = TAGLA;
                cache_tagst_match_addr_gp  : cache_pkt.opcode = TAGST;
                // Address ops
                cache_afl_match_addr_gp    : cache_pkt.opcode = AFL;
                cache_aflinv_match_addr_gp : cache_pkt.opcode = AFLINV;
                cache_ainv_match_addr_gp   : cache_pkt.opcode = AINV;
                cache_alock_match_addr_gp  : cache_pkt.opcode = fwd_pkt_data_lo[0] ? ALOCK : AUNLOCK;
                default : begin end
              endcase
            else
              unique casez (fsm_fwd_header_li.msg_type)
                e_bedrock_mem_rd:
                  case (fsm_fwd_header_li.size)
                    e_bedrock_msg_size_1: cache_pkt.opcode = LB;
                    e_bedrock_msg_size_2: cache_pkt.opcode = LH;
                    e_bedrock_msg_size_4: cache_pkt.opcode = LW;
                    e_bedrock_msg_size_8: cache_pkt.opcode = LD;
                    //e_bedrock_msg_size_16
                    //,e_bedrock_msg_size_32
                    //,e_bedrock_msg_size_64
                    //,e_bedrock_msg_size_128
                    default: cache_pkt.opcode = LM;
                  endcase
                e_bedrock_mem_wr, e_bedrock_mem_amo:
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
                    //e_bedrock_msg_size_16
                    //,e_bedrock_msg_size_32
                    //,e_bedrock_msg_size_64
                    //,e_bedrock_msg_size_128
                    default: cache_pkt.opcode = SM;
                  endcase
                default: cache_pkt.opcode = LB;
              endcase

            cache_pkt.addr = fwd_pkt_daddr_lo;
            cache_pkt.data = fwd_pkt_data_lo;
            cache_pkt.mask = cache_pkt_mask_lo;

            if (is_uc_op)
              begin
                cache_pkt_v_lo = fsm_fwd_v_li;
                fsm_fwd_yumi_lo = cache_pkt_yumi_li & ~fsm_fwd_last_li;

                state_n = (fsm_fwd_v_li & fsm_fwd_last_li & cache_pkt_yumi_li) ? e_uc_flush : state_r;
              end
            else
              begin
                cache_pkt_v_lo = fsm_fwd_v_li;
                fsm_fwd_yumi_lo = cache_pkt_yumi_li;
              end
          end
        e_uc_flush:
          begin
            cache_pkt_v_lo = fsm_fwd_v_li;
            cache_pkt.opcode = AFLINV;
            cache_pkt.addr = fwd_pkt_daddr_lo;
            cache_pkt.data = fwd_pkt_data_lo;
            cache_pkt.mask = cache_pkt_mask_lo;

            fsm_fwd_yumi_lo = cache_pkt_yumi_li;

            state_n = fsm_fwd_yumi_lo ? e_drain : state_r;
          end
        default : begin end
      endcase

      for (int i = 0; i < l2_banks_p; i++)
        if (op_v_lo[i] & op_data_lo[i] & (i == cache_rev_bank_lo))
          begin
            fsm_rev_v_lo = fsm_rev_ready_then_li & cache_data_v_i[i];
            cache_data_yumi_o[i] = fsm_rev_v_lo;
          end
        else if (op_v_lo[i] & ~op_data_lo[i])
          begin
            cache_data_yumi_o[i] = cache_data_v_i[i];
          end
    end

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_reset;
    else
      state_r <= state_n;

  // synopsys translate_off
  always_ff @(negedge clk_i)
    begin
      assert(reset_i !== '0 || ~fsm_fwd_v_li
             || ~(fsm_fwd_header_li.msg_type inside {e_bedrock_mem_wr})
             || ~(fsm_fwd_header_li.subop inside {e_bedrock_amolr, e_bedrock_amosc})
             )
          else $error("LR/SC not supported in bsg_cache");
    end
  // synopsys translate_on

  // requirement from BedRock Stream interface
  if (!(`BSG_IS_POW2(l2_data_width_p) || l2_data_width_p < 64 || l2_data_width_p > 512))
    $error("L2 data width must be 64, 128, 256, or 512");

endmodule

