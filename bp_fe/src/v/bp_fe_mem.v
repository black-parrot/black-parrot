
module bp_fe_mem
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_fe_pkg::*;
 import bp_fe_icache_pkg::*;
 import bp_common_rv64_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
   `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, icache_sets_p, icache_assoc_p, dword_width_p, icache_block_width_p, icache)
   
   , localparam way_id_width_lp=`BSG_SAFE_CLOG2(icache_assoc_p)
   , localparam block_size_in_words_lp=icache_assoc_p
   , localparam bank_width_lp = icache_block_width_p / icache_assoc_p
   , localparam num_dwords_per_bank_lp = bank_width_lp / dword_width_p
   , localparam data_mem_mask_width_lp=(bank_width_lp >> 3)
   , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(bank_width_lp >> 3)
   , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)
   , localparam index_width_lp=`BSG_SAFE_CLOG2(icache_sets_p)
   , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
   , localparam ptag_width_lp=(paddr_width_p-bp_page_offset_width_gp)

   , localparam stat_width_lp = `bp_cache_stat_info_width(icache_assoc_p)

   , localparam mem_cmd_width_lp  = `bp_fe_mem_cmd_width(vaddr_width_p, vtag_width_p, ptag_width_p)
   , localparam mem_resp_width_lp = `bp_fe_mem_resp_width

   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
   )
  (input                                              clk_i
   , input                                            reset_i

   , input [cfg_bus_width_lp-1:0]                     cfg_bus_i

   , input [mem_cmd_width_lp-1:0]                     mem_cmd_i
   , input                                            mem_cmd_v_i
   , output                                           mem_cmd_yumi_o

   , input [rv64_priv_width_gp-1:0]                   mem_priv_i
   , input                                            mem_translation_en_i
   , input                                            mem_poison_i

   , output [mem_resp_width_lp-1:0]                   mem_resp_o
   , output                                           mem_resp_v_o

   // Interface to LCE
   , output logic [icache_req_width_lp-1:0]           cache_req_o
   , output logic                                     cache_req_v_o
   , input                                            cache_req_ready_i
   , output logic [icache_req_metadata_width_lp-1:0]  cache_req_metadata_o
   , output logic                                     cache_req_metadata_v_o
 
   , input                                            cache_req_complete_i

   , input [icache_data_mem_pkt_width_lp-1:0]         data_mem_pkt_i
   , input                                            data_mem_pkt_v_i
   , output logic                                     data_mem_pkt_ready_o
   , output logic [icache_block_width_p-1:0]          data_mem_o

   , input [icache_tag_mem_pkt_width_lp-1:0]          tag_mem_pkt_i
   , input                                            tag_mem_pkt_v_i
   , output logic                                     tag_mem_pkt_ready_o
   , output logic [ptag_width_lp-1:0]                 tag_mem_o

   , input [icache_stat_mem_pkt_width_lp-1:0]         stat_mem_pkt_i
   , input                                            stat_mem_pkt_v_i
   , output logic                                     stat_mem_pkt_ready_o
   , output logic [stat_width_lp-1:0]                 stat_mem_o
   );

 `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
 `declare_bp_fe_mem_structs(vaddr_width_p, icache_sets_p, icache_block_width_p, vtag_width_p, ptag_width_p)

bp_cfg_bus_s cfg_bus_cast_i;
bp_fe_mem_cmd_s  mem_cmd_cast_i;
bp_fe_mem_resp_s mem_resp_cast_o;

assign cfg_bus_cast_i = cfg_bus_i;
assign mem_cmd_cast_i = mem_cmd_i;
assign mem_resp_o     = mem_resp_cast_o;

logic instr_page_fault_lo, instr_access_fault_lo, icache_miss_lo, itlb_miss_lo;

logic fetch_ready;
wire itlb_fence_v = mem_cmd_v_i & (mem_cmd_cast_i.op == e_fe_op_tlb_fence);
wire itlb_fill_v  = mem_cmd_v_i & (mem_cmd_cast_i.op == e_fe_op_tlb_fill);
wire fetch_v      = fetch_ready & mem_cmd_v_i & (mem_cmd_cast_i.op == e_fe_op_fetch);
wire fencei_v     = fetch_ready & mem_cmd_v_i & (mem_cmd_cast_i.op == e_fe_op_icache_fence);

bp_fe_tlb_entry_s itlb_r_entry;
logic itlb_r_v_lo;
bp_tlb
 #(.bp_params_p(bp_params_p), .tlb_els_p(itlb_els_p))
 itlb
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.flush_i(itlb_fence_v)
   ,.translation_en_i(mem_translation_en_i)
         
   ,.v_i(fetch_v | itlb_fill_v)
   ,.w_i(itlb_fill_v)
   ,.vtag_i(itlb_fill_v ? mem_cmd_cast_i.operands.fill.vtag : mem_cmd_cast_i.operands.fetch.vaddr.tag)
   ,.entry_i(mem_cmd_cast_i.operands.fill.entry)
     
   ,.v_o(itlb_r_v_lo)
   ,.entry_o(itlb_r_entry)

   ,.miss_v_o(itlb_miss_lo)
   ,.miss_vtag_o()
   );

wire [ptag_width_p-1:0] ptag_li     = itlb_r_entry.ptag;
wire                    ptag_v_li   = itlb_r_v_lo;

logic uncached_li;
bp_pma
 #(.bp_params_p(bp_params_p))
 pma
  (.ptag_v_i(ptag_v_li)
   ,.ptag_i(ptag_li)

   ,.uncached_o(uncached_li)
   );

logic [instr_width_p-1:0] icache_data_lo;
logic                     icache_data_v_lo;

logic instr_access_fault_v, instr_page_fault_v;
bp_fe_icache 
 #(.bp_params_p(bp_params_p)) 
 icache
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.cfg_bus_i(cfg_bus_i)

   ,.vaddr_i(mem_cmd_cast_i.operands.fetch.vaddr)
   ,.vaddr_v_i(fetch_v)
   ,.fencei_v_i(fencei_v)
   ,.vaddr_ready_o(fetch_ready)

   ,.ptag_i(ptag_li)
   ,.ptag_v_i(ptag_v_li)
   ,.uncached_i(uncached_li)
   ,.poison_i(mem_poison_i | instr_access_fault_v | instr_page_fault_v)

   ,.data_o(icache_data_lo)
   ,.data_v_o(icache_data_v_lo)
   ,.miss_o()

   // LCE Interface

   ,.cache_req_o(cache_req_o)
   ,.cache_req_v_o(cache_req_v_o)
   ,.cache_req_ready_i(cache_req_ready_i)
   ,.cache_req_metadata_o(cache_req_metadata_o)
   ,.cache_req_metadata_v_o(cache_req_metadata_v_o)

   ,.cache_req_complete_i(cache_req_complete_i)

   ,.data_mem_pkt_i(data_mem_pkt_i)
   ,.data_mem_pkt_v_i(data_mem_pkt_v_i)
   ,.data_mem_pkt_ready_o(data_mem_pkt_ready_o)
   ,.data_mem_o(data_mem_o)

   ,.tag_mem_pkt_i(tag_mem_pkt_i)
   ,.tag_mem_pkt_v_i(tag_mem_pkt_v_i)
   ,.tag_mem_pkt_ready_o(tag_mem_pkt_ready_o)
   ,.tag_mem_o(tag_mem_o)

   ,.stat_mem_pkt_v_i(stat_mem_pkt_v_i)
   ,.stat_mem_pkt_i(stat_mem_pkt_i)
   ,.stat_mem_pkt_ready_o(stat_mem_pkt_ready_o)
   ,.stat_mem_o(stat_mem_o)
   );

logic fetch_v_r, fetch_v_rr;
logic itlb_miss_r;
logic instr_access_fault_r, instr_page_fault_r;
always_ff @(posedge clk_i)
  begin
    if(reset_i) begin
      itlb_miss_r <= '0;
      fetch_v_r   <= '0;
      fetch_v_rr  <= '0;

      instr_access_fault_r <= '0;
      instr_page_fault_r   <= '0;
    end
    else begin
      fetch_v_r   <= fetch_v;
      fetch_v_rr  <= fetch_v_r & ~mem_poison_i;
      itlb_miss_r <= itlb_miss_lo & ~mem_poison_i;

      instr_access_fault_r <= instr_access_fault_v & ~mem_poison_i;
      instr_page_fault_r   <= instr_page_fault_v & ~mem_poison_i;
    end
  end

wire instr_priv_page_fault = ((mem_priv_i == `PRIV_MODE_S) & itlb_r_entry.u)
                               | ((mem_priv_i == `PRIV_MODE_U) & ~itlb_r_entry.u);
wire instr_exe_page_fault = ~itlb_r_entry.x;

// Fault if in uncached mode but access is not for an uncached address
wire is_uncached_mode = (cfg_bus_cast_i.icache_mode == e_lce_mode_uncached);
wire mode_fault_v = (is_uncached_mode & ~uncached_li);
// TODO: Enable other domains by setting enabled dids with cfg_bus
wire did_fault_v = (ptag_li[ptag_width_p-1-:io_noc_did_width_p] != '0);
// Don't allow speculative access to local tile memory
wire local_fault_v = (ptag_li < (dram_base_addr_gp >> page_offset_width_p));

assign instr_access_fault_v = fetch_v_r & (mode_fault_v | did_fault_v | local_fault_v);
assign instr_page_fault_v   = fetch_v_r & itlb_r_v_lo & mem_translation_en_i & (instr_priv_page_fault | instr_exe_page_fault);

assign mem_cmd_yumi_o = itlb_fence_v | itlb_fill_v | fetch_v | fencei_v;

assign mem_resp_v_o    = fetch_v_rr;
assign mem_resp_cast_o = '{instr_access_fault: instr_access_fault_r
                           ,instr_page_fault : instr_page_fault_r
                           ,itlb_miss        : itlb_miss_r
                           ,icache_miss      : fetch_v_rr & ~icache_data_v_lo
                           ,data             : icache_data_lo
                           };

endmodule
