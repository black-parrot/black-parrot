/**
 *  bp_core.v
 *
 *  icache is connected to 0.
 *  dcache is connected to 1.
 */

module bp_core_minimal
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_be_dcache_pkg::*;
 import bp_fe_pkg::*;
 import bp_fe_icache_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_common_cfg_link_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_single_core_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_fe_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
    `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
    `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_p, dcache_block_width_p, dcache)
    `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, icache_sets_p, icache_assoc_p, dword_width_p, icache_block_width_p, icache)

    , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)

    , localparam dcache_stat_info_width_lp = `bp_cache_stat_info_width(dcache_assoc_p)
    , localparam icache_stat_info_width_lp = `bp_cache_stat_info_width(icache_assoc_p)
    )
   (
    input          clk_i
    , input        reset_i

    // Config info
    , input [cfg_bus_width_lp-1:0] cfg_bus_i
    , output [vaddr_width_p-1:0] cfg_npc_data_o
    , output [dword_width_p-1:0] cfg_irf_data_o
    , output [dword_width_p-1:0] cfg_csr_data_o
    , output [1:0] cfg_priv_data_o

    // BP request side - Interface to LCE
    , input credits_full_i
    , input credits_empty_i

    , output logic [dcache_req_width_lp-1:0] dcache_req_o
    , output logic dcache_req_v_o
    , input  dcache_req_ready_i
    , output logic [dcache_req_metadata_width_lp-1:0] dcache_req_metadata_o
    , output logic  dcache_req_metadata_v_o

    , input dcache_req_complete_i

    , output logic [icache_req_width_lp-1:0] icache_req_o
    , output logic icache_req_v_o
    , input  icache_req_ready_i
    , output logic [icache_req_metadata_width_lp-1:0] icache_req_metadata_o
    , output logic  icache_req_metadata_v_o

    , input icache_req_complete_i

    // D$ response interface
    , input [dcache_data_mem_pkt_width_lp-1:0] dcache_data_mem_pkt_i
    , input dcache_data_mem_pkt_v_i
    , output logic dcache_data_mem_pkt_ready_o
    , output logic [dcache_block_width_p-1:0] dcache_data_mem_o 

    , input [dcache_tag_mem_pkt_width_lp-1:0] dcache_tag_mem_pkt_i
    , input dcache_tag_mem_pkt_v_i
    , output logic dcache_tag_mem_pkt_ready_o
    , output logic [ptag_width_p-1:0] dcache_tag_mem_o

    , input [dcache_stat_mem_pkt_width_lp-1:0] dcache_stat_mem_pkt_i
    , input dcache_stat_mem_pkt_v_i
    , output logic dcache_stat_mem_pkt_ready_o
    , output logic [dcache_stat_info_width_lp-1:0] dcache_stat_mem_o

    // I$ response interface
    , input [icache_data_mem_pkt_width_lp-1:0] icache_data_mem_pkt_i
    , input icache_data_mem_pkt_v_i
    , output logic icache_data_mem_pkt_ready_o
    , output logic [icache_block_width_p-1:0] icache_data_mem_o 

    , input [icache_tag_mem_pkt_width_lp-1:0] icache_tag_mem_pkt_i
    , input icache_tag_mem_pkt_v_i
    , output logic icache_tag_mem_pkt_ready_o
    , output logic [ptag_width_p-1:0] icache_tag_mem_o

    , input [icache_stat_mem_pkt_width_lp-1:0] icache_stat_mem_pkt_i
    , input icache_stat_mem_pkt_v_i
    , output logic icache_stat_mem_pkt_ready_o
    , output logic [icache_stat_info_width_lp-1:0] icache_stat_mem_o

    , input                                        timer_irq_i
    , input                                        software_irq_i
    , input                                        external_irq_i

    );

  // TODO: fix interfaces for fe/be
  `declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  bp_fe_queue_s fe_queue_li, fe_queue_lo;
  logic fe_queue_v_li, fe_queue_ready_lo;
  logic fe_queue_v_lo, fe_queue_yumi_li;

  bp_fe_cmd_s fe_cmd_li, fe_cmd_lo;
  logic fe_cmd_v_li, fe_cmd_ready_lo;
  logic fe_cmd_v_lo, fe_cmd_yumi_li;

  bp_fe_top
   #(.bp_params_p(bp_params_p))
   fe
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_i)

     ,.fe_queue_o(fe_queue_li)
     ,.fe_queue_v_o(fe_queue_v_li)
     ,.fe_queue_ready_i(fe_queue_ready_lo)

     ,.fe_cmd_i(fe_cmd_lo)
     ,.fe_cmd_v_i(fe_cmd_v_lo)
     ,.fe_cmd_yumi_o(fe_cmd_yumi_li)

     ,.cache_req_o(icache_req_o)
     ,.cache_req_v_o(icache_req_v_o)
     ,.cache_req_ready_i(icache_req_ready_i)
     ,.cache_req_metadata_o(icache_req_metadata_o)
     ,.cache_req_metadata_v_o(icache_req_metadata_v_o)
     ,.cache_req_complete_i(icache_req_complete_i)

     ,.data_mem_pkt_i(icache_data_mem_pkt_i)
     ,.data_mem_pkt_v_i(icache_data_mem_pkt_v_i)
     ,.data_mem_pkt_ready_o(icache_data_mem_pkt_ready_o)
     ,.data_mem_o(icache_data_mem_o)

     ,.tag_mem_pkt_i(icache_tag_mem_pkt_i)
     ,.tag_mem_pkt_v_i(icache_tag_mem_pkt_v_i)
     ,.tag_mem_pkt_ready_o(icache_tag_mem_pkt_ready_o)
     ,.tag_mem_o(icache_tag_mem_o)

     ,.stat_mem_pkt_v_i(icache_stat_mem_pkt_v_i)
     ,.stat_mem_pkt_i(icache_stat_mem_pkt_i)
     ,.stat_mem_pkt_ready_o(icache_stat_mem_pkt_ready_o)
     ,.stat_mem_o(icache_stat_mem_o)
     );

  bsg_fifo_1r1w_small
   #(.width_p(fe_cmd_width_lp)
     ,.els_p(fe_cmd_fifo_els_p)
     ,.ready_THEN_valid_p(1)
     )
   fe_cmd_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(fe_cmd_li)
     ,.v_i(fe_cmd_v_li)
     ,.ready_o(fe_cmd_ready_lo)

     ,.data_o(fe_cmd_lo)
     ,.v_o(fe_cmd_v_lo)
     ,.yumi_i(fe_cmd_yumi_li)
     );
 
  wire fe_cmd_empty_lo = ~fe_cmd_v_lo;
  wire fe_cmd_full_lo  = ~fe_cmd_ready_lo;
  wire fe_cmd_fence_li = fe_cmd_v_lo;

  logic fe_queue_clr_li, fe_queue_deq_li, fe_queue_roll_li;
  bsg_fifo_1r1w_rolly
   #(.width_p(fe_queue_width_lp)
     ,.els_p(fe_queue_fifo_els_p)
     ,.ready_THEN_valid_p(1)
     )
   fe_queue_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clr_v_i(fe_queue_clr_li)
     ,.deq_v_i(fe_queue_deq_li)
     ,.roll_v_i(fe_queue_roll_li)

     ,.data_i(fe_queue_li)
     ,.v_i(fe_queue_v_li)
     ,.ready_o(fe_queue_ready_lo)

     ,.data_o(fe_queue_lo)
     ,.v_o(fe_queue_v_lo)
     ,.yumi_i(fe_queue_yumi_li)
     );

  bp_be_top
   #(.bp_params_p(bp_params_p))
   be
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_i)
     ,.cfg_npc_data_o(cfg_npc_data_o)
     ,.cfg_irf_data_o(cfg_irf_data_o)
     ,.cfg_csr_data_o(cfg_csr_data_o)
     ,.cfg_priv_data_o(cfg_priv_data_o)

     ,.fe_queue_clr_o(fe_queue_clr_li)
     ,.fe_queue_deq_o(fe_queue_deq_li)
     ,.fe_queue_roll_o(fe_queue_roll_li)

     ,.fe_queue_i(fe_queue_lo)
     ,.fe_queue_v_i(fe_queue_v_lo)
     ,.fe_queue_yumi_o(fe_queue_yumi_li)

     ,.fe_cmd_o(fe_cmd_li)
     ,.fe_cmd_v_o(fe_cmd_v_li)
     ,.fe_cmd_ready_i(fe_cmd_ready_lo)
     ,.fe_cmd_fence_i(fe_cmd_fence_li)

      ,.cache_req_o(dcache_req_o)
     ,.cache_req_v_o(dcache_req_v_o)
     ,.cache_req_ready_i(dcache_req_ready_i)
     ,.cache_req_metadata_o(dcache_req_metadata_o)
     ,.cache_req_metadata_v_o(dcache_req_metadata_v_o)

     ,.cache_req_complete_i(dcache_req_complete_i)

     ,.data_mem_pkt_i(dcache_data_mem_pkt_i)
     ,.data_mem_pkt_v_i(dcache_data_mem_pkt_v_i)
     ,.data_mem_pkt_ready_o(dcache_data_mem_pkt_ready_o)
     ,.data_mem_o(dcache_data_mem_o)

     ,.tag_mem_pkt_i(dcache_tag_mem_pkt_i)
     ,.tag_mem_pkt_v_i(dcache_tag_mem_pkt_v_i)
     ,.tag_mem_pkt_ready_o(dcache_tag_mem_pkt_ready_o)
     ,.tag_mem_o(dcache_tag_mem_o)

     ,.stat_mem_pkt_v_i(dcache_stat_mem_pkt_v_i)
     ,.stat_mem_pkt_i(dcache_stat_mem_pkt_i)
     ,.stat_mem_pkt_ready_o(dcache_stat_mem_pkt_ready_o)
     ,.stat_mem_o(dcache_stat_mem_o)

     ,.credits_full_i(credits_full_i)
     ,.credits_empty_i(credits_empty_i)

     ,.timer_irq_i(timer_irq_i)
     ,.software_irq_i(software_irq_i)
     ,.external_irq_i(external_irq_i)
     );

endmodule

