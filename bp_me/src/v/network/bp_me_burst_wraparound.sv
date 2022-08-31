/**
 *
 * Name:
 *   bp_me_burst_wraparound.sv
 *
 * Description:
 *   Generates the stream word/cnt portion of a BedRock Stream protocol message address given
 *   an initial stream word and transaction size in stream words (both zero-based).
 *
 *   max_val_p is equal to (block width / stream width) - 1 (i.e., zero-based).
 *   max_val_p+1 must be a power of two for the wrap-around counting to work properly
 *   E.g., if a block is divided into 8 stream words, max_val_p = 7.
 *
 *   size_i is the zero-based transaction size (e.g., a transaction of 4 stream words has size_i = 3)
 *   - size_i+1 should be a power of two
 *   base_i is first address of the transaction
 *   Both size_i and base_i must be held constant throughout the transaction.
 *
 *   Two outputs are generated:
 *   1. cnt_o is a count that wraps around at the end of the full block
 *   2. wrap_o is a count that wraps around at the end of the naturally aligned sub-block with
 *      size size_i targeted by the transaction. wrap_o is typically used directed in the stream
 *      message address.
 *
 */

`include "bsg_defines.v"

module bp_me_burst_wraparound
 #(parameter `BSG_INV_PARAM(max_val_p)
   , parameter `BSG_INV_PARAM(addr_width_p)
   , parameter `BSG_INV_PARAM(offset_width_p)
   , localparam width_lp = `BSG_WIDTH(max_val_p)
   )
  (input                                          clk_i
   , input                                        reset_i

   // Increment counter
   , input                                        en_i
   , input [`BSG_SAFE_MINUS(width_lp,1):0]        size_i
   , input [addr_width_p-1:0]                     base_i

   // wraps within sub-block aligned portion of block targeted by request
   // the stream beat address using the wraparound count
   , output logic [addr_width_p-1:0]              addr_o
   // full width count, wraps at end of block
   , output logic [`BSG_SAFE_MINUS(width_lp,1):0] cnt_o

   , output logic                                 first_o
   , output logic                                 last_o
   );

  // parameter check
  if ((max_val_p > 0) && !`BSG_IS_POW2(max_val_p+1))
    $error("max_val_p+1 of %0d is not a power of two...wrap-around counting will break.", max_val_p+1);

  enum logic {e_ready, e_stream} state_n, state_r;
  wire is_ready  = (state_r == e_ready);
  wire is_stream = (state_r == e_stream);

  if (max_val_p == 0)
    begin : z
      assign addr_o  = '0;
      assign cnt_o   = '0;
      assign first_o = 1'b1;
      assign last_o  = 1'b1;
    end
  else
    begin : nz
      logic [width_lp-1:0] cnt_r;

      wire [width_lp-1:0] base_cnt = base_i[offset_width_p+:width_lp];
      wire [width_lp-1:0] cnt_val_li = base_cnt + en_i;
      bsg_counter_set_en
       #(.max_val_p(max_val_p), .reset_val_p('0))
       counter
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.set_i(is_ready & en_i)
         ,.en_i(en_i)
         ,.val_i(cnt_val_li)
         ,.count_o(cnt_r)
         );

      // Dynamically generate sub-block wrapped stream count
      // The count is wrapped within the size_i aligned portion of the block containing base_cnt
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
      // derived from the counter versus the initial stream word input (base_cnt) is determined by
      // the transaction size (size_i) input. A transaction with size_i == max_val_p uses the
      // stream count (cnt_o) directly as it already handles block-aligned wrapping.
      //
      // For example, consider a system with max_val_p = 7 (8 stream words per block), where a block
      // comprises stream words [7, 6, 5, 4, 3, 2, 1, 0], listed most to least significant.
      // An exampe system like this could have 512 bit blocks with a stream data width of 64 bits.
      // 3 bits = log2(512/64) are required for the stream count. The transaction size (size_i)
      // determines how many bits are used from base_cnt and cnt_o (cnt_r) to produce wrap_o.

      // E.g., max_val_p = 7 for a system with 512-bit blocks and 64-bit stream data width
      // A 512-bit transaction sets size_i = 7 and a 256-bit transactions sets size_i = 3
      // 512-bit, size_i = 7, base_cnt = 2: cnt_o and wrap_o = 2, 3, 4, 5, 6, 7, 0, 1
      // 256-bit, size_i = 3, base_cnt = 2: cnt_o = 2, 3, 4, 5 and wrap_o = 2, 3, 0, 1
      // 512-bit, size_i = 7, base_cnt = 6: cnt_o and wrap_o = 6, 7, 0, 1, 2, 3, 4, 5
      // 256-bit, size_i = 3, base_cnt = 6: cnt_o = 6, 7, 0, 1 and wrap_o = 6, 7, 4, 5

      // if size_i+1 is not a power of two, the transaction wraps as if size_i+1 is the next
      // power of two (e.g., max_val_p = 3, then size_i = 2 wraps same as size_i = 3)

      // selection input used to pick bits from block-wrapped and sub-block wrapped counts
      logic [width_lp-1:0] cnt_sel_li;
      for (genvar i = 0; i < width_lp; i++)
        begin : cnt_sel
          assign cnt_sel_li[i] = size_i >= 2**i;
        end

      wire [width_lp-1:0] last_cnt = base_cnt + size_i;
      // sub-block wrapped and aligned count (stream word)
      logic [width_lp-1:0] wrap_cnt;
      bsg_mux_bitwise
       #(.width_p(width_lp))
       wrap_mux
        (.data0_i(base_cnt)
         ,.data1_i(cnt_r)
         ,.sel_i(cnt_sel_li)
         ,.data_o(wrap_cnt)
         );
      assign first_o = is_ready;
      assign last_o  = (is_ready && (size_i == '0)) || (is_stream && (cnt_r == last_cnt));
      assign cnt_o   = is_ready ? base_cnt : cnt_r;

      wire [addr_width_p-1:0] wrap_addr =
        {base_i[addr_width_p-1:offset_width_p+width_lp], wrap_cnt, base_i[0+:offset_width_p]};

      assign addr_o = is_ready ? base_i : wrap_addr;

      always_comb
        case (state_r)
          e_stream: state_n = (last_o & en_i) ? e_ready : e_stream;
          // e_ready :
          default : state_n = (first_o & en_i & (size_i > '0)) ? e_stream : e_ready;
        endcase

      //synopsys sync_set_reset "reset_i"
      always_ff @(posedge clk_i)
        if (reset_i)
          state_r <= e_ready;
        else
          state_r <= state_n;
    end

endmodule

`BSG_ABSTRACT_MODULE(bp_me_burst_wraparound)
