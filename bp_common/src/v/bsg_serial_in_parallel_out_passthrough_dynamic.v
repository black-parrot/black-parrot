/**
 * bsg_serial_in_parallel_out_passthrough_dynamic.v
 *
 * This data structure takes in single word serial input and deserializes it 
 * to multi-word data output. This module is helpful on both sides, both v_o 
 * and ready_and_o are early.
 *
 * By definition of ready-and handshaking, v_o must be earlier than 
 * ready_and_i. Since v_o depends on value of len_i, so len_i must not depend
 * on ready_and_i. For this reason, len_i signal is on the serial data side of 
 * the module and depends on v_i.
 *
 */

`include "bsg_defines.v"

module bsg_serial_in_parallel_out_passthrough_dynamic

 #(parameter width_p       = "inv"
  ,parameter max_els_p     = "inv"
  ,parameter lg_max_els_lp = `BSG_SAFE_CLOG2(max_els_p)
  )

  (input                               clk_i
  ,input                               reset_i

  ,input                               v_i
  ,input  [width_p-1:0]                data_i
  ,output                              ready_and_o
  //
  // When first_o is asserted, the upcoming data is the first word of a new 
  // transaction. It can be asserted regardless of value of ready_and_o.
  ,output                              first_o
  //
  // len_i indicates the length (number of data words) of the upcoming new
  // transaction. User need to guarantee that len_i is valid when first_o and
  // v_i are both asserted (when enqueueing the first data word of 
  // the new transaction).
  //
  // Note that len_i is represented by (length - 1), in order to use minimum
  // number of bits. For example, when a 4-word transaction is coming, len_i 
  // should be set to 3. Single word transaction should have len_i == 0.
  ,input  [lg_max_els_lp-1:0]          len_i

  ,output                              v_o
  ,output [max_els_p-1:0][width_p-1:0] data_o
  ,input                               ready_and_i
  );

  if (max_els_p == 1)
  begin : single_word

    assign v_o         = v_i;
    assign data_o      = data_i;
    assign ready_and_o = ready_and_i;
    assign first_o     = 1'b1;

  end
  else
  begin : multi_word

    logic [lg_max_els_lp-1:0] count_r, len_r;
    logic is_zero_cnt, is_last_cnt, is_zero_len, is_waiting;
    logic en_li, clear_li, up_li;
    logic [max_els_p-1:0] data_en_li;

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

    // Count how many words have been received in each transaction
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
    // Last count indicates receiving last data word of transaction
    // Zero length means the upcoming new transaction has single data word
    assign is_zero_cnt = (count_r == (lg_max_els_lp)'(0));
    assign is_last_cnt = ~is_zero_cnt & (count_r == len_r);
    assign is_zero_len = v_i & (len_i == (lg_max_els_lp)'(0));
    //
    // There is a special case for single word transaction, when v_i==1
    // and ready_and_i==0, ready_and_o is asserted and data word is stored
    // into dff_bypass. In next several cycles, the module will "wait" for 
    // ready_and_i==1 and then proceed to next transaction.
    //
    // This does not happen when len_i>0, because ready_and_o will not be 
    // asserted when ready_and_i==0 and count_r==len_r. len_r is available 
    // from second word of each transaction. In idle state we cannot use 
    // len_i directly, because ready_and_o must not depend on len_i, where 
    // len_i depends on v_i.
    assign is_waiting  = ~is_zero_cnt & (len_r == (lg_max_els_lp)'(0));

    // Update length when receiving the first data word of new transaction
    // Count up when receiving data words
    // Clear the counter at the end of each transaction
    assign en_li       = v_i & ready_and_o & is_zero_cnt;
    assign up_li       = v_i & ready_and_o & ~clear_li;
    assign clear_li    = v_o & ready_and_i;

    // Output valid data after receiving all data words of each transaction
    // Also valid for special case of single word transation
    assign v_o         = (v_i & is_last_cnt) | is_zero_len | is_waiting;
    // Dequeue incoming serial data and store in registers. Last data word 
    // of each transaction is not registered to minimize hardware. Accept no 
    // data word when waiting to send previous single word transaction. 
    assign ready_and_o = (ready_and_i | ~is_last_cnt) & ~is_waiting;
    assign first_o     = is_zero_cnt;

    // Decide when to update data registers
    bsg_decode_with_v
   #(.num_out_p(max_els_p        )
    ) bdwv
    (.i        (count_r          )
    ,.v_i      (v_i & ~is_waiting)
    ,.o        (data_en_li       )
    );

    // Registered data words
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
    assign data_o[max_els_p-1] = data_i;

  end

endmodule
