
`define bsg_mem_1rw_sync_macro(words,bits)      \
  if (els_p == words && width_p == bits)        \
    begin: macro                                \
      hard_mem_1rw_d``words``_w``bits``_wrapper \
        mem                                     \
          (.clk_i  (clk_i)                      \
          ,.reset_i(reset_i)                    \
          ,.data_i (data_i)                     \
          ,.addr_i (addr_i)                     \
          ,.v_i    (v_i)                        \
          ,.w_i    (w_i)                        \
          ,.data_o (data_o)                     \
          );                                    \
    end: macro

module bsg_mem_1rw_sync #( parameter `BSG_INV_PARAM(width_p )
                         , parameter `BSG_INV_PARAM(els_p )
                         , parameter addr_width_lp = `BSG_SAFE_CLOG2(els_p)
                         , parameter latch_last_read_p = 0
                         // NOTE: unused
                         , parameter substitute_1r1w_p = 0
                         , parameter verbose_if_synth_p = 0
                         )
  ( input                                       clk_i
  , input                                       reset_i

  , input [`BSG_SAFE_MINUS(width_p,1):0]        data_i
  , input [addr_width_lp-1:0]                   addr_i
  , input                                       v_i
  , input                                       w_i

  , output logic [`BSG_SAFE_MINUS(width_p,1):0] data_o
  );

  wire unused = reset_i;

  // TODO: Define more hardened macro configs here
  `bsg_mem_1rw_sync_macro(512,64) else

  // no hardened version found
    begin : notmacro
      initial if (substitute_1r1w_p != 0) $warning("substitute_1r1w_p will have no effect");
      bsg_mem_1rw_sync_synth #(.width_p(width_p), .els_p(els_p), .latch_last_read_p(latch_last_read_p))
        synth
          (.*);
    end // block: notmacro


  // synopsys translate_off
  initial
    begin
      $display("## %L: instantiating width_p=%d, els_p=%d, latch_last_read_p=%d (%m)",width_p,els_p,latch_last_read_p);
    end
  // synopsys translate_on

endmodule

`BSG_ABSTRACT_MODULE(bsg_mem_1rw_sync)
