/**
 *  test_bp.v
 */

module test_bp
 import bp_common_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_be_pkg::*;
 import bp_be_dcache_pkg::*;
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
   , parameter cce_block_size_in_bytes_p   = "inv"
   , parameter cce_num_inst_ram_els_p      = "inv"

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
   , localparam cce_block_size_in_bits_lp = 8 * cce_block_size_in_bytes_p
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
                                                                         , cce_block_size_in_bytes_p
                                                                         )
   , localparam cce_lce_cmd_width_lp       = `bp_cce_lce_cmd_width(num_cce_p
                                                                   , num_lce_p
                                                                   , paddr_width_p
                                                                   , lce_assoc_p
                                                                   )
   , localparam cce_lce_data_cmd_width_lp  = `bp_cce_lce_data_cmd_width(num_cce_p
                                                                        , num_lce_p
                                                                        , paddr_width_p
                                                                        , cce_block_size_in_bytes_p
                                                                        , lce_assoc_p
                                                                        )
   , localparam lce_lce_tr_resp_width_lp   = `bp_lce_lce_tr_resp_width(num_lce_p
                                                                       , paddr_width_p
                                                                       , cce_block_size_in_bytes_p
                                                                       , lce_assoc_p
                                                                       )
   );

`declare_bp_common_proc_cfg_s(core_els_p, num_lce_p)
`declare_bp_common_fe_be_if_structs(vaddr_width_p
                                    , paddr_width_p
                                    , asid_width_p
                                    , branch_metadata_fwd_width_p
                                    )
`declare_bp_lce_cce_req_s(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p);
`declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, paddr_width_p);
`declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_p, paddr_width_p, cce_block_size_in_bits_lp);
`declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p);
`declare_bp_cce_lce_data_cmd_s(num_cce_p, num_lce_p, paddr_width_p, cce_block_size_in_bits_lp, lce_assoc_p);
`declare_bp_lce_lce_tr_resp_s(num_lce_p, paddr_width_p, cce_block_size_in_bits_lp, lce_assoc_p);
`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   )
`declare_bp_be_dcache_pkt_s(page_offset_width_lp, data_width_lp);

logic clk, reset;

// clock gen
//
bsg_nonsynth_clock_gen 
 #(.cycle_time_p(10)) 
 clk_gen 
  (.o(clk));

// reset gen
//
bsg_nonsynth_reset_gen 
 #(.num_clocks_p(1)
   ,.reset_cycles_lo_p(0)
   ,.reset_cycles_hi_p(4)
   ) 
 reset_gen 
  (.clk_i(clk)
   ,.async_reset_o(reset)
   );
 
// LCE-CCE connection
bp_cce_lce_cmd_s dcache_cce_lce_cmd_li;
logic dcache_cce_lce_cmd_v_li, dcache_cce_lce_cmd_ready_lo;

bp_cce_lce_data_cmd_s dcache_cce_lce_data_cmd_li;
logic dcache_cce_lce_data_cmd_v_li, dcache_cce_lce_data_cmd_ready_lo;

bp_lce_cce_req_s dcache_lce_cce_req_lo;
logic dcache_lce_cce_req_v_lo, dcache_lce_cce_req_ready_li;

bp_lce_cce_resp_s dcache_lce_cce_resp_lo;
logic dcache_lce_cce_resp_v_lo, dcache_lce_cce_resp_ready_li;

bp_lce_cce_data_resp_s dcache_lce_cce_data_resp_lo;
logic dcache_lce_cce_data_resp_v_lo, dcache_lce_cce_data_resp_ready_li;

// Trace replay connections
logic [trace_ring_width_p-1:0]      tr_data_li;
logic tr_v_li, tr_ready_lo;

logic [trace_ring_width_p-1:0]      tr_data_lo;
logic tr_v_lo, tr_yumi_li;

logic [trace_rom_addr_width_p-1:0]  tr_rom_addr_li;
logic [trace_rom_data_width_lp-1:0] tr_rom_data_lo;

logic test_done;

// D$ connections
bp_be_dcache_pkt_s dcache_pkt_li;
logic dcache_ready_lo;

logic [ptag_width_lp-1:0] dcache_paddr_li;

logic [data_width_lp-1:0] dcache_data_lo;
logic  dcache_v_lo;

logic dcache_miss_lo;
logic tlb_miss_lo;

// Rolly FIFO connection
bp_be_dcache_pkt_s rolly_dcache_pkt_li;
logic rolly_v_lo, rolly_ready_lo;

logic [ptag_width_lp-1:0] rolly_paddr_li;
logic [ptag_width_lp-1:0] rolly_paddr_lo;

// Boot ROM connection
logic [lg_boot_rom_els_lp-1:0] boot_rom_addr_li;
logic [boot_rom_width_p-1:0]   boot_rom_data_lo;

// Memory End
bp_me_top 
 #(.num_lce_p(num_lce_p)
   ,.num_cce_p(num_cce_p)
   ,.addr_width_p(paddr_width_p)
   ,.lce_assoc_p(lce_assoc_p)
   ,.lce_sets_p(lce_sets_p)
   ,.block_size_in_bytes_p(cce_block_size_in_bytes_p)
   ,.num_inst_ram_els_p(cce_num_inst_ram_els_p)
   ,.boot_rom_width_p(boot_rom_width_p)
   ,.boot_rom_els_p(boot_rom_els_p)
   )
 DUT
  (.clk_i(clk)
   ,.reset_i(reset)

   ,.lce_cmd_o(dcache_cce_lce_cmd_li)
   ,.lce_cmd_v_o(dcache_cce_lce_cmd_v_li)
   ,.lce_cmd_ready_i(dcache_cce_lce_cmd_ready_lo)

   ,.lce_data_cmd_o(dcache_cce_lce_data_cmd_li)
   ,.lce_data_cmd_v_o(dcache_cce_lce_data_cmd_v_li)
   ,.lce_data_cmd_ready_i(dcache_cce_lce_data_cmd_ready_lo)

   ,.lce_req_i(dcache_lce_cce_req_lo)
   ,.lce_req_v_i(dcache_lce_cce_req_v_lo)
   ,.lce_req_ready_o(dcache_lce_cce_req_ready_li)

   ,.lce_resp_i(dcache_lce_cce_resp_lo)
   ,.lce_resp_v_i(dcache_lce_cce_resp_v_lo)
   ,.lce_resp_ready_o(dcache_lce_cce_resp_ready_li)

   ,.lce_data_resp_i(dcache_lce_cce_data_resp_lo)
   ,.lce_data_resp_v_i(dcache_lce_cce_data_resp_v_lo)
   ,.lce_data_resp_ready_o(dcache_lce_cce_data_resp_ready_li)

   /* No LCE to LCE communication in this testbench */
   ,.lce_tr_resp_i()
   ,.lce_tr_resp_v_i(1'b0)
   ,.lce_tr_resp_ready_o()

   ,.lce_tr_resp_o()
   ,.lce_tr_resp_v_o()
   ,.lce_tr_resp_ready_i(1'b0)

   ,.boot_rom_addr_o(boot_rom_addr_li)
   ,.boot_rom_data_i(boot_rom_data_lo)
   );

bp_boot_rom
 #(.addr_width_p(lg_boot_rom_els_lp)
   ,.width_p(boot_rom_width_p)
   )
 mrom
  (.addr_i(boot_rom_addr_li)
   ,.data_o(boot_rom_data_lo)
   );

bsg_fsb_node_trace_replay 
 #(.ring_width_p(trace_ring_width_p)
   ,.rom_addr_width_p(trace_rom_addr_width_p)
   )
 be_trace_replay 
  (.clk_i(clk)
   ,.reset_i(reset)
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
 dcache 
  (.clk_i(clk)
   ,.reset_i(reset)
   ,.lce_id_i(1'b0)

   ,.dcache_pkt_i(dcache_pkt_li)
   ,.v_i(rolly_v_lo)
   ,.ready_o(dcache_ready_lo)

   ,.v_o(dcache_v_lo)
   ,.data_o(dcache_data_lo)

   ,.tlb_miss_i(tlb_miss_lo)
   ,.ptag_i(dcache_paddr_li)

   // ctrl
   ,.cache_miss_o(dcache_miss_lo)
   ,.poison_i(dcache_miss_lo)

   // LCE-CCE interface
   ,.lce_req_o(dcache_lce_cce_req_lo)
   ,.lce_req_v_o(dcache_lce_cce_req_v_lo)
   ,.lce_req_ready_i(dcache_lce_cce_req_ready_li)

   ,.lce_resp_o(dcache_lce_cce_resp_lo)
   ,.lce_resp_v_o(dcache_lce_cce_resp_v_lo)
   ,.lce_resp_ready_i(dcache_lce_cce_resp_ready_li)

   ,.lce_data_resp_o(dcache_lce_cce_data_resp_lo)
   ,.lce_data_resp_v_o(dcache_lce_cce_data_resp_v_lo)
   ,.lce_data_resp_ready_i(dcache_lce_cce_data_resp_ready_li)

   // CCE-LCE interface
   ,.lce_cmd_i(dcache_cce_lce_cmd_li)
   ,.lce_cmd_v_i(dcache_cce_lce_cmd_v_li)
   ,.lce_cmd_ready_o(dcache_cce_lce_cmd_ready_lo)

   ,.lce_data_cmd_i(dcache_cce_lce_data_cmd_li)
   ,.lce_data_cmd_v_i(dcache_cce_lce_data_cmd_v_li)
   ,.lce_data_cmd_ready_o(dcache_cce_lce_data_cmd_ready_lo)

   // LCE-LCE interface
   ,.lce_tr_resp_i()
   ,.lce_tr_resp_v_i(1'b0)
   ,.lce_tr_resp_ready_o()

   ,.lce_tr_resp_o()
   ,.lce_tr_resp_v_o()
   ,.lce_tr_resp_ready_i(1'b0)
   );




always_comb begin
  tr_yumi_li = tr_v_lo & rolly_ready_lo;
  rolly_dcache_pkt_li.opcode = bp_be_dcache_opcode_e'(tr_data_lo[data_width_lp+paddr_width_p+:4]);
  rolly_dcache_pkt_li.page_offset = tr_data_lo[data_width_lp+:page_offset_width_lp];
  rolly_dcache_pkt_li.data        = tr_data_lo[0+:data_width_lp];
  rolly_paddr_li                  = tr_data_lo[data_width_lp+page_offset_width_lp+:ptag_width_lp];

  tr_v_li = dcache_v_lo;
  tr_data_li = trace_ring_width_p'(dcache_data_lo);
end


bsg_fifo_1r1w_rolly 
 #(.width_p(bp_be_dcache_pkt_width_lp+ptag_width_lp)
   ,.els_p(8)
   ) 
 rolly 
  (.clk_i(clk)
   ,.reset_i(reset)

   ,.roll_v_i(dcache_miss_lo)
   ,.clr_v_i(1'b0)

   ,.ckpt_v_i(dcache_v_lo)

   ,.data_i({rolly_paddr_li, rolly_dcache_pkt_li})
   ,.v_i(tr_v_lo & rolly_ready_lo)
   ,.ready_o(rolly_ready_lo)

   ,.data_o({rolly_paddr_lo, dcache_pkt_li})
   ,.v_o(rolly_v_lo)
   ,.yumi_i(rolly_v_lo & dcache_ready_lo)
   );


mock_tlb 
 #(.tag_width_p(ptag_width_lp)) 
 tlb 
  (.clk_i(clk)
   
   ,.v_i(rolly_v_lo & dcache_ready_lo)
   ,.tag_i(rolly_paddr_lo)

   ,.tag_o(dcache_paddr_li)
   ,.tlb_miss_o(tlb_miss_lo)
   );

always_ff @(posedge clk) 
  begin
    if (test_done) 
      begin
        $display("TEST PASSED");
        $finish;
      end
  end

endmodule
