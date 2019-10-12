/**
 *
 * testbench.v
 *
 */

module testbench
 import bp_common_aviary_pkg::*;
 import bp_common_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 import bp_cce_pkg::*;
 #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_fe_be_if_widths(vaddr_width_p
                               ,paddr_width_p
                               ,asid_width_p
                               ,branch_metadata_fwd_width_p
                               )
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

   , parameter bp_first_pc_p          = "inv"
   , parameter boot_rom_width_p       = "inv"
   , parameter boot_rom_els_p         = "inv"
   , parameter mem_els_p              = "inv"

   , parameter trace_ring_width_p     = "inv"
   , parameter trace_rom_addr_width_p = "inv"

   , localparam trace_rom_data_width_lp   = trace_ring_width_p + 4
   , localparam lg_boot_rom_els_lp        = `BSG_SAFE_CLOG2(boot_rom_els_p)

   // Config link parameters
   , parameter cfg_link_addr_width_p       = 16
   , parameter cfg_link_data_width_p       = 32

   , localparam cce_inst_ram_addr_width_lp = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   )
  (input clk_i
   , input reset_i
   );

`declare_bp_common_cfg_bus_s(num_core_p, num_lce_p)
`declare_bp_fe_be_if(vaddr_width_p
                     , paddr_width_p
                     , asid_width_p
                     , branch_metadata_fwd_width_p
                     )
`declare_bp_lce_cce_if(num_cce_p
                       ,num_lce_p
                       ,paddr_width_p
                       ,lce_assoc_p
                       ,dword_width_p
                       ,cce_block_width_p
                       )
logic test_done;

// Top-level interface connections
bp_fe_queue_s fe_fe_queue, be_fe_queue;
logic fe_fe_queue_v, be_fe_queue_v, fe_fe_queue_ready, be_fe_queue_ready;

logic fe_queue_clr, fe_queue_dequeue, fe_queue_rollback;

bp_fe_cmd_s fe_fe_cmd, be_fe_cmd;
logic fe_fe_cmd_v, be_fe_cmd_v, fe_fe_cmd_ready, be_fe_cmd_ready;

bp_lce_cce_req_s  lce_req, lce_cce_req;
logic  lce_cce_req_v, lce_cce_req_ready;

bp_lce_cce_resp_s  lce_cce_resp;
logic  lce_cce_resp_v, lce_cce_resp_ready;

bp_lce_cce_data_resp_s  lce_cce_data_resp;
logic  lce_cce_data_resp_v, lce_cce_data_resp_ready;

bp_cce_lce_cmd_s  cce_lce_cmd;
logic  cce_lce_cmd_v, cce_lce_cmd_ready;

bp_lce_data_cmd_s  lce_data_cmd_lo;
logic  lce_data_cmd_v_lo, lce_data_cmd_ready_li;

bp_lce_data_cmd_s  lce_data_cmd_li;
logic  lce_data_cmd_v_li, lce_data_cmd_ready_lo;

bp_cfg_bus_s cfg_bus;

logic [trace_ring_width_p-1:0] tr_data_li, tr_data_lo;
logic tr_v_li, tr_ready_lo, tr_v_lo, tr_yumi_li;

logic [trace_rom_addr_width_p-1:0]  tr_rom_addr_li;
logic [trace_rom_data_width_lp-1:0] tr_rom_data_lo;

logic [num_cce_p-1:0][lg_boot_rom_els_lp-1:0] mrom_addr;
logic [num_cce_p-1:0][boot_rom_width_p-1:0]   mrom_data;

// CCE Inst Boot ROM
logic [num_cce_p-1:0][cce_inst_ram_addr_width_lp-1:0] cce_inst_boot_rom_addr;
logic [num_cce_p-1:0][`bp_cce_inst_width-1:0]         cce_inst_boot_rom_data;

assign cfg_bus.mhartid   = 1'b0;
assign cfg_bus.icache_id = 1'b0;
assign cfg_bus.dcache_id = 1'b1; // Unused

    wrapper
     #(.bp_params_p(bp_params_p))
     wrapper
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.icache_id_i(cfg_bus.icache_id)

       ,.fe_queue_o(fe_fe_queue)
       ,.fe_queue_v_o(fe_fe_queue_v)
       ,.fe_queue_ready_i(fe_fe_queue_ready)

       ,.fe_cmd_i(fe_fe_cmd)
       ,.fe_cmd_v_i(fe_fe_cmd_v)
       ,.fe_cmd_ready_o(fe_fe_cmd_ready)

       ,.lce_req_o(lce_cce_req)
       ,.lce_req_v_o(lce_cce_req_v)
       ,.lce_req_ready_i(lce_cce_req_ready)

       ,.lce_resp_o(lce_cce_resp)
       ,.lce_resp_v_o(lce_cce_resp_v)
       ,.lce_resp_ready_i(lce_cce_resp_ready)

       ,.lce_data_resp_o(lce_cce_data_resp)
       ,.lce_data_resp_v_o(lce_cce_data_resp_v)
       ,.lce_data_resp_ready_i(lce_cce_data_resp_ready)

       ,.lce_cmd_i(cce_lce_cmd)
       ,.lce_cmd_v_i(cce_lce_cmd_v)
       ,.lce_cmd_ready_o(cce_lce_cmd_ready)

       ,.lce_data_cmd_i(lce_data_cmd_li)
       ,.lce_data_cmd_v_i(lce_data_cmd_v_li)
       ,.lce_data_cmd_ready_o(lce_data_cmd_ready_lo)

       ,.lce_data_cmd_o(lce_data_cmd_lo)
       ,.lce_data_cmd_v_o(lce_data_cmd_v_lo)
       ,.lce_data_cmd_ready_i(lce_data_cmd_ready_li)
       );


bsg_fifo_1r1w_rolly
 #(.width_p(fe_queue_width_lp)
   ,.els_p(16)
   ,.ready_THEN_valid_p(1)
   )
 fe_queue_fifo
  (.clk_i(clk_i)
   ,.reset_i(reset_i) 

   ,.clr_v_i(1'b0) 
   ,.ckpt_v_i((be_fe_queue_v & be_fe_queue_ready))
   ,.roll_v_i(1'b0)

   ,.data_i(fe_fe_queue)
   ,.v_i(fe_fe_queue_v)
   ,.ready_o(fe_fe_queue_ready)

   ,.data_o(be_fe_queue)
   ,.v_o(be_fe_queue_v)
   ,.yumi_i(be_fe_queue_ready)
   );

bsg_fifo_1r1w_small
 #(.width_p(fe_cmd_width_lp)
   ,.els_p(8)
   ,.ready_THEN_valid_p(1)
   )
 fe_cmd_fifo
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.data_i(be_fe_cmd)
   ,.v_i(be_fe_cmd_v)
   ,.ready_o(be_fe_cmd_ready)

   ,.data_o(fe_fe_cmd)
   ,.v_o(fe_fe_cmd_v)
   ,.yumi_i(fe_fe_cmd_ready)
   );

mock_be_trace 
 #(.bp_first_pc_p(bp_first_pc_p)
   ,.vaddr_width_p(vaddr_width_p)
   ,.paddr_width_p(paddr_width_p)
   ,.asid_width_p(asid_width_p)
   ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
   ,.btb_tag_width_p(btb_tag_width_p)
   ,.btb_idx_width_p(btb_idx_width_p)
   ,.bht_idx_width_p(bht_idx_width_p)
   ,.ras_idx_width_p(ras_idx_width_p)
   ,.num_cce_p(num_cce_p)
   ,.num_lce_p(num_lce_p)
   ,.num_mem_p(1)
   ,.lce_assoc_p(lce_assoc_p)
   ,.lce_sets_p(lce_sets_p)
   ,.cce_block_size_in_bytes_p(cce_block_width_p/8)

   ,.trace_ring_width_p(trace_ring_width_p)
	 ,.num_core_p(num_core_p)
   )
 be
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.bp_fe_queue_i(be_fe_queue)
   ,.bp_fe_queue_v_i(be_fe_queue_v)
   ,.bp_fe_queue_ready_o(be_fe_queue_ready)

   ,.bp_fe_queue_clr_o(fe_queue_clr)

   ,.bp_fe_cmd_o(be_fe_cmd)
   ,.bp_fe_cmd_v_o(be_fe_cmd_v)
   ,.bp_fe_cmd_ready_i(be_fe_cmd_ready)

   ,.trace_data_o(tr_data_li)
   ,.trace_v_o(tr_v_li)
   ,.trace_ready_i(tr_ready_lo)

   ,.trace_data_i(tr_data_lo)
   ,.trace_v_i(tr_v_lo)
   ,.trace_yumi_o(tr_yumi_li)
   );

bsg_fsb_node_trace_replay
 #(.ring_width_p(trace_ring_width_p)
   ,.rom_addr_width_p(trace_rom_addr_width_p)
   )
 fe_trace_replay
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(1'b1)

   ,.data_i(tr_data_li)
   ,.v_i(tr_v_li)
   ,.ready_o(tr_ready_lo)

   ,.data_o(tr_data_lo)
   ,.v_o(tr_v_lo)
   ,.yumi_i(tr_yumi_li)

   ,.rom_addr_o(tr_rom_addr_li)
   ,.rom_data_i(tr_rom_data_lo)

   ,.done_o(test_done)
   ,.error_o()
   );


bp_trace_rom 
 #(.width_p  (trace_rom_data_width_lp)
   ,.addr_width_p(trace_rom_addr_width_p)
   ) 
 trace_rom
  (.addr_i(tr_rom_addr_li)
   ,.data_o(tr_rom_data_lo)
   );

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


bp_me_top 
 #(.bp_params_p(bp_params_p)
   ,.cfg_link_addr_width_p(cfg_link_addr_width_p)
   ,.cfg_link_data_width_p(cfg_link_data_width_p)
 )
 me
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.freeze_i('0)

   ,.config_addr_i('0)
   ,.config_data_i('0)
   ,.config_v_i('0)
   ,.config_w_i('0)
   ,.config_ready_o()

   ,.config_data_o()
   ,.config_v_o()
   ,.config_ready_i('0)

   ,.lce_req_i(lce_cce_req)
   ,.lce_req_v_i(lce_cce_req_v)
   ,.lce_req_ready_o(lce_cce_req_ready)

   ,.lce_resp_i(lce_cce_resp)
   ,.lce_resp_v_i(lce_cce_resp_v)
   ,.lce_resp_ready_o(lce_cce_resp_ready)        

   ,.lce_data_resp_i(lce_cce_data_resp)
   ,.lce_data_resp_v_i(lce_cce_data_resp_v)
   ,.lce_data_resp_ready_o(lce_cce_data_resp_ready)

   ,.lce_cmd_o(cce_lce_cmd)
   ,.lce_cmd_v_o(cce_lce_cmd_v)
   ,.lce_cmd_ready_i(cce_lce_cmd_ready)

   ,.lce_data_cmd_o(lce_data_cmd_li)
   ,.lce_data_cmd_v_o(lce_data_cmd_v_li)
   ,.lce_data_cmd_ready_i(lce_data_cmd_ready_lo)

   ,.lce_data_cmd_i(lce_data_cmd_lo)
   ,.lce_data_cmd_v_i(lce_data_cmd_v_lo)
   ,.lce_data_cmd_ready_o(lce_data_cmd_ready_li)

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
    ,.mem_els_p(mem_els_p)
    ,.boot_rom_width_p(cce_block_width_p)
    ,.boot_rom_els_p(boot_rom_els_p)
    ,.lce_req_data_width_p(reg_data_width_lp)
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

   ,.boot_rom_addr_o(mrom_addr[i])
   ,.boot_rom_data_i(mrom_data[i])
   );

bp_boot_rom 
 #(.width_p(boot_rom_width_p)
   ,.addr_width_p(lg_boot_rom_els_lp)
   ) 
 me_boot_rom 
  (.addr_i(mrom_addr[i])
   ,.data_o(mrom_data[i])
   );


end

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
     ,.up_i(tr_v_li)

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
        booted <= booted | fe_fe_queue_v; // Booted when we fetch the first instruction
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


endmodule : testbench

