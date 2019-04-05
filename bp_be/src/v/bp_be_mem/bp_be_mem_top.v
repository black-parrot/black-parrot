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

   , input [proc_cfg_width_lp-1:0]         proc_cfg_i

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

    , output [lce_data_cmd_width_lp-1:0]   lce_data_cmd_o
    , output                               lce_data_cmd_v_o
    , input                                lce_data_cmd_ready_i 

    // CSRs
    , input                                instret_i
    , input [vaddr_width_p-1:0]            exception_pc_i
    , input [instr_width_lp-1:0]           exception_instr_i
    , input                                exception_v_i

    , output [reg_data_width_lp-1:0]       mepc_o
    , output [reg_data_width_lp-1:0]       mtvec_o
    );

`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   );

`declare_bp_common_proc_cfg_s(num_core_p, num_lce_p)
`declare_bp_be_mmu_structs(vaddr_width_p, lce_sets_p, cce_block_size_in_bytes_p)
`declare_bp_be_dcache_pkt_s(page_offset_width_lp, reg_data_width_lp);

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

// TODO: This struct is not working properly (mismatched widths in synth). Figure out why.
//         This cast works, though
assign mmu_cmd_vaddr = mmu_cmd.vaddr;

/* Internal connections */
logic tlb_miss;
logic [ptag_width_lp-1:0] ptag_r;

bp_be_dcache_pkt_s dcache_pkt;
logic dcache_ready, dcache_miss_v, dcache_v;

logic [reg_data_width_lp-1:0] dcache_data_lo, csr_data_lo;
logic                         csr_v_lo, illegal_csr_v;

// Passthrough TLB conversion
always_ff @(posedge clk_i) 
  begin
    ptag_r <= ptag_width_lp'(mmu_cmd_vaddr.tag);
  end

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
   ,.illegal_csr_o(illegal_csr_v)

   ,.hartid_i(proc_cfg.mhartid)
   ,.instret_i(instret_i)
   ,.exception_pc_i(exception_pc_i)
   ,.exception_instr_i(exception_instr_i)
   ,.exception_v_i(exception_v_i)

   ,.mepc_o(mepc_o)
   ,.mtvec_o(mtvec_o)
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
   ,.v_i(mmu_cmd_v_i)
   ,.ready_o(dcache_ready)

   ,.v_o(dcache_v)
   ,.data_o(dcache_data_lo)

   ,.tlb_miss_i(1'b0)
   ,.ptag_i(ptag_r)
   ,.uncached_i(1'b0)

   ,.cache_miss_o(dcache_miss_v)
   ,.poison_i(chk_poison_ex_i)

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

always_comb 
  begin
    dcache_pkt.opcode      = bp_be_dcache_opcode_e'(mmu_cmd.mem_op);
    dcache_pkt.page_offset = {mmu_cmd_vaddr.index, mmu_cmd_vaddr.offset};
    dcache_pkt.data        = mmu_cmd.data;

    mem_resp.data = dcache_v ? dcache_data_lo : csr_data_lo;
    mem_resp.exception.cache_miss_v = dcache_miss_v;
    mem_resp.exception.illegal_instr_v = illegal_csr_v;
  end

// Ready-valid handshakes
assign mem_resp_v_o    = dcache_v | csr_cmd_v_i;
assign mmu_cmd_ready_o = dcache_ready & ~dcache_miss_v;

endmodule : bp_be_mem_top

