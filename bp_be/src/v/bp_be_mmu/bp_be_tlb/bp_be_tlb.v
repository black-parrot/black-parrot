//`include "bp_plru.v"

module bp_be_tlb
 #(parameter vtag_width_p="inv"
   ,parameter ptag_width_p="inv"
   ,parameter els_p="inv"
   
   ,localparam lg_els_lp=`BSG_SAFE_CLOG2(els_p)
 )
 (input 							clk_i
  , input 							reset_i
  
  , input 							r_v_i
  , input [vtag_width_p-1:0] 		r_vtag_i
  
  , input							w_v_i
  , input [vtag_width_p-1:0]		w_vtag_i
  , input [ptag_width_p-1:0]		w_ptag_i
  
  , output logic 					r_v_o
  , output logic [ptag_width_p-1:0]	r_ptag_o
  , output logic 					tlb_miss_o
 );
  
  
logic [vtag_width_p-1:0] 	cam_w_data_i;
logic [lg_els_lp-1:0] 		cam_w_addr_i, cam_r_addr_o, cam_empty_addr_o, victim_addr, ram_addr_i;
logic 						cam_w_v_i, cam_w_set_not_clear_i, cam_r_v_o, cam_empty_v_o;
logic [ptag_width_p-1:0]	ram_data_o;

assign r_ptag_o 	= ram_data_o;

assign cam_w_addr_i = (cam_empty_v_o)? cam_empty_addr_o : victim_addr;
assign ram_addr_i	= (w_v_i)? cam_w_addr_i : cam_r_addr_o;


always_ff @(posedge clk_i) begin
	tlb_miss_o	<= r_v_i & ~cam_r_v_o;
	r_v_o		<= r_v_i & cam_r_v_o;
end


  
bp_plru #(.ways_p(els_p))
  plru
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   
   ,.v_i(cam_r_v_o)
   ,.way_i(cam_r_addr_o)
   
   ,.way_o(victim_addr)
  );
  
  
bp_tlb_cam 
  #(.els_p(els_p)
    ,.width_p(vtag_width_p)
  )
  cam
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   
   ,.w_v_i(w_v_i)
   ,.w_addr_i(cam_w_addr_i)
   ,.w_data_i(w_vtag_i)
  
   ,.r_v_i(r_v_i)
   ,.r_data_i(r_vtag_i)
   
   ,.r_v_o(cam_r_v_o)
   ,.r_addr_o(cam_r_addr_o)
   
   ,.empty_v_o(cam_empty_v_o)
   ,.empty_addr_o(cam_empty_addr_o)
  );
  
bsg_mem_1rw_sync_synth
  #(.width_p(ptag_width_p)
    ,.els_p(els_p)
  )
  ram
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.data_i(w_ptag_i)
   ,.addr_i(ram_addr_i)
   ,.v_i(1'b1)
   ,.w_i(w_v_i)
   ,.data_o(ram_data_o)
  );

endmodule