/**
 *  bp_be_dcache_lru_decode.v
 */

module bp_be_dcache_lru_decode
  #(parameter ways_p="inv"
    , localparam lg_ways_lp=`BSG_SAFE_CLOG2(ways_p)
  )
  (
    input [lg_ways_lp-1:0] way_i
    , output logic [ways_p-2:0] data_o
    , output logic [ways_p-2:0] mask_o
  );

  if (ways_p == 8) begin
    always_comb begin
      case (way_i)
        3'b000: begin
          data_o = 7'b000_1011;
          mask_o = 7'b000_1011;
        end
        3'b001: begin
          data_o = 7'b000_0011;
          mask_o = 7'b000_1011;
        end
        3'b010: begin
          data_o = 7'b001_0001;
          mask_o = 7'b001_0011;
        end
        3'b011: begin
          data_o = 7'b000_0001;
          mask_o = 7'b001_0011;
        end
        3'b100: begin
          data_o = 7'b010_0100;
          mask_o = 7'b010_0101;
        end
        3'b101: begin
          data_o = 7'b000_0100;
          mask_o = 7'b010_0101;
        end
        3'b110: begin
          data_o = 7'b100_0000;
          mask_o = 7'b100_0101;
        end
        3'b111: begin
          data_o = 7'b000_0000;
          mask_o = 7'b100_0101;
        end
      endcase
    end
  end
  else begin
    initial begin
      assert("ways_p" == "unhandled") else $error("unhandled case for %m");
    end
  end

endmodule
