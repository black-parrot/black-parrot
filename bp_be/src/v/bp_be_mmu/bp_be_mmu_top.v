/**
 *
 *  Name:
 *    bp_be_mmu_top.v
 * 
 *  Description:
 *    memory management unit.
 *
 */

module bp_be_mmu_top 
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

   , parameter data_width_p = rv64_reg_data_width_gp

   // Generated parameters
   // D$   
   , localparam lce_data_width_lp = cce_block_size_in_bytes_p*8
   , localparam block_size_in_words_lp = lce_assoc_p // Due to cache interleaving scheme
   , localparam data_mask_width_lp     = (data_width_p >> 3) // Byte mask
   , localparam byte_offset_width_lp   = `BSG_SAFE_CLOG2(data_width_p >> 3)
   , localparam word_offset_width_lp   = `BSG_SAFE_CLOG2(block_size_in_words_lp)
   , localparam block_offset_width_lp  = (word_offset_width_lp + byte_offset_width_lp)
   , localparam index_width_lp         = `BSG_SAFE_CLOG2(lce_sets_p)
   , localparam page_offset_width_lp   = (block_offset_width_lp + index_width_lp)
   , localparam dcache_pkt_width_lp    = `bp_be_dcache_pkt_width(page_offset_width_lp
                                                                 , data_width_p
                                                                 )
   , localparam lce_id_width_lp        = `BSG_SAFE_CLOG2(num_lce_p)

   // MMU                                                              
   , localparam mmu_cmd_width_lp  = `bp_be_mmu_cmd_width(vaddr_width_p)
   , localparam mmu_resp_width_lp = `bp_be_mmu_resp_width
   , localparam vtag_width_lp     = (vaddr_width_p-bp_page_offset_width_gp)
   , localparam ptag_width_lp     = (paddr_width_p-bp_page_offset_width_gp)
                                                      
   // ME
   , localparam cce_block_size_in_bits_lp = 8 * cce_block_size_in_bytes_p

    , localparam lce_req_width_lp         = `bp_lce_cce_req_width(num_cce_p
                                                                  , num_lce_p
                                                                  , paddr_width_p
                                                                  , lce_assoc_p
                                                                  , data_width_p
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

   , input                                 chk_poison_ex_i

   , output [mmu_resp_width_lp-1:0]        mmu_resp_o
   , output                                mmu_resp_v_o

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

   , input [lce_id_width_lp-1:0]           dcache_id_i
   );

`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   );

`declare_bp_be_mmu_structs(vaddr_width_p, lce_sets_p, cce_block_size_in_bytes_p)
`declare_bp_be_dcache_pkt_s(page_offset_width_lp, data_width_p);

// Cast input and output ports 
bp_be_mmu_cmd_s        mmu_cmd;
bp_be_mmu_resp_s       mmu_resp;
bp_be_mmu_vaddr_s      mmu_cmd_vaddr;

assign mmu_cmd    = mmu_cmd_i;
assign mmu_resp_o = mmu_resp;

// TODO: This struct is not working properly (mismatched widths in synth). Figure out why.
//         This cast works, though
assign mmu_cmd_vaddr = mmu_cmd.vaddr;

/* Internal connections */
logic tlb_miss;
logic [ptag_width_lp-1:0] ptag_r;

bp_be_dcache_pkt_s dcache_pkt;
logic dcache_ready, dcache_miss_v, dcache_v;


// Passthrough TLB conversion
always_ff @(posedge clk_i) 
  begin
    ptag_r <= ptag_width_lp'(mmu_cmd_vaddr.tag);
  end

bp_be_dcache 
  #(.data_width_p(data_width_p) 
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

    mmu_resp.exception.cache_miss_v = dcache_miss_v;
  end

// Ready-valid handshakes
assign mmu_resp_v_o    = dcache_v;
assign mmu_cmd_ready_o = dcache_ready & ~dcache_miss_v;

endmodule : bp_be_mmu_top

