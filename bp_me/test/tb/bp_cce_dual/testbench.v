/**
  *
  * testbench.v
  *
  */
  
//`include "bp_be_dcache_pkt.vh"

module testbench
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_be_dcache_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bp_cfg_link_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_cfg_e cfg_p = BP_CFG_FLOWVAR // Replaced by the flow with a specific bp_cfg
   `declare_bp_proc_params(cfg_p)

   // interface widths
   `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

   , parameter cce_trace_p = 0
   , parameter axe_trace_p = 0
   , parameter instr_count = 1
   , parameter skip_init_p = 0
   , parameter lce_perf_trace_p = 0

   // Number of elements in the fake BlackParrot memory
   , parameter clock_period_in_ps_p = 1000
   , parameter prog_name_p = "prog.mem"
   , parameter dram_cfg_p  = "dram_ch.ini"
   , parameter dram_sys_cfg_p = "dram_sys.ini"
   , parameter dram_capacity_p = 16384

   // LCE Trace Replay Width
   , localparam dcache_opcode_width_lp=$bits(bp_be_dcache_opcode_e)
   , localparam tr_ring_width_lp=(dcache_opcode_width_lp+paddr_width_p+dword_width_p)
   , localparam tr_rom_addr_width_p = 20

   // Config link
   , localparam cce_instr_ram_addr_width_lp = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)

   , localparam lg_num_lce_lp=`BSG_SAFE_CLOG2(num_lce_p)

   )
  (input clk_i
   , input reset_i
   );

`declare_bsg_ready_and_link_sif_s(mem_noc_width_p, bsg_ready_and_link_sif_s);
`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p);
`declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p);

//logic [mem_noc_cord_width_p-1:0]                 dram_cord_lo, clint_cord_lo;
logic [noc_cord_width_p-1:0]                 dram_cord_lo, mmio_cord_lo;
assign dram_cord_lo  = num_core_p+1;
assign mmio_cord_lo = mmio_pos_p;

// CFG IF
bp_cce_mem_cmd_s       cfg_cmd_lo;
logic                  cfg_cmd_v_lo, cfg_cmd_yumi_li;
bp_mem_cce_resp_s      cfg_resp_li;
logic                  cfg_resp_v_li, cfg_resp_ready_lo;

logic [cfg_addr_width_p-1:0] config_addr_li;
logic [cfg_data_width_p-1:0] config_data_li;
logic                        config_v_li;

// Freeze signal register
logic freeze_r;
always_ff @(posedge clk_i) begin
  if (reset_i)
    freeze_r <= 1'b1;
  else if (config_v_li & (config_addr_li == bp_cfg_reg_freeze_gp))
    freeze_r <= config_data_li[0];
end

// CCE-MEM IF
bp_mem_cce_resp_s          mem_resp;
logic                      mem_resp_v, mem_resp_ready;
bp_cce_mem_cmd_s           mem_cmd;
logic                      mem_cmd_v, mem_cmd_yumi;

// LCE-CCE IF

// signals to/from CCE
bp_lce_cce_req_s     lce_req_cce;
logic                lce_req_v_cce, lce_req_ready_cce;
bp_lce_cce_resp_s    lce_resp_cce;
logic                lce_resp_v_cce, lce_resp_ready_cce;
bp_lce_cmd_s         lce_cmd_cce;
logic                lce_cmd_v_cce, lce_cmd_ready_cce;

// signals to/from LCEs
bp_lce_cce_req_s     [num_lce_p-1:0] lce_req;
logic                [num_lce_p-1:0] lce_req_v, lce_req_ready;
bp_lce_cce_resp_s    [num_lce_p-1:0] lce_resp;
logic                [num_lce_p-1:0] lce_resp_v, lce_resp_ready;
bp_lce_cmd_s         [num_lce_p-1:0] lce_cmd;
logic                [num_lce_p-1:0] lce_cmd_v, lce_cmd_ready;
bp_lce_cmd_s         [num_lce_p-1:0] lce_cmd_lo;
logic                [num_lce_p-1:0] lce_cmd_v_lo, lce_cmd_ready_li;

logic                [num_lce_p-1:0] tr_done_lo;

// Arbitration for LCE Req and LCE Resp from LCE to CCE
assign lce_req_cce = lce_req_v[0] ? lce_req[0] : lce_req[1];
assign lce_req_v_cce = lce_req_v[0] ? lce_req_v[0] : lce_req_v[1];
assign lce_req_ready[0] = lce_req_ready_cce;
assign lce_req_ready[1] = ~lce_req_v[0] & lce_req_ready_cce;

assign lce_resp_cce = lce_resp_v[0] ? lce_resp[0] : lce_resp[1];
assign lce_resp_v_cce = lce_resp_v[0] ? lce_resp_v[0] : lce_resp_v[1];
assign lce_resp_ready[0] = lce_resp_ready_cce;
assign lce_resp_ready[1] = ~lce_resp_v[0] & lce_resp_ready_cce;

// LCE Commands
// valid command to LCE if from CCE and target correct LCE, or from other LCE (must target this LCE)
assign lce_cmd_v[0] = (lce_cmd_v_cce & lce_cmd_cce.dst_id == 1'b0) | lce_cmd_v_lo[1];
assign lce_cmd_v[1] = (lce_cmd_v_cce & lce_cmd_cce.dst_id == 1'b1) | lce_cmd_v_lo[0];

assign lce_cmd[0] = (lce_cmd_v_cce & lce_cmd_cce.dst_id == 1'b0)
                    ? lce_cmd_cce
                    : lce_cmd_v_lo[1]
                      ? lce_cmd_lo[1]
                      : '0;

assign lce_cmd[1] = (lce_cmd_v_cce & lce_cmd_cce.dst_id == 1'b1)
                    ? lce_cmd_cce
                    : lce_cmd_v_lo[0]
                      ? lce_cmd_lo[0]
                      : '0;

assign lce_cmd_ready_cce = (lce_cmd_v_cce & lce_cmd_cce.dst_id == 1'b0)
                           ? lce_cmd_ready[0]
                           : (lce_cmd_v_cce & lce_cmd_cce.dst_id == 1'b1)
                             ? lce_cmd_ready[1]
                             : '0;

assign lce_cmd_ready_li[0] = lce_cmd_ready[1] & ~(lce_cmd_v_cce & lce_cmd_cce.dst_id == 1'b1);
assign lce_cmd_ready_li[1] = lce_cmd_ready[0] & ~(lce_cmd_v_cce & lce_cmd_cce.dst_id == 1'b0);

// instantiate LCEs
for (genvar i = 0; i < num_lce_p; i++) begin : rof1

// Trace Replay for LCE
logic                        tr_v_li, tr_ready_lo;
logic [tr_ring_width_lp-1:0] tr_data_li;
logic                        tr_v_lo, tr_yumi_li;
logic [tr_ring_width_lp-1:0] tr_data_lo;

bsg_trace_node_master #(
  .id_p(i)
  ,.ring_width_p(tr_ring_width_lp)
  ,.rom_addr_width_p(tr_rom_addr_width_p)
) trace_node_master (
  .clk_i(clk_i)
  ,.reset_i(reset_i)
  ,.en_i(1'b1)

  ,.v_i(tr_v_li)
  ,.data_i({{tr_data_li[tr_ring_width_lp-1:dword_width_p]},{dword_width_p{1'b0}}})
  ,.ready_o(tr_ready_lo)

  ,.v_o(tr_v_lo)
  ,.yumi_i(tr_yumi_li)
  ,.data_o(tr_data_lo)

  ,.done_o(tr_done_lo[i])
);

// LCE
bp_me_nonsynth_mock_lce #(
  .cfg_p(cfg_p)
  ,.axe_trace_p(axe_trace_p)
  ,.perf_trace_p(lce_perf_trace_p)
) lce (
  .clk_i(clk_i)
  ,.reset_i(reset_i)
  ,.freeze_i(freeze_r)

  ,.lce_id_i(lg_num_lce_lp'(i))

  ,.tr_pkt_i(tr_data_lo)
  ,.tr_pkt_v_i(tr_v_lo)
  ,.tr_pkt_yumi_o(tr_yumi_li)

  ,.tr_pkt_v_o(tr_v_li)
  ,.tr_pkt_o(tr_data_li)
  ,.tr_pkt_ready_i(tr_ready_lo)

  ,.lce_req_o(lce_req[i])
  ,.lce_req_v_o(lce_req_v[i])
  ,.lce_req_ready_i(lce_req_ready[i])

  ,.lce_resp_o(lce_resp[i])
  ,.lce_resp_v_o(lce_resp_v[i])
  ,.lce_resp_ready_i(lce_resp_ready[i])

  ,.lce_cmd_i(lce_cmd[i])
  ,.lce_cmd_v_i(lce_cmd_v[i])
  ,.lce_cmd_ready_o(lce_cmd_ready[i])

  ,.lce_cmd_o(lce_cmd_lo[i])
  ,.lce_cmd_v_o(lce_cmd_v_lo[i])
  ,.lce_cmd_ready_i(lce_cmd_ready_li[i])
);

bind lce
bp_me_nonsynth_lce_tracer #(
  .cfg_p(cfg_p)
  ,.perf_trace_p(perf_trace_p)
) lce (
  .clk_i(clk_i)
  ,.reset_i(reset_i)
  ,.freeze_i(freeze_i)

  ,.lce_id_i(lce_id_i)

  ,.tr_pkt_i(tr_pkt_i)
  ,.tr_pkt_v_i(tr_pkt_v_i)
  ,.tr_pkt_yumi_i(tr_pkt_yumi_o)

  ,.tr_pkt_v_o_i(tr_pkt_v_o)
  ,.tr_pkt_ready_i(tr_pkt_ready_i)

  ,.lce_req_i(lce_req_o)
  ,.lce_req_v_i(lce_req_v_o)
  ,.lce_req_ready_i(lce_req_ready_i)

  ,.lce_cmd_i(lce_cmd_i)
  ,.lce_cmd_v_i(lce_cmd_v_i)
  ,.lce_cmd_ready_i(lce_cmd_ready_o)
);

end // rof1

// CCE
wrapper
#(.cfg_p(cfg_p)
  ,.cce_trace_p(cce_trace_p)
 )
wrapper
 (.clk_i(clk_i)
  ,.reset_i(reset_i)

  ,.freeze_i(freeze_r)

  ,.cfg_w_v_i(config_v_li)
  ,.cfg_addr_i(config_addr_li)
  ,.cfg_data_i(config_data_li)

  ,.cce_id_i('0)

  ,.lce_cmd_o(lce_cmd_cce)
  ,.lce_cmd_v_o(lce_cmd_v_cce)
  ,.lce_cmd_ready_i(lce_cmd_ready_cce)

  ,.lce_req_i(lce_req_cce)
  ,.lce_req_v_i(lce_req_v_cce)
  ,.lce_req_ready_o(lce_req_ready_cce)

  ,.lce_resp_i(lce_resp_cce)
  ,.lce_resp_v_i(lce_resp_v_cce)
  ,.lce_resp_ready_o(lce_resp_ready_cce)

  ,.mem_resp_i(mem_resp)
  ,.mem_resp_v_i(mem_resp_v)
  ,.mem_resp_ready_o(mem_resp_ready)

  ,.mem_cmd_o(mem_cmd)
  ,.mem_cmd_v_o(mem_cmd_v)
  ,.mem_cmd_yumi_i(mem_cmd_yumi)
);

// DRAM
bp_mem_dramsim2
#(.mem_id_p(0)
   ,.clock_period_in_ps_p(clock_period_in_ps_p)
   ,.prog_name_p(prog_name_p)
   ,.dram_cfg_p(dram_cfg_p)
   ,.dram_sys_cfg_p(dram_sys_cfg_p)
   ,.dram_capacity_p(dram_capacity_p)
   ,.num_lce_p(num_lce_p)
   ,.num_cce_p(num_cce_p)
   ,.paddr_width_p(paddr_width_p)
   ,.lce_assoc_p(lce_assoc_p)
   ,.block_size_in_bytes_p(cce_block_width_p/8)
   ,.lce_sets_p(lce_sets_p)
   ,.lce_req_data_width_p(dword_width_p)
  )
mem
 (.clk_i(clk_i)
  ,.reset_i(reset_i)

  ,.mem_cmd_i(mem_cmd)
  ,.mem_cmd_v_i(mem_cmd_v)
  ,.mem_cmd_yumi_o(mem_cmd_yumi)

  ,.mem_resp_o(mem_resp)
  ,.mem_resp_v_o(mem_resp_v)
  ,.mem_resp_ready_i(mem_resp_ready)
  );

// CFG Loader
bp_cce_mmio_cfg_loader
#(.cfg_p(cfg_p)
  ,.inst_width_p(`bp_cce_inst_width)
  ,.inst_ram_addr_width_p(cce_instr_ram_addr_width_lp)
  ,.inst_ram_els_p(num_cce_instr_ram_els_p)
  ,.skip_ram_init_p(skip_init_p)
 )
cfg_loader
 (.clk_i(clk_i)
  ,.reset_i(reset_i)
 
  ,.mem_cmd_o(cfg_cmd_lo)
  ,.mem_cmd_v_o(cfg_cmd_v_lo)
  ,.mem_cmd_yumi_i(cfg_cmd_yumi_li)
 
  ,.mem_resp_i(cfg_resp_li)
  ,.mem_resp_v_i(cfg_resp_v_li)
  ,.mem_resp_ready_o(cfg_resp_ready_lo)
  );

// CFG Loader Master
bsg_ready_and_link_sif_s cfg_link_li, cfg_link_lo;
bp_me_cce_to_wormhole_link_master
 #(.cfg_p(cfg_p))
  master_link
  (.clk_i(clk_i)
  ,.reset_i(reset_i)

  ,.mem_cmd_i(cfg_cmd_lo)
  ,.mem_cmd_v_i(cfg_cmd_v_lo)
  ,.mem_cmd_yumi_o(cfg_cmd_yumi_li)

  ,.mem_resp_o(cfg_resp_li)
  ,.mem_resp_v_o(cfg_resp_v_li)
  ,.mem_resp_ready_i(cfg_resp_ready_lo)

  ,.my_cord_i(dram_cord_lo)
  
  ,.mem_cmd_dest_cord_i(mmio_cord_lo)
  
  //,.mem_data_cmd_dest_cord_i(mmio_cord_lo)
  
  ,.link_i(cfg_link_li)
  ,.link_o(cfg_link_lo)
  );
 
// We use the clint just as a config loader converter
bsg_ready_and_link_sif_s clint_cmd_link_i;
bsg_ready_and_link_sif_s clint_cmd_link_o;
bsg_ready_and_link_sif_s clint_resp_link_i;
bsg_ready_and_link_sif_s clint_resp_link_o;


// CLINT sends nothing to CFG
assign cfg_link_li.v = '0;
assign cfg_link_li.data = '0;
// Ready signal to master, from CLINT client
assign cfg_link_li.ready_and_rev = clint_cmd_link_o.ready_and_rev;

// command to clint comes from cfg_link_lo
assign clint_cmd_link_i.v = cfg_link_lo.v;
assign clint_cmd_link_i.data = cfg_link_lo.data;
assign clint_cmd_link_i.ready_and_rev = '0;

// clint has no responses inbound
assign clint_resp_link_i.v = '0;
assign clint_resp_link_i.data = '0;
assign clint_resp_link_i.ready_and_rev = cfg_link_lo.ready_and_rev;

bp_clint
 #(.cfg_p(cfg_p))
 clint
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   
   ,.cfg_w_v_o(config_v_li)
   ,.cfg_addr_o(config_addr_li)
   ,.cfg_data_o(config_data_li)

   ,.soft_irq_o()
   ,.timer_irq_o()
   ,.external_irq_o()

   ,.my_cord_i(mmio_cord_lo)
   ,.dram_cord_i(dram_cord_lo)
   ,.mmio_cord_i(mmio_cord_lo)

   // to client
   ,.cmd_link_i(clint_cmd_link_i)
   // from master - unused
   ,.cmd_link_o(clint_cmd_link_o)
   // to master - unused
   ,.resp_link_i(clint_resp_link_i)
   // from client
   ,.resp_link_o(clint_resp_link_o)
   );


// Program done info
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

   ,.clear_i(reset_i)
   ,.up_i(1'b1)

   ,.count_o(clock_cnt)
   );

always_ff @(negedge clk_i) begin
  if (&tr_done_lo) begin
    $display("Bytes: %d Clocks: %d mBPC: %d "
             , instr_count*64
             , clock_cnt
             , (instr_count*64*1000) / clock_cnt
             );
    $display("Test PASSed");
    $finish(0);
  end
end



endmodule : testbench

