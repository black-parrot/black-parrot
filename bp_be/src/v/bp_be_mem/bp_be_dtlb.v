
module bp_be_dtlb
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_be_pkg::*;
  import bp_be_rv64_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   
   ,localparam lg_els_lp      = `BSG_SAFE_CLOG2(dtlb_els_p)
   ,localparam entry_width_lp = `bp_be_tlb_entry_width(ptag_width_p)
 )
 (input                               clk_i
  , input                             reset_i
  , input                             flush_i
  
  // Connections to Cache
  , input                             r_v_i
  , output                            r_ready_o
  , input [vtag_width_p-1:0]          r_vtag_i
  
  , output logic                      r_v_o
  , output logic [entry_width_lp-1:0] r_entry_o
  
  // Connections to PTW
  , input                             w_v_i
  , input [vtag_width_p-1:0]          w_vtag_i
  , input [entry_width_lp-1:0]        w_entry_i
  
  , output logic                      miss_v_o
  , output logic [vtag_width_p-1:0]   miss_vtag_o
 );
  
// Declare parameterizable structs
`declare_bp_be_mmu_structs(vaddr_width_p, ptag_width_p, lce_sets_p, cce_block_width_p/8)

`declare_bp_be_tlb_entry_s(ptag_width_p)
bp_be_tlb_entry_s r_entry, w_entry, ram_r_data;

assign r_entry_o = r_entry;
assign w_entry   = w_entry_i;

assign r_ready_o = ~w_v_i;
  
logic [lg_els_lp-1:0] cam_w_addr, cam_r_addr, victim_addr, ram_addr;
logic                 cam_r_v;
logic                 r_v_n, miss_v_n;

assign cam_w_addr                 = victim_addr;
assign ram_addr                   = (w_v_i)? cam_w_addr : cam_r_addr;

assign r_entry                    = ram_r_data;
assign r_v_n                      = r_v_i & cam_r_v;
assign miss_v_n                   = r_v_i & ~cam_r_v;

bsg_dff_reset #(.width_p(1))
  r_v_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.data_i(r_v_n)
   ,.data_o(r_v_o)
  );

bsg_dff_reset #(.width_p(1))
  miss_v_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.data_i(miss_v_n)
   ,.data_o(miss_v_o)
  );

bsg_dff_reset #(.width_p(vtag_width_p))
  miss_vtag_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.data_i(r_vtag_i)
   ,.data_o(miss_vtag_o)
  );
  
bp_be_dtlb_replacement #(.ways_p(dtlb_els_p))
  plru
  (.clk_i(clk_i)
   ,.reset_i(reset_i | flush_i)
   
   ,.v_i(cam_r_v)
   ,.way_i(cam_r_addr)
   
   ,.way_o(victim_addr)
  ); 
  
bsg_cam_1r1w 
  #(.els_p(dtlb_els_p)
    ,.width_p(vtag_width_p)
    ,.multiple_entries_p(0)
    ,.find_empty_entry_p(1)
  )
  vtag_cam
  (.clk_i(clk_i)
   ,.reset_i(reset_i | flush_i)
   ,.en_i(1'b1)
   
   ,.w_v_i(w_v_i)
   ,.w_set_not_clear_i(1'b1)
   ,.w_addr_i(cam_w_addr)
   ,.w_data_i(w_vtag_i)
  
   ,.r_v_i(r_v_i)
   ,.r_data_i(r_vtag_i)
   
   ,.r_v_o(cam_r_v)
   ,.r_addr_o(cam_r_addr)
   
   ,.empty_v_o()
   ,.empty_addr_o()
  );

bsg_mem_1rw_sync
  #(.width_p(entry_width_lp)
    ,.els_p(dtlb_els_p)
  )
  entry_ram
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.data_i(w_entry)
   ,.addr_i(ram_addr)
   ,.v_i(cam_r_v | w_v_i)
   ,.w_i(w_v_i)
   ,.data_o(ram_r_data)
  );

endmodule
