
module bp_be_bserial_alu
 #(localparam opcode_width_lp = 4)
  (input                         a_i
   , input                       b_i
   , input                       c_i

   , input [opcode_width_lp-1:0] op_i

   , output                      s_o
   , output                      c_o
   );

always_comb 
  begin
    unique case (op_i)
      e_bserial_add: 
        begin
          s_o = a_i ^ b_i ^ c_i;
          c_o = (a_i & b_i) | (b_i & c_i) | (a_i & c_i);
        end

      e_bserial_and:
        begin
          s_o = a_i & b_i;
          c_o = 1'b0;
        end

      e_bserial_or:
        begin
          s_o = a_i | b_i;
          c_o = 1'b0;
        end

      e_bserial_xor:
        begin
          s_o = a_i ^ b_i;
          c_o = 1'b0;
        end

      e_bserial_sltu:
        begin
          s_o = (~a_i & b_i) | c_i;
          c_o = c_i;
        end

      default:
        begin
          s_o = 1'b0;
          c_o = 1'b0;
        end
    endcase
  end

endmodule : bp_be_bserial_alu

