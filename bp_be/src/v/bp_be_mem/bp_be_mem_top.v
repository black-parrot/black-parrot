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
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
   `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_p, dcache_block_width_p, dcache)
   
   // Generated parameters
   // D$
   , localparam block_size_in_words_lp = dcache_assoc_p // Due to cache interleaving scheme
   , localparam bank_width_lp = dcache_block_width_p / dcache_assoc_p
   , localparam num_dwords_per_bank_lp = bank_width_lp / dword_width_p
   , localparam data_mem_mask_width_lp = (bank_width_lp >> 3) // Byte mask
   , localparam bypass_data_mask_width_lp = (dword_width_p >> 3)
   , localparam byte_offset_width_lp   = `BSG_SAFE_CLOG2(bank_width_lp >> 3)
   , localparam word_offset_width_lp   = `BSG_SAFE_CLOG2(block_size_in_words_lp)
   , localparam block_offset_width_lp  = (word_offset_width_lp + byte_offset_width_lp)
   , localparam index_width_lp         = `BSG_SAFE_CLOG2(dcache_sets_p)
   , localparam page_offset_width_lp   = (block_offset_width_lp + index_width_lp)
   , localparam way_id_width_lp=`BSG_SAFE_CLOG2(dcache_assoc_p)
   
   , localparam stat_info_width_lp = `bp_cache_stat_info_width(dcache_assoc_p)   

   , localparam cfg_bus_width_lp      = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)

   , localparam trap_pkt_width_lp      = `bp_be_trap_pkt_width(vaddr_width_p)
   , localparam commit_pkt_width_lp    = `bp_be_commit_pkt_width(vaddr_width_p)

   // MMU
   , localparam mmu_cmd_width_lp  = `bp_be_mmu_cmd_width(vaddr_width_p)
   , localparam csr_cmd_width_lp  = `bp_be_csr_cmd_width
   , localparam mem_resp_width_lp = `bp_be_mem_resp_width(vaddr_width_p)

   // VM
   , localparam tlb_entry_width_lp = `bp_pte_entry_leaf_width(paddr_width_p)
   )
  (input                                     clk_i
   , input                                   reset_i

   , input [cfg_bus_width_lp-1:0]            cfg_bus_i
   , output [dword_width_p-1:0]              cfg_csr_data_o
   , output [1:0]                            cfg_priv_data_o

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

   // D$-LCE Interface
   // signals to LCE
   , output logic [dcache_req_width_lp-1:0]         cache_req_o
   , output logic                                   cache_req_v_o
   , input                                          cache_req_ready_i
   , output logic [dcache_req_metadata_width_lp-1:0]cache_req_metadata_o
   , output logic                                   cache_req_metadata_v_o

   , input cache_req_complete_i

   // data_mem
   , input data_mem_pkt_v_i
   , input [dcache_data_mem_pkt_width_lp-1:0] data_mem_pkt_i
   , output logic data_mem_pkt_ready_o
   , output logic [dcache_block_width_p-1:0] data_mem_o

   // tag_mem
   , input tag_mem_pkt_v_i
   , input [dcache_tag_mem_pkt_width_lp-1:0] tag_mem_pkt_i
   , output logic tag_mem_pkt_ready_o
   , output logic [ptag_width_p-1:0] tag_mem_o

   // stat_mem
   , input stat_mem_pkt_v_i
   , input [dcache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_i
   , output logic stat_mem_pkt_ready_o
   , output logic [stat_info_width_lp-1:0] stat_mem_o

   , input [commit_pkt_width_lp-1:0]         commit_pkt_i

   , input                                   timer_irq_i
   , input                                   software_irq_i
   , input                                   external_irq_i
   , output                                  accept_irq_o
   , output                                  single_step_o
   , output                                  debug_mode_o

   , output [trap_pkt_width_lp-1:0]          trap_pkt_o
   );

`declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
`declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

`declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
// Not sure if this is right.
`declare_bp_be_mmu_structs(vaddr_width_p, ptag_width_p, dcache_sets_p, dcache_block_width_p/8)
`declare_bp_be_dcache_pkt_s(page_offset_width_lp, dword_width_p);
`declare_bp_cache_service_if(paddr_width_p, ptag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_p, dcache_block_width_p, dcache);
  bp_dcache_req_s cache_req_cast_o;

  assign cache_req_o = cache_req_cast_o;

// Cast input and output ports
bp_cfg_bus_s           cfg_bus;
bp_be_mmu_cmd_s        mmu_cmd;
bp_be_csr_cmd_s        csr_cmd;
bp_be_mem_resp_s       mem_resp;
bp_be_mmu_vaddr_s      mmu_cmd_vaddr;
bp_be_commit_pkt_s     commit_pkt;
bp_be_trap_pkt_s       trap_pkt;

assign cfg_bus = cfg_bus_i;
assign mmu_cmd = mmu_cmd_i;
assign csr_cmd = csr_cmd_i;

assign mem_resp_o = mem_resp;
assign commit_pkt = commit_pkt_i;
assign trap_pkt_o = trap_pkt;

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
logic                     dcache_v, dcache_fencei_v, dcache_pkt_v;
logic                     dcache_tlb_miss, dcache_poison;
logic                     dcache_uncached;
logic                     dcache_ready_lo;
logic                     dcache_miss_lo;


/* CSR signals */
logic                     csr_illegal_instr_lo;
logic [ptag_width_p-1:0]  satp_ppn_lo;
logic [dword_width_p-1:0] csr_data_lo;
logic                     csr_v_lo;
logic                     mstatus_sum_lo, mstatus_mxr_lo, translation_en_lo;
logic                     itlb_fill_lo, instr_page_fault_lo, instr_access_fault_lo, instr_misaligned_lo;
logic                     ebreak_lo;
logic [rv64_priv_width_gp-1:0] priv_mode_lo;

logic load_access_fault_v, load_access_fault_mem3, store_access_fault_v, store_access_fault_mem3;
logic load_page_fault_v, load_page_fault_mem3, store_page_fault_v, store_page_fault_mem3;

/* Control signals */
logic dcache_cmd_v;
logic fencei_cmd_v;
logic fencei_v_r, fencei_v_rr;
logic itlb_not_dtlb_resp;
logic mmu_cmd_v_r, mmu_cmd_v_rr, dtlb_miss_r;
logic is_store_r, is_store_rr;
bp_be_mmu_vaddr_s vaddr_mem3, fault_vaddr;
logic [vaddr_width_p-1:0] fault_pc;

wire itlb_fill_cmd_v = itlb_fill_lo;
wire dtlb_fill_cmd_v = dtlb_miss_r;

bsg_dff_en
 #(.width_p(2*vaddr_width_p))
 fault_reg
  (.clk_i(clk_i)
   ,.en_i(itlb_fill_cmd_v | dtlb_fill_cmd_v)

   ,.data_i({vaddr_mem3, commit_pkt.pc})
   ,.data_o({fault_vaddr, fault_pc})
   );

wire is_store = mmu_cmd_v_i & mmu_cmd.mem_op inside {e_sb, e_sh, e_sw, e_sd, e_scw, e_scd};

bsg_dff_chain
 #(.width_p(vaddr_width_p)
   ,.num_stages_p(2)
   )
 vaddr_pipe
  (.clk_i(clk_i)

   ,.data_i(mmu_cmd.vaddr)
   ,.data_o(vaddr_mem3)
   );

bp_be_ecode_dec_s exception_ecode_dec_li;

wire exception_v_li = commit_pkt.v | ptw_page_fault_v;
wire [vaddr_width_p-1:0] exception_pc_li = ptw_page_fault_v ? fault_pc : commit_pkt.pc;
wire [vaddr_width_p-1:0] exception_npc_li = commit_pkt.npc;
// TODO: vaddr_mem3 -> commit_pkt.vaddr
wire [vaddr_width_p-1:0] exception_vaddr_li = ptw_page_fault_v ? fault_vaddr : vaddr_mem3;
wire [instr_width_p-1:0] exception_instr_li = commit_pkt.instr;
// TODO: exception priority is non-compliant with the spec.
assign exception_ecode_dec_li =
  '{instr_misaligned : instr_misaligned_lo
    ,instr_fault     : instr_access_fault_lo
    ,illegal_instr   : csr_cmd_v_i & ((csr_cmd.csr_op == e_op_illegal_instr) || csr_illegal_instr_lo)
    ,breakpoint      : ebreak_lo
    ,load_misaligned : 1'b0 // TODO: Need to detect this
    ,load_fault      : load_access_fault_mem3
    ,store_misaligned: 1'b0 // TODO: Need to detect this
    ,store_fault     : store_access_fault_mem3
    ,ecall_u_mode    : csr_cmd_v_i & (csr_cmd.csr_op == e_ecall) & (priv_mode_lo == `PRIV_MODE_U)
    ,ecall_s_mode    : csr_cmd_v_i & (csr_cmd.csr_op == e_ecall) & (priv_mode_lo == `PRIV_MODE_S)
    ,ecall_m_mode    : csr_cmd_v_i & (csr_cmd.csr_op == e_ecall) & (priv_mode_lo == `PRIV_MODE_M)
    ,instr_page_fault: ptw_instr_page_fault_v | instr_page_fault_lo
    ,load_page_fault : ptw_load_page_fault_v | load_page_fault_mem3
    ,store_page_fault: ptw_store_page_fault_v | store_page_fault_mem3
    ,default: '0
    };

bp_be_csr
 #(.bp_params_p(bp_params_p))
  csr
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.cfg_bus_i(cfg_bus_i)
   ,.cfg_csr_data_o(cfg_csr_data_o)
   ,.cfg_priv_data_o(cfg_priv_data_o)

   ,.csr_cmd_i(csr_cmd_i)
   ,.csr_cmd_v_i(csr_cmd_v_i)
   ,.csr_cmd_ready_o(csr_cmd_ready_o)

   ,.data_o(csr_data_lo)
   ,.v_o(csr_v_lo)
   ,.illegal_instr_o(csr_illegal_instr_lo)

   ,.hartid_i(cfg_bus.core_id)
   ,.instret_i(commit_pkt.instret)

   ,.exception_v_i(exception_v_li)
   ,.fencei_v_i(dcache_fencei_v)
   ,.exception_pc_i(exception_pc_li)
   ,.exception_npc_i(exception_npc_li)
   ,.exception_vaddr_i(exception_vaddr_li)
   ,.exception_instr_i(exception_instr_li)
   ,.exception_ecode_dec_i(exception_ecode_dec_li)

   ,.timer_irq_i(timer_irq_i)
   ,.software_irq_i(software_irq_i)
   ,.external_irq_i(external_irq_i)
   ,.accept_irq_o(accept_irq_o)
   ,.debug_mode_o(debug_mode_o)
   ,.single_step_o(single_step_o)

   ,.priv_mode_o(priv_mode_lo)
   ,.trap_pkt_o(trap_pkt)
   ,.satp_ppn_o(satp_ppn_lo)
   ,.translation_en_o(translation_en_lo)
   ,.mstatus_sum_o(mstatus_sum_lo)
   ,.mstatus_mxr_o(mstatus_mxr_lo)

   ,.itlb_fill_o(itlb_fill_lo)
   ,.instr_page_fault_o(instr_page_fault_lo)
   ,.instr_access_fault_o(instr_access_fault_lo)
   ,.instr_misaligned_o(instr_misaligned_lo)
   ,.ebreak_o(ebreak_lo)
   );

bp_tlb
  #(.bp_params_p(bp_params_p)
    ,.tlb_els_p(dtlb_els_p)
  )
  dtlb
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.flush_i(trap_pkt.sfence)
   ,.translation_en_i(translation_en_lo)

   ,.v_i(dtlb_r_v | dtlb_w_v)
   ,.w_i(dtlb_w_v)
   ,.vtag_i((dtlb_w_v)? dtlb_w_vtag : dtlb_r_vtag)
   ,.entry_i(dtlb_w_entry)

   ,.v_o(dtlb_r_v_lo)
   ,.entry_o(dtlb_r_entry)

   ,.miss_v_o(dtlb_miss_v)
   ,.miss_vtag_o(dtlb_miss_vtag)
  );

bp_pma
 #(.bp_params_p(bp_params_p))
 pma
  (.ptag_v_i(dtlb_r_v_lo)
   ,.ptag_i(dtlb_r_entry.ptag)

   ,.uncached_o(dcache_uncached)
   );

bp_be_ptw
  #(.bp_params_p(bp_params_p)
    ,.pte_width_p(bp_sv39_pte_width_gp)
    ,.page_table_depth_p(bp_sv39_page_table_depth_gp)
  )
  ptw
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.base_ppn_i(satp_ppn_lo)
   ,.priv_mode_i(priv_mode_lo)
   ,.mstatus_sum_i(mstatus_sum_lo)
   ,.mstatus_mxr_i(mstatus_mxr_lo)
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
   ,.dcache_rdy_i(dcache_ready_lo) 
   ,.dcache_miss_i(dcache_miss_lo)
  );

logic load_op_tl_lo, store_op_tl_lo;
bp_be_dcache
  #(.bp_params_p(bp_params_p)
    ,.writethrough_p(0))
  dcache
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.cfg_bus_i(cfg_bus_i)

    ,.dcache_pkt_i(dcache_pkt)
    ,.v_i(dcache_pkt_v)
    ,.ready_o(dcache_ready_lo)

    ,.fencei_v_o(dcache_fencei_v)
    ,.v_o(dcache_v)
    ,.data_o(dcache_data)

    ,.tlb_miss_i(dcache_tlb_miss)
    ,.ptag_i(dcache_ptag)
    ,.uncached_i(dcache_uncached)

    ,.load_op_tl_o(load_op_tl_lo)
    ,.store_op_tl_o(store_op_tl_lo)
    ,.poison_i(dcache_poison)


    // D$-LCE Interface
    ,.dcache_miss_o(dcache_miss_lo)
    ,.cache_req_complete_i(cache_req_complete_i)
    ,.cache_req_o(cache_req_cast_o)
    ,.cache_req_v_o(cache_req_v_o)
    ,.cache_req_ready_i(cache_req_ready_i)
    ,.cache_req_metadata_o(cache_req_metadata_o)
    ,.cache_req_metadata_v_o(cache_req_metadata_v_o)

    ,.data_mem_pkt_v_i(data_mem_pkt_v_i)
    ,.data_mem_pkt_i(data_mem_pkt_i)
    ,.data_mem_o(data_mem_o)
    ,.data_mem_pkt_ready_o(data_mem_pkt_ready_o)
    ,.tag_mem_pkt_v_i(tag_mem_pkt_v_i)
    ,.tag_mem_pkt_i(tag_mem_pkt_i)
    ,.tag_mem_o(tag_mem_o)
    ,.tag_mem_pkt_ready_o(tag_mem_pkt_ready_o)
    ,.stat_mem_pkt_v_i(stat_mem_pkt_v_i)
    ,.stat_mem_pkt_i(stat_mem_pkt_i)
    ,.stat_mem_o(stat_mem_o)
    ,.stat_mem_pkt_ready_o(stat_mem_pkt_ready_o)
    );

// We delay the tlb miss signal by one cycle to synchronize with cache miss signal
// We latch the dcache miss signal
always_ff @(posedge clk_i) begin
  if(reset_i) begin
    dtlb_miss_r  <= '0;
    mmu_cmd_v_r  <= '0;
    mmu_cmd_v_rr <= '0;
    is_store_r   <= '0;
    is_store_rr  <= '0;
    fencei_v_r   <= '0;
    fencei_v_rr  <= '0;
    load_page_fault_mem3    <= '0;
    store_page_fault_mem3   <= '0;
    load_access_fault_mem3  <= '0;
    store_access_fault_mem3 <= '0;
  end
  else begin
    dtlb_miss_r  <= dtlb_miss_v & ~chk_poison_ex_i;
    mmu_cmd_v_r  <= mmu_cmd_v_i;
    mmu_cmd_v_rr <= mmu_cmd_v_r & ~chk_poison_ex_i;
    is_store_r   <= is_store;
    is_store_rr  <= is_store_r & ~chk_poison_ex_i;
    fencei_v_r   <= fencei_cmd_v;
    fencei_v_rr  <= fencei_v_r & ~chk_poison_ex_i;
    load_page_fault_mem3    <= load_page_fault_v & ~chk_poison_ex_i;
    store_page_fault_mem3   <= store_page_fault_v & ~chk_poison_ex_i;
    load_access_fault_mem3  <= load_access_fault_v & ~chk_poison_ex_i;
    store_access_fault_mem3 <= store_access_fault_v & ~chk_poison_ex_i;
  end
end

// Check instruction accesses
wire data_priv_page_fault = ((priv_mode_lo == `PRIV_MODE_S) & ~mstatus_sum_lo & dtlb_r_entry.u)
                              | ((priv_mode_lo == `PRIV_MODE_U) & ~dtlb_r_entry.u);
wire data_write_page_fault = is_store_r & (~dtlb_r_entry.w | ~dtlb_r_entry.d);

assign load_page_fault_v  = mmu_cmd_v_r & dtlb_r_v_lo & translation_en_lo & ~is_store_r & data_priv_page_fault;
assign store_page_fault_v = mmu_cmd_v_r & dtlb_r_v_lo & translation_en_lo & is_store_r & (data_priv_page_fault | data_write_page_fault);

// Decode cmd type
assign dcache_cmd_v    = mmu_cmd_v_i;
assign fencei_cmd_v    = mmu_cmd_v_i & (mmu_cmd.mem_op == e_fencei);

// D-Cache connections
assign dcache_ptag     = (ptw_busy)? ptw_dcache_ptag : dtlb_r_entry.ptag;
assign dcache_tlb_miss = (ptw_busy)? 1'b0 : dtlb_miss_v;
assign dcache_poison   = (ptw_busy)? 1'b0 : chk_poison_ex_i
                                            | (load_page_fault_v | store_page_fault_v)
                                            | (load_access_fault_v | store_access_fault_v);
assign dcache_pkt_v    = (ptw_busy)? ptw_dcache_v : dcache_cmd_v;

always_comb
  begin
    if(ptw_busy) begin
      dcache_pkt = ptw_dcache_pkt;
    end
    else begin
      // We assume that mem op == dcache op
      dcache_pkt.opcode      = bp_be_dcache_opcode_e'(mmu_cmd.mem_op);
      dcache_pkt.page_offset = {mmu_cmd.vaddr.index, mmu_cmd.vaddr.offset};
      dcache_pkt.data        = mmu_cmd.data;
    end
end

// Fault if in uncached mode but access is not for an uncached address
wire is_uncached_mode = (cfg_bus.dcache_mode == e_lce_mode_uncached);
wire mode_fault_v = (is_uncached_mode & ~dcache_uncached);
  // TODO: Enable other domains by setting enabled dids with cfg_bus
wire did_fault_v = (dcache_ptag[ptag_width_p-1-:io_noc_did_width_p] != '0) &
                   ~((dcache_ptag[ptag_width_p-1-:io_noc_did_width_p] == 1) & sac_x_dim_p > 0);

assign load_access_fault_v  = load_op_tl_lo & (mode_fault_v | did_fault_v);
assign store_access_fault_v = store_op_tl_lo & (mode_fault_v | did_fault_v);

// D-TLB connections
assign dtlb_r_v     = dcache_cmd_v & ~fencei_cmd_v;
assign dtlb_r_vtag  = mmu_cmd.vaddr.tag;
assign dtlb_w_v     = ptw_tlb_w_v & ~itlb_not_dtlb_resp;
assign dtlb_w_vtag  = ptw_tlb_w_vtag;
assign dtlb_w_entry = ptw_tlb_w_entry;

// PTW connections
assign ptw_tlb_miss_v    = itlb_fill_cmd_v | dtlb_fill_cmd_v;
assign ptw_tlb_miss_vtag = vaddr_mem3.tag;
assign ptw_page_fault_v  = ptw_instr_page_fault_v | ptw_load_page_fault_v | ptw_store_page_fault_v;
assign ptw_store_not_load = dtlb_fill_cmd_v & is_store_rr;

// MMU response connections
assign mem_resp.exc_v  = |exception_ecode_dec_li;
assign mem_resp.miss_v = mmu_cmd_v_rr & ~dcache_v & ~dcache_fencei_v & ~|exception_ecode_dec_li;
assign mem_resp.data   = dcache_v ? dcache_data : csr_data_lo;

assign mem_resp_v_o    = ptw_busy ? 1'b0 : mmu_cmd_v_rr | csr_v_lo;
assign mmu_cmd_ready_o = dcache_ready_lo & ~dcache_miss_lo & ~ptw_busy;

assign itlb_fill_v_o     = ptw_tlb_w_v & itlb_not_dtlb_resp;
assign itlb_fill_vaddr_o = fault_vaddr;
assign itlb_fill_entry_o = ptw_tlb_w_entry;

// synopsys translate_off
bp_be_mmu_cmd_s mmu_cmd_r;
always_ff @(posedge clk_i)
  mmu_cmd_r <= mmu_cmd;

always_ff @(negedge clk_i)
  begin
    assert ((reset_i !== 1'b0) || ~(mmu_cmd_v_r & dtlb_r_v_lo & dcache_uncached & (mmu_cmd_r.mem_op inside {e_lrw, e_lrd, e_scw, e_scd})))
      else $warning("LR/SC to uncached memory not supported");
  end

// synopsys translate_on
//
endmodule

