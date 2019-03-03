/**
 *
 * test_bp.v
 *
 */

module test_bp
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter vtag_width_p="inv"
   ,parameter ptag_width_p="inv"
   ,parameter els_p="inv"
   
   ,localparam lg_els_lp=`BSG_SAFE_CLOG2(els_p)
   ,localparam entry_width_lp = `bp_be_tlb_entry_width(ptag_width_p)
 );
 
localparam mapSize = 100;
localparam testNum = 1000;
 
logic clk, reset;
logic [mapSize-1:0][vtag_width_p-1:0] vtag_map;
//logic [mapSize-1:0][ptag_width_p-1:0] ptag_map;
logic [mapSize-1:0]					  w_map;

initial begin
    for(integer i=0; i<mapSize; i+=1) begin
        vtag_map[i] = $random();
//        ptag_map[i] = $random();
    end
end

logic r_v_i, w_v_i, r_v_o, miss_o, en_i;
logic [vtag_width_p-1:0] r_vtag_i, w_vtag_i, miss_vtag_o;
logic [entry_width_lp-1:0] w_entry_i, r_entry_o;

logic [31:0] counter;
logic [31:0] addr;
logic [31:0] hit_cntr;

assign en_i     = 1'b1;
assign r_v_i    = ~(reset | miss_o);
assign r_vtag_i = vtag_map[addr];

always_ff @(posedge clk) begin
    if(reset) begin
        counter  <= '0;
		hit_cntr <= '0;
        addr     <= '0;
    end
    else begin
		
		if(r_v_i) begin
			counter <= counter + 'b1;
			addr     <= $urandom_range(0,mapSize-1);
		end
		
		if(r_v_o) begin
		//	$display("hit: %x", miss_vtag_o);
			hit_cntr <= hit_cntr + 'b1;
		end
		
        if(counter > testNum) begin
			$display("hit ratio: %d/%d", hit_cntr, testNum);
            $finish();
		end
    end
end

//always_ff @(posedge miss_o) begin
//	$display("miss: %x", miss_vtag_o);
//end

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

bp_be_dtlb
  #(.vtag_width_p(vtag_width_p)
    ,.ptag_width_p(ptag_width_p)
    ,.els_p(els_p)
  )
  tlb
  (.clk_i(clk)
   ,.reset_i(reset)
   ,.en_i(en_i)
   
   ,.r_v_i(r_v_i)
   ,.r_vtag_i(r_vtag_i)
   
   ,.r_v_o(r_v_o)
   ,.r_entry_o(r_entry_o)
   
   ,.w_v_i(w_v_i)
   ,.w_vtag_i(w_vtag_i)
   ,.w_entry_i(w_entry_i)
   
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
   ,.entry_o(w_entry_i)
  );

endmodule : test_bp