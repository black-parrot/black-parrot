
`include "bp_common_fe_be_if.vh"

`include "bp_be_rv64_defines.vh"

module bp_be_nonsynth_mock_fe_trace
 /* TODO: Get rid of this */
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 #(parameter vaddr_width_p="inv"
   ,parameter paddr_width_p="inv"
   ,parameter asid_width_p="inv"
   ,parameter branch_metadata_fwd_width_p="inv"
   
   ,localparam bp_fe_queue_width_lp=`bp_fe_queue_width(vaddr_width_p     			
                        							   ,branch_metadata_fwd_width_p
                                                       )   
   										
   ,localparam bp_fe_cmd_width_lp=`bp_fe_cmd_width(vaddr_width_p    				
                    							   ,paddr_width_p   				
                    							   ,asid_width_p    				
                    							   ,branch_metadata_fwd_width_p
                                                   )
 
   ,localparam instr_width_lp=rv64_instr_width_gp
   ,localparam eaddr_width_lp=rv64_eaddr_width_gp
   ,localparam byte_width_lp=rv64_byte_width_gp
   ,localparam reg_data_width_lp=rv64_reg_data_width_gp
   ,localparam pc_entry_point_lp=bp_pc_entry_point_gp
   )
  (input logic                              clk_i
   ,input logic                             reset_i

   ,input logic [bp_fe_cmd_width_lp-1:0]    fe_cmd_i
   ,input logic                             fe_cmd_v_i
   ,output logic                            fe_cmd_rdy_o

   ,output logic [bp_fe_queue_width_lp-1:0] fe_queue_o
   ,output logic                            fe_queue_v_o
   ,input logic                             fe_queue_rdy_i
  );
	
	localparam rom_width_p = 100;
	localparam rom_addr_width_p = 16; 
	localparam ring_width_p = rom_width_p - 4;
	
	`declare_bp_common_fe_be_if_structs(vaddr_width_p,paddr_width_p,asid_width_p
								,branch_metadata_fwd_width_p);
		
	// Cast input and output ports
	bp_fe_cmd_s	  fe_cmd;
	bp_fe_queue_s fe_queue;
	
	assign fe_cmd 	  = fe_cmd_i;
	assign fe_queue_o = fe_queue;

	logic TR_reset_i;
	//logic 	TR_v_i;       
	//logic 	TR_data_i;    
	//logic 	TR_ready_o;             
	logic 	TR_v_o;       
	logic 	[ring_width_p-1:0] TR_data_o;    
	logic 	TR_yumi_i;    
	logic 	[rom_addr_width_p-1:0] TR_rom_addr_o;
	logic 	[rom_width_p-1:0] TR_rom_data_i;
	logic 	TR_done_o;    
	logic 	TR_error_o;   
	
	always_comb begin : fe_cmd_gen
	
		TR_reset_i = 0;
		TR_yumi_i = 1;
		if(fe_cmd_v_i & fe_cmd_rdy_o) begin
			case(fe_cmd.opcode)
				e_op_state_reset    : TR_reset_i = 1;
			//	e_op_pc_redirection : pc_n = fe_cmd.operands.pc_redirect_operands.pc;
			endcase
		end
	
		fe_cmd_rdy_o 	= 1;
	
		//pc_n = pc_r + 'd4;
		//if(fe_cmd_v_i & fe_cmd_rdy_o) begin
		//	case(fe_cmd.opcode)
		//		e_op_state_reset    : pc_n = pc_entry_point_lp;
		//		e_op_pc_redirection : pc_n = fe_cmd.operands.pc_redirect_operands.pc;
		//	endcase
		//end
	end
	
	always_comb begin : fe_queue_gen
		fe_queue_v_o = 1;
	
		fe_queue.msg_type 					    = e_fe_fetch;
		fe_queue.msg.fetch.pc 					= TR_data_o[32 +: 64];
		fe_queue.msg.fetch.instr 				= TR_data_o[0 +: 32];
		fe_queue.msg.fetch.branch_metadata_fwd 	= '0;
	end
	
	always_ff @(posedge clk_i) begin
		
	end
	
	bsg_fsb_node_trace_replay
	#(   
		.ring_width_p(ring_width_p)
		,.rom_addr_width_p(rom_addr_width_p)
	)
	TR
	(
		.clk_i			(clk_i)
		,.reset_i       (reset_i | TR_reset_i)
		,.en_i          (1'b1)
						
		,.v_i           (1'b0)
		,.data_i        ('0)
		,.ready_o       ()
					
		,.v_o           (TR_v_o)
		,.data_o        (TR_data_o)
		,.yumi_i        (TR_yumi_i)
					
		,.rom_addr_o    (TR_rom_addr_o)
		,.rom_data_i    (TR_rom_data_i)
					
		,.done_o        ()
		,.error_o       ()
	);
		
	rv64ui_p_add_trace_rom 
	#(
		.width_p(rom_width_p)
		,.addr_width_p(rom_addr_width_p)
	)
	TR_ROM
	(
		.addr_i(TR_rom_addr_o)
		,.data_o(TR_rom_data_i)
	);

endmodule

