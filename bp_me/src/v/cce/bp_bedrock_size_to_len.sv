/**
 *
 * Name:
 *   bp_bedrock_size_to_len.sv
 *
 * Description:
 *   This module computes the number of data beats required to send the data field of
 *   a BedRock message based on a BedRock size field and the specified data beat width.
 *
 *   len_width_p is the width to use for the output length integer
 *
 *   beat_width_p is the number of bits per data beat
 *
 *   The len_o output is zero-based and equal to msg_size_bytes / data beat width - 1
 *
 *   (1 << e_bedrock_msg_size_X) gives the number of bytes for the message size enum value
 *
 */

`include "bp_common_defines.svh"

module bp_bedrock_size_to_len
  import bp_common_pkg::*;
  #(parameter beat_width_p = "inv"
    , parameter len_width_p    = "inv"
  )
  (input bp_bedrock_msg_size_e  size_i
   , output logic [len_width_p-1:0] len_o
  );

  localparam msg_size_1_beats_lp = `BSG_CDIV((1 << e_bedrock_msg_size_1)*8, beat_width_p) - 1;
  localparam msg_size_2_beats_lp = `BSG_CDIV((1 << e_bedrock_msg_size_2)*8, beat_width_p) - 1;
  localparam msg_size_4_beats_lp = `BSG_CDIV((1 << e_bedrock_msg_size_4)*8, beat_width_p) - 1;
  localparam msg_size_8_beats_lp = `BSG_CDIV((1 << e_bedrock_msg_size_8)*8, beat_width_p) - 1;
  localparam msg_size_16_beats_lp = `BSG_CDIV((1 << e_bedrock_msg_size_16)*8, beat_width_p) - 1;
  localparam msg_size_32_beats_lp = `BSG_CDIV((1 << e_bedrock_msg_size_32)*8, beat_width_p) - 1;
  localparam msg_size_64_beats_lp = `BSG_CDIV((1 << e_bedrock_msg_size_64)*8, beat_width_p) - 1;
  localparam msg_size_128_beats_lp = `BSG_CDIV((1 << e_bedrock_msg_size_128)*8, beat_width_p) - 1;

  always_comb begin
    unique case (size_i)
      e_bedrock_msg_size_1: len_o = len_width_p'(msg_size_1_beats_lp);
      e_bedrock_msg_size_2: len_o = len_width_p'(msg_size_2_beats_lp);
      e_bedrock_msg_size_4: len_o = len_width_p'(msg_size_4_beats_lp);
      e_bedrock_msg_size_8: len_o = len_width_p'(msg_size_8_beats_lp);
      e_bedrock_msg_size_16: len_o = len_width_p'(msg_size_16_beats_lp);
      e_bedrock_msg_size_32: len_o = len_width_p'(msg_size_32_beats_lp);
      e_bedrock_msg_size_64: len_o = len_width_p'(msg_size_64_beats_lp);
      e_bedrock_msg_size_128: len_o = len_width_p'(msg_size_128_beats_lp);
      default: len_o = '0;
    endcase
  end

  //synopsys translate_off
  initial begin
    assert(len_width_p >= `BSG_SAFE_CLOG2(msg_size_128_beats_lp)) else
      $error("len_width_p must be large enough to ");
    assert(`BSG_IS_POW2(beat_width_p)) else
      $error("beat_width_p must be a power of two");
    assert(beat_width_p >= 8) else
      $error("beat_width_p must be at least 8 bits wide");
  end
  //synopsys translate_on


endmodule

