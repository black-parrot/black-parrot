
`define bsg_mem_1rw_sync_mask_write_byte_macro(words,bits) \
  if (els_p == words && data_width_p == bits)              \
    begin: macro                                           \
      hard_mem_1rw_byte_mask_d``words``_w``bits``_wrapper  \
        mem                                                \
          (.clk_i        (clk_i)                           \
          ,.reset_i      (reset_i)                         \
          ,.v_i          (v_i)                             \
          ,.w_i          (w_i)                             \
          ,.addr_i       (addr_i)                          \
          ,.data_i       (data_i)                          \
          ,.write_mask_i (write_mask_i)                    \
          ,.data_o       (data_o)                          \
          );                                               \
    end: macro

`define bsg_mem_1rw_sync_mask_write_byte_banked_macro(words,bits,wbank,dbank) \
  if (els_p == words && data_width_p == bits) begin: macro                    \
      bsg_mem_1rw_sync_mask_write_byte_banked #(                              \
        .data_width_p(data_width_p)                                           \
        ,.els_p(els_p)                                                        \
        ,.latch_last_read_p(latch_last_read_p)                                \
        ,.num_width_bank_p(wbank)                                             \
        ,.num_depth_bank_p(dbank)                                             \
      ) bmem (                                                                \
        .clk_i(clk_i)                                                         \
        ,.reset_i(reset_i)                                                    \
        ,.v_i(v_i)                                                            \
        ,.w_i(w_i)                                                            \
        ,.addr_i(addr_i)                                                      \
        ,.data_i(data_i)                                                      \
        ,.write_mask_i(write_mask_i)                                          \
        ,.data_o(data_o)                                                      \
      );                                                                      \
    end: macro

module bsg_mem_1rw_sync_mask_write_byte #( parameter `BSG_INV_PARAM(els_p )
                                         , parameter `BSG_INV_PARAM(data_width_p )
                                         , parameter addr_width_lp = `BSG_SAFE_CLOG2(els_p)
                                         , parameter write_mask_width_lp = data_width_p>>3
                                         , parameter latch_last_read_p = 0
                                         )

  ( input                                            clk_i
  , input                                            reset_i
  , input                                            v_i
  , input                                            w_i
  , input [addr_width_lp-1:0]                        addr_i
  , input [`BSG_SAFE_MINUS(data_width_p,1):0]        data_i
  , input [write_mask_width_lp-1:0]                  write_mask_i
  , output logic [`BSG_SAFE_MINUS(data_width_p,1):0] data_o
  );

  wire unused = reset_i;

  // TODO: Define more hardened macro configs here
  `bsg_mem_1rw_sync_mask_write_byte_macro(512,64) else
  `bsg_mem_1rw_sync_mask_write_byte_banked_macro(1024,512,8,2) else
  // no hardened version found
    begin : notmacro
      bsg_mem_1rw_sync_mask_write_byte_synth #(.data_width_p(data_width_p), .els_p(els_p), .latch_last_read_p(latch_last_read_p))
        synth
          (.*);
    end // block: notmacro


  // synopsys translate_off
  always_comb
    begin
      assert (data_width_p % 8 == 0)
        else $error("data width should be a multiple of 8 for byte masking");
    end

  initial
    begin
      $display("## bsg_mem_1rw_sync_mask_write_byte: instantiating data_width_p=%d, els_p=%d (%m)",data_width_p,els_p);
    end
  // synopsys translate_on
   
endmodule

`BSG_ABSTRACT_MODULE(bsg_mem_1rw_sync_mask_write_byte)

