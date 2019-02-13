 
`timescale 1ns/1ps

module test_bp
	#(
		parameter width_p="inv"
		,parameter els_p="inv"
		,parameter ready_THEN_valid_p="inv"
		
		,parameter testCycles="inv"
	);

	bsg_nonsynth_clock_gen #(.cycle_time_p(1)
                         )
              clock_gen (.o(clk)
                         );
						 
	bsg_nonsynth_reset_gen #(.num_clocks_p(1)
                         ,.reset_cycles_lo_p(1)
                         ,.reset_cycles_hi_p(1)
                         )
               reset_gen(.clk_i(clk)
                         ,.async_reset_o(reset)
                         );
		
	logic [$clog2(testCycles+1):0] counter;
	
	logic clear_i;
	logic [width_p-1:0] data_i;
	logic v_i;
	logic ready_o;
	
	logic [width_p-1:0] data_o;     
	logic v_o;   
	logic yumi_i;
	logic rollback_v_i;
	logic ckpt_inc_v_i;
	logic ckpt_inc_ready_o;
	
	logic [els_p-1:0][width_p-1:0] sim_fifo;
	logic [els_p-1:0] sim_wptr;
	logic [els_p-1:0] sim_rptr;
	logic [els_p-1:0] sim_ckpt;
	logic [width_p-1:0]  sim_data_o;
	
	assign sim_data_o = sim_fifo[sim_rptr];
	
	assign clear_i			= $random() % 10 == 0;
	assign v_i 				= (~ready_THEN_valid_p | ready_o) & $random();
	assign ckpt_inc_v_i 	= (~ready_THEN_valid_p | ckpt_inc_ready_o) & ($random() % 10 == 0);

	assign yumi_i 			= v_o & $random();
	assign rollback_v_i 	= $random() % 10 == 0;
	
	always_ff @(posedge clk) begin
		if(reset) begin
			$display("-------------- Test Start! -------------");
			data_i 			<= {width_p{1'b0}};
			counter			<= 0;
			
			sim_wptr		<= 0;
			sim_rptr		<= 0;
			sim_ckpt		<= 0;
			
		end else begin
			data_i 			<= data_i + 1;	
			counter 		<= counter + 1;
			
			//Write
			if(clear_i)
				sim_wptr			<= sim_rptr;
			else if((ready_THEN_valid_p | ready_o) & v_i) begin
				sim_wptr			<= (sim_wptr + 1) % els_p;
				sim_fifo[sim_wptr] 	<= data_i;
			end
			
			//Read
			if(rollback_v_i)
				sim_rptr		<= sim_ckpt;
			else if(yumi_i) begin
				sim_rptr		<= (sim_rptr + 1) % els_p;
			end
			
			//Checkpoint
			if((ready_THEN_valid_p | ckpt_inc_ready_o) & ckpt_inc_v_i) begin
				sim_ckpt		<= (sim_ckpt + 1) % els_p;
			end
		
			if(v_o) begin
				if(sim_data_o != data_o) begin
					$display("--------- Error!----------");
					$display("expected %x but got %x", sim_data_o, data_o);
					$finish();
				end
			end
		
			if(counter == testCycles) begin
				$display("-------------- Test Successful! -------------");
				$finish();
			end
		
		end
	
	end

	bsg_fifo_1r1w_rolly
    	#(
    		.width_p				(width_p)
    		,.els_p                 (els_p)
			,.ready_THEN_valid_p	(ready_THEN_valid_p)
    	)
	DUT
    	(
    		.clk_i			(clk)
    		,.reset_i       (reset)
    		,.clear_i       (clear_i)
			
			,.ckpt_inc_v_i		(ckpt_inc_v_i)
			,.ckpt_inc_ready_o	(ckpt_inc_ready_o)
			
			,.rollback_v_i	(rollback_v_i)
			
			,.data_i		(data_i)
			,.v_i           (v_i)
			,.ready_o       (ready_o)
			                
			,.data_o        (data_o)
			,.v_o           (v_o)
			,.yumi_i        (yumi_i)
    	);
		
endmodule
