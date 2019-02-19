/**
 *
 * test_bp.v
 *
 */

module test_bp
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 #(parameter vtag_width_p="inv"
   ,parameter ptag_width_p="inv"
   ,parameter els_p="inv"
   
   ,localparam lg_els_lp=`BSG_SAFE_CLOG2(els_p)
 );
 
localparam mapSize = 10;
 
logic clk, reset;
logic [mapSize-1:0][vtag_width_p-1:0] vtag_map;
logic [mapSize-1:0][ptag_width_p-1:0] ptag_map;
logic [mapSize-1:0]					  w_map;

initial begin
    for(integer i=0; i<mapSize; i+=1) begin
        vtag_map[i] = $random();
        ptag_map[i] = $random();
    end
end

logic r_v_i, w_v_i, r_v_o, miss_o;
logic [vtag_width_p-1:0] r_vtag_i, w_vtag_i, miss_vtag_o;
logic [ptag_width_p-1:0] w_ptag_i, r_ptag_o;

bsg_nonsynth_clock_gen #(.cycle_time_p(10)
                         )
              clock_gen (.o(clk)
                         );

bsg_nonsynth_reset_gen #(.num_clocks_p(1)
                         ,.reset_cycles_lo_p(1)
                         ,.reset_cycles_hi_p(4)
                         )
               reset_gen(.clk_i(clk)
                         ,.async_reset_o(reset)
                         );

bp_be_tlb
  #(.vtag_width_p(vtag_width_p)
    ,.ptag_width_p(ptag_width_p)
    ,.els_p(els_p)
  )
  tlb
  (.clk_i(clk)
   ,.reset_i(reset)
   
   ,.r_v_i(r_v_i)
   ,.r_vtag_i(r_vtag_i)
   
   ,.r_v_o(r_v_o)
   ,.r_ptag_o(r_ptag_o)
   
   ,.w_v_i(w_v_i)
   ,.w_vtag_i(w_vtag_i)
   ,.w_ptag_i(w_ptag_i)
   
   ,.miss_v_o(miss_o)
   ,.miss_vtag_o(miss_vtag_o)
  );
  
bp_be_mock_ptw
  #(.vtag_width_p(vtag_width_p)
    ,.ptag_width_p(ptag_width_p)
  )
  ptw
  (.clk_i(clk)
   ,.reset_i(reset)
   
   ,.miss_v_i(miss_o)
   ,.vtag_i(miss_vtag_o)
  
   ,.v_o(w_v_i)
   ,.vtag_o(w_vtag_i)
   ,.ptag_o(w_ptag_i)
  );


logic [31:0] counter;
logic [31:0] addr;

always_ff @(posedge clk) begin
    if(reset) begin
        r_v_i    <= '0;
        r_vtag_i <= '0;
        
        counter  <= '0;
        addr     <= '0;
    end
    else begin
        counter <= counter + 'b1;
        r_v_i <= '0;

        if(!miss_o && counter[0]) begin
		    addr     <= $urandom_range(0,mapSize-1);
            r_v_i    <= 'b1;
            r_vtag_i <= vtag_map[addr];
        end
        
        if(counter == 'd10000)
            $finish();
    end
end

endmodule : test_bp