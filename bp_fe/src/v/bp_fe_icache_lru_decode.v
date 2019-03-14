/**
 *  Name:
 *    bp_be_dcache_lru_decode.v
 *
 *  Description:
 *    LRU decode unit. Given input referred way_id, generate data and mask that updates
 *    the pseudo-LRU tree. Data and mask is chosen so that referred way_id is
 *    no longer the LRU way.
 */

module bp_fe_icache_lru_decode
  #(parameter ways_p="inv"
    , localparam way_id_width_lp=`BSG_SAFE_CLOG2(ways_p)
  )
  (
    input [way_id_width_lp-1:0] way_id_i
    , output logic [ways_p-2:0] data_o
    , output logic [ways_p-2:0] mask_o
  );

  if (ways_p == 8) begin
    always_comb begin
      case (way_id_i)
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
  
  // ways = 4
  else if (ways_p == 4) begin
    always_comb begin
      case (way_id_i)
        2'b00: begin
          data_o = 3'b011;
          mask_o = 3'b011;
        end
        2'b01: begin
          data_o = 3'b001;
          mask_o = 3'b011;
        end
        2'b10: begin
          data_o = 3'b100;
          mask_o = 3'b101;
        end
        2'b11: begin
          data_o = 3'b000;
          mask_o = 3'b101;
        end
      endcase
    end
  end
  
  // ways = 2
  else if (ways_p == 2) begin
    always_comb begin
      case (way_id_i)
        1'b0: begin
          data_o = 1'b1;
          mask_o = 1'b1;
        end
        1'b1: begin
          data_o = 1'b0;
          mask_o = 1'b1;
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
