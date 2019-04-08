/**
 *  testbench.v
 */

module testbench
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_be_pkg::*;
 import bp_be_dcache_pkg::*;
 import bp_cce_pkg::*;
 #(parameter bp_cfg_e cfg_p = BP_CFG_FLOWVAR // Replaced by the flow with a specific bp_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, dword_width_p, num_lce_p, lce_assoc_p)
   `declare_bp_lce_cce_if_widths(num_cce_p
                                 ,num_lce_p
                                 ,paddr_width_p
                                 ,lce_assoc_p
                                 ,dword_width_p
                                 ,cce_block_width_p
                                 )

   , parameter mem_els_p                   = "inv"

   // Trace replay parameters
   , parameter trace_ring_width_p          = "inv"
   , parameter trace_rom_addr_width_p      = "inv"
   , localparam trace_rom_dword_width_p    = trace_ring_width_p + 4

   // Test program related parameters
   , parameter boot_rom_els_p              = "inv"
   , parameter boot_rom_width_p            = "inv"
   , localparam lg_boot_rom_els_lp         = `BSG_SAFE_CLOG2(boot_rom_els_p)

   // D$ calculated parameters
   , localparam word_offset_width_lp = `BSG_SAFE_CLOG2(lce_assoc_p)
   , localparam index_width_lp       = `BSG_SAFE_CLOG2(lce_sets_p)
   , localparam data_mask_width_lp   = (dword_width_p>>3)
   , localparam byte_offset_width_lp = `BSG_SAFE_CLOG2(data_mask_width_lp)
   , localparam page_offset_width_lp = word_offset_width_lp+index_width_lp+byte_offset_width_lp
   , localparam ptag_width_lp        = paddr_width_p-page_offset_width_lp

   // For the D$, cache block size is number of ways multiplied by D$ "word" size
   , localparam bp_be_dcache_pkt_width_lp = `bp_be_dcache_pkt_width(page_offset_width_lp
                                                                    , dword_width_p
                                                                    )

   , localparam cce_inst_ram_addr_width_lp = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)
   )
  (input clk_i
   , input reset_i
   );

`declare_bp_common_proc_cfg_s(num_core_p, num_lce_p)
`declare_bp_fe_be_if(vaddr_width_p
                                    , paddr_width_p
                                    , asid_width_p
                                    , branch_metadata_fwd_width_p
                                    )
`declare_bp_lce_cce_req_s(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p);
`declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, paddr_width_p);
`declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_p, paddr_width_p, cce_block_width_p);
`declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p);
`declare_bp_lce_data_cmd_s(num_lce_p, cce_block_width_p, lce_assoc_p);
`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   )
`declare_bp_be_dcache_pkt_s(page_offset_width_lp, dword_width_p);

// LCE-CCE connection
bp_cce_lce_cmd_s [1:0] cce_lce_cmd_li;
logic [1:0] cce_lce_cmd_v_li, cce_lce_cmd_ready_lo;

bp_lce_data_cmd_s [1:0] lce_data_cmd_li;
logic [1:0] lce_data_cmd_v_li, lce_data_cmd_ready_lo;

bp_lce_data_cmd_s [1:0] lce_data_cmd_lo;
logic [1:0] lce_data_cmd_v_lo, lce_data_cmd_ready_li;

bp_lce_cce_req_s [1:0] lce_cce_req_lo;
logic [1:0] lce_cce_req_v_lo, lce_cce_req_ready_li;

bp_lce_cce_resp_s [1:0] lce_cce_resp_lo;
logic [1:0] lce_cce_resp_v_lo, lce_cce_resp_ready_li;

bp_lce_cce_data_resp_s [1:0] lce_cce_data_resp_lo;
logic [1:0] lce_cce_data_resp_v_lo, lce_cce_data_resp_ready_li;

// Trace replay connections
logic [trace_ring_width_p-1:0]      tr_data_li;
logic tr_v_li, tr_ready_lo;

logic [trace_ring_width_p-1:0]      tr_data_lo;
logic tr_v_lo, tr_yumi_li;

logic [trace_rom_addr_width_p-1:0]  tr_rom_addr_li;
logic [trace_rom_dword_width_p-1:0] tr_rom_data_lo;

logic test_done;

// D$ connections
bp_be_dcache_pkt_s [1:0] dcache_pkt_li;
logic [1:0] dcache_ready_lo;

logic [1:0] [ptag_width_lp-1:0] dcache_paddr_li;

logic [1:0] [dword_width_p-1:0] dcache_data_lo;
logic [1:0]  dcache_v_lo;

logic [1:0] dcache_miss_lo;
logic [1:0] tlb_miss_lo;

// Rolly FIFO connection
bp_be_dcache_pkt_s [1:0] rolly_dcache_pkt_li;
logic [1:0] rolly_v_lo, rolly_ready_lo;

logic [1:0][ptag_width_lp-1:0] rolly_paddr_li;
logic [1:0][ptag_width_lp-1:0] rolly_paddr_lo;

// Boot ROM connection
logic [num_cce_p-1:0][lg_boot_rom_els_lp-1:0] boot_rom_addr_li;
logic [num_cce_p-1:0][boot_rom_width_p-1:0]   boot_rom_data_lo;

// CCE Inst Boot ROM
logic [num_cce_p-1:0][cce_inst_ram_addr_width_lp-1:0] cce_inst_boot_rom_addr;
logic [num_cce_p-1:0][`bp_cce_inst_width-1:0]         cce_inst_boot_rom_data;

// Memory End

logic [num_cce_p-1:0][mem_cce_resp_width_lp-1:0] mem_resp;
logic [num_cce_p-1:0] mem_resp_v;
logic [num_cce_p-1:0] mem_resp_ready;

logic [num_cce_p-1:0][mem_cce_data_resp_width_lp-1:0] mem_data_resp;
logic [num_cce_p-1:0] mem_data_resp_v;
logic [num_cce_p-1:0] mem_data_resp_ready;

logic [num_cce_p-1:0][cce_mem_cmd_width_lp-1:0] mem_cmd;
logic [num_cce_p-1:0] mem_cmd_v;
logic [num_cce_p-1:0] mem_cmd_yumi;

logic [num_cce_p-1:0][cce_mem_data_cmd_width_lp-1:0] mem_data_cmd;
logic [num_cce_p-1:0] mem_data_cmd_v;
logic [num_cce_p-1:0] mem_data_cmd_yumi;

wrapper 
 #(.cfg_p(cfg_p))
 wrapper
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.lce_cmd_o(cce_lce_cmd_li)
   ,.lce_cmd_v_o(cce_lce_cmd_v_li)
   ,.lce_cmd_ready_i(cce_lce_cmd_ready_lo)

   ,.lce_data_cmd_o(lce_data_cmd_li)
   ,.lce_data_cmd_v_o(lce_data_cmd_v_li)
   ,.lce_data_cmd_ready_i(lce_data_cmd_ready_lo)

   ,.lce_data_cmd_i(lce_data_cmd_lo)
   ,.lce_data_cmd_v_i(lce_data_cmd_v_lo)
   ,.lce_data_cmd_ready_o(lce_data_cmd_ready_li)

   ,.lce_req_i(lce_cce_req_lo)
   ,.lce_req_v_i(lce_cce_req_v_lo)
   ,.lce_req_ready_o(lce_cce_req_ready_li)

   ,.lce_resp_i(lce_cce_resp_lo)
   ,.lce_resp_v_i(lce_cce_resp_v_lo)
   ,.lce_resp_ready_o(lce_cce_resp_ready_li)

   ,.lce_data_resp_i(lce_cce_data_resp_lo)
   ,.lce_data_resp_v_i(lce_cce_data_resp_v_lo)
   ,.lce_data_resp_ready_o(lce_cce_data_resp_ready_li)

   ,.cce_inst_boot_rom_addr_o(cce_inst_boot_rom_addr)
   ,.cce_inst_boot_rom_data_i(cce_inst_boot_rom_data)

   ,.mem_resp_i(mem_resp)
   ,.mem_resp_v_i(mem_resp_v)
   ,.mem_resp_ready_o(mem_resp_ready)

   ,.mem_data_resp_i(mem_data_resp)
   ,.mem_data_resp_v_i(mem_data_resp_v)
   ,.mem_data_resp_ready_o(mem_data_resp_ready)

   ,.mem_cmd_o(mem_cmd)
   ,.mem_cmd_v_o(mem_cmd_v)
   ,.mem_cmd_yumi_i(mem_cmd_yumi)

   ,.mem_data_cmd_o(mem_data_cmd)
   ,.mem_data_cmd_v_o(mem_data_cmd_v)
   ,.mem_data_cmd_yumi_i(mem_data_cmd_yumi)

   );

for (genvar i = 0; i < num_cce_p; i++) begin

bp_cce_inst_rom
  #(.width_p(`bp_cce_inst_width)
    ,.addr_width_p(cce_inst_ram_addr_width_lp)
    )
  cce_inst_rom
   (.addr_i(cce_inst_boot_rom_addr[i])
    ,.data_o(cce_inst_boot_rom_data[i])
    );

bp_mem
  #(.num_lce_p(num_lce_p)
    ,.num_cce_p(num_cce_p)
    ,.paddr_width_p(paddr_width_p)
    ,.lce_assoc_p(lce_assoc_p)
    ,.block_size_in_bytes_p(cce_block_width_p/8)
    ,.lce_sets_p(lce_sets_p)
    ,.lce_req_data_width_p(dword_width_p)
    ,.mem_els_p(mem_els_p)
    ,.boot_rom_width_p(cce_block_width_p)
    ,.boot_rom_els_p(boot_rom_els_p)
  )
  bp_mem
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.mem_cmd_i(mem_cmd[i])
   ,.mem_cmd_v_i(mem_cmd_v[i])
   ,.mem_cmd_yumi_o(mem_cmd_yumi[i])

   ,.mem_data_cmd_i(mem_data_cmd[i])
   ,.mem_data_cmd_v_i(mem_data_cmd_v[i])
   ,.mem_data_cmd_yumi_o(mem_data_cmd_yumi[i])

   ,.mem_resp_o(mem_resp[i])
   ,.mem_resp_v_o(mem_resp_v[i])
   ,.mem_resp_ready_i(mem_resp_ready[i])

   ,.mem_data_resp_o(mem_data_resp[i])
   ,.mem_data_resp_v_o(mem_data_resp_v[i])
   ,.mem_data_resp_ready_i(mem_data_resp_ready[i])

   ,.boot_rom_addr_o(boot_rom_addr_li[i])
   ,.boot_rom_data_i(boot_rom_data_lo[i])
   );


bp_boot_rom
 #(.addr_width_p(lg_boot_rom_els_lp)
   ,.width_p(boot_rom_width_p)
   )
 mrom
  (.addr_i(boot_rom_addr_li[i])
   ,.data_o(boot_rom_data_lo[i])
   );

end

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
 #(.data_width_p(dword_width_p)
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
   ,.uncached_i(1'b0)
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

   ,.lce_data_cmd_i(lce_data_cmd_li[0])
   ,.lce_data_cmd_v_i(lce_data_cmd_v_li[0])
   ,.lce_data_cmd_ready_o(lce_data_cmd_ready_lo[0])

   ,.lce_data_cmd_o(lce_data_cmd_lo[0])
   ,.lce_data_cmd_v_o(lce_data_cmd_v_lo[0])
   ,.lce_data_cmd_ready_i(lce_data_cmd_ready_li[0])
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
   ,.lce_id_i(1'b1)

   ,.dcache_pkt_i(dcache_pkt_li[1])
   ,.v_i(rolly_v_lo[1])
   ,.ready_o(dcache_ready_lo[1])

   ,.v_o(dcache_v_lo[1])
   ,.data_o(dcache_data_lo[1])

   ,.tlb_miss_i(tlb_miss_lo[1])
   ,.ptag_i(dcache_paddr_li[1])

   // ctrl
   ,.uncached_i(1'b0)
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

   ,.lce_data_cmd_i(lce_data_cmd_li[1])
   ,.lce_data_cmd_v_i(lce_data_cmd_v_li[1])
   ,.lce_data_cmd_ready_o(lce_data_cmd_ready_lo[1])

   ,.lce_data_cmd_o(lce_data_cmd_lo[1])
   ,.lce_data_cmd_v_o(lce_data_cmd_v_lo[1])
   ,.lce_data_cmd_ready_i(lce_data_cmd_ready_li[1])
   );

logic tr_icache_match, tr_dcache_match, tr_is_fetch;
always_comb begin
      // Trace replay will not fail (only stall).  We could do better if the trace format 
      // was a little more advanced
      // This fetch thing is a hack, but is necessary unless we change the trace format
      tr_is_fetch     = tr_data_lo[dword_width_p+paddr_width_p+:4]  == 4'b1111;
      tr_icache_match = tr_data_lo[0+:dword_width_p] == dcache_data_lo[0];
      tr_dcache_match = tr_data_lo[0+:dword_width_p] == dcache_data_lo[1];

      rolly_dcache_pkt_li[0].opcode      = e_dcache_opcode_lwu;
      rolly_dcache_pkt_li[0].page_offset = tr_data_lo[dword_width_p+:page_offset_width_lp];
      rolly_dcache_pkt_li[0].data        = tr_data_lo[0+:dword_width_p];
      rolly_paddr_li[0]                  = tr_data_lo[dword_width_p+page_offset_width_lp+:ptag_width_lp];

      rolly_dcache_pkt_li[1].opcode      = bp_be_dcache_opcode_e'(tr_data_lo[dword_width_p+paddr_width_p+:4]);
      rolly_dcache_pkt_li[1].page_offset = tr_data_lo[dword_width_p+:page_offset_width_lp];
      rolly_dcache_pkt_li[1].data        = tr_data_lo[0+:dword_width_p];
      rolly_paddr_li[1]                  = tr_data_lo[dword_width_p+page_offset_width_lp+:ptag_width_lp];

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
