/*
 * bp_be_bserial_adder.v
 *
 * Notes: DOES NOT HANDLE OVERFLOW.  We'll probably need to have an exception be raised...if we
 *          care.  Benchmarks probably don't test this :)
 */ 


module bp_be_bserial_adder
  (input                         clk_i
   , input                       clr_i

   , input                       a_i
   , input                       b_i
   , output                      s_o
   );

logic c_r, c_n;

assign s_o = a_i ^ b_i ^ c_r;
assign c_n = (a_i & b_i) | (b_i & c_r) | (a_i & c_r);

always_ff @(posedge clk_i)
  begin
    if (clr_i)
        c_r <= 1'b0;
    else 
      begin
        c_r <= c_n;
      end
  end

endmodule : bp_be_bserial_adder

