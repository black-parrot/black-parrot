
module bp_fe_itlb
 #(parameter vtag_width_p="inv"
   ,parameter ptag_width_p="inv"
   ,parameter els_p="inv"
   ,parameter passthrough_tlb="inv"
   ,localparam lg_els_lp=`BSG_SAFE_CLOG2(els_p)
   ,parameter ppn_start_bit_p="inv"
 )
 (input                             clk_i
  , input                           reset_i
  
  // Connections to Cache
  , input                           r_v_i
  , input [vtag_width_p-1:0]        r_vtag_i //change it to .vtag right now it receives the lowest bits if you reduce the width to vtag_width_p ==> so change it to pass the exact part of the address which is vtag

  , input [63:0]                    vaddr_i   
  , output logic                    r_v_o
  , output logic [ptag_width_p-1:0] r_ptag_o
  
  // Connections to PTW
  , input                           w_v_i
  , input [vtag_width_p-1:0]        w_vtag_i
  , input [ptag_width_p-1:0]        w_ptag_i
  
  , output logic                    miss_v_o
  , output logic [vtag_width_p-1:0] miss_vtag_o
  , output [63:0]                   miss_vaddr
 );
  
  
logic [vtag_width_p-1:0]       cam_w_data_i;
logic [lg_els_lp-1:0]          cam_w_addr_i, cam_r_addr_o, cam_empty_addr_o, victim_addr, ram_addr_i;
logic                          cam_w_v_i, cam_w_set_not_clear_i, cam_r_v_o, cam_empty_v_o;
logic [ptag_width_p-1:0]       ram_data_o;
logic 		               tlb_r_v_o;
logic 		               itlb_miss_v_o;
logic [ptag_width_p-1:0]       ppn;
logic [ptag_width_p-1:0]       tlb_r_ptag_o;
logic [63:0] 	               itlb_miss_vaddr;
   
   
assign tlb_r_ptag_o = ram_data_o;
assign cam_w_addr_i = (cam_empty_v_o)? cam_empty_addr_o : victim_addr;
assign ram_addr_i   = (w_v_i)? cam_w_addr_i : cam_r_addr_o;

assign r_v_o = (passthrough_tlb) ? 1'b1 : tlb_r_v_o;
assign miss_v_o = (passthrough_tlb) ? 1'b0 : itlb_miss_v_o;
   
always @(posedge clk_i)
  begin
     ppn <= vaddr_i[ppn_start_bit_p+ptag_width_p-1:ppn_start_bit_p];
     itlb_miss_vaddr <= vaddr_i;
  end

assign miss_vaddr = itlb_miss_vaddr;   
assign r_ptag_o = (passthrough_tlb) ? ppn : tlb_r_ptag_o;
   
   
bsg_dff_reset #(.width_p(1))
  r_v_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.data_i(r_v_i & cam_r_v_o)
   ,.data_o(tlb_r_v_o)
  );

bsg_dff_reset_en #(.width_p(1))
  miss_v_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i | w_v_i)
   ,.en_i(r_v_i)
   ,.data_i(~cam_r_v_o)
   ,.data_o(itlb_miss_v_o)
  );

bsg_dff_reset_en #(.width_p(vtag_width_p))
  miss_vtag_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(r_v_i)
   ,.data_i(r_vtag_i)
   ,.data_o(miss_vtag_o)
  );
  
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
  vtag_cam
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
  ptag_ram
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.data_i(w_ptag_i)
   ,.addr_i(ram_addr_i)
   ,.v_i(cam_r_v_o | w_v_i)
   ,.w_i(w_v_i)
   ,.data_o(ram_data_o)
  );

endmodule