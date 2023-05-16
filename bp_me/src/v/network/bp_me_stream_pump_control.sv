/**
 *
 * Name:
 *   bp_me_stream_pump_control.sv
 *
 * Description:
 *   Generates the stream word/cnt portion of a BedRock Stream protocol message address given
 *   an initial stream word and transaction size in stream words (both zero-based).
 *
 *   max_val_p is equal to (block width / stream width) - 1 (i.e., zero-based).
 *   max_val_p+1 must be a power of two for the wrap-around counting to work properly
 *   E.g., if a block is divided into 8 stream words, max_val_p = 7.
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
   , parameter `BSG_INV_PARAM(max_val_p)
   , parameter `BSG_INV_PARAM(payload_width_p)
   , parameter `BSG_INV_PARAM(data_width_p)
   , parameter fsm_stream_mask_p = 0
   , localparam width_lp = `BSG_WIDTH(max_val_p)
   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, xce)
   )
  (input                                          clk_i
   , input                                        reset_i

   , input [xce_header_width_lp-1:0]              msg_header_i
   // Increment counter
   , input                                        en_i

   // wrap-around count, used to construct proper stream beat address
   // wraps within sub-block aligned portion of block targeted by request
   , output logic [`BSG_SAFE_MINUS(width_lp,1):0] wrap_o
   , output logic                                 first_o
   , output logic                                 last_o
   );

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, lce_id_width_p, lce_assoc_p, xce);
  `bp_cast_i(bp_bedrock_xce_header_s, msg_header);

  if (max_val_p == 0)
    begin : z
      assign wrap_o = '0;
      assign first_o = 1'b1;
      assign last_o = 1'b1;
    end
  else
    begin : nz
      enum logic {e_ready, e_stream} state_n, state_r;
      wire is_ready = (state_r == e_ready);
      wire is_stream = (state_r == e_stream);

      localparam data_bytes_lp = (data_width_p >> 3);
      localparam offset_width_lp = `BSG_SAFE_CLOG2(data_bytes_lp);

      wire [width_lp-1:0] stream_size =
        `BSG_MAX((1'b1 << msg_header_cast_i.size) / data_bytes_lp, 1'b1) - 1'b1;
      wire fsm_stream = fsm_stream_mask_p[msg_header_cast_i.msg_type];

      wire [width_lp-1:0] size_li = fsm_stream ? stream_size : '0;
      wire [width_lp-1:0] first_cnt = msg_header_cast_i.addr[offset_width_lp+:width_lp];

      assign first_o = is_ready;

      logic [width_lp-1:0] cnt_r;
      wire [width_lp-1:0] cnt_val_li = first_cnt + en_i;
      bsg_counter_set_en
       #(.max_val_p(max_val_p), .reset_val_p('0))
       counter
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.set_i(is_ready)
         ,.en_i(en_i)
         ,.val_i(cnt_val_li)
         ,.count_o(cnt_r)
         );

      logic [width_lp-1:0] last_cnt_r;
      wire [width_lp-1:0] last_cnt_n = first_cnt + size_li;
      bsg_dff_en
       #(.width_p(width_lp))
       last_cnt_reg
        (.clk_i(clk_i)
         ,.en_i(is_ready)
         ,.data_i(last_cnt_n)
         ,.data_o(last_cnt_r)
         );
      assign last_o = is_ready ? (size_li == '0) : (last_cnt_r == cnt_r);

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
         ,.data1_i(cnt_r)
         ,.sel_i(wrap_sel_li)
         ,.data_o(wrap_lo)
         );

      assign wrap_o = is_ready ? first_cnt : wrap_lo;

      always_comb
        case (state_r)
          e_stream: state_n = (en_i &  last_o) ? e_ready : e_stream;
          default : state_n = (en_i & ~last_o) ? e_stream : e_ready;
        endcase

      // synopsys sync_set_reset "reset_i"
      always_ff @(posedge clk_i)
        if (reset_i)
          state_r <= e_ready;
        else
          state_r <= state_n;
    end

  // parameter check
  if ((max_val_p > 0) && !`BSG_IS_POW2(max_val_p+1))
    $error("max_val_p+1 of %0d is not a power of two...wrap-around counting will break.", max_val_p+1);

endmodule

`BSG_ABSTRACT_MODULE(bp_me_stream_pump_control)

