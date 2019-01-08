/**
 *
 * test_bp.v
 *
 */
 
`include "bp_common_fe_be_if.vh"

`define vaddr_width      			64
`define paddr_width            		64
`define asid_width  				4
`define branch_metadata_fwd_width	10

module test_bp;
	////////////////// generate clock 
	reg clk = 1'b1;
	always @(clk)
      clk <= #1 ~clk;
	  
	/////////////////  reset the module  
	reg reset;
	initial begin
		reset = 1'b0;
		@(posedge clk)
		reset = 1'b1;
		@(posedge clk)
		reset = 1'b0;
	end
	
	parameter vaddr_width_p=`vaddr_width;
	parameter paddr_width_p=`paddr_width;
	parameter asid_width_p=`asid_width;
	parameter branch_metadata_fwd_width_p=`branch_metadata_fwd_width;
	
	parameter bp_fe_queue_width_p=`bp_fe_queue_width(			
									`vaddr_width     			
									,`branch_metadata_fwd_width);
											
	parameter bp_fe_cmd_width_p=`bp_fe_cmd_width( 			
								   `vaddr_width    				
								   ,`paddr_width   				
								   ,`asid_width    				
								   ,`branch_metadata_fwd_width);
								   
	`declare_bp_fe_be_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
	
	logic [bp_fe_cmd_width_p-1:0] bp_fe_cmd_i;
	logic bp_fe_cmd_v_i;
	logic bp_fe_cmd_ready_o;
	
	logic [bp_fe_queue_width_p-1:0] bp_fe_queue_o;
	logic bp_fe_queue_v_o;
	logic bp_fe_queue_ready_i;
	
	bp_fe_queue_s	fe_queue;	
	bp_fe_cmd_s		fe_cmd;
	
	always_comb begin
		fe_queue = bp_fe_queue_o;
		bp_fe_cmd_i = fe_cmd;
	end

	
	
	initial begin
		bp_fe_cmd_v_i = 0;
		bp_fe_queue_ready_i = 1;
		
		for(integer i=0; i < 100; i=i+1) begin
			@(posedge clk);
			if(fe_queue.msg.fetch.pc == 64'h0c) begin
				bp_fe_cmd_v_i = 1;
				fe_cmd.command_queue_opcodes = e_op_pc_redirection;
				fe_cmd.operands.pc_redirect_operands.pc = 64'b0;
			end
			else
				bp_fe_cmd_v_i = 0;
			$display("Addr[%x]: %x", fe_queue.msg.fetch.pc, fe_queue.msg.fetch.instr);
		end
	
		$finish();
	end
	
	bp_be_nonsynth_mock_fe
	#(
		.vaddr_width_p(`vaddr_width)
		,.paddr_width_p(`paddr_width)
		,.asid_width_p(`asid_width)
		,.branch_metadata_fwd_width_p(`branch_metadata_fwd_width)
	)
	DUT
	(
		.clk_i(clk)
	    ,.reset_i(reset)
		
	    ,.bp_fe_cmd_i(bp_fe_cmd_i)
	    ,.bp_fe_cmd_v_i(bp_fe_cmd_v_i)
		,.bp_fe_cmd_ready_o(bp_fe_cmd_ready_o)
		
		,.bp_fe_queue_o(bp_fe_queue_o)
		,.bp_fe_queue_v_o(bp_fe_queue_v_o)
		,.bp_fe_queue_ready_i(bp_fe_queue_ready_i)
	);
	
endmodule
