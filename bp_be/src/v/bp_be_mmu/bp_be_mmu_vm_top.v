
module bp_be_mmu_vm_top 
  import bp_common_pkg::*;
  import bp_be_pkg::*;
  import bp_be_rv64_pkg::*;
  import bp_be_dcache_pkg::*;
 #(parameter vaddr_width_p                 = "inv"
   , parameter paddr_width_p               = "inv"
   , parameter asid_width_p                = "inv"
   , parameter branch_metadata_fwd_width_p = "inv"
 
   // ME parameters
   , parameter num_cce_p                 = "inv"
   , parameter num_lce_p                 = "inv"
   , parameter cce_block_size_in_bytes_p = "inv"
   , parameter lce_assoc_p               = "inv"
   , parameter lce_sets_p                = "inv"


   // From RISC-V specifications
   , localparam reg_data_width_lp = rv64_reg_data_width_gp

   // Generated parameters
   // D$   
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
   , localparam lce_id_width_lp = `BSG_SAFE_CLOG2(num_lce_p)

   // MMU                                                              
   , localparam mmu_cmd_width_lp  = `bp_be_mmu_cmd_width(vaddr_width_p)
   , localparam mmu_resp_width_lp = `bp_be_mmu_resp_width
   , localparam vtag_width_lp     = vaddr_width_p - page_offset_width_lp
   , localparam ptag_width_lp     = paddr_width_p - page_offset_width_lp
                                                      
   // ME
   , localparam cce_block_size_in_bits_lp = 8 * cce_block_size_in_bytes_p

   , localparam lce_req_width_lp = `bp_lce_cce_req_width(num_cce_p
                                                         , num_lce_p
                                                         , paddr_width_p
                                                         , lce_assoc_p
                                                         )
   , localparam lce_resp_width_lp = `bp_lce_cce_resp_width(num_cce_p
                                                           , num_lce_p
                                                           , paddr_width_p
                                                           )
   , localparam lce_data_resp_width_lp = `bp_lce_cce_data_resp_width(num_cce_p
                                                                     , num_lce_p
                                                                     , paddr_width_p
                                                                     , cce_block_size_in_bits_lp
                                                                     )
   , localparam cce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p
                                                       , num_lce_p
                                                       , paddr_width_p
                                                       , lce_assoc_p
                                                       )
   , localparam cce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p
                                                                 , num_lce_p
                                                                 , paddr_width_p
                                                                 , cce_block_size_in_bits_lp
                                                                 , lce_assoc_p
                                                                 )
   , localparam lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_p
                                                                   , paddr_width_p
                                                                   , cce_block_size_in_bits_lp
                                                                   , lce_assoc_p
                                                                   )
   )
  (input                                   clk_i
   , input                                 reset_i


   , input [mmu_cmd_width_lp-1:0]          mmu_cmd_i
   , input                                 mmu_cmd_v_i
   , output                                mmu_cmd_ready_o

   , input                                 chk_poison_ex_i

   , output [mmu_resp_width_lp-1:0]        mmu_resp_o
   , output                                mmu_resp_v_o
   , input                                 mmu_resp_ready_i

   , output [lce_req_width_lp-1:0]         lce_req_o
   , output                                lce_req_v_o
   , input                                 lce_req_ready_i

   , output [lce_resp_width_lp-1:0]        lce_resp_o
   , output                                lce_resp_v_o
   , input                                 lce_resp_ready_i                                 

   , output [lce_data_resp_width_lp-1:0]   lce_data_resp_o
   , output                                lce_data_resp_v_o
   , input                                 lce_data_resp_ready_i

   , input [cce_cmd_width_lp-1:0]          lce_cmd_i
   , input                                 lce_cmd_v_i
   , output                                lce_cmd_ready_o

   , input [cce_data_cmd_width_lp-1:0]     lce_data_cmd_i
   , input                                 lce_data_cmd_v_i
   , output                                lce_data_cmd_ready_o

   , input [lce_lce_tr_resp_width_lp-1:0]  lce_tr_resp_i
   , input                                 lce_tr_resp_v_i
   , output                                lce_tr_resp_ready_o

   , output [lce_lce_tr_resp_width_lp-1:0] lce_tr_resp_o
   , output                                lce_tr_resp_v_o
   , input                                 lce_tr_resp_ready_i

   , input [lce_id_width_lp-1:0]           dcache_id_i
   );

`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   );

`declare_bp_be_mmu_structs(vaddr_width_p, lce_sets_p, cce_block_size_in_bytes_p)
`declare_bp_be_dcache_pkt_s(page_offset_width_lp, reg_data_width_lp);
`declare_bp_be_tlb_entry_s(ptag_width_lp);

// Cast input and output ports 
bp_be_mmu_cmd_s        mmu_cmd;
bp_be_mmu_resp_s       mmu_resp;
//bp_be_mmu_vaddr_s      mmu_cmd_vaddr;

assign mmu_cmd    = mmu_cmd_i;
assign mmu_resp_o = mmu_resp;

// TODO: This struct is not working properly (mismatched widths in synth). Figure out why.
//         This cast works, though
//assign mmu_cmd_vaddr = mmu_cmd.vaddr;

/* Internal connections */
logic                     tlb_miss, tlb_w_v;
logic [vtag_width_lp-1:0] tlb_w_vtag, tlb_miss_vtag;
bp_be_tlb_entry_s         tlb_r_entry, tlb_w_entry;

bp_be_dcache_pkt_s dcache_pkt;
logic dcache_ready, dcache_miss_v, dcache_v;

/* Suppress warnings */
logic unused0;
assign unused0 = mmu_resp_ready_i;

bp_be_dtlb
  #(.vtag_width_p(vtag_width_lp)
    ,.ptag_width_p(ptag_width_lp)
	,.els_p(16)
  )
  dtlb
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(1'b0)
   
   ,.r_v_i(mmu_cmd_v_i)
   ,.r_vtag_i(mmu_cmd.vaddr.tag)
   
   ,.r_v_o()
   ,.r_entry_o(tlb_r_entry)
   
   ,.w_v_i(/*tlb_w_v*/1'b0)
   ,.w_vtag_i(tlb_w_vtag)
   ,.w_entry_i(tlb_w_entry)
   
   ,.miss_v_o(tlb_miss)
   ,.miss_vtag_o(tlb_miss_vtag)
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

    ,.lce_id_i(dcache_id_i)

    ,.dcache_pkt_i(dcache_pkt)
    ,.v_i(mmu_cmd_v_i)
    ,.ready_o(dcache_ready)

    ,.v_o(dcache_v)
    ,.data_o(mmu_resp.data)

    ,.tlb_miss_i(tlb_miss)
    ,.ptag_i(tlb_r_entry.ptag)

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

    // LCE-LCE interface
    ,.lce_tr_resp_i(lce_tr_resp_i)
    ,.lce_tr_resp_v_i(lce_tr_resp_v_i)
    ,.lce_tr_resp_ready_o(lce_tr_resp_ready_o)

    ,.lce_tr_resp_o(lce_tr_resp_o)
    ,.lce_tr_resp_v_o(lce_tr_resp_v_o)
    ,.lce_tr_resp_ready_i(lce_tr_resp_ready_i)
    );

always_comb 
  begin
    dcache_pkt.opcode      = bp_be_dcache_opcode_e'(mmu_cmd.mem_op);
    dcache_pkt.page_offset = {mmu_cmd.vaddr.index, mmu_cmd.vaddr.offset};
    dcache_pkt.data        = mmu_cmd.data;

    mmu_resp.exception.cache_miss_v = dcache_miss_v;
  end

// Ready-valid handshakes
assign mmu_resp_v_o    = dcache_v;
assign mmu_cmd_ready_o = dcache_ready & ~dcache_miss_v;

endmodule : bp_be_mmu_vm_top

