
//
// This module fattens a skinny bitmasked RAM to a more PD-friendly wider ram
// It does so by 'folding' the RAM like so:
// [aa]
// [bb]
// [cc]      [bbaa]    
// [dd]  ->  [ddcc] -> [ddccbbaa]
// [ee]  ->  [ffee] -> [hhggffee]
// [ff]      [hhgg]
// [gg]
// [hh]
//
//
module bsg_mem_1r1w_sync_mask_write_bit_reshape #(parameter skinny_width_p=-1
                                                  , parameter skinny_els_p=-1
                                                  , parameter skinny_addr_width_lp=`BSG_SAFE_CLOG2(skinny_els_p)

                                                  , parameter fat_width_p=-1
                                                  , parameter fat_els_p=-1
                                                  , parameter fat_addr_width_lp=`BSG_SAFE_CLOG2(fat_els_p)

                                                  // We must drop one of the requests during
                                                  //   a silent conflict, this parameter
                                                  //   dictates which one
                                                  , parameter drop_write_not_read_p = 0

                                                  , parameter debug_lp = 0
                                                  )
   (input   clk_i
    , input reset_i

    , input                             w_v_i
    , input [skinny_width_p-1:0]        w_mask_i
    , input [skinny_addr_width_lp-1:0]  w_addr_i
    , input [skinny_width_p-1:0]        w_data_i

    , input                             r_v_i
    , input [skinny_addr_width_lp-1:0]  r_addr_i
    , output logic [skinny_width_p-1:0] r_data_o

    // This is a same cycle signal that there was a read/write conflict
    , output logic                      conflict_o
    );

  localparam offset_width_lp = $clog2(fat_width_p/skinny_width_p);
  logic [`BSG_SAFE_MINUS(offset_width_lp,1):0] fat_w_offset, fat_r_offset, fat_r_offset_r;
  if (skinny_width_p == fat_width_p)
    begin : ident
      assign fat_w_offset = '0;
      assign fat_r_offset = '0;
      assign fat_r_offset_r = '0;
    end
  else
    begin : nident
      assign fat_w_offset = w_addr_i[0+:offset_width_lp];
      assign fat_r_offset = r_addr_i[0+:offset_width_lp];

      bsg_dff_reset
       #(.width_p(offset_width_lp))
       fat_r_offset_reg
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.data_i(fat_r_offset)
         ,.data_o(fat_r_offset_r)
         );
    end

  logic rw_same_fat_addr;
  wire drop_read = w_v_i & rw_same_fat_addr & (drop_write_not_read_p == 0);
  wire drop_write = r_v_i & rw_same_fat_addr & (drop_write_not_read_p == 1);

  wire                            fat_w_v_li = w_v_i & ~drop_write;
  wire [fat_width_p-1:0]       fat_w_mask_li = w_mask_i << (fat_w_offset*skinny_width_p);
  wire [fat_addr_width_lp-1:0] fat_w_addr_li = w_addr_i[offset_width_lp+:fat_addr_width_lp];
  wire [fat_width_p-1:0]       fat_w_data_li = w_data_i << (fat_w_offset*skinny_width_p);

  wire                            fat_r_v_li = r_v_i & ~drop_read;
  wire [fat_addr_width_lp-1:0] fat_r_addr_li = r_addr_i[offset_width_lp+:fat_addr_width_lp];

  assign rw_same_fat_addr = (fat_r_addr_li == fat_w_addr_li);

  logic [fat_width_p-1:0] fat_r_data_lo;
  bsg_mem_1r1w_sync_mask_write_bit
   #(.width_p(fat_width_p), .els_p(fat_els_p))
   fat_mem
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.w_v_i(fat_w_v_li)
     ,.w_mask_i(fat_w_mask_li)
     ,.w_addr_i(fat_w_addr_li)
     ,.w_data_i(fat_w_data_li)

     ,.r_v_i(fat_r_v_li)
     ,.r_addr_i(fat_r_addr_li)
     ,.r_data_o(fat_r_data_lo)
     );

  bsg_mux
   #(.width_p(skinny_width_p), .els_p(fat_width_p/skinny_width_p))
   data_mux
    (.data_i(fat_r_data_lo)
     ,.sel_i(fat_r_offset_r)
     ,.data_o(r_data_o)
     );

  assign conflict_o = drop_read | drop_write;

  //synopsys translate_off
  initial
    begin
      assert (fat_width_p % skinny_width_p == 0) else $error("%m Fat width must be multiple of skinny width");
      assert (skinny_els_p % fat_els_p == 0) else $error("%m Skinny els must be a multiple of fat els");
    end

  logic r_v_r;
  logic [skinny_addr_width_lp-1:0] skinny_r_addr_r;
  logic [fat_addr_width_lp-1:0] fat_r_addr_r;

  bsg_dff
   #(.width_p(1+skinny_addr_width_lp+fat_addr_width_lp))
   read_reg
    (.clk_i(clk_i)
     ,.data_i({r_v_i, r_addr_i, fat_r_addr_li})
     ,.data_o({r_v_r, skinny_r_addr_r, fat_r_addr_r})
     );

  if (debug_lp)
    always_ff @(negedge clk_i)
      begin
        if (w_v_i)
            $display("%t [WRITE] Skinny[%x] = %b, WMASK: %b; Fat[%x] = %b, WMASK: %b", $time, w_addr_i, w_data_i, w_mask_i, fat_w_addr_li, fat_w_data_li, fat_w_mask_li);
        if (r_v_r)
            $display("%t [READ] Skinny[%x]: %b; Fat[%x]: %b", $time, skinny_r_addr_r, r_data_o, fat_r_addr_r, fat_r_data_lo);
      end
  //synopsys translate_on
   
endmodule
