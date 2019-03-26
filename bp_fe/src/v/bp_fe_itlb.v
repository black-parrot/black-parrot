module bp_fe_itlb
 #(parameter vtag_width_p  = "inv"
   , parameter ptag_width_p = "inv"
   , parameter els_p = "inv"
   , localparam lg_els_lp = `BSG_SAFE_CLOG2(els_p)
   , localparam entry_width_lp = `bp_be_tlb_entry_width(ptag_width_p)
   , parameter ppn_start_bit_p ="inv"
   )
  (input                               clk_i
   , input                             reset_i
   , input                             en_i

   // Connections to ICache
   , input                             r_v_i
   , input [vtag_width_p-1:0]          r_vtag_i
   , input [63:0]                      vaddr_i
     
   , output logic                      r_v_o
   , output logic [entry_width_lp-1:0] r_entry_o

   // Connections to BE
   , input                             w_v_i
   , input [vtag_width_p-1:0]          w_vtag_i
   , input [entry_width_lp-1:0]        w_entry_i

   , output logic                      miss_v_o
   , output logic [vtag_width_p-1:0]   miss_vtag_o
   , output [63:0]                     miss_vaddr
   );


`declare_bp_be_tlb_entry_s(ptag_width_p);

bp_be_tlb_entry_s r_entry, w_entry, r_entry_passthrough, ram_r_data;

logic [ptag_width_p-1:0] ppn;
logic [63:0] 	           itlb_miss_vaddr;


assign miss_vaddr = itlb_miss_vaddr;

always @(posedge clk_i)
  begin
    ppn <= vaddr_i[ppn_start_bit_p+ptag_width_p-1:ppn_start_bit_p];
    itlb_miss_vaddr <= vaddr_i;
  end

assign r_entry_o = r_entry;
assign w_entry   = w_entry_i;


logic [lg_els_lp-1:0] cam_w_addr, cam_r_addr, cam_empty_addr, victim_addr, ram_addr;
logic                 cam_r_v, cam_empty_v;
logic                 r_v_n, miss_v_n, en_r;


assign cam_w_addr                 = (cam_empty_v)? cam_empty_addr : victim_addr;
assign ram_addr                   = (w_v_i)? cam_w_addr : cam_r_addr;

assign r_entry_passthrough.ptag   = ppn;
assign r_entry_passthrough.extent = '0;
assign r_entry_passthrough.u      = '0;
assign r_entry_passthrough.g      = '0;
assign r_entry_passthrough.l      = '0;
assign r_entry_passthrough.x      = '0;

assign r_entry                    = (en_r)? ram_r_data : r_entry_passthrough;
assign r_v_n                      = (en_i)? (r_v_i & cam_r_v) : r_v_i;
assign miss_v_n                   = (en_i)? ~cam_r_v : 1'b0;


bsg_dff_reset #(.width_p(1))
 en_reg
  (.clk_i(clk_i)
	 ,.reset_i(reset_i)
   ,.data_i(en_i)
   ,.data_o(en_r)
	 );


bsg_dff_reset #(.width_p(1))
 r_v_reg
  (.clk_i(clk_i)
	 ,.reset_i(reset_i)
   ,.data_i(r_v_n)
   ,.data_o(r_v_o)
	 );


bsg_dff_reset_en #(.width_p(1))
 miss_v_reg
  (.clk_i(clk_i)
	 ,.reset_i(reset_i | w_v_i)
	 ,.en_i(r_v_i)
	 ,.data_i(miss_v_n)
	 ,.data_o(miss_v_o)
	 );


bsg_dff_reset_en #(.width_p(vtag_width_p))
 miss_vtag_reg
  (.clk_i(clk_i)
	 ,.reset_i(reset_i)
	 ,.en_i(r_v_i)
	 ,.data_i(r_vtag_i)
	 ,.data_o(miss_vtag_o)
	 );


bp_fe_itlb_replacement #(.ways_p(els_p))
 plru
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.v_i(cam_r_v)
   ,.way_i(cam_r_addr)

   ,.way_o(victim_addr)
   );


bsg_cam_1r1w
 #(.els_p(els_p)
   ,.width_p(vtag_width_p)
   ,.multiple_entries_p(0)
   ,.find_empty_entry_p(1)
	 )
 vtag_cam
  (.clk_i(clk_i)
	 ,.reset_i(reset_i)
	 ,.en_i(en_i)

   ,.w_v_i(w_v_i)
   ,.w_set_not_clear_i(1'b1)
   ,.w_addr_i(cam_w_addr)
   ,.w_data_i(w_vtag_i)

   ,.r_v_i(r_v_i)
   ,.r_data_i(r_vtag_i)

   ,.r_v_o(cam_r_v)
   ,.r_addr_o(cam_r_addr)

   ,.empty_v_o(cam_empty_v)
   ,.empty_addr_o(cam_empty_addr)
	 );


bsg_mem_1rw_sync
 #(.width_p(entry_width_lp)
   ,.els_p(els_p)
	 )
 entry_ram
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.data_i(w_entry)
   ,.addr_i(ram_addr)
   ,.v_i(en_i & (cam_r_v | w_v_i))
   ,.w_i(w_v_i)
   ,.data_o(ram_r_data)
	 );


endmodule
