/**
 *  testbench.v
 */

module testbench
 import bp_common_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_be_pkg::*;
 import bp_be_dcache_pkg::*;
 import bp_cce_pkg::*;
 #(parameter vaddr_width_p                 = "inv"
   , parameter paddr_width_p               = "inv"
   , parameter asid_width_p                = "inv"
   , parameter branch_metadata_fwd_width_p = "inv"
   , parameter btb_indx_width_p            = "inv"
   , parameter bht_indx_width_p            = "inv"
   , parameter ras_addr_width_p            = "inv"
   , parameter core_els_p                  = "inv"
   , parameter num_cce_p                   = "inv"
   , parameter num_lce_p                   = "inv"
   , parameter lce_sets_p                  = "inv"
   , parameter lce_assoc_p                 = "inv"
   , parameter block_size_in_bytes_p       = "inv"
   , parameter num_inst_ram_els_p          = "inv"
   , parameter mem_els_p                   = "inv"

   // Trace replay parameters
   , parameter trace_ring_width_p          = "inv"
   , parameter trace_rom_addr_width_p      = "inv"
   , localparam trace_rom_data_width_lp    = trace_ring_width_p + 4

   // Test program related parameters
   , parameter boot_rom_els_p              = "inv"
   , parameter boot_rom_width_p            = "inv"
   , localparam lg_boot_rom_els_lp         = `BSG_SAFE_CLOG2(boot_rom_els_p)

   // From RISC-V specifications
   , localparam data_width_lp = rv64_dword_width_gp
   , localparam word_width_lp = rv64_word_width_gp
   , localparam half_width_lp = rv64_hword_width_gp
   , localparam byte_width_lp = rv64_byte_width_gp

   // D$ calculated parameters
   , localparam word_offset_width_lp = `BSG_SAFE_CLOG2(lce_assoc_p)
   , localparam index_width_lp       = `BSG_SAFE_CLOG2(lce_sets_p)
   , localparam data_mask_width_lp   = (data_width_lp>>3)
   , localparam byte_offset_width_lp = `BSG_SAFE_CLOG2(data_mask_width_lp)
   , localparam page_offset_width_lp = word_offset_width_lp+index_width_lp+byte_offset_width_lp
   , localparam ptag_width_lp        = paddr_width_p-page_offset_width_lp

   // For the D$, cache block size is number of ways multiplied by D$ "word" size
   , localparam block_size_in_bits_lp = 8 * block_size_in_bytes_p
   , localparam bp_be_dcache_pkt_width_lp = `bp_be_dcache_pkt_width(page_offset_width_lp
                                                                    , data_width_lp
                                                                    )

   , localparam lce_cce_req_width_lp       = `bp_lce_cce_req_width(num_cce_p
                                                                   , num_lce_p
                                                                   , paddr_width_p
                                                                   , lce_assoc_p
                                                                   )
   , localparam lce_cce_resp_width_lp      = `bp_lce_cce_resp_width(num_cce_p
                                                                    , num_lce_p
                                                                    , paddr_width_p
                                                                    )
   , localparam lce_cce_data_resp_width_lp = `bp_lce_cce_data_resp_width(num_cce_p
                                                                         , num_lce_p
                                                                         , paddr_width_p
                                                                         , block_size_in_bytes_p
                                                                         )
   , localparam cce_lce_cmd_width_lp       = `bp_cce_lce_cmd_width(num_cce_p
                                                                   , num_lce_p
                                                                   , paddr_width_p
                                                                   , lce_assoc_p
                                                                   )
   , localparam cce_lce_data_cmd_width_lp  = `bp_cce_lce_data_cmd_width(num_cce_p
                                                                        , num_lce_p
                                                                        , paddr_width_p
                                                                        , block_size_in_bytes_p
                                                                        , lce_assoc_p
                                                                        )
   , localparam lce_lce_tr_resp_width_lp   = `bp_lce_lce_tr_resp_width(num_lce_p
                                                                       , paddr_width_p
                                                                       , block_size_in_bytes_p
                                                                       , lce_assoc_p
                                                                       )

   , localparam cce_inst_ram_addr_width_lp = `BSG_SAFE_CLOG2(num_inst_ram_els_p)
   )
  (input clk_i
   , input reset_i
   );

`declare_bp_common_proc_cfg_s(core_els_p, num_lce_p)
`declare_bp_common_fe_be_if_structs(vaddr_width_p
                                    , paddr_width_p
                                    , asid_width_p
                                    , branch_metadata_fwd_width_p
                                    )
`declare_bp_lce_cce_req_s(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p);
`declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, paddr_width_p);
`declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_p, paddr_width_p, block_size_in_bits_lp);
`declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p);
`declare_bp_cce_lce_data_cmd_s(num_cce_p, num_lce_p, paddr_width_p, block_size_in_bits_lp, lce_assoc_p);
`declare_bp_lce_lce_tr_resp_s(num_lce_p, paddr_width_p, block_size_in_bits_lp, lce_assoc_p);
`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   )
`declare_bp_be_dcache_pkt_s(page_offset_width_lp, data_width_lp);

// LCE-CCE connection
bp_cce_lce_cmd_s [1:0] cce_lce_cmd_li;
logic [1:0] cce_lce_cmd_v_li, cce_lce_cmd_ready_lo;

bp_cce_lce_data_cmd_s [1:0] cce_lce_data_cmd_li;
logic [1:0] cce_lce_data_cmd_v_li, cce_lce_data_cmd_ready_lo;

bp_lce_cce_req_s [1:0] lce_cce_req_lo;
logic [1:0] lce_cce_req_v_lo, lce_cce_req_ready_li;

bp_lce_cce_resp_s [1:0] lce_cce_resp_lo;
logic [1:0] lce_cce_resp_v_lo, lce_cce_resp_ready_li;

bp_lce_cce_data_resp_s [1:0] lce_cce_data_resp_lo;
logic [1:0] lce_cce_data_resp_v_lo, lce_cce_data_resp_ready_li;

bp_lce_lce_tr_resp_s [1:0] lce_tr_resp_li;
logic [1:0] lce_tr_resp_v_li, lce_tr_resp_ready_lo;

bp_lce_lce_tr_resp_s [1:0] lce_tr_resp_lo;
logic [1:0] lce_tr_resp_v_lo, lce_tr_resp_ready_li;

// Trace replay connections
logic [trace_ring_width_p-1:0]      tr_data_li;
logic tr_v_li, tr_ready_lo;

logic [trace_ring_width_p-1:0]      tr_data_lo;
logic tr_v_lo, tr_yumi_li;

logic [trace_rom_addr_width_p-1:0]  tr_rom_addr_li;
logic [trace_rom_data_width_lp-1:0] tr_rom_data_lo;

logic test_done;

// D$ connections
bp_be_dcache_pkt_s [1:0] dcache_pkt_li;
logic [1:0] dcache_ready_lo;

logic [1:0] [ptag_width_lp-1:0] dcache_paddr_li;

logic [1:0] [data_width_lp-1:0] dcache_data_lo;
logic [1:0]  dcache_v_lo;

logic [1:0] dcache_miss_lo;
logic [1:0] tlb_miss_lo;

// Rolly FIFO connection
bp_be_dcache_pkt_s [1:0] rolly_dcache_pkt_li;
logic [1:0] rolly_v_lo, rolly_ready_lo;

logic [1:0][ptag_width_lp-1:0] rolly_paddr_li;
logic [1:0][ptag_width_lp-1:0] rolly_paddr_lo;

// Boot ROM connection
logic [lg_boot_rom_els_lp-1:0] boot_rom_addr_li;
logic [boot_rom_width_p-1:0]   boot_rom_data_lo;

// CCE Inst Boot ROM
logic [cce_inst_ram_addr_width_lp-1:0] cce_inst_boot_rom_addr;
logic [`bp_cce_inst_width-1:0]         cce_inst_boot_rom_data;

// Memory End
bp_me_top 
 #(.num_lce_p(num_lce_p)
   ,.num_cce_p(num_cce_p)
   ,.paddr_width_p(paddr_width_p)
   ,.lce_assoc_p(lce_assoc_p)
   ,.lce_sets_p(lce_sets_p)
   ,.block_size_in_bytes_p(block_size_in_bytes_p)
   ,.num_inst_ram_els_p(num_inst_ram_els_p)
   ,.mem_els_p(mem_els_p)
   ,.boot_rom_width_p(boot_rom_width_p)
   ,.boot_rom_els_p(boot_rom_els_p)
   )
 DUT
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.lce_cmd_o(cce_lce_cmd_li)
   ,.lce_cmd_v_o(cce_lce_cmd_v_li)
   ,.lce_cmd_ready_i(cce_lce_cmd_ready_lo)

   ,.lce_data_cmd_o(cce_lce_data_cmd_li)
   ,.lce_data_cmd_v_o(cce_lce_data_cmd_v_li)
   ,.lce_data_cmd_ready_i(cce_lce_data_cmd_ready_lo)

   ,.lce_req_i(lce_cce_req_lo)
   ,.lce_req_v_i(lce_cce_req_v_lo)
   ,.lce_req_ready_o(lce_cce_req_ready_li)

   ,.lce_resp_i(lce_cce_resp_lo)
   ,.lce_resp_v_i(lce_cce_resp_v_lo)
   ,.lce_resp_ready_o(lce_cce_resp_ready_li)

   ,.lce_data_resp_i(lce_cce_data_resp_lo)
   ,.lce_data_resp_v_i(lce_cce_data_resp_v_lo)
   ,.lce_data_resp_ready_o(lce_cce_data_resp_ready_li)

   ,.lce_tr_resp_i(lce_tr_resp_li)
   ,.lce_tr_resp_v_i(lce_tr_resp_v_li)
   ,.lce_tr_resp_ready_o(lce_tr_resp_ready_lo)

   ,.lce_tr_resp_o(lce_tr_resp_lo)
   ,.lce_tr_resp_v_o(lce_tr_resp_v_lo)
   ,.lce_tr_resp_ready_i(lce_tr_resp_ready_li)

   ,.boot_rom_addr_o(boot_rom_addr_li)
   ,.boot_rom_data_i(boot_rom_data_lo)

   ,.cce_inst_boot_rom_addr_o(cce_inst_boot_rom_addr)
   ,.cce_inst_boot_rom_data_i(cce_inst_boot_rom_data)
   );

bp_boot_rom
 #(.addr_width_p(lg_boot_rom_els_lp)
   ,.width_p(boot_rom_width_p)
   )
 mrom
  (.addr_i(boot_rom_addr_li)
   ,.data_o(boot_rom_data_lo)
   );

bp_cce_inst_rom
  #(.width_p(`bp_cce_inst_width)
    ,.addr_width_p(cce_inst_ram_addr_width_lp)
    )
  cce_inst_rom
   (.addr_i(cce_inst_boot_rom_addr)
    ,.data_o(cce_inst_boot_rom_data)
    );

bsg_fsb_node_trace_replay 
 #(.ring_width_p(trace_ring_width_p)
   ,.rom_addr_width_p(trace_rom_addr_width_p)
   )
 me_trace_replay 
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(1'b1)
                    
   ,.v_i(tr_v_li)
   ,.data_i(tr_data_li)
   ,.ready_o(tr_ready_lo)
                  
   ,.v_o(tr_v_lo)
   ,.data_o(tr_data_lo)
   ,.yumi_i(tr_yumi_li)
                  
   ,.rom_addr_o(tr_rom_addr_li)
   ,.rom_data_i(tr_rom_data_lo)
                  
   ,.done_o(test_done)
   ,.error_o()
   );

bp_trace_rom 
 #(.width_p(trace_ring_width_p+4)
   ,.addr_width_p(trace_rom_addr_width_p)
   )
 trace_rom 
  (.addr_i(tr_rom_addr_li)
   ,.data_o(tr_rom_data_lo)
   );

bp_be_dcache 
 #(.data_width_p(data_width_lp)
   ,.sets_p(lce_sets_p)
   ,.ways_p(lce_assoc_p)
   ,.paddr_width_p(paddr_width_p)
   ,.num_cce_p(num_cce_p)
   ,.num_lce_p(num_lce_p)
   ) 
 icache  // Yes, I know this is a dcache
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.lce_id_i(1'b0)

   ,.dcache_pkt_i(dcache_pkt_li[0])
   ,.v_i(rolly_v_lo[0])
   ,.ready_o(dcache_ready_lo[0])

   ,.v_o(dcache_v_lo[0])
   ,.data_o(dcache_data_lo[0])

   ,.tlb_miss_i(tlb_miss_lo[0])
   ,.ptag_i(dcache_paddr_li[0])

   // ctrl
   ,.cache_miss_o(dcache_miss_lo[0])
   ,.poison_i(dcache_miss_lo[0])

   // LCE-CCE interface
   ,.lce_req_o(lce_cce_req_lo[0])
   ,.lce_req_v_o(lce_cce_req_v_lo[0])
   ,.lce_req_ready_i(lce_cce_req_ready_li[0])

   ,.lce_resp_o(lce_cce_resp_lo[0])
   ,.lce_resp_v_o(lce_cce_resp_v_lo[0])
   ,.lce_resp_ready_i(lce_cce_resp_ready_li[0])

   ,.lce_data_resp_o(lce_cce_data_resp_lo[0])
   ,.lce_data_resp_v_o(lce_cce_data_resp_v_lo[0])
   ,.lce_data_resp_ready_i(lce_cce_data_resp_ready_li[0])

   // CCE-LCE interface
   ,.lce_cmd_i(cce_lce_cmd_li[0])
   ,.lce_cmd_v_i(cce_lce_cmd_v_li[0])
   ,.lce_cmd_ready_o(cce_lce_cmd_ready_lo[0])

   ,.lce_data_cmd_i(cce_lce_data_cmd_li[0])
   ,.lce_data_cmd_v_i(cce_lce_data_cmd_v_li[0])
   ,.lce_data_cmd_ready_o(cce_lce_data_cmd_ready_lo[0])

   // LCE-LCE interface
   ,.lce_tr_resp_i(lce_tr_resp_lo[0])
   ,.lce_tr_resp_v_i(lce_tr_resp_v_lo[0])
   ,.lce_tr_resp_ready_o(lce_tr_resp_ready_li[0])

   ,.lce_tr_resp_o(lce_tr_resp_li[0])
   ,.lce_tr_resp_v_o(lce_tr_resp_v_li[0])
   ,.lce_tr_resp_ready_i(lce_tr_resp_ready_lo[0])
   );



bp_be_dcache 
 #(.data_width_p(data_width_lp)
   ,.sets_p(lce_sets_p)
   ,.ways_p(lce_assoc_p)
   ,.paddr_width_p(paddr_width_p)
   ,.num_cce_p(num_cce_p)
   ,.num_lce_p(num_lce_p)
   ) 
 dcache 
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.lce_id_i(1'b1)

   ,.dcache_pkt_i(dcache_pkt_li[1])
   ,.v_i(rolly_v_lo[1])
   ,.ready_o(dcache_ready_lo[1])

   ,.v_o(dcache_v_lo[1])
   ,.data_o(dcache_data_lo[1])

   ,.tlb_miss_i(tlb_miss_lo[1])
   ,.ptag_i(dcache_paddr_li[1])

   // ctrl
   ,.cache_miss_o(dcache_miss_lo[1])
   ,.poison_i(dcache_miss_lo[1])

   // LCE-CCE interface
   ,.lce_req_o(lce_cce_req_lo[1])
   ,.lce_req_v_o(lce_cce_req_v_lo[1])
   ,.lce_req_ready_i(lce_cce_req_ready_li[1])

   ,.lce_resp_o(lce_cce_resp_lo[1])
   ,.lce_resp_v_o(lce_cce_resp_v_lo[1])
   ,.lce_resp_ready_i(lce_cce_resp_ready_li[1])

   ,.lce_data_resp_o(lce_cce_data_resp_lo[1])
   ,.lce_data_resp_v_o(lce_cce_data_resp_v_lo[1])
   ,.lce_data_resp_ready_i(lce_cce_data_resp_ready_li[1])

   // CCE-LCE interface
   ,.lce_cmd_i(cce_lce_cmd_li[1])
   ,.lce_cmd_v_i(cce_lce_cmd_v_li[1])
   ,.lce_cmd_ready_o(cce_lce_cmd_ready_lo[1])

   ,.lce_data_cmd_i(cce_lce_data_cmd_li[1])
   ,.lce_data_cmd_v_i(cce_lce_data_cmd_v_li[1])
   ,.lce_data_cmd_ready_o(cce_lce_data_cmd_ready_lo[1])

   // LCE-LCE interface
   ,.lce_tr_resp_i(lce_tr_resp_lo[1])
   ,.lce_tr_resp_v_i(lce_tr_resp_v_lo[1])
   ,.lce_tr_resp_ready_o(lce_tr_resp_ready_li[1])

   ,.lce_tr_resp_o(lce_tr_resp_li[1])
   ,.lce_tr_resp_v_o(lce_tr_resp_v_li[1])
   ,.lce_tr_resp_ready_i(lce_tr_resp_ready_lo[1])
   );

logic tr_icache_match, tr_dcache_match, tr_is_fetch;
always_comb begin
      // Trace replay will not fail (only stall).  We could do better if the trace format 
      // was a little more advanced
      // This fetch thing is a hack, but is necessary unless we change the trace format
      tr_is_fetch     = tr_data_lo[data_width_lp+paddr_width_p+:4]  == 4'b1111;
      tr_icache_match = tr_data_lo[0+:data_width_lp] == dcache_data_lo[0];
      tr_dcache_match = tr_data_lo[0+:data_width_lp] == dcache_data_lo[1];

      rolly_dcache_pkt_li[0].opcode      = e_dcache_opcode_lwu;
      rolly_dcache_pkt_li[0].page_offset = tr_data_lo[data_width_lp+:page_offset_width_lp];
      rolly_dcache_pkt_li[0].data        = tr_data_lo[0+:data_width_lp];
      rolly_paddr_li[0]                  = tr_data_lo[data_width_lp+page_offset_width_lp+:ptag_width_lp];

      rolly_dcache_pkt_li[1].opcode      = bp_be_dcache_opcode_e'(tr_data_lo[data_width_lp+paddr_width_p+:4]);
      rolly_dcache_pkt_li[1].page_offset = tr_data_lo[data_width_lp+:page_offset_width_lp];
      rolly_dcache_pkt_li[1].data        = tr_data_lo[0+:data_width_lp];
      rolly_paddr_li[1]                  = tr_data_lo[data_width_lp+page_offset_width_lp+:ptag_width_lp];

  if (tr_icache_match)
    begin
      tr_yumi_li = tr_v_lo & rolly_ready_lo[0];

      tr_v_li = dcache_v_lo[0];
      tr_data_li = trace_ring_width_p'(dcache_data_lo[0]);
    end
  else // tr_dcache_match or no match
    begin
      tr_yumi_li = tr_v_lo & rolly_ready_lo[1];

      tr_v_li = dcache_v_lo[1];
      tr_data_li = trace_ring_width_p'(dcache_data_lo[1]);
    end
end

bsg_fifo_1r1w_rolly 
 #(.width_p(bp_be_dcache_pkt_width_lp+ptag_width_lp)
   ,.els_p(8)
   ) 
 irolly 
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.roll_v_i(dcache_miss_lo[0])
   ,.clr_v_i(1'b0)

   ,.ckpt_v_i(dcache_v_lo[0])

   ,.data_i({rolly_paddr_li[0], rolly_dcache_pkt_li[0]})
   ,.v_i(tr_v_lo & rolly_ready_lo[0] & tr_is_fetch)
   ,.ready_o(rolly_ready_lo[0])

   ,.data_o({rolly_paddr_lo[0], dcache_pkt_li[0]})
   ,.v_o(rolly_v_lo[0])
   ,.yumi_i(rolly_v_lo[0] & dcache_ready_lo[0])
   );

bsg_fifo_1r1w_rolly 
 #(.width_p(bp_be_dcache_pkt_width_lp+ptag_width_lp)
   ,.els_p(8)
   ) 
 drolly 
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.roll_v_i(dcache_miss_lo[1])
   ,.clr_v_i(1'b0)

   ,.ckpt_v_i(dcache_v_lo[1])

   ,.data_i({rolly_paddr_li[1], rolly_dcache_pkt_li[1]})
   ,.v_i(tr_v_lo & rolly_ready_lo[1] & ~tr_is_fetch)
   ,.ready_o(rolly_ready_lo[1])

   ,.data_o({rolly_paddr_lo[1], dcache_pkt_li[1]})
   ,.v_o(rolly_v_lo[1])
   ,.yumi_i(rolly_v_lo[1] & dcache_ready_lo[1])
   );

mock_tlb 
 #(.tag_width_p(ptag_width_lp)) 
 itlb 
  (.clk_i(clk_i)
   
   ,.v_i(rolly_v_lo[0] & dcache_ready_lo[0])
   ,.tag_i(rolly_paddr_lo[0])

   ,.tag_o(dcache_paddr_li[0])
   ,.tlb_miss_o(tlb_miss_lo[0])
   );

mock_tlb 
 #(.tag_width_p(ptag_width_lp)) 
 dtlb 
  (.clk_i(clk_i)
   
   ,.v_i(rolly_v_lo[1] & dcache_ready_lo[1])
   ,.tag_i(rolly_paddr_lo[1])

   ,.tag_o(dcache_paddr_li[1])
   ,.tlb_miss_o(tlb_miss_lo[1])
   );

logic booted;

localparam max_instr_cnt_lp    = 2**30-1;
localparam lg_max_instr_cnt_lp = `BSG_SAFE_CLOG2(max_instr_cnt_lp);
logic [lg_max_instr_cnt_lp-1:0] instr_cnt;

  bsg_counter_clear_up
   #(.max_val_p(max_instr_cnt_lp)
     ,.init_val_p(0)
     )
   instr_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(1'b0)
     ,.up_i(tr_v_li & tr_icache_match)

     ,.count_o(instr_cnt)
     );

localparam max_clock_cnt_lp    = 2**30-1;
localparam lg_max_clock_cnt_lp = `BSG_SAFE_CLOG2(max_clock_cnt_lp);
logic [lg_max_clock_cnt_lp-1:0] clock_cnt;

  bsg_counter_clear_up
   #(.max_val_p(max_clock_cnt_lp)
     ,.init_val_p(0)
     )
   clock_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(~booted)
     ,.up_i(1'b1)

     ,.count_o(clock_cnt)
     );

always_ff @(posedge clk_i)
  begin
    if (reset_i)
        booted <= 1'b0;
    else
      begin
        booted <= booted | |dcache_ready_lo; // Booted when either cache is ready
      end
  end

always_ff @(posedge clk_i)
  begin
    if (test_done)
      begin
        $display("Test PASSed! Clocks: %d Instr: %d mIPC: %d", clock_cnt, instr_cnt, (1000*instr_cnt) / clock_cnt);
        $finish(0);
      end
  end

endmodule
