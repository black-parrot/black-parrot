//
// This data structure takes in a multi-word data and serializes
// it to a single word output. This module is helpful on both sides.
// Note:
//   A transaction starts when ready_and_o & v_i. data_i must
//     stay constant for the entirety of the transaction until
//     ready_and_o is asserted.
//   This may make the module incompatible with upstream modules that
//     multiplex multiple inputs and can change which input they multiplex
//     on the fly based on arrival of new inputs.

`include "bsg_defines.sv"

module bsg_parallel_in_serial_out_passthrough_dynamic #( parameter `BSG_INV_PARAM(width_p    )
                                                       , parameter `BSG_INV_PARAM(els_p      )
                                                       , parameter hi_to_lo_p = 0
                                                       , parameter lg_max_els_lp = `BSG_SAFE_CLOG2(els_p)
                                                       )
    ( input clk_i
    , input reset_i

    // Data Input Channel
    , input                           v_i
    , input  [els_p-1:0][width_p-1:0] data_i
    , input  [lg_max_els_lp-1:0]      len_i // Must remain constant
    , output                          ready_and_o

    // Data Output Channel
    , output               v_o
    , output [width_p-1:0] data_o
    , input                ready_and_i
    );

  logic [els_p-1:0] count_r;
  // For single word piso, we're just passing through the signals
  if (els_p == 1)
    begin : single_word
      assign count_r = 1'b1;
      assign ready_and_o = ready_and_i;
    end
  else
    begin : multi_word
      logic last_word;
      bsg_counter_clear_up_one_hot
       #(.max_val_p(els_p-1), .init_val_p(1))
       counter
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.clear_i(ready_and_o & v_i)
         ,.up_i(v_o & ready_and_i & ~last_word)
         ,.count_r_o(count_r)
         );

      assign last_word = count_r[len_i];

      assign ready_and_o = ready_and_i & last_word;
    end

  // If send hi_to_lo, reverse the input data array
  logic [els_p-1:0][width_p-1:0] data_li;

  if (hi_to_lo_p == 0)
    begin: lo2hi
      assign data_li = data_i;
    end
  else
    begin: hi2lo
      bsg_array_reverse
       #(.width_p(width_p), .els_p(els_p))
       bar
       (.i(data_i)
        ,.o(data_li)
        );
    end

  bsg_mux_one_hot
   #(.width_p(width_p), .els_p(els_p))
   data_mux
    (.data_i(data_li)
     ,.sel_one_hot_i(count_r)
     ,.data_o(data_o)
     );
  assign v_o = v_i;

  //synopsys translate_off
  logic [els_p-1:0][width_p-1:0] initial_data_r;
  bsg_dff_en
   #(.width_p(width_p*els_p))
   initial_data_reg
    (.clk_i(clk_i)
     ,.en_i(count_r[0] & v_i)

     ,.data_i(data_i)
     ,.data_o(initial_data_r)
     );

  always_ff @(negedge clk_i)
    begin
      if (~reset_i & (count_r[0] === 1'b0))
        begin
          assert (v_i)
            else $error("v_i must be held high during the entire PISO transaction");
          assert (data_i === initial_data_r)
            else $error("data_i must be held constant during the entire PISO transaction");
        end
    end
  //synopsys translate_on

endmodule

`BSG_ABSTRACT_MODULE(bsg_parallel_in_serial_out_passthrough_dynamic)

