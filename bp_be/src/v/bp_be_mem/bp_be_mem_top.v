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
  import bp_be_pkg::*;
  import bp_be_rv64_pkg::*;
  import bp_be_dcache_pkg::*;
 #(parameter num_core_p                    = "inv"
   , parameter vaddr_width_p               = "inv"
   , parameter paddr_width_p               = "inv"
   , parameter asid_width_p                = "inv"
   , parameter branch_metadata_fwd_width_p = "inv"
 
   // ME parameters
   , parameter num_cce_p                 = "inv"
   , parameter num_lce_p                 = "inv"
   , parameter cce_block_size_in_bytes_p = "inv"
   , parameter lce_assoc_p               = "inv"
   , parameter lce_sets_p                = "inv"

   , parameter reg_data_width_lp = rv64_reg_data_width_gp
   , parameter instr_width_lp    = rv64_instr_width_gp

   , localparam ecode_dec_width_lp = `bp_be_ecode_dec_width
   // Generated parameters
   // D$   
   , localparam lce_data_width_lp = cce_block_size_in_bytes_p*8
   , localparam block_size_in_words_lp = lce_assoc_p // Due to cache interleaving scheme
   , localparam data_mask_width_lp     = (reg_data_width_lp >> 3) // Byte mask
   , localparam byte_offset_width_lp   = `BSG_SAFE_CLOG2(reg_data_width_lp >> 3)
   , localparam word_offset_width_lp   = `BSG_SAFE_CLOG2(block_size_in_words_lp)
   , localparam block_offset_width_lp  = (word_offset_width_lp + byte_offset_width_lp)
   , localparam index_width_lp         = `BSG_SAFE_CLOG2(lce_sets_p)
   , localparam page_offset_width_lp   = (block_offset_width_lp + index_width_lp)
   , localparam dcache_pkt_width_lp    = `bp_be_dcache_pkt_width(page_offset_width_lp
                                                                 , reg_data_width_lp
                                                                 )
   , localparam proc_cfg_width_lp      = `bp_proc_cfg_width(num_core_p, num_lce_p)
   , localparam lce_id_width_lp        = `BSG_SAFE_CLOG2(num_lce_p)

   // MMU                                                              
   , localparam mmu_cmd_width_lp  = `bp_be_mmu_cmd_width(vaddr_width_p)
   , localparam csr_cmd_width_lp  = `bp_be_csr_cmd_width
   , localparam mem_resp_width_lp = `bp_be_mem_resp_width
   , localparam vtag_width_lp     = (vaddr_width_p-bp_page_offset_width_gp)
   , localparam ptag_width_lp     = (paddr_width_p-bp_page_offset_width_gp)
   
   // VM
   , localparam tlb_entry_width_lp = `bp_be_tlb_entry_width(ptag_width_lp)
                                                      
   // ME
   , localparam cce_block_size_in_bits_lp = 8 * cce_block_size_in_bytes_p

    , localparam lce_req_width_lp         = `bp_lce_cce_req_width(num_cce_p
                                                                  , num_lce_p
                                                                  , paddr_width_p
                                                                  , lce_assoc_p
                                                                  , reg_data_width_lp
                                                                  )
    , localparam lce_resp_width_lp        = `bp_lce_cce_resp_width(num_cce_p
                                                                   , num_lce_p
                                                                   , paddr_width_p
                                                                   )
    , localparam lce_data_resp_width_lp   = `bp_lce_cce_data_resp_width(num_cce_p
                                                                        , num_lce_p
                                                                        , paddr_width_p
                                                                        , lce_data_width_lp
                                                                        )
    , localparam lce_cmd_width_lp         = `bp_cce_lce_cmd_width(num_cce_p
                                                                  , num_lce_p
                                                                  , paddr_width_p
                                                                  , lce_assoc_p)
    , localparam lce_data_cmd_width_lp    = `bp_lce_data_cmd_width(num_lce_p
                                                                   , lce_data_width_lp
                                                                   , lce_assoc_p
                                                                   )
   )
  (input                                   clk_i
   , input                                 reset_i

   , input [mmu_cmd_width_lp-1:0]          mmu_cmd_i
   , input                                 mmu_cmd_v_i
   , output                                mmu_cmd_ready_o

   , input [csr_cmd_width_lp-1:0]          csr_cmd_i
   , input                                 csr_cmd_v_i
   , output                                csr_cmd_ready_o

   , input                                 chk_poison_ex_i

   , output [mem_resp_width_lp-1:0]        mem_resp_o
   , output                                mem_resp_v_o
   , input                                 mem_resp_ready_i
   
   , output                                itlb_fill_v_o
   , output [vtag_width_lp-1:0]            itlb_fill_vtag_o
   , output [tlb_entry_width_lp-1:0]       itlb_fill_entry_o
   

   , output [lce_req_width_lp-1:0]         lce_req_o
   , output                                lce_req_v_o
   , input                                 lce_req_ready_i

   , output [lce_resp_width_lp-1:0]        lce_resp_o
   , output                                lce_resp_v_o
   , input                                 lce_resp_ready_i                                 

   , output [lce_data_resp_width_lp-1:0]   lce_data_resp_o
   , output                                lce_data_resp_v_o
   , input                                 lce_data_resp_ready_i

   , input [lce_cmd_width_lp-1:0]          lce_cmd_i
   , input                                 lce_cmd_v_i
   , output                                lce_cmd_ready_o

   , input [lce_data_cmd_width_lp-1:0]     lce_data_cmd_i
   , input                                 lce_data_cmd_v_i
   , output                                lce_data_cmd_ready_o

   , output [lce_data_cmd_width_lp-1:0]    lce_data_cmd_o
   , output                                lce_data_cmd_v_o
   , input                                 lce_data_cmd_ready_i 

   // CSRs
   , input [proc_cfg_width_lp-1:0]         proc_cfg_i
   , input                                 instret_i

   , input [vaddr_width_p-1:0]             exception_pc_i
   , input [instr_width_lp-1:0]            exception_instr_i
   , input                                 exception_v_i
   , input [ecode_dec_width_lp-1:0]        exception_ecode_dec_i

   , input                                 mret_v_i
   , input                                 sret_v_i
   , input                                 uret_v_i

   , input                                 timer_int_i
   , input                                 software_int_i
   , input                                 external_int_i
   , input [reg_data_width_lp-1:0]         interrupt_pc_i

   , output [reg_data_width_lp-1:0]        mepc_o
   , output [reg_data_width_lp-1:0]        mtvec_o
   );

`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   );

`declare_bp_common_proc_cfg_s(num_core_p, num_lce_p)
`declare_bp_be_mmu_structs(vaddr_width_p, lce_sets_p, cce_block_size_in_bytes_p)
`declare_bp_be_dcache_pkt_s(page_offset_width_lp, reg_data_width_lp);
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

<<<<<<< HEAD

/* Internal connections */
/* TLB ports */
logic                     dtlb_en, dtlb_miss, dtlb_w_v, dtlb_r_v;
logic [vtag_width_lp-1:0] dtlb_r_vtag, dtlb_w_vtag, dtlb_miss_vtag;
bp_be_tlb_entry_s         dtlb_r_entry, dtlb_w_entry;

/* PTW ports */
logic [ptag_width_lp-1:0] base_ppn, ptw_dcache_ptag;
logic                     ptw_dcache_v, ptw_busy;
bp_be_dcache_pkt_s        ptw_dcache_pkt; 
logic                     ptw_tlb_miss_v, ptw_tlb_w_v;
logic [vtag_width_lp-1:0] ptw_tlb_w_vtag, ptw_tlb_miss_vtag;
bp_be_tlb_entry_s         ptw_tlb_w_entry;

assign base_ppn = 'h80009;    //TODO: pass from upper level modules

/* D-Cache ports */
bp_be_dcache_pkt_s        dcache_pkt;
logic [reg_data_width_lp-1:0]  dcache_data;
logic [ptag_width_lp-1:0] dcache_ptag;
logic                     dcache_ready, dcache_miss_v, dcache_v, dcache_pkt_v, dcache_tlb_miss, dcache_poison;

/* CSR signals */
logic [reg_data_width_lp-1:0] csr_data_lo;
logic                         csr_v_lo, illegal_instr_v;
logic translation_en;

/* Control signals */
logic itlb_fill_cmd_v, itlb_fill_resp_v;

assign itlb_fill_cmd_v = mmu_cmd_v_i & (mmu_cmd.mem_op == e_ptw);

bp_be_csr
 #(.vaddr_width_p(vaddr_width_p)
   ,.num_core_p(num_core_p)
   ,.lce_sets_p(lce_sets_p)
   ,.cce_block_size_in_bytes_p(cce_block_size_in_bytes_p)
   )
  csr
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.csr_cmd_i(csr_cmd_i)
   ,.csr_cmd_v_i(csr_cmd_v_i)
   ,.csr_cmd_ready_o(csr_cmd_ready_o)

   ,.data_o(csr_data_lo)
   ,.v_o(csr_v_lo)
   ,.illegal_instr_o(illegal_instr_v)

   ,.hartid_i(proc_cfg.mhartid)
   ,.instret_i(instret_i)

   ,.exception_pc_i(exception_pc_i)
   ,.exception_instr_i(exception_instr_i)
   ,.exception_v_i(exception_v_i)
   ,.exception_ecode_dec_i(exception_ecode_dec_i)

   ,.mret_v_i(mret_v_i)
   ,.sret_v_i(sret_v_i)
   ,.uret_v_i(uret_v_i)

   ,.timer_int_i(timer_int_i)
   ,.software_int_i(software_int_i)
   ,.external_int_i(external_int_i)
   ,.interrupt_pc_i(interrupt_pc_i)

   ,.mepc_o(mepc_o)
   ,.mtvec_o(mtvec_o)
   ,.satp_o(satp_lo)
   ,.translation_en_o(translation_en_lo)
   );

bp_be_dtlb
  #(.vtag_width_p(vtag_width_lp)
    ,.ptag_width_p(ptag_width_lp)
    ,.els_p(16)
  )
  dtlb
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(1'b1)
   
   ,.r_v_i(dtlb_r_v)
   ,.r_vtag_i(dtlb_r_vtag)
   
   ,.r_v_o()
   ,.r_entry_o(dtlb_r_entry)
   
   ,.w_v_i(dtlb_w_v)
   ,.w_vtag_i(dtlb_w_vtag)
   ,.w_entry_i(dtlb_w_entry)
   
   ,.miss_clear_i(1'b0)
   ,.miss_v_o(dtlb_miss)
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
   ,.base_ppn_i(base_ppn)
   ,.translation_en_i(1'b0)
   ,.busy_o(ptw_busy)
   
   ,.itlb_not_dtlb_i(itlb_fill_cmd_v)
   ,.itlb_not_dtlb_o(itlb_fill_resp_v)
   
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
  #(.data_width_p(reg_data_width_lp) 
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
    ,.uncached_i(1'b0)                  

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

// D-Cache connections
assign dcache_ptag     = (ptw_busy)? ptw_dcache_ptag : dtlb_r_entry.ptag;
assign dcache_tlb_miss = (ptw_busy)? 1'b0 : dtlb_miss;
assign dcache_poison   = (ptw_busy)? 1'b0 : chk_poison_ex_i;
assign dcache_pkt_v    = (ptw_busy)? ptw_dcache_v 
                         : ((itlb_fill_cmd_v | dtlb_miss)? 1'b0
                         : mmu_cmd_v_i);    
always_comb 
  begin
<<<<<<< HEAD
    if(ptw_busy) begin
      dcache_pkt = ptw_dcache_pkt;
    end
    else begin
      // Currently uncached I/O  is determined by high bit of translated address
      // TODO: Add the uncached signal
      dcache_pkt.opcode      = bp_be_dcache_opcode_e'(mmu_cmd.mem_op);
      dcache_pkt.page_offset = {mmu_cmd.vaddr.index, mmu_cmd.vaddr.offset};
      dcache_pkt.data        = mmu_cmd.data;
    end
end

// D-TLB connections
assign dtlb_r_v     = (itlb_fill_cmd_v | dtlb_miss)? 1'b0 : mmu_cmd_v_i;
assign dtlb_r_vtag  = mmu_cmd.vaddr.tag;
assign dtlb_w_v     = ptw_tlb_w_v & ~itlb_fill_resp_v;
assign dtlb_w_vtag  = ptw_tlb_w_vtag;
assign dtlb_w_entry = ptw_tlb_w_entry;

// PTW connections
assign ptw_tlb_miss_v = dtlb_miss | itlb_fill_cmd_v;
assign ptw_tlb_miss_vtag = (itlb_fill_cmd_v)? mmu_cmd.vaddr.tag : dtlb_miss_vtag;
 
// MMU response connections
assign mem_resp.data   = (dcache_v) ? dcache_data : csr_data_lo;  
assign mem_resp.exception.cache_miss_v = dcache_miss_v;
assign mem_resp.exception.tlb_miss_v = dtlb_miss;
assign mem_resp.exception.illegal_instr_v = illegal_instr_v;

// Ready-valid handshakes
assign mem_resp_v_o    = (ptw_busy)? 1'b0 : (dcache_v | csr_cmd_v_i);
assign mmu_cmd_ready_o = dcache_ready & ~dcache_miss_v & ~dtlb_miss & ~ptw_busy;

assign itlb_fill_v_o     = itlb_fill_resp_v & ptw_tlb_w_v;
assign itlb_fill_vtag_o  = ptw_tlb_w_vtag;
assign itlb_fill_entry_o = ptw_tlb_w_entry;

endmodule : bp_be_mem_top

