
`ifndef BP_COMMON_TEST_DEFINES_SVH
`define BP_COMMON_TEST_DEFINES_SVH

  `define declare_bp_tracer_control(clk_mp, reset_mp, en_mp, str_mp, n_mp) \
      enum logic [1:0] { e_init, e_go, e_stop } state_n, state_r;          \
      wire is_init = (state_r == e_init);                                  \
      wire is_go   = (state_r == e_go);                                    \
      wire is_stop = (state_r == e_stop);                                  \
      wire do_init = (state_r == e_init) && (state_n == e_go);             \
                                                                           \
      int file, inited;                                                    \
      initial                                                              \
        begin                                                              \
          wait (!reset_mp);                                                \
          $display("BSG-INFO: %m initializing...");                        \
          file = $fopen($sformatf("%s_%d.trace", str_mp, n_mp), "w");      \
          inited = 1;                                                      \
        end                                                                \
                                                                           \
      always_comb                                                          \
        case (state_r)                                                     \
          e_stop  : state_n =  en_mp  ? e_go   : state_r;                  \
          e_go    : state_n = ~en_mp  ? e_stop : state_r;                  \
          /*e_init*/                                                       \
          default : state_n = inited ? e_stop : state_r;                   \
        endcase                                                            \
                                                                           \
      always_ff @(posedge clk_mp)                                          \
        if (reset_mp) state_r <= e_init; else state_r <= state_n;          \
                                                                           \
      final                                                                \
        begin                                                              \
          $display("BSG-INFO: %m terminating...");                         \
        end

`endif

