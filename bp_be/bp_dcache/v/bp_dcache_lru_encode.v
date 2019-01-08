/**
 *  bp_dcache_lru_encode.v
 *
 *  @author tommy
 */

module bp_dcache_lru_encode
  #(parameter ways_p="inv"
    ,parameter lg_ways_lp=`BSG_SAFE_CLOG2(ways_p)
  )
  (
    input [ways_p-2:0] lru_i
    ,output logic [lg_ways_lp-1:0] way_o
  );

  if (ways_p == 8) begin
    always_comb begin
      casez (lru_i)
        7'b???_0?00: way_o = 3'd0;
        7'b???_1?00: way_o = 3'd1;
        7'b??0_??10: way_o = 3'd2;
        7'b??1_??10: way_o = 3'd3;
        7'b?0?_?0?1: way_o = 3'd4;
        7'b?1?_?0?1: way_o = 3'd5;
        7'b0??_?1?1: way_o = 3'd6;
        7'b1??_?1?1: way_o = 3'd7;
      endcase
    end
  end 

endmodule
