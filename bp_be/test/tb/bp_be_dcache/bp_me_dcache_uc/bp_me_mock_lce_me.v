/**
 *  bp_me_mock_lce_me.v
 */

`include "bp_be_dcache_pkt.vh"

module bp_me_mock_lce_me
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_be_dcache_pkg::*;
  import bp_cce_pkg::*;
  import bp_common_cfg_link_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)
    , parameter mem_els_p="inv"
    , parameter boot_rom_els_p="inv"
    , parameter cce_trace_p = 0
    , parameter axe_trace_p = 0

    , parameter skip_ram_init_p = 0

    , localparam block_size_in_bytes_lp=(cce_block_width_p / 8)

    , localparam lce_id_width_lp=`BSG_SAFE_CLOG2(num_lce_p)

    , localparam inst_ram_addr_width_lp = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)

    , localparam ptag_width_lp = (paddr_width_p-bp_page_offset_width_gp)
    , localparam dcache_opcode_width_lp=$bits(bp_be_dcache_opcode_e)
    , localparam tr_ring_width_lp=(dcache_opcode_width_lp+paddr_width_p+dword_width_p)

    , localparam cfg_link_addr_width_p=cfg_addr_width_p
    , localparam cfg_link_data_width_p=cfg_data_width_p
    , localparam cce_instr_ram_addr_width_lp = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)

    , localparam dcache_pkt_width_lp=
      `bp_be_dcache_pkt_width(bp_page_offset_width_gp,dword_width_p)

    // dramsim2 stuff
    , parameter dramsim2_en_p = 0
    , parameter clock_period_in_ps_p = 1000
    , parameter prog_name_p = "null.mem"
    , parameter dram_bp_params_p  = "DDR2_micron_16M_8b_x8_sg3E.ini"
    , parameter dram_sys_bp_params_p = "system.ini"
    , parameter dram_capacity_p = 16384

  )
  (
    input clk_i
    , input reset_i

    , input [tr_ring_width_lp-1:0] tr_pkt_i
    , input tr_pkt_v_i
    , output logic tr_pkt_yumi_o

    , input tr_pkt_ready_i
    , output logic tr_pkt_v_o
    , output logic [tr_ring_width_lp-1:0] tr_pkt_o
  );

  // Config link
  logic [num_cce_p-1:0]                              freeze_li;
  logic [num_cce_p-1:0][cfg_link_addr_width_p-2:0]   config_addr_li;
  logic [num_cce_p-1:0][cfg_link_data_width_p-1:0]   config_data_li;
  logic [num_cce_p-1:0]                              config_v_li;
  logic [num_cce_p-1:0]                              config_w_li;
  logic [num_cce_p-1:0]                              config_ready_lo;

  logic [num_cce_p-1:0][cfg_link_data_width_p-1:0]   config_data_lo;
  logic [num_cce_p-1:0]                              config_v_lo;
  logic [num_cce_p-1:0]                              config_ready_li;

  // LCE
  //
  `declare_bp_lce_cce_req_s(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p);
  `declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, paddr_width_p);
  `declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_p, paddr_width_p, cce_block_width_p);
  `declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p);
  `declare_bp_lce_data_cmd_s(num_lce_p, cce_block_width_p, lce_assoc_p);

  bp_lce_cce_req_s lce_req_lo;
  logic lce_req_v_lo;
  logic lce_req_ready_li;

  bp_lce_cce_resp_s lce_resp_lo;
  logic lce_resp_v_lo;
  logic lce_resp_ready_li;

  bp_lce_cce_data_resp_s lce_data_resp_lo;
  logic lce_data_resp_v_lo;
  logic lce_data_resp_ready_li;

  bp_cce_lce_cmd_s lce_cmd_li;
  logic lce_cmd_v_li;
  logic lce_cmd_ready_lo;

  bp_lce_data_cmd_s lce_data_cmd_li;
  logic lce_data_cmd_v_li;
  logic lce_data_cmd_ready_lo;

  // Data command sent by LCE - never used in this setup because there is only one LCE
  bp_lce_data_cmd_s lce_data_cmd_lo;
  logic lce_data_cmd_v_lo;
  logic lce_data_cmd_ready_li;
  assign lce_data_cmd_ready_li = '0;

  // D$ Instantiation
  `declare_bp_be_dcache_pkt_s(bp_page_offset_width_gp, dword_width_p);

  // uncached store credit signals from D$ LCE
  logic credits_full_lo, credits_empty_lo;

  // Rolly FIFO inputs (from trace replay input)
  // create the D$ packet and strip the tag
  bp_be_dcache_pkt_s dcache_pkt_li;
  logic [ptag_width_lp-1:0] ptag_li;
  assign {dcache_pkt_li.opcode, ptag_li, dcache_pkt_li.page_offset, dcache_pkt_li.data} =
    tr_pkt_i;
  logic rolly_ready_lo;
  assign tr_pkt_yumi_o = tr_pkt_v_i & rolly_ready_lo;

  // Rolly FIFO outputs (to dcache)
  logic [ptag_width_lp-1:0] rolly_ptag_lo;
  bp_be_dcache_pkt_s rolly_dcache_pkt_lo;
  logic rolly_v_lo;
  logic rolly_yumi_li;
  logic dcache_ready_lo;
  assign rolly_yumi_li = rolly_v_lo & dcache_ready_lo & ~credits_full_lo;
  logic dcache_v_li;
  assign dcache_v_li = rolly_v_lo & ~credits_full_lo;

  // Rolly FIFO other inputs
  logic cache_miss_lo;

  // TLB to dcache
  logic dcache_tlb_miss_li;
  logic [ptag_width_lp-1:0] dcache_ptag_li;

  // outputs from data cache
  logic dcache_v_lo;
  logic [dword_width_p-1:0] dcache_data_lo;
  logic dcache_ready_li; // unused

  bsg_fifo_1r1w_rolly #(
    .width_p(dcache_pkt_width_lp+ptag_width_lp)
    ,.els_p(8)
  ) rolly (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.roll_v_i(cache_miss_lo)
    ,.clr_v_i(1'b0)
    ,.ckpt_v_i(dcache_v_lo)

    ,.data_i({ptag_li, dcache_pkt_li})
    ,.v_i(tr_pkt_v_i)
    ,.ready_o(rolly_ready_lo)

    ,.data_o({rolly_ptag_lo, rolly_dcache_pkt_lo})
    ,.v_o(rolly_v_lo)
    ,.yumi_i(rolly_yumi_li)
  );

  bp_be_dcache #(
    .data_width_p(dword_width_p)
    ,.paddr_width_p(paddr_width_p)
    ,.sets_p(lce_sets_p)
    ,.ways_p(lce_assoc_p)
    ,.num_cce_p(num_cce_p)
    ,.num_lce_p(num_lce_p)
    ,.max_credits_p(max_credits_p)
    ,.debug_p(0)
  ) dcache (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.freeze_i(freeze_li)
    ,.lce_id_i(lce_id_width_lp'(0))

    ,.dcache_pkt_i(rolly_dcache_pkt_lo)
    ,.v_i(dcache_v_li)
    ,.ready_o(dcache_ready_lo)

    ,.v_o(dcache_v_lo)
    ,.data_o(dcache_data_lo)

    ,.tlb_miss_i(dcache_tlb_miss_li)
    ,.ptag_i(dcache_ptag_li)
    ,.uncached_i(dcache_ptag_li[ptag_width_lp-1])

    ,.cache_miss_o(cache_miss_lo)
    ,.poison_i(cache_miss_lo)

    ,.lce_req_o(lce_req_lo)
    ,.lce_req_v_o(lce_req_v_lo)
    ,.lce_req_ready_i(lce_req_ready_li)

    ,.lce_resp_o(lce_resp_lo)
    ,.lce_resp_v_o(lce_resp_v_lo)
    ,.lce_resp_ready_i(lce_resp_ready_li)

    ,.lce_data_resp_o(lce_data_resp_lo)
    ,.lce_data_resp_v_o(lce_data_resp_v_lo)
    ,.lce_data_resp_ready_i(lce_data_resp_ready_li)

    ,.lce_cmd_i(lce_cmd_li)
    ,.lce_cmd_v_i(lce_cmd_v_li)
    ,.lce_cmd_ready_o(lce_cmd_ready_lo)

    ,.lce_data_cmd_i(lce_data_cmd_li)
    ,.lce_data_cmd_v_i(lce_data_cmd_v_li)
    ,.lce_data_cmd_ready_o(lce_data_cmd_ready_lo)

    ,.lce_data_cmd_o(lce_data_cmd_lo)
    ,.lce_data_cmd_v_o(lce_data_cmd_v_lo)
    ,.lce_data_cmd_ready_i(lce_data_cmd_ready_li)

    ,.credits_full_o(credits_full_lo)
    ,.credits_empty_o(credits_empty_lo)

    ,.config_addr_i(config_addr_li)
    ,.config_data_i(config_data_li)
    ,.config_v_i(config_v_li)
    ,.config_w_i(config_w_li)
    ,.config_ready_o()
    ,.config_data_o()
    ,.config_v_o()
    ,.config_ready_i(config_ready_li)

  );

  // mock tlb
  //
  mock_tlb #(
    .tag_width_p(ptag_width_lp)
  ) tlb (
    .clk_i(clk_i)

    ,.v_i(rolly_yumi_li)
    ,.tag_i(rolly_ptag_lo)

    ,.tag_o(dcache_ptag_li)
    ,.tlb_miss_o(dcache_tlb_miss_li)
  );

  // output fifo
  //
  logic fifo_yumi_li;
  assign fifo_yumi_li = tr_pkt_v_o & tr_pkt_ready_i;
  logic [dword_width_p-1:0] fifo_data_lo;
  assign tr_pkt_o = {{(tr_ring_width_lp-dword_width_p){1'b0}}, fifo_data_lo};

  bsg_fifo_1r1w_small #(
    .width_p(dword_width_p)
    ,.els_p(16)//2**12
  ) output_fifo (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    // from dcache
    ,.v_i(dcache_v_lo)
    ,.ready_o(dcache_ready_li)
    ,.data_i(dcache_data_lo)

    // to trace replay
    ,.v_o(tr_pkt_v_o)
    ,.yumi_i(fifo_yumi_li)
    ,.data_o(fifo_data_lo)
  );

  // CCE Boot ROM

  // Memory End
  //
  `declare_bp_me_if(paddr_width_p,cce_block_width_p,num_lce_p,lce_assoc_p);

  logic [num_cce_p-1:0][inst_ram_addr_width_lp-1:0] cce_inst_boot_rom_addr;
  logic [num_cce_p-1:0][`bp_cce_inst_width-1:0] cce_inst_boot_rom_data;

  bp_mem_cce_resp_s [num_cce_p-1:0] mem_resp;
  logic [num_cce_p-1:0] mem_resp_v;
  logic [num_cce_p-1:0] mem_resp_ready;

  bp_mem_cce_data_resp_s [num_cce_p-1:0] mem_data_resp;
  logic [num_cce_p-1:0] mem_data_resp_v;
  logic [num_cce_p-1:0] mem_data_resp_ready;

  bp_cce_mem_cmd_s [num_cce_p-1:0] mem_cmd;
  logic [num_cce_p-1:0] mem_cmd_v;
  logic [num_cce_p-1:0] mem_cmd_yumi;

  bp_cce_mem_data_cmd_s [num_cce_p-1:0] mem_data_cmd;
  logic [num_cce_p-1:0] mem_data_cmd_v;
  logic [num_cce_p-1:0] mem_data_cmd_yumi;

  // Config link
  bp_cce_mem_data_cmd_s [num_cce_p-1:0] cfg_data_cmd_lo;
  logic [num_cce_p-1:0] cfg_data_cmd_v_lo;
  logic [num_cce_p-1:0] cfg_data_cmd_yumi_li;

  bp_mem_cce_resp_s [num_cce_p-1:0] cfg_resp_li;
  logic [num_cce_p-1:0] cfg_resp_v_li;
  logic [num_cce_p-1:0] cfg_resp_ready_lo;

  logic [num_cce_p-1:0]                              freeze_li;
  logic [num_cce_p-1:0][cfg_link_addr_width_p-1:0]   config_addr_li;
  logic [num_cce_p-1:0][cfg_link_data_width_p-1:0]   config_data_li;
  logic [num_cce_p-1:0]                              config_v_li;
  logic [num_cce_p-1:0]                              config_w_li;
  logic [num_cce_p-1:0]                              config_ready_lo;

  logic [num_cce_p-1:0][cfg_link_data_width_p-1:0]   config_data_lo;
  logic [num_cce_p-1:0]                              config_v_lo;
  logic [num_cce_p-1:0]                              config_ready_li;

logic freeze_r;
always_ff @(posedge clk_i)
  begin
    if (config_v_li & (config_addr_li == bp_cfg_reg_freeze_gp))
      freeze_r <= config_data_li[0];
  end

  bp_cce_top #(
    .bp_params_p(bp_params_p)
    ,.cce_trace_p(cce_trace_p)
  ) cce (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.freeze_i(freeze_r)

    ,.cfg_w_v_i(config_v_li)
    ,.cfg_addr_i(config_addr_li)
    ,.cfg_data_i(config_data_li)

    ,.cce_id_i('0)

    ,.lce_cmd_o(lce_cmd_li)
    ,.lce_cmd_v_o(lce_cmd_v_li)
    ,.lce_cmd_ready_i(lce_cmd_ready_lo)

    ,.lce_data_cmd_o(lce_data_cmd_li)
    ,.lce_data_cmd_v_o(lce_data_cmd_v_li)
    ,.lce_data_cmd_ready_i(lce_data_cmd_ready_lo)

    ,.lce_req_i(lce_req_lo)
    ,.lce_req_v_i(lce_req_v_lo)
    ,.lce_req_ready_o(lce_req_ready_li)

    ,.lce_resp_i(lce_resp_lo)
    ,.lce_resp_v_i(lce_resp_v_lo)
    ,.lce_resp_ready_o(lce_resp_ready_li)

    ,.lce_data_resp_i(lce_data_resp_lo)
    ,.lce_data_resp_v_i(lce_data_resp_v_lo)
    ,.lce_data_resp_ready_o(lce_data_resp_ready_li)

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

  bp_mem_dramsim2
   #(.mem_id_p('0)
     ,.clock_period_in_ps_p(clock_period_in_ps_p)
     ,.prog_name_p(prog_name_p)
     ,.dram_bp_params_p(dram_bp_params_p)
     ,.dram_sys_bp_params_p(dram_sys_bp_params_p)
     ,.dram_capacity_p(dram_capacity_p)
     ,.num_lce_p(num_lce_p)
     ,.num_cce_p(num_cce_p)
     ,.paddr_width_p(paddr_width_p)
     ,.lce_assoc_p(lce_assoc_p)
     ,.block_size_in_bytes_p(block_size_in_bytes_lp)
     ,.lce_sets_p(lce_sets_p)
     ,.lce_req_data_width_p(dword_width_p)
     )
   mem
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_cmd_i(mem_cmd)
     ,.mem_cmd_v_i(mem_cmd_v)
     ,.mem_cmd_yumi_o(mem_cmd_yumi)

     ,.mem_data_cmd_i(mem_data_cmd)
     ,.mem_data_cmd_v_i(mem_data_cmd_v)
     ,.mem_data_cmd_yumi_o(mem_data_cmd_yumi)

     ,.mem_resp_o(mem_resp)
     ,.mem_resp_v_o(mem_resp_v)
     ,.mem_resp_ready_i(mem_resp_ready)

     ,.mem_data_resp_o(mem_data_resp)
     ,.mem_data_resp_v_o(mem_data_resp_v)
     ,.mem_data_resp_ready_i(mem_data_resp_ready)
     );

  bp_cce_mmio_cfg_loader
  #(.bp_params_p(bp_params_p)
    ,.inst_width_p(`bp_cce_inst_width)
    ,.inst_ram_addr_width_p(cce_instr_ram_addr_width_lp)
    ,.inst_ram_els_p(num_cce_instr_ram_els_p)
    ,.skip_ram_init_p('0)
  )
  cfg_loader
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.mem_data_cmd_o(cfg_data_cmd_lo)
   ,.mem_data_cmd_v_o(cfg_data_cmd_v_lo)
   ,.mem_data_cmd_yumi_i(cfg_data_cmd_yumi_li)

   ,.mem_resp_i(cfg_resp_li)
   ,.mem_resp_v_i(cfg_resp_v_li)
   ,.mem_resp_ready_o(cfg_resp_ready_lo)
  );

  // We use the clint just as a config loader converter
  bp_clint
  #(.bp_params_p(bp_params_p))
  clint
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.mem_cmd_i('0)
    ,.mem_cmd_v_i(1'b0)
    ,.mem_cmd_yumi_o()

    ,.mem_data_cmd_i(cfg_data_cmd_lo)
    ,.mem_data_cmd_v_i(cfg_data_cmd_v_lo)
    ,.mem_data_cmd_yumi_o(cfg_data_cmd_yumi_li)

    ,.mem_resp_o(cfg_resp_li)
    ,.mem_resp_v_o(cfg_resp_v_li)
    ,.mem_resp_ready_i(cfg_resp_ready_lo)

    ,.mem_data_resp_o()
    ,.mem_data_resp_v_o()
    ,.mem_data_resp_ready_i(1'b0)

    ,.soft_irq_o()
    ,.timer_irq_o()
    ,.external_irq_o()

    ,.cfg_link_w_v_o(config_v_li)
    ,.cfg_link_addr_o(config_addr_li)
    ,.cfg_link_data_o(config_data_li)
    );


endmodule
