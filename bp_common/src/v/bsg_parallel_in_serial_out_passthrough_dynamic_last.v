/**
 * bsg_parallel_in_serial_out_passthrough_dynamic_last.v
 *
 * This data structure takes in a multi-word parallel input and serializes
 * it to a single word output. This module is helpful on both sides, both v_o
 * and ready_and_o are early.
 *
 * Note:
 *   A transaction starts when ready_and_o & v_i. data_i must
 *     stay constant for the entirety of the transaction until
 *     ready_and_o is asserted.
 *   This may make the module incompatible with upstream modules that
 *     multiplex multiple inputs and can change which input they multiplex
 *     on the fly based on arrival of new inputs.
 *
 * By definition of ready-and handshaking, ready_and_o must be earlier than
 * v_i. Since ready_and_o depends on value of len_i, so len_i must not depend
 * on v_i. For this reason, len_i signal is on the serial data side of the
 * module and depends on ready_and_i.
 *
 */

`include "bsg_defines.v"

module bsg_parallel_in_serial_out_passthrough_dynamic_last
 #(parameter `BSG_INV_PARAM(width_p)
   , parameter `BSG_INV_PARAM(max_els_p)
   , parameter lg_max_els_lp = `BSG_SAFE_CLOG2(max_els_p)
   )

  (input                               clk_i
  ,input                               reset_i

  // Data Input Channel
  ,input                               v_i
  ,input  [max_els_p-1:0][width_p-1:0] data_i
  ,output                              ready_and_o

  // Data Output Channel
  ,output                              v_o
  ,output [width_p-1:0]                data_o
  ,input                               ready_and_i

  // len_i is a zero-based count of the number of output words that will be
  // consumed by the output channel for each new transaction. It must be
  // provided when the output channel consumes the first output beat (i.e.,
  // when v_o & ready_and_i are both raised). A valid len_i is required for
  // every transaction, even if the output will consume all of the serial
  // output words.
  ,input  [lg_max_els_lp-1:0]          len_i

  // last_o is raised when the last serial word is valid on the output
  ,output logic                        last_o
  );

  if (max_els_p == 1)
  begin : single_word

    assign v_o         = v_i;
    assign data_o      = data_i;
    assign ready_and_o = ready_and_i;
    assign last_o      = 1'b1;

  end
  else
  begin : multi_word

    logic [lg_max_els_lp-1:0] count_r, len_r;
    logic is_zero_cnt, is_last_cnt, is_zero_len;
    logic en_li, clear_li, up_li;

    // Register the length of upcoming transaction
    // Add reset to prevent X-pessimism issue in simulation
    bsg_dff_reset_en
   #(.width_p    (lg_max_els_lp)
    ,.reset_val_p(0            )
    ) len_dff
    (.clk_i      (clk_i        )
    ,.reset_i    (reset_i      )
    ,.data_i     (len_i        )
    ,.en_i       (en_li        )
    ,.data_o     (len_r        )
    );

    // Count how many words have been sent in each transaction
    bsg_counter_clear_up
   #(.max_val_p (max_els_p-1)
    ,.init_val_p(0          )
    ) ctr
    (.clk_i     (clk_i      )
    ,.reset_i   (reset_i    )
    ,.clear_i   (clear_li   )
    ,.up_i      (up_li      )
    ,.count_o   (count_r    )
    );

    // Zero count means idle state, accepting new transaction
    // Last count indicates sending last data word of transaction
    // Zero length means the upcoming new transaction has single data word
    assign is_zero_cnt = (count_r == (lg_max_els_lp)'(0));
    assign is_last_cnt = ~is_zero_cnt & (count_r == len_r);
    assign is_zero_len = is_zero_cnt & (len_i == (lg_max_els_lp)'(0));

    // Update length when sending the first data word of new transaction
    // Count up when sending out data words
    // Clear the counter at the end of each transaction
    assign en_li       = v_o & ready_and_i & is_zero_cnt;
    assign up_li       = v_o & ready_and_i & ~clear_li;
    assign clear_li    = v_i & ready_and_o;

    // Output valid data when input data is valid, there is no registered data
    // in this module.
    assign v_o         = v_i;
    // Dequeue incoming parallel data at the end of each transaction.
    // When incoming data is single-word, dequeue immediately.
    assign ready_and_o = ready_and_i & (is_last_cnt | is_zero_len);
    // last_o is raised on last data word being output
    assign last_o      = is_zero_len | is_last_cnt;

    // Output data
    bsg_mux
   #(.width_p(width_p  )
    ,.els_p  (max_els_p)
    ) data_mux
    (.data_i (data_i   )
    ,.sel_i  (count_r  )
    ,.data_o (data_o   )
    );

    //synopsys translate_off
    logic [max_els_p-1:0][width_p-1:0] initial_data_r;
    bsg_dff_en
   #(.width_p(width_p*max_els_p)
    ) initial_reg
    (.clk_i  (clk_i            )
    ,.en_i   (is_zero_cnt & v_i)
    ,.data_i (data_i           )
    ,.data_o (initial_data_r   )
    );
    always_ff @(negedge clk_i)
      begin
        if (~reset_i & ~is_zero_cnt)
          begin
            assert (v_i)
              else $error("v_i must be held high during the entire PISO transaction");
            assert (data_i == initial_data_r)
              else $error("data_i must be held constant during the entire PISO transaction");
          end
      end
    //synopsys translate_on
  end

endmodule

`BSG_ABSTRACT_MODULE(bsg_parallel_in_serial_out_passthrough_dynamic_last)

