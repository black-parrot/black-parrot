
module bp_be_bserial_alu
 import bp_be_rv64_pkg::*;
 import bp_be_bserial_pkg::*;
 #(localparam opcode_width_lp  = `bp_be_bserial_opcode_width

   , localparam reg_data_width_lp = rv64_reg_data_width_gp)
  (input                         clk_i
   , input                       reset_i 

   , input                       clr_i
   , input                       set_i
  
   , input                       a_i
   , input                       b_i

   , input [opcode_width_lp-1:0] op_i

   , output                      s_o
   );

// Casting
bp_be_bserial_opcode_e op;
logic c_n, c_r;
logic s, s_r;

assign op  = bp_be_bserial_opcode_e'(op_i);
assign s_o = s;

always_comb 
  begin
    unique case (op)
      e_bserial_op_add: 
        begin
          s = a_i ^ b_i ^ c_r;
          c_n = (a_i & b_i) | (b_i & c_r) | (a_i & c_r);
        end

      e_bserial_op_sub:
        begin
          s = a_i ^ ~b_i ^ c_r;
          c_n = (a_i & ~b_i) | (~b_i & c_r) | (a_i & c_r);
        end

      e_bserial_op_sll:
        begin
          s = 1'b0;
          c_n = '0;
        end

      e_bserial_op_sext:
        begin
          s = s_r;
          c_n = 1'b0;
        end

      e_bserial_op_ne:
        begin
          s   = c_r | (a_i != b_i);
          c_n = c_r | (a_i != b_i);
        end

      e_bserial_op_eq:
        begin
          s   = ~(c_r | (a_i != b_i));
          c_n =   c_r | (a_i != b_i); 
        end

      e_bserial_op_and:
        begin
          s = a_i & b_i;
          c_n = 1'b0;
        end

      e_bserial_op_or:
        begin
          s = a_i | b_i;
          c_n = 1'b0;
        end

      e_bserial_op_xor:
        begin
          s = a_i ^ b_i;
          c_n = 1'b0;
        end

      e_bserial_op_passb:
        begin
          s = b_i;
          c_n = 1'b0;
        end

      default:
        begin
          $display("ERROR: op %s not currently supported", op);
          s = 1'b0;
          c_n = 1'b0;
        end
    endcase
  end

always_ff @(posedge clk_i)
  begin
    if (reset_i | set_i | clr_i)
      begin
        c_r <= set_i & ~clr_i & ~reset_i;
        s_r <= 1'b0;
      end
    else 
      begin
        c_r <= c_n;
        s_r <= s;
      end
  end

endmodule : bp_be_bserial_alu

