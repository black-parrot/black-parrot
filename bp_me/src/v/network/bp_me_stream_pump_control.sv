/**
 *
 * Name:
 *   bp_me_stream_pump_control.sv
 *
 * Description:
 *   Generates the stream word/cnt portion of a BedRock Stream protocol message address given
 *   an initial stream word and transaction size in stream words (both zero-based).
 *
 *   size_li is the zero-based transaction size (e.g., a transaction of 4 stream words has size_li = 3)
 *   - size_li+1 should be a power of two
 *
 *   wrap_o is a count that wraps around at the end of the naturally aligned sub-block with
 *      size size_li targeted by the transaction. wrap_o is typically used directed in the stream
 *      message address.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_stream_pump_control
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   , parameter `BSG_INV_PARAM(payload_width_p)
   , parameter `BSG_INV_PARAM(data_width_p)
   , parameter `BSG_INV_PARAM(stream_mask_p)
   , parameter `BSG_INV_PARAM(widest_beat_size_p)
   `declare_bp_bedrock_generic_if_width(paddr_width_p, payload_width_p, xce)
   )
  (input                                          clk_i
   , input                                        reset_i

   // Move to next beat
   , input [xce_header_width_lp-1:0]              header_i
   , input                                        ack_i

   // wrap-around count, used to construct proper stream beat address
   // wraps within sub-block aligned portion of block targeted by request
   , output logic [paddr_width_p-1:0]             addr_o
   , output logic                                 first_o
   , output logic                                 critical_o
   , output logic                                 last_o
   );

  `declare_bp_bedrock_generic_if(paddr_width_p, payload_width_p, xce);
  `bp_cast_i(bp_bedrock_xce_header_s, header);

  localparam bytes_lp = data_width_p >> 3;
  localparam width_lp = `BSG_SAFE_CLOG2(bedrock_block_width_p/data_width_p);
  localparam offset_width_lp = `BSG_SAFE_CLOG2(bytes_lp);
  wire [$bits(bp_bedrock_msg_size_e)-1:0] beat_size = `BSG_SAFE_CLOG2(bytes_lp);

  if (bedrock_block_width_p == data_width_p)
    begin : z
      assign addr_o = header_cast_i.addr;
      assign first_o = 1'b1;
      assign critical_o = 1'b1;
      assign last_o = 1'b1;
    end
  else
    begin : nz
      enum logic {e_ready, e_stream} state_n, state_r;
      wire is_ready = (state_r == e_ready);
      wire is_stream = (state_r == e_stream);

      wire [width_lp-1:0] stream_size =
        `BSG_MAX((1'b1 << header_cast_i.size) / bytes_lp, 1'b1) - 1'b1;
      wire stream = stream_mask_p[header_cast_i.msg_type];
      wire [width_lp-1:0] size_li = stream ? stream_size : '0;
      wire [paddr_width_p-1:0] req_mask = ~((1'b1 << header_cast_i.size) - 1'b1);
      wire [paddr_width_p-1:0] max_mask = ~((1'b1 << widest_beat_size_p) - 1'b1);
      wire [paddr_width_p-1:0] addr_mask = `BSG_MAX(req_mask, max_mask);
      wire [paddr_width_p-1:0] beat_mask = ~((1'b1 << beat_size) - 1'b1);
      wire [paddr_width_p-1:0] final_mask = `BSG_MAX(addr_mask, beat_mask);

      wire [paddr_width_p-1:0] base_addr     = header_cast_i.addr & addr_mask;
      wire [paddr_width_p-1:0] critical_addr = header_cast_i.addr & beat_mask;

      wire [width_lp-1:0] first_cnt    = base_addr[offset_width_lp+:width_lp];
      wire [width_lp-1:0] critical_cnt = critical_addr[offset_width_lp+:width_lp];
      wire [width_lp-1:0] last_cnt     = first_cnt + size_li;

      logic [width_lp-1:0] cnt_r;
      wire [width_lp-1:0] cnt_val_li = first_cnt + ack_i;
      bsg_counter_set_en
       #(.max_val_p(2**width_lp-1), .reset_val_p('0))
       counter
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.set_i(is_ready)
         ,.en_i(ack_i)
         ,.val_i(cnt_val_li)
         ,.count_o(cnt_r)
         );
      wire [width_lp-1:0] cnt_lo = is_ready ? first_cnt : cnt_r;

      assign first_o    = is_ready;
      assign critical_o = (critical_cnt == cnt_lo);
      assign last_o     = (last_cnt == cnt_lo);

      // Dynamically generate sub-block wrapped stream count
      // The count is wrapped within the size_li aligned portion of the block containing first_cnt
      //
      // A canonical block address can be viewed as:
      // __________________________________________________________
      // |                |          block offset                  |  block address
      // |  upper address |________________________________________|
      // |                |     stream count   |  stream offset    |  stream word address
      // |________________|____________________|___________________|
      // where stream offset is a byte offset of the current stream word and stream count is
      // the current stream word portion of the block, having width = stream data channel width
      //
      // stream count is further divided into:
      // __________________________________________________
      // |    sub-block number     |    sub-block count    |
      // |_________________________|_______________________|
      //
      // To produce wrap_o, which is the sub-block aligned and wrapped count, the sub-block number
      // field is held constant while sub-block count comes from the counter. The number of bits
      // derived from the counter versus the initial stream word input (first_cnt) is determined by
      // the transaction size (size_li) input.
      //
      // For example, consider a system with max_val_p = 7 (8 stream words per block), where a block
      // comprises stream words [7, 6, 5, 4, 3, 2, 1, 0], listed most to least significant.
      // An exampe system like this could have 512 bit blocks with a stream data width of 64 bits.
      // 3 bits = log2(512/64) are required for the stream count. The transaction size (size_li)
      // determines how many bits are used from first_cnt and cnt_r to produce wrap_o.

      // E.g., max_val_p = 7 for a system with 512-bit blocks and 64-bit stream data width
      // A 512-bit transaction sets size_li = 7 and a 256-bit transactions sets size_li = 3
      // 512-bit, size_li = 7, first_cnt = 2: wrap_o = 2, 3, 4, 5, 6, 7, 0, 1
      // 256-bit, size_li = 3, first_cnt = 2: wrap_o = 2, 3, 0, 1
      // 512-bit, size_li = 7, first_cnt = 6: wrap_o = 6, 7, 0, 1, 2, 3, 4, 5
      // 256-bit, size_li = 3, first_cnt = 6: wrap_o = 6, 7, 4, 5

      // if size_li+1 is not a power of two, the transaction wraps as if size_li+1 is the next
      // power of two (e.g., max_val_p = 3, then size_li = 2 wraps same as size_li = 3)

      // selection input used to pick bits from block-wrapped and sub-block wrapped counts
      logic [width_lp-1:0] wrap_sel_li;
      for (genvar i = 0; i < width_lp; i++)
        begin : cnt_sel
          assign wrap_sel_li[i] = size_li >= 2**i;
        end

      // sub-block wrapped and aligned count (stream word)
      logic [width_lp-1:0] wrap_lo;
      bsg_mux_bitwise
       #(.width_p(width_lp))
       wrap_mux
        (.data0_i(first_cnt)
         ,.data1_i(cnt_lo)
         ,.sel_i(wrap_sel_li)
         ,.data_o(wrap_lo)
         );

      localparam block_offset_width_lp = `BSG_SAFE_CLOG2(bedrock_block_width_p >> 3);
      wire [`BSG_SAFE_MINUS(width_lp,1):0] wrap_cnt = is_ready ? first_cnt : wrap_lo;
      wire [paddr_width_p-1:block_offset_width_lp] high_bits =
        header_cast_i.addr[paddr_width_p-1:block_offset_width_lp];
      wire [offset_width_lp-1:0] low_bits = header_cast_i.addr[0+:offset_width_lp];

      assign addr_o = {high_bits, {bedrock_block_width_p>data_width_p{wrap_cnt}}, low_bits} & final_mask;

      always_comb
        case (state_r)
          e_stream: state_n = (ack_i &  last_o) ? e_ready : e_stream;
          default : state_n = (ack_i & ~last_o) ? e_stream : e_ready;
        endcase

      // synopsys sync_set_reset "reset_i"
      always_ff @(posedge clk_i)
        if (reset_i)
          state_r <= e_ready;
        else
          state_r <= state_n;
    end

endmodule

`BSG_ABSTRACT_MODULE(bp_me_stream_pump_control)

