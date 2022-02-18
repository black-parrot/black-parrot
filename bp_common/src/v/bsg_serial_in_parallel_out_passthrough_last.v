/**
 * bsg_serial_in_parallel_out_passthrough_last.v
 *
 * This data structure takes in single word serial input and deserializes it
 * to multi-word data output. This module is helpful on both sides, both v_o
 * and ready_and_o are early.
 *
 * This module passes through the last input data word directly to the output
 * and can handle transactions with fewer than max_els_p input words.
 *
 * The last_i signal must be raised early with v_i when the last serial word
 * is available on the input and the input will not fill the SIPO (i.e., less
 * than max_els_p are being deserialized to the parallel output).
 *
 * If max_els_p == 1 then this module simply passes through the signals.
 * Otherwise, the output becomes valid when either the SIPO is filled (final
 * word is valid on the input) or the sender indicates the last word of the
 * transaction is arriving on the input by raising last_i.
 *
 */

`include "bsg_defines.v"

module bsg_serial_in_parallel_out_passthrough_last

 #(parameter `BSG_INV_PARAM(width_p)
  ,parameter `BSG_INV_PARAM(max_els_p)
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
    logic [max_els_p-1:0] data_en_li;
    bsg_counter_clear_up_one_hot
    #(.max_val_p(max_els_p-1))
    data_en_counter
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.clear_i(transaction_done)
      ,.up_i(word_received & ~transaction_done)
      ,.count_r_o(data_en_li)
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
    // holds v_o high after last input word is consumed, until data_o sends
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

    // data is valid on output when:
    // 1. current valid input element is the last element required to fill the SIPO
    // 2. last_i is raised, indicating input transaction last word is arriving
    //    in the current cycle
    // 3. last_r is raised, indicating last word of input transaction was
    //    registered in a previous cycle, and waiting for output to consume
    assign v_o = last_i | last_r | (v_i & data_en_li[max_els_p-1]);

    // module is ready to consume data when:
    // 1. if waiting for the final input word to "fill" the SIPO, patch through ready_and_i
    //    from the output side because word is passed through without being registered
    // 2. otherwise, only consume more words if last_r is not set because the SIPO
    //    is not full and the input has not indicated that a previous word was the last word
    //    of the current transaction
    assign ready_and_o = data_en_li[max_els_p-1]
                         ? ready_and_i
                         : ~last_r;

  end

endmodule

`BSG_ABSTRACT_MODULE(bsg_serial_in_parallel_out_passthrough_last)

