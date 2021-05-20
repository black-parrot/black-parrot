/**
 * bsg_serial_in_parallel_out_passthrough_last.v
 *
 * This data structure takes in single word serial input and deserializes it
 * to multi-word data output. This module is helpful on both sides, both v_o
 * and ready_and_o are early.
 *
 * The last_i signal must be raised early with v_i when the last serial word
 * is available on the input and the input will not fill the SIPO (i.e., less
 * than max_els_p are being deserialized to the parallel output).
 *
 * If max_els_p == 1 then this module simply passes through the signals.
 * Otherwise, the output becomes valid in the cycle that the last input
 * arrives.
 *
 * This module passes throught he last input data word directly to the output
 * and can handle transactions with fewer than max_els_p input words.
 *
 */

`include "bsg_defines.v"

module bsg_serial_in_parallel_out_passthrough_dynamic_last

 #(parameter width_p       = "inv"
  ,parameter max_els_p     = "inv"
  ,parameter lg_max_els_lp = `BSG_SAFE_CLOG2(max_els_p)
  )

  (input                               clk_i
  ,input                               reset_i

  ,input                               v_i
  ,input  [width_p-1:0]                data_i
  ,output                              ready_and_o
  ,input                               last_i

  ,output                              v_o
  ,output [max_els_p-1:0][width_p-1:0] data_o
  ,input                               ready_and_i
  );

  if (max_els_p == 1)
  begin : single_word

    assign v_o         = v_i;
    assign data_o      = data_i;
    assign ready_and_o = ready_and_i;
    wire unused        = last_i;

  end
  else
  begin : multi_word

    wire transaction_done = (v_o & ready_and_i);
    wire word_received = (v_i & ready_and_o);
    wire last_word_received = word_received & last_i;

    // data_dff enable generation
    // start with enable on for word 0, shift to next word as each input word arrives
    // reset to initial mask when output sends
    logic [max_els_p-1:0] data_en_li;
    bsg_dff_reset_en
    #(.width_p(max_els_p)
      ,.reset_val_p(1)
      )
    data_en_dff
     (.clk_i(clk_i)
      ,.reset_i(reset_i | transaction_done)
      ,.en_i(word_received)
      ,.data_i(data_en_li << 1)
      ,.data_o(data_en_li)
      );

    // Registered data words (all but final word of full message will be registered)
    for (genvar i = 0; i < max_els_p-1; i++)
      begin: rof
        bsg_dff_en_bypass
       #(.width_p(width_p      )
        ) data_dff
        (.clk_i  (clk_i        )
        ,.data_i (data_i       )
        ,.en_i   (data_en_li[i])
        ,.data_o (data_o    [i])
        );
      end
    // final word of full message is passed through directly to output
    assign data_o[max_els_p-1] = data_i;

    // data valid register
    // output data becomes available the cycle following the last input word
    logic last_r;
    bsg_dff_reset_set_clear
    #(.width_p(1)
      ,.clear_over_set_p(1)
      )
    last_dff
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.set_i(last_word_received)
      ,.clear_i(transaction_done)
      ,.data_o(last_r)
      );

    // data becomes valid when last_i is raised as last word is simply passed
    // through directly to output or when the last word has been captured into
    // the data_dff if the input message has fewer than max_els_p words.
    // v_o is also raised if last element is valid on input
    assign v_o = last_i | last_r | (v_i & data_en_li[max_els_p-1]);

    // For messages with max_els_p input words unit is always ready until
    // reaching the last input word, indicated by the highest bit of
    // data_en_li being set, at which point the last word will be passed
    // directly through to the output channel and the ready signals need to be
    // connected.
    // For messages with fewer than max_els_p words, module is ready until the
    // cycle after the last word is captured. If the last word arrives and
    // output channel is not ready, that word will be captured into the
    // data_dff and last_r will be set. The following cycle last_r will be
    // high, indicating that all the data has arrived for the current
    // transaction and no more data should be accepted until a new transaction
    // starts.
    assign ready_and_o = data_en_li[max_els_p-1]
                         ? ready_and_i
                         : ~last_r;

  end

endmodule
