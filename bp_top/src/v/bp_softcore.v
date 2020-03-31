

module bp_softcore
 import bsg_wormhole_router_pkg::*;
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_fe_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_me_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
   )
  (input                                               clk_i
   , input                                             reset_i

   // Outgoing I/O
   , output [cce_mem_msg_width_lp-1:0]                 io_cmd_o
   , output                                            io_cmd_v_o
   , input                                             io_cmd_ready_i

   , input [cce_mem_msg_width_lp-1:0]                  io_resp_i
   , input                                             io_resp_v_i
   , output                                            io_resp_yumi_o

   // Memory Requests
   , output [cce_mem_msg_width_lp-1:0]                 mem_cmd_o
   , output                                            mem_cmd_v_o
   , input                                             mem_cmd_ready_i

   , input [cce_mem_msg_width_lp-1:0]                  mem_resp_i
   , input                                             mem_resp_v_i
   , output                                            mem_resp_yumi_o
   );

  `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);

  `declare_bp_cache_service_if(paddr_width_p, ptag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_p, dcache_block_width_p, dcache);
  `declare_bp_cache_service_if(paddr_width_p, ptag_width_p, icache_sets_p, icache_assoc_p, dword_width_p, icache_block_width_p, icache);
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
  `declare_bp_cache_stat_info_s(dcache_assoc_p, dcache);
  `declare_bp_cache_stat_info_s(icache_assoc_p, icache);

  bp_cfg_bus_s cfg_bus_li;

  `bp_cast_o(bp_cce_mem_msg_s, mem_cmd);
  `bp_cast_o(bp_cce_mem_msg_s, io_cmd);
  `bp_cast_i(bp_cce_mem_msg_s, mem_resp);
  `bp_cast_i(bp_cce_mem_msg_s, io_resp);

  bp_dcache_req_s dcache_req_lo;
  bp_icache_req_s icache_req_lo;
  logic dcache_req_v_lo, dcache_req_ready_li;
  logic icache_req_v_lo, icache_req_ready_li;

  bp_dcache_req_metadata_s dcache_req_metadata_lo;
  bp_icache_req_metadata_s icache_req_metadata_lo;
  logic dcache_req_metadata_v_lo, icache_req_metadata_v_lo;

  bp_dcache_tag_mem_pkt_s dcache_tag_mem_pkt_li;
  bp_icache_tag_mem_pkt_s icache_tag_mem_pkt_li;
  logic dcache_tag_mem_pkt_v_li, dcache_tag_mem_pkt_ready_lo;
  logic icache_tag_mem_pkt_v_li, icache_tag_mem_pkt_ready_lo;
  logic [ptag_width_p-1:0] dcache_tag_mem_lo, icache_tag_mem_lo;

  bp_dcache_data_mem_pkt_s dcache_data_mem_pkt_li;
  bp_icache_data_mem_pkt_s icache_data_mem_pkt_li;
  logic dcache_data_mem_pkt_v_li, dcache_data_mem_pkt_ready_lo;
  logic icache_data_mem_pkt_v_li, icache_data_mem_pkt_ready_lo;
  logic [dcache_block_width_p-1:0] dcache_data_mem_lo;
  logic [icache_block_width_p-1:0] icache_data_mem_lo;

  bp_dcache_stat_mem_pkt_s dcache_stat_mem_pkt_li;
  bp_icache_stat_mem_pkt_s icache_stat_mem_pkt_li;
  logic dcache_stat_mem_pkt_v_li, dcache_stat_mem_pkt_ready_lo;
  logic icache_stat_mem_pkt_v_li, icache_stat_mem_pkt_ready_lo;
  bp_dcache_stat_info_s dcache_stat_mem_lo;
  bp_icache_stat_info_s icache_stat_mem_lo;

  logic dcache_req_complete_li, icache_req_complete_li;

  logic [1:0] credits_full_li, credits_empty_li;
  logic timer_irq_li, software_irq_li, external_irq_li;

  bp_cce_mem_msg_s [1:0] proc_cmd_lo;
  logic [1:0] proc_cmd_v_lo, proc_cmd_ready_li;
  bp_cce_mem_msg_s [1:0] proc_resp_li;
  logic [1:0] proc_resp_v_li, proc_resp_yumi_lo;

  bp_cce_mem_msg_s clint_cmd_li;
  logic clint_cmd_v_li, clint_cmd_ready_lo;
  bp_cce_mem_msg_s clint_resp_lo;
  logic clint_resp_v_lo, clint_resp_yumi_li;

  bp_cce_mem_msg_s cache_cmd_li;
  logic cache_cmd_v_li, cache_cmd_ready_lo;
  bp_cce_mem_msg_s cache_resp_lo;
  logic cache_resp_v_lo, cache_resp_yumi_li;

  always_comb
    begin
      cfg_bus_li = '0;
      cfg_bus_li.icache_mode = e_lce_mode_normal;
      cfg_bus_li.icache_id   = 1'b0;
      cfg_bus_li.dcache_mode = e_lce_mode_normal;
      cfg_bus_li.dcache_id   = 1'b1;
    end

  bp_core_minimal
   #(.bp_params_p(bp_params_p))
   core
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_li)
     ,.cfg_npc_data_o()
     ,.cfg_irf_data_o()
     ,.cfg_csr_data_o()
     ,.cfg_priv_data_o()

     ,.dcache_req_o(dcache_req_lo)
     ,.dcache_req_v_o(dcache_req_v_lo)
     ,.dcache_req_ready_i(dcache_req_ready_li)
     ,.dcache_req_metadata_o(dcache_req_metadata_lo)
     ,.dcache_req_metadata_v_o(dcache_req_metadata_v_lo)
     ,.dcache_req_complete_i(dcache_req_complete_li)

     ,.icache_req_o(icache_req_lo)
     ,.icache_req_v_o(icache_req_v_lo)
     ,.icache_req_ready_i(icache_req_ready_li)
     ,.icache_req_metadata_o(icache_req_metadata_lo)
     ,.icache_req_metadata_v_o(icache_req_metadata_v_lo)
     ,.icache_req_complete_i(icache_req_complete_li)

     ,.dcache_tag_mem_pkt_i(dcache_tag_mem_pkt_li)
     ,.dcache_tag_mem_pkt_v_i(dcache_tag_mem_pkt_v_li)
     ,.dcache_tag_mem_pkt_ready_o(dcache_tag_mem_pkt_ready_lo)
     ,.dcache_tag_mem_o(dcache_tag_mem_lo)

     ,.dcache_data_mem_pkt_i(dcache_data_mem_pkt_li)
     ,.dcache_data_mem_pkt_v_i(dcache_data_mem_pkt_v_li)
     ,.dcache_data_mem_pkt_ready_o(dcache_data_mem_pkt_ready_lo)
     ,.dcache_data_mem_o(dcache_data_mem_lo)

     ,.dcache_stat_mem_pkt_i(dcache_stat_mem_pkt_li)
     ,.dcache_stat_mem_pkt_v_i(dcache_stat_mem_pkt_v_li)
     ,.dcache_stat_mem_pkt_ready_o(dcache_stat_mem_pkt_ready_lo)
     ,.dcache_stat_mem_o(dcache_stat_mem_lo)

     ,.icache_tag_mem_pkt_i(icache_tag_mem_pkt_li)
     ,.icache_tag_mem_pkt_v_i(icache_tag_mem_pkt_v_li)
     ,.icache_tag_mem_pkt_ready_o(icache_tag_mem_pkt_ready_lo)
     ,.icache_tag_mem_o(icache_tag_mem_lo)

     ,.icache_data_mem_pkt_i(icache_data_mem_pkt_li)
     ,.icache_data_mem_pkt_v_i(icache_data_mem_pkt_v_li)
     ,.icache_data_mem_pkt_ready_o(icache_data_mem_pkt_ready_lo)
     ,.icache_data_mem_o(icache_data_mem_lo)

     ,.icache_stat_mem_pkt_i(icache_stat_mem_pkt_li)
     ,.icache_stat_mem_pkt_v_i(icache_stat_mem_pkt_v_li)
     ,.icache_stat_mem_pkt_ready_o(icache_stat_mem_pkt_ready_lo)
     ,.icache_stat_mem_o(icache_stat_mem_lo)

     ,.credits_full_i(|credits_full_li)
     ,.credits_empty_i(&credits_empty_li)

     ,.timer_irq_i(timer_irq_li)
     ,.software_irq_i(software_irq_li)
     ,.external_irq_i(external_irq_li)
     );

  wire [1:0][lce_id_width_p-1:0] lce_id_li = {cfg_bus_li.dcache_id, cfg_bus_li.icache_id};

  bp_uce
    #(.bp_params_p(bp_params_p)
     ,.assoc_p(dcache_assoc_p)
     ,.sets_p(dcache_sets_p)
     ,.block_width_p(dcache_block_width_p))
    dcache_uce
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.lce_id_i(lce_id_li[1])

    ,.cache_req_i(dcache_req_lo)
    ,.cache_req_v_i(dcache_req_v_lo)
    ,.cache_req_ready_o(dcache_req_ready_li)
    ,.cache_req_metadata_i(dcache_req_metadata_lo)
    ,.cache_req_metadata_v_i(dcache_req_metadata_v_lo)

    ,.tag_mem_pkt_o(dcache_tag_mem_pkt_li)
    ,.tag_mem_pkt_v_o(dcache_tag_mem_pkt_v_li)
    ,.tag_mem_pkt_ready_i(dcache_tag_mem_pkt_ready_lo)
    ,.tag_mem_i(dcache_tag_mem_lo)

    ,.data_mem_pkt_o(dcache_data_mem_pkt_li)
    ,.data_mem_pkt_v_o(dcache_data_mem_pkt_v_li)
    ,.data_mem_pkt_ready_i(dcache_data_mem_pkt_ready_lo)
    ,.data_mem_i(dcache_data_mem_lo)

    ,.stat_mem_pkt_o(dcache_stat_mem_pkt_li)
    ,.stat_mem_pkt_v_o(dcache_stat_mem_pkt_v_li)
    ,.stat_mem_pkt_ready_i(dcache_stat_mem_pkt_ready_lo)
    ,.stat_mem_i(dcache_stat_mem_lo)

    ,.cache_req_complete_o(dcache_req_complete_li)

    ,.credits_full_o(credits_full_li[1])
    ,.credits_empty_o(credits_empty_li[1])

    ,.mem_cmd_o(mem_cmd_lo[1])
    ,.mem_cmd_v_o(mem_cmd_v_lo[1])
    ,.mem_cmd_ready_i(mem_cmd_ready_li[1])

    ,.mem_resp_i(mem_resp_li[1])
    ,.mem_resp_v_i(mem_resp_v_li[1])
    ,.mem_resp_yumi_o(mem_resp_yumi_lo[1])
    );

  bp_uce
    #(.bp_params_p(bp_params_p)
     ,.assoc_p(icache_assoc_p)
     ,.sets_p(icache_sets_p)
     ,.block_width_p(icache_block_width_p))
    icache_uce
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.lce_id_i(lce_id_li[0])

    ,.cache_req_i(icache_req_lo)
    ,.cache_req_v_i(icache_req_v_lo)
    ,.cache_req_ready_o(icache_req_ready_li)
    ,.cache_req_metadata_i(icache_req_metadata_lo)
    ,.cache_req_metadata_v_i(icache_req_metadata_v_lo)

    ,.tag_mem_pkt_o(icache_tag_mem_pkt_li)
    ,.tag_mem_pkt_v_o(icache_tag_mem_pkt_v_li)
    ,.tag_mem_pkt_ready_i(icache_tag_mem_pkt_ready_lo)
    ,.tag_mem_i(icache_tag_mem_lo)

    ,.data_mem_pkt_o(icache_data_mem_pkt_li)
    ,.data_mem_pkt_v_o(icache_data_mem_pkt_v_li)
    ,.data_mem_pkt_ready_i(icache_data_mem_pkt_ready_lo)
    ,.data_mem_i(icache_data_mem_lo)

    ,.stat_mem_pkt_o(icache_stat_mem_pkt_li)
    ,.stat_mem_pkt_v_o(icache_stat_mem_pkt_v_li)
    ,.stat_mem_pkt_ready_i(icache_stat_mem_pkt_ready_lo)
    ,.stat_mem_i(icache_stat_mem_lo)

    ,.cache_req_complete_o(icache_req_complete_li)

    ,.credits_full_o(credits_full_li[0])
    ,.credits_empty_o(credits_empty_li[0])

    ,.mem_cmd_o(mem_cmd_lo[0])
    ,.mem_cmd_v_o(mem_cmd_v_lo[0])
    ,.mem_cmd_ready_i(mem_cmd_ready_li[0])

    ,.mem_resp_i(mem_resp_li[0])
    ,.mem_resp_v_i(mem_resp_v_li[0])
    ,.mem_resp_yumi_o(mem_resp_yumi_lo[0])
    );

  bp_clint_slice_buffered
   #(.bp_params_p(bp_params_p))
   clint
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_cmd_i(clint_cmd_li)
     ,.mem_cmd_v_i(clint_cmd_v_li)
     ,.mem_cmd_ready_o(clint_cmd_ready_lo)

     ,.mem_resp_o(clint_resp_lo)
     ,.mem_resp_v_o(clint_resp_v_lo)
     ,.mem_resp_yumi_i(clint_resp_yumi_li)

     ,.timer_irq_o(timer_irq_li)
     ,.software_irq_o(software_irq_li)
     ,.external_irq_o(external_irq_li)
     );

  // Arbitration logic
  //   Don't necessarily need to arbitrate. On an FPGA, can use a 2r1w RAM. But, we might also be on
  //   a bus
  bp_cce_mem_msg_s [1:0] fifo_lo;
  logic [1:0] fifo_v_lo, fifo_yumi_li;
  for (genvar i = 0; i < 2; i++)
    begin : fifo
      bsg_two_fifo
       #(.width_p($bits(bp_cce_mem_msg_s)))
       mem_fifo
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.data_i(proc_cmd_lo[i])
         ,.v_i(proc_cmd_v_lo[i])
         ,.ready_o(proc_cmd_ready_li[i])

         ,.data_o(fifo_lo[i])
         ,.v_o(fifo_v_lo[i])
         ,.yumi_i(fifo_yumi_li[i])
         );
    end

  wire arb_ready_li = clint_cmd_ready_lo & cache_cmd_ready_lo & io_cmd_ready_i;
  bsg_arb_fixed
   #(.inputs_p(2)
     ,.lo_to_hi_p(0)
     )
   mem_arbiter
    (.ready_i(arb_ready_li)
     ,.reqs_i(fifo_v_lo)
     ,.grants_o(fifo_yumi_li)
     );

  /* TODO: Extract local memory map to module */
  wire local_cmd_li = (cache_cmd_li.header.addr < 32'h8000_0000);
  wire [3:0] device_cmd_li = cache_cmd_li.header.addr[20+:4];
  wire is_io_cmd = local_cmd_li & (device_cmd_li == host_dev_gp);
  wire is_clint_cmd = local_cmd_li & (device_cmd_li == clint_dev_gp);

  assign clint_cmd_li   = fifo_v_lo[1] ? fifo_lo[1] : fifo_lo[0];
  assign clint_cmd_v_li = is_clint_cmd & |fifo_yumi_li;

  assign io_cmd_cast_o  = fifo_v_lo[1] ? fifo_lo[1] : fifo_lo[0];
  assign io_cmd_v_o     = is_io_cmd & |fifo_yumi_li;

  assign cache_cmd_li   = fifo_v_lo[1] ? fifo_lo[1] : fifo_lo[0];
  assign cache_cmd_v_li = ~is_clint_cmd & ~is_io_cmd & |fifo_yumi_li;

  assign proc_resp_li[0]   = clint_resp_v_lo & (clint_resp_lo.header.payload.lce_id == 1'b0)
                            ? clint_resp_lo
                            : io_resp_v_i & (io_resp_cast_i.header.payload.lce_id == 1'b0)
                              ? io_resp_i 
                              : cache_resp_lo;
  assign proc_resp_li[1]   = clint_resp_v_lo & (clint_resp_lo.header.payload.lce_id == 1'b1)
                            ? clint_resp_lo
                            : io_resp_v_i & (io_resp_cast_i.header.payload.lce_id == 1'b1)
                              ? io_resp_i
                              : cache_resp_lo;
  assign proc_resp_v_li[0] = (clint_resp_v_lo & (clint_resp_lo.header.payload.lce_id == 1'b0))
                            | (cache_resp_v_lo & (cache_resp_lo.header.payload.lce_id == 1'b0))
                            | (io_resp_v_i & (io_resp_cast_i.header.payload.lce_id == 1'b0));
  assign proc_resp_v_li[1] = (clint_resp_v_lo & (clint_resp_lo.header.payload.lce_id == 1'b1))
                            | (cache_resp_v_lo & (cache_resp_lo.header.payload.lce_id == 1'b1))
                            | (io_resp_v_i & (io_resp_cast_i.header.payload.lce_id == 1'b1));
  assign clint_resp_yumi_li = ((clint_resp_v_lo & (clint_resp_lo.header.payload.lce_id == 1'b0)) & proc_resp_yumi_lo[0])
                            | ((clint_resp_v_lo & (clint_resp_lo.header.payload.lce_id == 1'b1)) & proc_resp_yumi_lo[1]);
  assign io_resp_yumi_o   = ((io_resp_v_i & (io_resp_cast_i.header.payload.lce_id == 1'b0)) & proc_resp_yumi_lo[0])
                            | ((io_resp_v_i & (io_resp_cast_i.header.payload.lce_id == 1'b1)) & proc_resp_yumi_lo[1]);
  assign cache_resp_yumi_li = ((cache_resp_v_lo & (cache_resp_lo.header.payload.lce_id == 1'b0)) & proc_resp_yumi_lo[0])
                              | ((cache_resp_v_lo & (cache_resp_lo.header.payload.lce_id == 1'b1)) & proc_resp_yumi_lo[1]);

  if (l2_en_p)
    begin : l2
      logic mem_resp_ready_lo;
      bp_me_cache_slice
       #(.bp_params_p(bp_params_p))
       l2s
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.mem_cmd_i(cache_cmd_li)
         ,.mem_cmd_v_i(cache_cmd_v_li)
         ,.mem_cmd_ready_o(cache_cmd_ready_lo)

         ,.mem_resp_o(cache_resp_lo)
         ,.mem_resp_v_o(cache_resp_v_lo)
         ,.mem_resp_yumi_i(cache_resp_yumi_li)

         ,.mem_cmd_o(mem_cmd_cast_o)
         ,.mem_cmd_v_o(mem_cmd_v_o)
         ,.mem_cmd_yumi_i(mem_cmd_ready_i & mem_cmd_v_o)

         ,.mem_resp_i(mem_resp_cast_i)
         ,.mem_resp_v_i(mem_resp_v_i)
         ,.mem_resp_ready_o(mem_resp_ready_lo)
         );
      assign mem_resp_yumi_o = mem_resp_ready_lo & mem_resp_v_i;
    end
  else
    begin : no_l2
      assign mem_cmd_cast_o = cache_cmd_li;
      assign mem_cmd_v_o = cache_cmd_v_li;
      assign cache_cmd_ready_lo = mem_cmd_ready_i;

      assign cache_resp_lo = mem_resp_cast_i;
      assign cache_resp_v_lo = mem_resp_v_i;
      assign mem_resp_yumi_o = cache_resp_yumi_li;
    end

endmodule

