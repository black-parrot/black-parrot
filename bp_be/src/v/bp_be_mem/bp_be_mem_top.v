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
  import bp_be_rv64_pkg::*;
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
   , localparam vtag_width_lp     = (vaddr_width_p-bp_page_offset_width_gp)
   , localparam ptag_width_lp     = (paddr_width_p-bp_page_offset_width_gp)
   
   // VM
   , localparam tlb_entry_width_lp = `bp_be_tlb_entry_width(ptag_width_lp)

   // CSRs
   , localparam mepc_width_lp  = `bp_mepc_width
   , localparam mtvec_width_lp = `bp_mtvec_width
   )
  (input                                     clk_i
   , input                                   reset_i

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

   , output [lce_cce_data_resp_width_lp-1:0] lce_data_resp_o
   , output                                  lce_data_resp_v_o
   , input                                   lce_data_resp_ready_i

   , input [cce_lce_cmd_width_lp-1:0]        lce_cmd_i
   , input                                   lce_cmd_v_i
   , output                                  lce_cmd_ready_o

   , input [lce_data_cmd_width_lp-1:0]       lce_data_cmd_i
   , input                                   lce_data_cmd_v_i
   , output                                  lce_data_cmd_ready_o

   , output [lce_data_cmd_width_lp-1:0]      lce_data_cmd_o
   , output                                  lce_data_cmd_v_o
   , input                                   lce_data_cmd_ready_i 

   // CSRs
   , input [proc_cfg_width_lp-1:0]           proc_cfg_i
   , input                                   instret_i

   , input [vaddr_width_p-1:0]               exception_pc_i
   , input [vaddr_width_p-1:0]               exception_vaddr_i
   , input [instr_width_p-1:0]               exception_instr_i
   , input                                   exception_ecode_v_i
   , input [ecode_dec_width_lp-1:0]          exception_ecode_dec_i

   , input                                   timer_int_i
   , input                                   software_int_i
   , input                                   external_int_i
   , input [vaddr_width_p-1:0]               interrupt_pc_i

   , output                                  trap_v_o
   , output                                  ret_v_o
   , output [mepc_width_lp-1:0]              mepc_o
   , output [mtvec_width_lp-1:0]             mtvec_o
   , output                                  tlb_fence_o
   , output                                  ifence_o
   );

`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   );

`declare_bp_common_proc_cfg_s(num_core_p, num_cce_p, num_lce_p)
`declare_bp_be_mmu_structs(vaddr_width_p, lce_sets_p, cce_block_width_p/8)
`declare_bp_be_dcache_pkt_s(page_offset_width_lp, dword_width_p);
`declare_bp_be_tlb_entry_s(ptag_width_lp);

// Cast input and output ports 
bp_proc_cfg_s          proc_cfg;
bp_be_mmu_cmd_s        mmu_cmd;
bp_be_csr_cmd_s        csr_cmd;
bp_be_mem_resp_s       mem_resp;
bp_be_mmu_vaddr_s      mmu_cmd_vaddr;

assign proc_cfg = proc_cfg_i;
assign mmu_cmd = mmu_cmd_i;
assign csr_cmd = csr_cmd_i;

assign mem_resp_o = mem_resp;

// Suppress unused signal warnings
wire unused0 = mem_resp_ready_i;

/* Internal connections */
/* TLB ports */
logic                     dtlb_en, dtlb_miss_v, dtlb_w_v, dtlb_r_v;
logic [vtag_width_lp-1:0] dtlb_r_vtag, dtlb_w_vtag, dtlb_miss_vtag;
bp_be_tlb_entry_s         dtlb_r_entry, dtlb_w_entry;

/* PTW ports */
logic [ptag_width_lp-1:0] ptw_dcache_ptag;
logic                     ptw_dcache_v, ptw_busy, ptw_store_not_load;
bp_be_dcache_pkt_s        ptw_dcache_pkt; 
logic                     ptw_tlb_miss_v, ptw_tlb_w_v;
logic [vtag_width_lp-1:0] ptw_tlb_w_vtag, ptw_tlb_miss_vtag;
bp_be_tlb_entry_s         ptw_tlb_w_entry;
logic                     ptw_page_fault_v, ptw_instr_page_fault_v, ptw_load_page_fault_v, ptw_store_page_fault_v;

/* D-Cache ports */
bp_be_dcache_pkt_s        dcache_pkt;
logic [dword_width_p-1:0] dcache_data;
logic [ptag_width_lp-1:0] dcache_ptag;
logic                     dcache_ready, dcache_miss_v, dcache_v, dcache_pkt_v;
logic                     dcache_tlb_miss, dcache_poison;
logic                     dcache_uncached;

/* CSR signals */
logic                     illegal_instr;
bp_satp_s                 satp_lo;
logic [dword_width_p-1:0] csr_data_lo;
logic                     csr_v_lo;
logic                     translation_en_lo;

/* Control signals */
logic dcache_cmd_v, itlb_fill_cmd_v, dtlb_fill_cmd_v, fence_i_cmd_v, nop_cmd_v;
logic itlb_not_dtlb_resp;
logic dtlb_miss_r;
logic [vaddr_width_p-1:0] vaddr_r, vaddr_r2, fault_vaddr;
logic [dword_width_p-1:0] fault_pc;

always_ff @(posedge clk_i) begin
  if(reset_i) begin
    vaddr_r <= '0;
    vaddr_r2 <= '0;
  end
  else begin
    vaddr_r <= mmu_cmd.vaddr;
    vaddr_r2 <= vaddr_r;
  end
end

always_ff @(posedge clk_i) begin
  if(reset_i) begin
    fault_vaddr <= '0;
    fault_pc    <= '0; 
  end
  else if(mmu_cmd_v_i) begin
    fault_vaddr <= mmu_cmd.vaddr;
    fault_pc    <= mmu_cmd.data; 
  end
end

bp_be_csr
 #(.vaddr_width_p(vaddr_width_p)
   ,.num_core_p(num_core_p)
   ,.lce_sets_p(lce_sets_p)
   ,.cce_block_size_in_bytes_p(cce_block_width_p/8)
   )
  csr
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.csr_cmd_i(csr_cmd_i)
   ,.csr_cmd_v_i(csr_cmd_v_i)
   ,.csr_cmd_ready_o(csr_cmd_ready_o)

   ,.data_o(csr_data_lo)
   ,.v_o(csr_v_lo)
   ,.illegal_instr_o(illegal_instr)

   ,.hartid_i(proc_cfg.core_id)
   ,.instret_i(instret_i)

   ,.exception_pc_i(exception_pc_i)
   ,.exception_vaddr_i(exception_vaddr_i)
   ,.exception_instr_i(exception_instr_i)
   ,.exception_ecode_v_i(exception_ecode_v_i)
   ,.exception_ecode_dec_i(exception_ecode_dec_i)

   ,.timer_int_i(timer_int_i)
   ,.software_int_i(software_int_i)
   ,.external_int_i(external_int_i)
   ,.interrupt_pc_i(interrupt_pc_i)

   ,.trap_v_o(trap_v_o)
   ,.ret_v_o(ret_v_o)
   ,.mepc_o(mepc_o)
   ,.mtvec_o(mtvec_o)
   ,.satp_o(satp_lo)
   ,.translation_en_o(translation_en_lo)
   ,.tlb_fence_o(tlb_fence_o)
   );

bp_be_dtlb
  #(.vtag_width_p(vtag_width_lp)
    ,.ptag_width_p(ptag_width_lp)
    ,.els_p(16)
  )
  dtlb
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.flush_i(tlb_fence_o)
   
   ,.r_v_i(dtlb_r_v)
   ,.r_ready_o()
   ,.r_vtag_i(dtlb_r_vtag)
   
   ,.r_v_o()
   ,.r_entry_o(dtlb_r_entry)
   
   ,.w_v_i(dtlb_w_v)
   ,.w_vtag_i(dtlb_w_vtag)
   ,.w_entry_i(dtlb_w_entry)
   
   ,.miss_v_o(dtlb_miss_v)
   ,.miss_vtag_o(dtlb_miss_vtag)
  );
  
bp_be_ptw
  #(.pte_width_p(bp_sv39_pte_width_gp)
    ,.vaddr_width_p(vaddr_width_p)
    ,.paddr_width_p(paddr_width_p)
    ,.page_offset_width_p(page_offset_width_lp)
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
  #(.data_width_p(dword_width_p) 
    ,.sets_p(lce_sets_p)
    ,.ways_p(lce_assoc_p)
    ,.paddr_width_p(paddr_width_p)
    ,.num_cce_p(num_cce_p)
    ,.num_lce_p(num_lce_p)
    )
  dcache
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.lce_id_i(proc_cfg.dcache_id)

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

    ,.lce_data_resp_o(lce_data_resp_o)
    ,.lce_data_resp_v_o(lce_data_resp_v_o)
    ,.lce_data_resp_ready_i(lce_data_resp_ready_i)

    // CCE-LCE interface
    ,.lce_cmd_i(lce_cmd_i)
    ,.lce_cmd_v_i(lce_cmd_v_i)
    ,.lce_cmd_ready_o(lce_cmd_ready_o)

    ,.lce_data_cmd_i(lce_data_cmd_i)
    ,.lce_data_cmd_v_i(lce_data_cmd_v_i)
    ,.lce_data_cmd_ready_o(lce_data_cmd_ready_o)

    ,.lce_data_cmd_o(lce_data_cmd_o)
    ,.lce_data_cmd_v_o(lce_data_cmd_v_o)
    ,.lce_data_cmd_ready_i(lce_data_cmd_ready_i)
    );

// We delay the tlb miss signal by one cycle to synchronize with cache miss signal
always_ff @(posedge clk_i) begin
  if(reset_i) begin
    dtlb_miss_r <= '0;
  end
  else begin
    dtlb_miss_r <= dtlb_miss_v;
  end
end
    
// Decode cmd type
assign itlb_fill_cmd_v = mmu_cmd_v_i & (mmu_cmd.mem_op == e_ptw_i);
assign dtlb_fill_cmd_v = mmu_cmd_v_i & (mmu_cmd.mem_op == e_ptw_l | mmu_cmd.mem_op == e_ptw_s);
assign fence_i_cmd_v   = mmu_cmd_v_i & (mmu_cmd.mem_op == e_fence_i);
assign nop_cmd_v       = mmu_cmd_v_i & (mmu_cmd.mem_op == e_mmu_nop);
assign dcache_cmd_v    = mmu_cmd_v_i & ~(itlb_fill_cmd_v
                                         | dtlb_fill_cmd_v
                                         | fence_i_cmd_v
                                         | nop_cmd_v);


// D-Cache connections
assign dcache_ptag     = (ptw_busy)? ptw_dcache_ptag : dtlb_r_entry.ptag;
assign dcache_tlb_miss = (ptw_busy)? 1'b0 : dtlb_miss_v;
assign dcache_poison   = (ptw_busy)? 1'b0 : chk_poison_ex_i;
assign dcache_pkt_v    = (ptw_busy)? ptw_dcache_v : dcache_cmd_v;

always_comb 
  begin
    // Currently uncached I/O  is determined by high bit of translated address
    dcache_uncached = dcache_ptag[ptag_width_lp-1];

    if(ptw_busy) begin
      dcache_pkt = ptw_dcache_pkt;
      dcache_uncached = '0;
    end
    else begin
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
assign ptw_tlb_miss_vtag = mmu_cmd.vaddr.tag;
assign ptw_page_fault_v  = ptw_instr_page_fault_v | ptw_load_page_fault_v | ptw_store_page_fault_v;
assign ptw_store_not_load = mmu_cmd_v_i & (mmu_cmd.mem_op == e_ptw_s);
 
// MMU response connections
assign mem_resp.data                       = ptw_page_fault_v
                                              ? fault_pc
                                              : dcache_v
                                                 ? dcache_data
                                                 : csr_data_lo;
assign mem_resp.vaddr                      = ptw_page_fault_v ? fault_vaddr : vaddr_r2;
assign mem_resp.exception.illegal_instr    = illegal_instr;
assign mem_resp.exception.instr_fault      = 1'b0; // TODO: Fill in
assign mem_resp.exception.load_fault       = 1'b0;
assign mem_resp.exception.store_fault      = 1'b0;
assign mem_resp.exception.instr_page_fault = ptw_instr_page_fault_v;
assign mem_resp.exception.load_page_fault  = ptw_load_page_fault_v;
assign mem_resp.exception.store_page_fault = ptw_store_page_fault_v;
assign mem_resp.exception.dtlb_miss        = dtlb_miss_r;
assign mem_resp.exception.dcache_miss      = dcache_miss_v;

assign mem_resp_v_o    = ptw_busy ? 1'b0 : (dcache_v | csr_v_lo | fence_i_cmd_v | nop_cmd_v);
assign mmu_cmd_ready_o = dcache_ready & ~dcache_miss_v & ~ptw_busy;

assign itlb_fill_v_o     = ptw_tlb_w_v & itlb_not_dtlb_resp;
assign itlb_fill_vaddr_o = fault_vaddr;
assign itlb_fill_entry_o = ptw_tlb_w_entry;

assign ifence_o = fence_i_cmd_v;

logic dcache_pkt_v_r;
always_ff @(negedge clk_i)
  begin
    dcache_pkt_v_r <= dcache_pkt_v;
    assert (~(dcache_pkt_v_r & dcache_uncached & ~dtlb_miss_v & mmu_cmd.mem_op inside {e_lrw, e_lrd, e_scw, e_scd}))
      else $warning("LR/SC to uncached memory not supported");
  end

endmodule : bp_be_mem_top

