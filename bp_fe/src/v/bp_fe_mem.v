
module bp_fe_mem
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_fe_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

   , localparam mem_cmd_width_lp  = `bp_fe_mem_cmd_width(vaddr_width_p, vtag_width_p, ptag_width_p)
   , localparam mem_resp_width_lp = `bp_fe_mem_resp_width

   , localparam lce_id_width_lp = `BSG_SAFE_CLOG2(num_lce_p)
   )
  (input                                              clk_i
   , input                                            reset_i
   , input                                            freeze_i

   , input [lce_id_width_lp-1:0]                      lce_id_i

   , input                                            cfg_w_v_i
   , input [cfg_addr_width_p-1:0]                     cfg_addr_i
   , input [cfg_data_width_p-1:0]                     cfg_data_i

   , input [mem_cmd_width_lp-1:0]                     mem_cmd_i
   , input                                            mem_cmd_v_i
   , output                                           mem_cmd_ready_o

   , input                                            mem_poison_i

   , output [mem_resp_width_lp-1:0]                   mem_resp_o
   , output                                           mem_resp_v_o
   , input                                            mem_resp_ready_i

   , output [lce_cce_req_width_lp-1:0]                lce_req_o
   , output                                           lce_req_v_o
   , input                                            lce_req_ready_i

   , input [lce_cmd_width_lp-1:0]                     lce_cmd_i
   , input                                            lce_cmd_v_i
   , output                                           lce_cmd_ready_o

   , output [lce_cmd_width_lp-1:0]                    lce_cmd_o
   , output                                           lce_cmd_v_o
   , input                                            lce_cmd_ready_i

   , output [lce_cce_resp_width_lp-1:0]               lce_resp_o
   , output                                           lce_resp_v_o
   , input                                            lce_resp_ready_i
   );

`declare_bp_fe_mem_structs(vaddr_width_p, lce_sets_p, cce_block_width_p, vtag_width_p, ptag_width_p)
bp_fe_mem_cmd_s  mem_cmd_cast_i;
bp_fe_mem_resp_s mem_resp_cast_o;

assign mem_cmd_cast_i = mem_cmd_i;
assign mem_resp_o     = mem_resp_cast_o;

logic instr_access_fault_lo, icache_miss_lo, itlb_miss_lo;
logic itlb_ready_lo;

wire itlb_fence_v = mem_cmd_v_i & (mem_cmd_cast_i.op == e_fe_op_tlb_fence);
wire itlb_fill_v  = mem_cmd_v_i & (mem_cmd_cast_i.op == e_fe_op_tlb_fill);
wire fetch_v      = mem_cmd_v_i & (mem_cmd_cast_i.op == e_fe_op_fetch);

bp_fe_tlb_entry_s itlb_r_entry;
logic itlb_r_v_lo;
bp_tlb
 #(.cfg_p(cfg_p), .tlb_els_p(itlb_els_p))
 itlb
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.flush_i(itlb_fence_v)
	       
   ,.v_i(fetch_v | itlb_fill_v)
   ,.w_i(itlb_fill_v)
   ,.vtag_i(itlb_fill_v ? mem_cmd_cast_i.operands.fill.vtag : mem_cmd_cast_i.operands.fetch.vaddr.tag)
	 ,.entry_i(mem_cmd_cast_i.operands.fill.entry)
	   
   ,.v_o(itlb_r_v_lo)
   ,.entry_o(itlb_r_entry)

	 ,.miss_v_o(itlb_miss_lo)
	 ,.miss_vtag_o()
	 );
wire                    uncached_li = itlb_r_entry.uc;
wire [ptag_width_p-1:0] ptag_li     = itlb_r_entry.ptag;
wire                    ptag_v_li   = itlb_r_v_lo;

logic                     icache_ready_lo;
logic [instr_width_p-1:0] icache_data_lo;
logic                     icache_data_v_lo;
bp_fe_icache 
 #(.cfg_p(cfg_p)) 
 icache
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.freeze_i(freeze_i)

   ,.lce_id_i(lce_id_i)

   ,.cfg_w_v_i(cfg_w_v_i)
   ,.cfg_addr_i(cfg_addr_i)
   ,.cfg_data_i(cfg_data_i)

   ,.vaddr_i(mem_cmd_cast_i.operands.fetch.vaddr)
   ,.vaddr_v_i(fetch_v)
   ,.vaddr_ready_o(icache_ready_lo)

   ,.uncached_i(uncached_li)
   ,.ptag_i(ptag_li)
   ,.ptag_v_i(ptag_v_li)
   ,.poison_tl_i(mem_poison_i)

   ,.data_o(icache_data_lo)
   ,.data_v_o(icache_data_v_lo)
   ,.instr_access_fault_o(instr_access_fault_lo)
   ,.cache_miss_o(icache_miss_lo)
  
   ,.lce_req_o(lce_req_o)
   ,.lce_req_v_o(lce_req_v_o)
   ,.lce_req_ready_i(lce_req_ready_i)
         
   ,.lce_cmd_i(lce_cmd_i)
   ,.lce_cmd_v_i(lce_cmd_v_i)
   ,.lce_cmd_ready_o(lce_cmd_ready_o)
         
   ,.lce_cmd_o(lce_cmd_o)
   ,.lce_cmd_v_o(lce_cmd_v_o)
   ,.lce_cmd_ready_i(lce_cmd_ready_i)

   ,.lce_resp_o(lce_resp_o)
   ,.lce_resp_v_o(lce_resp_v_o)
   ,.lce_resp_ready_i(lce_resp_ready_i)
   );

// We don't need to check itlb ready, because it is only ready when not writing.  
//   Reads and writes to itlb are mutually exclusive by construction
assign mem_cmd_ready_o = icache_ready_lo;

always_ff @(negedge clk_i)
  begin
    assert(mem_cmd_ready_o || ~mem_cmd_v_i);
  end

logic mem_cmd_v_r, mem_cmd_v_rr;
logic itlb_miss_r;
always_ff @(posedge clk_i)
  begin
    itlb_miss_r  <= itlb_miss_lo;
    mem_cmd_v_r  <= mem_cmd_v_i;
    mem_cmd_v_rr <= mem_cmd_v_r & ~mem_poison_i;
  end

assign mem_resp_v_o    = mem_resp_ready_i & mem_cmd_v_rr;
assign mem_resp_cast_o = '{instr_access_fault: instr_access_fault_lo
                           ,itlb_miss        : itlb_miss_r
                           ,icache_miss      : icache_miss_lo
                           ,data             : icache_data_lo
                           };

endmodule
