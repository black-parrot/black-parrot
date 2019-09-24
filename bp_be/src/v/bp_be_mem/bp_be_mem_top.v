/**
 *
 *  Name:
 *    bp_be_mem_top.v
 * 
 *  Description:
 *    memory management unit.
 *
 */

module bp_be_mem_top 
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_be_pkg::*;
  import bp_common_rv64_pkg::*;
  import bp_be_dcache_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_lce_cce_if_widths(num_cce_p
                                 ,num_lce_p
                                 ,paddr_width_p
                                 ,lce_assoc_p
                                 ,dword_width_p
                                 ,cce_block_width_p
                                 )
   , localparam ecode_dec_width_lp = `bp_be_ecode_dec_width
   // Generated parameters
   // D$   
   , localparam block_size_in_words_lp = lce_assoc_p // Due to cache interleaving scheme
   , localparam data_mask_width_lp     = (dword_width_p >> 3) // Byte mask
   , localparam byte_offset_width_lp   = `BSG_SAFE_CLOG2(dword_width_p >> 3)
   , localparam word_offset_width_lp   = `BSG_SAFE_CLOG2(block_size_in_words_lp)
   , localparam block_offset_width_lp  = (word_offset_width_lp + byte_offset_width_lp)
   , localparam index_width_lp         = `BSG_SAFE_CLOG2(lce_sets_p)
   , localparam page_offset_width_lp   = (block_offset_width_lp + index_width_lp)
   , localparam dcache_pkt_width_lp    = `bp_be_dcache_pkt_width(page_offset_width_lp
                                                                 , dword_width_p
                                                                 )
   , localparam proc_cfg_width_lp      = `bp_proc_cfg_width(num_core_p, num_cce_p, num_lce_p)
   , localparam lce_id_width_lp        = `BSG_SAFE_CLOG2(num_lce_p)

   // MMU                                                              
   , localparam mmu_cmd_width_lp  = `bp_be_mmu_cmd_width(vaddr_width_p)
   , localparam csr_cmd_width_lp  = `bp_be_csr_cmd_width
   , localparam mem_resp_width_lp = `bp_be_mem_resp_width(vaddr_width_p)
   
   // VM
   , localparam tlb_entry_width_lp = `bp_pte_entry_leaf_width(paddr_width_p)
   )
  (input                                     clk_i
   , input                                   reset_i
   , input                                   freeze_i

   // Config channel
   , input                                   cfg_w_v_i
   , input [cfg_addr_width_p-1:0]            cfg_addr_i
   , input [cfg_data_width_p-1:0]            cfg_data_i

   , input [mmu_cmd_width_lp-1:0]            mmu_cmd_i
   , input                                   mmu_cmd_v_i
   , output                                  mmu_cmd_ready_o

   , input [csr_cmd_width_lp-1:0]            csr_cmd_i
   , input                                   csr_cmd_v_i
   , output                                  csr_cmd_ready_o

   , input                                   chk_poison_ex_i

   , output [mem_resp_width_lp-1:0]          mem_resp_o
   , output                                  mem_resp_v_o
   , input                                   mem_resp_ready_i

   , output                                  itlb_fill_v_o
   , output [vaddr_width_p-1:0]              itlb_fill_vaddr_o
   , output [tlb_entry_width_lp-1:0]         itlb_fill_entry_o
   
   , output [lce_cce_req_width_lp-1:0]       lce_req_o
   , output                                  lce_req_v_o
   , input                                   lce_req_ready_i

   , output [lce_cce_resp_width_lp-1:0]      lce_resp_o
   , output                                  lce_resp_v_o
   , input                                   lce_resp_ready_i                                 

   , input [lce_cmd_width_lp-1:0]            lce_cmd_i
   , input                                   lce_cmd_v_i
   , output                                  lce_cmd_ready_o

   , output [lce_cmd_width_lp-1:0]           lce_cmd_o
   , output                                  lce_cmd_v_o
   , input                                   lce_cmd_ready_i 

   , output                                  credits_full_o
   , output                                  credits_empty_o

   // CSRs
   , input [proc_cfg_width_lp-1:0]           proc_cfg_i
   , input                                   instret_i

   , input [vaddr_width_p-1:0]               pc_mem3_i
   , input [instr_width_p-1:0]               instr_mem3_i
   , input                                   pc_v_mem3_i

   , input                                   timer_int_i
   , input                                   software_int_i
   , input                                   external_int_i
   , input [vaddr_width_p-1:0]               interrupt_pc_i

   , output [rv64_priv_width_gp-1:0]         priv_mode_o
   , output                                  trap_v_o
   , output                                  ret_v_o
   , output [vaddr_width_p-1:0]              epc_o
   , output [vaddr_width_p-1:0]              tvec_o
   , output                                  tlb_fence_o
   );

`declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
`declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

`declare_bp_common_proc_cfg_s(num_core_p, num_cce_p, num_lce_p)
`declare_bp_be_mmu_structs(vaddr_width_p, ptag_width_p, lce_sets_p, cce_block_width_p/8)
`declare_bp_be_dcache_pkt_s(page_offset_width_lp, dword_width_p);

// Cast input and output ports 
bp_proc_cfg_s          proc_cfg;
bp_be_mmu_cmd_s        mmu_cmd;
bp_be_csr_cmd_s        csr_cmd;
bp_be_mem_resp_s       mem_resp;
bp_be_mmu_vaddr_s      mmu_cmd_vaddr;
bp_be_mmu_vaddr_s      pc_mem3_cast_i;

assign proc_cfg = proc_cfg_i;
assign mmu_cmd = mmu_cmd_i;
assign csr_cmd = csr_cmd_i;

assign mem_resp_o = mem_resp;
assign pc_mem3_cast_i = pc_mem3_i;

// Suppress unused signal warnings
wire unused0 = mem_resp_ready_i;

/* Internal connections */
/* TLB ports */
logic                    dtlb_en, dtlb_miss_v, dtlb_w_v, dtlb_r_v, dtlb_r_v_lo;
logic [vtag_width_p-1:0] dtlb_r_vtag, dtlb_w_vtag, dtlb_miss_vtag;
bp_pte_entry_leaf_s      dtlb_r_entry, dtlb_w_entry;

/* PTW ports */
logic [ptag_width_p-1:0]  ptw_dcache_ptag;
logic                     ptw_dcache_v, ptw_busy, ptw_store_not_load;
bp_be_dcache_pkt_s        ptw_dcache_pkt; 
logic                     ptw_tlb_miss_v, ptw_tlb_w_v;
logic [vtag_width_p-1:0]  ptw_tlb_w_vtag, ptw_tlb_miss_vtag;
bp_pte_entry_leaf_s       ptw_tlb_w_entry;
logic                     ptw_page_fault_v, ptw_instr_page_fault_v, ptw_load_page_fault_v, ptw_store_page_fault_v;

/* D-Cache ports */
bp_be_dcache_pkt_s        dcache_pkt;
logic [dword_width_p-1:0] dcache_data;
logic [ptag_width_p-1:0]  dcache_ptag;
logic                     dcache_ready, dcache_miss_v, dcache_v, dcache_pkt_v;
logic                     dcache_tlb_miss, dcache_poison;
logic                     dcache_uncached;

/* CSR signals */
logic                     csr_illegal_instr_lo;
bp_satp_s                 satp_lo;
logic [dword_width_p-1:0] csr_data_lo;
logic                     csr_v_lo;
logic                     translation_en_lo;

logic load_access_fault_v, store_access_fault_v;

/* Control signals */
logic dcache_cmd_v;
logic itlb_not_dtlb_resp;
logic mmu_cmd_v_r, mmu_cmd_v_rr, dtlb_miss_r;
bp_be_mmu_vaddr_s vaddr_mem3, fault_vaddr;
logic is_itlb_fill_mem3;
logic is_store_mem3;
logic [vaddr_width_p-1:0] fault_pc;

wire itlb_fill_cmd_v = is_itlb_fill_mem3;
wire dtlb_fill_cmd_v = dtlb_miss_r & pc_v_mem3_i;

bsg_dff_en
 #(.width_p(2*vaddr_width_p))
 fault_reg
  (.clk_i(clk_i)
   ,.en_i(itlb_fill_cmd_v | dtlb_fill_cmd_v)

   ,.data_i({vaddr_mem3, pc_mem3_i})
   ,.data_o({fault_vaddr, fault_pc})
   );

wire is_itlb_fill = mmu_cmd_v_i & mmu_cmd.mem_op inside {e_itlb_fill};
wire is_store     = mmu_cmd_v_i & mmu_cmd.mem_op inside {e_sb, e_sh, e_sw, e_sd};
bsg_dff_chain
 #(.width_p(2+vaddr_width_p)
   ,.num_stages_p(2)
   )
 fill_pipe
  (.clk_i(clk_i)
   
   ,.data_i({mmu_cmd.vaddr, is_store, is_itlb_fill})
   ,.data_o({vaddr_mem3, is_store_mem3, is_itlb_fill_mem3})
   );

bp_be_ecode_dec_s exception_ecode_dec_li;
assign exception_ecode_dec_li = 
  '{instr_misaligned : csr_cmd_v_i & (csr_cmd.csr_op == e_op_instr_misaligned)
    ,instr_fault     : csr_cmd_v_i & (csr_cmd.csr_op == e_op_instr_access_fault)
    ,illegal_instr   : csr_cmd_v_i & ((csr_cmd.csr_op == e_op_illegal_instr) || csr_illegal_instr_lo)
    ,breakpoint      : csr_cmd_v_i & (csr_cmd.csr_op == e_ebreak)
    ,load_misaligned : 1'b0
    ,load_fault      : load_access_fault_v
    ,store_misaligned: 1'b0
    ,store_fault     : store_access_fault_v
    ,ecall_u_mode    : csr_cmd_v_i & (csr_cmd.csr_op == e_ecall) & (priv_mode_o == `PRIV_MODE_U)
    ,ecall_s_mode    : csr_cmd_v_i & (csr_cmd.csr_op == e_ecall) & (priv_mode_o == `PRIV_MODE_S)
    ,ecall_m_mode    : csr_cmd_v_i & (csr_cmd.csr_op == e_ecall) & (priv_mode_o == `PRIV_MODE_M)
    ,instr_page_fault: ptw_instr_page_fault_v
    ,load_page_fault : ptw_load_page_fault_v
    ,store_page_fault: ptw_store_page_fault_v
    ,default: '0
    };

wire [vaddr_width_p-1:0] pc_mem3_li = pc_v_mem3_i ? pc_mem3_i : fault_pc;
wire [vaddr_width_p-1:0] exception_vaddr_li = pc_v_mem3_i ? vaddr_mem3 : fault_vaddr;
bp_be_csr
 #(.cfg_p(cfg_p))
  csr
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.csr_cmd_i(csr_cmd_i)
   ,.csr_cmd_v_i(csr_cmd_v_i)
   ,.csr_cmd_ready_o(csr_cmd_ready_o)

   ,.data_o(csr_data_lo)
   ,.v_o(csr_v_lo)
   ,.illegal_instr_o(csr_illegal_instr_lo)

   ,.hartid_i(proc_cfg.core_id)
   ,.instret_i(instret_i)

   ,.exception_v_i(pc_v_mem3_i | ptw_page_fault_v)
   ,.exception_pc_i(pc_mem3_li)
   ,.exception_vaddr_i(exception_vaddr_li)
   ,.exception_instr_i(instr_mem3_i)
   ,.exception_ecode_dec_i(exception_ecode_dec_li)

   ,.timer_int_i(timer_int_i)
   ,.software_int_i(software_int_i)
   ,.external_int_i(external_int_i)
   ,.interrupt_pc_i(interrupt_pc_i)

   ,.priv_mode_o(priv_mode_o)
   ,.trap_v_o(trap_v_o)
   ,.ret_v_o(ret_v_o)
   ,.epc_o(epc_o)
   ,.tvec_o(tvec_o)
   ,.satp_o(satp_lo)
   ,.translation_en_o(translation_en_lo)
   ,.tlb_fence_o(tlb_fence_o)
   );

bp_tlb
  #(.cfg_p(cfg_p)
    ,.tlb_els_p(dtlb_els_p)
  )
  dtlb
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.flush_i(tlb_fence_o)
   
   ,.v_i(dtlb_r_v | dtlb_w_v)
   ,.w_i(dtlb_w_v)
   ,.vtag_i((dtlb_w_v)? dtlb_w_vtag : dtlb_r_vtag)
   ,.entry_i(dtlb_w_entry)
   
   ,.v_o(dtlb_r_v_lo)
   ,.entry_o(dtlb_r_entry)
      
   ,.miss_v_o(dtlb_miss_v)
   ,.miss_vtag_o(dtlb_miss_vtag)
  );
  
bp_be_ptw
  #(.cfg_p(cfg_p)
    ,.pte_width_p(bp_sv39_pte_width_gp)
    ,.page_table_depth_p(bp_sv39_page_table_depth_gp)
  )
  ptw
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.base_ppn_i(satp_lo.ppn)
   ,.translation_en_i(translation_en_lo)
   ,.busy_o(ptw_busy)
   
   ,.itlb_not_dtlb_i(itlb_fill_cmd_v)
   ,.itlb_not_dtlb_o(itlb_not_dtlb_resp)
   
   ,.store_not_load_i(ptw_store_not_load)
   
   ,.instr_page_fault_o(ptw_instr_page_fault_v)
   ,.load_page_fault_o(ptw_load_page_fault_v)
   ,.store_page_fault_o(ptw_store_page_fault_v)
   
   ,.tlb_miss_v_i(ptw_tlb_miss_v)
   ,.tlb_miss_vtag_i(ptw_tlb_miss_vtag)
   
   ,.tlb_w_v_o(ptw_tlb_w_v)
   ,.tlb_w_vtag_o(ptw_tlb_w_vtag)
   ,.tlb_w_entry_o(ptw_tlb_w_entry)

   ,.dcache_v_i(dcache_v)
   ,.dcache_data_i(dcache_data)
   
   ,.dcache_v_o(ptw_dcache_v)
   ,.dcache_pkt_o(ptw_dcache_pkt)
   ,.dcache_ptag_o(ptw_dcache_ptag)
   ,.dcache_rdy_i(dcache_ready)
   ,.dcache_miss_i(dcache_miss_v)
  );

bp_be_dcache 
  #(.cfg_p(cfg_p))
  dcache
   (.clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.freeze_i(freeze_i)

    ,.lce_id_i(proc_cfg.dcache_id)
    ,.cfg_w_v_i(cfg_w_v_i)
    ,.cfg_addr_i(cfg_addr_i)
    ,.cfg_data_i(cfg_data_i)

    ,.dcache_pkt_i(dcache_pkt)
    ,.v_i(dcache_pkt_v)
    ,.ready_o(dcache_ready)

    ,.v_o(dcache_v)
    ,.data_o(dcache_data)

    ,.tlb_miss_i(dcache_tlb_miss)
    ,.ptag_i(dcache_ptag)
    ,.uncached_i(dcache_uncached)

    ,.cache_miss_o(dcache_miss_v)
    ,.poison_i(dcache_poison)

    // LCE-CCE interface
    ,.lce_req_o(lce_req_o)
    ,.lce_req_v_o(lce_req_v_o)
    ,.lce_req_ready_i(lce_req_ready_i)

    ,.lce_resp_o(lce_resp_o)
    ,.lce_resp_v_o(lce_resp_v_o)
    ,.lce_resp_ready_i(lce_resp_ready_i)

    // CCE-LCE interface
    ,.lce_cmd_i(lce_cmd_i)
    ,.lce_cmd_v_i(lce_cmd_v_i)
    ,.lce_cmd_ready_o(lce_cmd_ready_o)

    ,.lce_cmd_o(lce_cmd_o)
    ,.lce_cmd_v_o(lce_cmd_v_o)
    ,.lce_cmd_ready_i(lce_cmd_ready_i)

    ,.credits_full_o(credits_full_o)
    ,.credits_empty_o(credits_empty_o)
  
    ,.load_access_fault_o(load_access_fault_v)
    ,.store_access_fault_o(store_access_fault_v)
    );

// We delay the tlb miss signal by one cycle to synchronize with cache miss signal
// We latch the dcache miss signal
always_ff @(posedge clk_i) begin
  if(reset_i) begin
    dtlb_miss_r  <= '0;
    mmu_cmd_v_r  <= '0;
    mmu_cmd_v_rr <= '0;
  end
  else begin
    dtlb_miss_r  <= dtlb_miss_v;
    mmu_cmd_v_r  <= mmu_cmd_v_i;
    mmu_cmd_v_rr <= mmu_cmd_v_r;
  end
end
    
// Decode cmd type
assign dcache_cmd_v    = mmu_cmd_v_i & ~(itlb_fill_cmd_v | dtlb_fill_cmd_v);

// D-Cache connections
assign dcache_ptag     = (ptw_busy)? ptw_dcache_ptag : dtlb_r_entry.ptag;
assign dcache_tlb_miss = (ptw_busy)? 1'b0 : dtlb_miss_v;
assign dcache_poison   = (ptw_busy)? 1'b0 : chk_poison_ex_i;
assign dcache_pkt_v    = (ptw_busy)? ptw_dcache_v : dcache_cmd_v;

always_comb 
  begin
    // TODO: Should we allow uncached accesses during PTW?
    //   I don't see why not, but it's something to think about...
    if(ptw_busy) begin
      dcache_pkt = ptw_dcache_pkt;
      dcache_uncached = '0;
    end
    else begin
      dcache_uncached        = dtlb_r_v_lo & dtlb_r_entry.uc;
      dcache_pkt.opcode      = bp_be_dcache_opcode_e'(mmu_cmd.mem_op);
      dcache_pkt.page_offset = {mmu_cmd.vaddr.index, mmu_cmd.vaddr.offset};
      dcache_pkt.data        = mmu_cmd.data;
    end
end

// D-TLB connections
assign dtlb_r_v     = dcache_cmd_v;
assign dtlb_r_vtag  = mmu_cmd.vaddr.tag;
assign dtlb_w_v     = ptw_tlb_w_v & ~itlb_not_dtlb_resp;
assign dtlb_w_vtag  = ptw_tlb_w_vtag;
assign dtlb_w_entry = ptw_tlb_w_entry;

// PTW connections
assign ptw_tlb_miss_v    = itlb_fill_cmd_v | dtlb_fill_cmd_v;
assign ptw_tlb_miss_vtag = vaddr_mem3.tag;
assign ptw_page_fault_v  = ptw_instr_page_fault_v | ptw_load_page_fault_v | ptw_store_page_fault_v;
assign ptw_store_not_load = dtlb_fill_cmd_v & is_store_mem3;
 
// MMU response connections
assign mem_resp.miss_v = dtlb_miss_r | dcache_miss_v;
assign mem_resp.exc_v  = |exception_ecode_dec_li;
assign mem_resp.data   = dcache_v ? dcache_data : csr_data_lo;

assign mem_resp_v_o    = ptw_busy ? 1'b0 : mmu_cmd_v_rr | csr_v_lo;
assign mmu_cmd_ready_o = dcache_ready & ~dcache_miss_v & ~ptw_busy;

assign itlb_fill_v_o     = ptw_tlb_w_v & itlb_not_dtlb_resp;
assign itlb_fill_vaddr_o = fault_vaddr;
assign itlb_fill_entry_o = ptw_tlb_w_entry;

logic dcache_pkt_v_r;
always_ff @(negedge clk_i)
  begin
    dcache_pkt_v_r <= dcache_pkt_v;
    assert (~(dcache_pkt_v_r & dcache_uncached & ~dtlb_miss_v & mmu_cmd.mem_op inside {e_lrw, e_lrd, e_scw, e_scd}))
      else $warning("LR/SC to uncached memory not supported");
  end

endmodule : bp_be_mem_top

