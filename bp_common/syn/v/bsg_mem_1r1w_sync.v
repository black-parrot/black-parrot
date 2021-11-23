
`define bsg_mem_1r1w_sync_macro(words,bits)      \
  if (els_p == words && width_p == bits)         \
    begin: macro                                 \
      hard_mem_1r1w_d``words``_w``bits``_wrapper \
        mem                                      \
          (.clk_i   ( clk_i     )                \
          ,.reset_i ( reset_i   )                \
          ,.w_v_i   ( w_v_i     )                \
          ,.w_addr_i( w_addr_i  )                \
          ,.w_data_i( w_data_i  )                \
          ,.r_v_i   ( r_v_i    )                 \
          ,.r_addr_i( r_addr_i )                 \
          ,.r_data_o( r_data_o )                 \
          );                                     \
    end

module bsg_mem_1r1w_sync #( parameter `BSG_INV_PARAM(width_p)
                          , parameter `BSG_INV_PARAM(els_p)
                          , parameter read_write_same_addr_p = 0
                          , parameter addr_width_lp = `BSG_SAFE_CLOG2(els_p)
                          , parameter harden_p = 0
                          // NOTE: unused
                          , parameter substitute_1r1w_p = 0
                          )
  ( input clk_i
  , input reset_i
  
  , input                     w_v_i
  , input [addr_width_lp-1:0] w_addr_i
  , input [width_p-1:0]       w_data_i
  
  , input                      r_v_i
  , input [addr_width_lp-1:0]  r_addr_i
  , output logic [width_p-1:0] r_data_o
  );

  wire unused = reset_i;

  // TODO: Define more hardened macro configs here
  `bsg_mem_1r1w_sync_macro(64,50) else
  `bsg_mem_1r1w_sync_macro(1024,4) else

  // no hardened version found
    begin : notmacro
      initial if (substitute_1r1w_p != 0) $warning("substitute_1r1w_p will have no effect");
      bsg_mem_1r1w_sync_synth #(.width_p(width_p), .els_p(els_p), .read_write_same_addr_p(read_write_same_addr_p), .harden_p(harden_p))
        synth
          (.*);
    end // block: notmacro

  //synopsys translate_off
  always_ff @(posedge clk_i)
    if (w_v_i)
    begin
      assert (w_addr_i < els_p)
        else $error("Invalid address %x to %m of size %x\n", w_addr_i, els_p);

      assert (~(r0_addr_i == w_addr_i && w_v_i && r0_v_i && !read_write_same_addr_p))
        else $error("%m: port 0 Attempt to read and write same address");

      assert (~(r1_addr_i == w_addr_i && w_v_i && r1_v_i && !read_write_same_addr_p))
        else $error("%m: port 1 Attempt to read and write same address");
    end

  initial
    begin
      $display("## %L: instantiating width_p=%d, els_p=%d, read_write_same_addr_p=%d, harden_p=%d (%m)",width_p,els_p,read_write_same_addr_p,harden_p);
    end
  //synopsys translate_on

endmodule

`BSG_ABSTRACT_MODULE(bsg_mem_1r1w_sync)
