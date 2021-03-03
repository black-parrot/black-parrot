
`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"
`include "bp_be_defines.svh"
`include "bp_me_defines.svh"
`include "bp_pce_l15_if.svh"

module bp_piton_top
 import bsg_wormhole_router_pkg::*;
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_piton_cfg // Warning: Change this at your own peril!
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, icache_fill_width_p, lce_id_width_p, lce_assoc_p, pce)
   //`declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
   `declare_bp_pce_l15_if_widths(paddr_width_p, dword_width_gp)

   , localparam cce_instr_ram_addr_width_lp = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)
   )
  (input                                               clk_i
   , input                                             reset_i
   , input [7:0]                                       config_coreid_x
   , input [7:0]                                       config_coreid_y

   , input                                             timer_irq_i
   , input                                             software_irq_i
   , input                                             external_irq_i

   // Transducer -> L1.5
   , output logic [4:0]                                transducer_l15_rqtype
   , output logic                                      transducer_l15_nc
   , output logic [2:0]                                transducer_l15_size
   , output logic                                      transducer_l15_val
   , output logic [paddr_width_p-1:0]                  transducer_l15_address
   , output logic [dword_width_gp-1:0]                 transducer_l15_data
   , output logic [1:0]                                transducer_l15_l1rplway
   , output logic                                      transducer_l15_threadid
   , output logic [3:0]                                transducer_l15_amo_op
   , output logic                                      transducer_l15_prefetch
   , output logic                                      transducer_l15_invalidate_cacheline
   , output logic                                      transducer_l15_blockstore
   , output logic                                      transducer_l15_blockinitstore
   , output logic [dword_width_gp-1:0]                 transducer_l15_data_next_entry
   , output logic [32:0]                               transducer_l15_csm_data
   , input                                             l15_transducer_ack
   
   // L1.5 -> Transducer
   , input                                             l15_transducer_val
   , input [3:0]                                       l15_transducer_returntype
   , input [dword_width_gp-1:0]                        l15_transducer_data_0
   , input [dword_width_gp-1:0]                        l15_transducer_data_1
   , input [dword_width_gp-1:0]                        l15_transducer_data_2
   , input [dword_width_gp-1:0]                        l15_transducer_data_3
   , input                                             l15_transducer_noncacheable
   , input                                             l15_transducer_atomic
   , input                                             l15_transducer_threadid 
   , input [11:0]                                      l15_transducer_inval_address_15_4
   , input                                             l15_transducer_inval_icache_inval
   , input                                             l15_transducer_inval_dcache_inval
   , input                                             l15_transducer_inval_icache_all_way
   , input                                             l15_transducer_inval_dcache_all_way
   , input [1:0]                                       l15_transducer_inval_way
   , output logic                                      transducer_l15_req_ack
   );

  `declare_bp_cfg_bus_s(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  //`declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_gp, dcache_block_width_p, dcache_fill_width_p, dcache);
  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, icache_sets_p, icache_assoc_p, dword_width_gp, icache_block_width_p, icache_fill_width_p, icache);
  `declare_bp_bedrock_mem_if(paddr_width_p, icache_fill_width_p, lce_id_width_p, lce_assoc_p, pce);
  `declare_bp_pce_l15_if(paddr_width_p, dword_width_gp);

  bp_dcache_req_s dcache_req_lo;
  bp_icache_req_s icache_req_lo;
  logic dcache_req_v_lo, dcache_req_yumi_li, dcache_req_busy_li, dcache_req_credits_full_li, dcache_req_credits_empty_li;
  logic icache_req_v_lo, icache_req_yumi_li, icache_req_busy_li, icache_req_credits_full_li, icache_req_credits_empty_li;

  bp_dcache_req_metadata_s dcache_req_metadata_lo;
  bp_icache_req_metadata_s icache_req_metadata_lo;
  logic dcache_req_metadata_v_lo, icache_req_metadata_v_lo;

  bp_dcache_tag_mem_pkt_s dcache_tag_mem_pkt_li;
  bp_icache_tag_mem_pkt_s icache_tag_mem_pkt_li;
  logic dcache_tag_mem_pkt_v_li, dcache_tag_mem_pkt_yumi_lo;
  logic icache_tag_mem_pkt_v_li, icache_tag_mem_pkt_yumi_lo;
  logic [ptag_width_p-1:0] dcache_tag_mem_lo, icache_tag_mem_lo;

  bp_dcache_data_mem_pkt_s dcache_data_mem_pkt_li;
  bp_icache_data_mem_pkt_s icache_data_mem_pkt_li;
  logic dcache_data_mem_pkt_v_li, dcache_data_mem_pkt_yumi_lo;
  logic icache_data_mem_pkt_v_li, icache_data_mem_pkt_yumi_lo;
  logic [dcache_block_width_p-1:0] dcache_data_mem_lo;
  logic [icache_block_width_p-1:0] icache_data_mem_lo;

  bp_dcache_stat_mem_pkt_s dcache_stat_mem_pkt_li;
  bp_icache_stat_mem_pkt_s icache_stat_mem_pkt_li;
  logic dcache_stat_mem_pkt_v_li, dcache_stat_mem_pkt_yumi_lo;
  logic icache_stat_mem_pkt_v_li, icache_stat_mem_pkt_yumi_lo;
  bp_dcache_stat_info_s dcache_stat_mem_lo;
  bp_icache_stat_info_s icache_stat_mem_lo;

  logic dcache_req_complete_li, icache_req_complete_li;
  logic dcache_req_critical_li, icache_req_critical_li;

  bp_pce_l15_req_s [1:0] pce_l15_req_lo;
  logic [1:0] pce_l15_req_v_lo, pce_l15_req_ready_li;
  bp_l15_pce_ret_s [1:0] l15_pce_ret_li;
  logic [1:0] l15_pce_ret_v_li, l15_pce_ret_yumi_lo;

  bp_bedrock_pce_mem_msg_s cfg_cmd_li;
  //bp_cce_mem_msg_s cfg_cmd_li;
  logic cfg_cmd_v_li, cfg_cmd_ready_lo;
  bp_bedrock_pce_mem_msg_s cfg_resp_lo;
  //bp_cce_mem_msg_s cfg_resp_lo;
  logic cfg_resp_v_lo, cfg_resp_yumi_li;

  bp_cfg_bus_s cfg_bus_lo;
  logic [dword_width_gp-1:0] cfg_irf_data_li;
  logic [vaddr_width_p-1:0]  cfg_npc_data_li;
  logic [dword_width_gp-1:0] cfg_csr_data_li;
  logic [1:0]                cfg_priv_data_li;

  bp_fe_queue_s fe_queue_li;
  logic fe_queue_v_li, fe_queue_ready_lo;

  bp_fe_cmd_s fe_cmd_lo;
  logic fe_cmd_v_lo, fe_cmd_yumi_li;

  bp_fe_top
   #(.bp_params_p(bp_params_p))
   fe
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_lo)

     ,.fe_queue_o(fe_queue_li)
     ,.fe_queue_v_o(fe_queue_v_li)
     ,.fe_queue_ready_i(fe_queue_ready_lo)

     ,.fe_cmd_i(fe_cmd_lo)
     ,.fe_cmd_v_i(fe_cmd_v_lo)
     ,.fe_cmd_yumi_o(fe_cmd_yumi_li)

     ,.cache_req_o(icache_req_lo)
     ,.cache_req_v_o(icache_req_v_lo)
     ,.cache_req_yumi_i(icache_req_yumi_li)
     ,.cache_req_busy_i(icache_req_busy_li)
     ,.cache_req_metadata_o(icache_req_metadata_lo)
     ,.cache_req_metadata_v_o(icache_req_metadata_v_lo)
     ,.cache_req_complete_i(icache_req_complete_li)
     ,.cache_req_critical_i(icache_req_critical_li)
     ,.cache_req_credits_full_i(icache_req_credits_full_li)
     ,.cache_req_credits_empty_i(icache_req_credits_empty_li)

     ,.data_mem_pkt_i(icache_data_mem_pkt_li)
     ,.data_mem_pkt_v_i(icache_data_mem_pkt_v_li)
     ,.data_mem_pkt_yumi_o(icache_data_mem_pkt_yumi_lo)
     ,.data_mem_o(icache_data_mem_lo)

     ,.tag_mem_pkt_i(icache_tag_mem_pkt_li)
     ,.tag_mem_pkt_v_i(icache_tag_mem_pkt_v_li)
     ,.tag_mem_pkt_yumi_o(icache_tag_mem_pkt_yumi_lo)
     ,.tag_mem_o(icache_tag_mem_lo)

     ,.stat_mem_pkt_v_i(icache_stat_mem_pkt_v_li)
     ,.stat_mem_pkt_i(icache_stat_mem_pkt_li)
     ,.stat_mem_pkt_yumi_o(icache_stat_mem_pkt_yumi_lo)
     ,.stat_mem_o(icache_stat_mem_lo)
     );

  bp_be_top
   #(.bp_params_p(bp_params_p))
   be
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_lo)

     ,.fe_queue_i(fe_queue_li)
     ,.fe_queue_v_i(fe_queue_v_li)
     ,.fe_queue_ready_o(fe_queue_ready_lo)

     ,.fe_cmd_o(fe_cmd_lo)
     ,.fe_cmd_v_o(fe_cmd_v_lo)
     ,.fe_cmd_yumi_i(fe_cmd_yumi_li)

     ,.cache_req_o(dcache_req_lo)
     ,.cache_req_v_o(dcache_req_v_lo)
     ,.cache_req_yumi_i(dcache_req_yumi_li)
     ,.cache_req_busy_i(dcache_req_busy_li)
     ,.cache_req_metadata_o(dcache_req_metadata_lo)
     ,.cache_req_metadata_v_o(dcache_req_metadata_v_lo)

     ,.cache_req_complete_i(dcache_req_complete_li)
     ,.cache_req_critical_i(dcache_req_critical_li)
     ,.cache_req_credits_full_i(dcache_req_credits_full_li)
     ,.cache_req_credits_empty_i(dcache_req_credits_empty_li)

     ,.data_mem_pkt_i(dcache_data_mem_pkt_li)
     ,.data_mem_pkt_v_i(dcache_data_mem_pkt_v_li)
     ,.data_mem_pkt_yumi_o(dcache_data_mem_pkt_yumi_lo)
     ,.data_mem_o(dcache_data_mem_lo)

     ,.tag_mem_pkt_i(dcache_tag_mem_pkt_li)
     ,.tag_mem_pkt_v_i(dcache_tag_mem_pkt_v_li)
     ,.tag_mem_pkt_yumi_o(dcache_tag_mem_pkt_yumi_lo)
     ,.tag_mem_o(dcache_tag_mem_lo)

     ,.stat_mem_pkt_i(dcache_stat_mem_pkt_li)
     ,.stat_mem_pkt_v_i(dcache_stat_mem_pkt_v_li)
     ,.stat_mem_pkt_yumi_o(dcache_stat_mem_pkt_yumi_lo)
     ,.stat_mem_o(dcache_stat_mem_lo)

     ,.timer_irq_i(timer_irq_i)
     ,.software_irq_i(software_irq_i)
     ,.external_irq_i(external_irq_i)
     );

  bp_pce
    #(.bp_params_p(bp_params_p)
     ,.assoc_p(dcache_assoc_p)
     ,.sets_p(dcache_sets_p)
     ,.block_width_p(dcache_block_width_p)
     ,.fill_width_p(dcache_fill_width_p)
     ,.pce_id_p(1)
     )
    dcache_pce
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.core_idx(config_coreid_x)
    ,.core_idy(config_coreid_y)

    ,.cache_req_i(dcache_req_lo)
    ,.cache_req_v_i(dcache_req_v_lo)
    ,.cache_req_yumi_o(dcache_req_yumi_li)
    ,.cache_req_busy_o(dcache_req_busy_li)
    ,.cache_req_metadata_i(dcache_req_metadata_lo)
    ,.cache_req_metadata_v_i(dcache_req_metadata_v_lo)
    ,.cache_req_complete_o(dcache_req_complete_li)
    ,.cache_req_critical_o(dcache_req_critical_li)
    ,.cache_req_credits_full_o(dcache_req_credits_full_li)
    ,.cache_req_credits_empty_o(dcache_req_credits_empty_li)

    ,.cache_tag_mem_pkt_o(dcache_tag_mem_pkt_li)
    ,.cache_tag_mem_pkt_v_o(dcache_tag_mem_pkt_v_li)
    ,.cache_tag_mem_pkt_yumi_i(dcache_tag_mem_pkt_yumi_lo)

    ,.cache_data_mem_pkt_o(dcache_data_mem_pkt_li)
    ,.cache_data_mem_pkt_v_o(dcache_data_mem_pkt_v_li)
    ,.cache_data_mem_pkt_yumi_i(dcache_data_mem_pkt_yumi_lo)

    ,.cache_stat_mem_pkt_o(dcache_stat_mem_pkt_li)
    ,.cache_stat_mem_pkt_v_o(dcache_stat_mem_pkt_v_li)
    ,.cache_stat_mem_pkt_yumi_i(dcache_stat_mem_pkt_yumi_lo)

    ,.pce_l15_req_v_o(pce_l15_req_v_lo[1])
    ,.pce_l15_req_o(pce_l15_req_lo[1])
    ,.pce_l15_req_ready_i(pce_l15_req_ready_li[1])

    ,.l15_pce_ret_v_i(l15_pce_ret_v_li[1])
    ,.l15_pce_ret_i(l15_pce_ret_li[1])
    ,.l15_pce_ret_yumi_o(l15_pce_ret_yumi_lo[1])
    );

  bp_pce
    #(.bp_params_p(bp_params_p)
     ,.assoc_p(icache_assoc_p)
     ,.sets_p(icache_sets_p)
     ,.block_width_p(icache_block_width_p)
     ,.fill_width_p(icache_fill_width_p)
     ,.pce_id_p(0)
     )
    icache_pce
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.core_idx(config_coreid_x)
    ,.core_idy(config_coreid_y)

    ,.cache_req_i(icache_req_lo)
    ,.cache_req_v_i(icache_req_v_lo)
    ,.cache_req_yumi_o(icache_req_yumi_li)
    ,.cache_req_busy_o(icache_req_busy_li)
    ,.cache_req_metadata_i(icache_req_metadata_lo)
    ,.cache_req_metadata_v_i(icache_req_metadata_v_lo)
    ,.cache_req_complete_o(icache_req_complete_li)
    ,.cache_req_critical_o(icache_req_critical_li)
    ,.cache_req_credits_full_o(icache_req_credits_full_li)
    ,.cache_req_credits_empty_o(icache_req_credits_empty_li)

    ,.cache_tag_mem_pkt_o(icache_tag_mem_pkt_li)
    ,.cache_tag_mem_pkt_v_o(icache_tag_mem_pkt_v_li)
    ,.cache_tag_mem_pkt_yumi_i(icache_tag_mem_pkt_yumi_lo)

    ,.cache_data_mem_pkt_o(icache_data_mem_pkt_li)
    ,.cache_data_mem_pkt_v_o(icache_data_mem_pkt_v_li)
    ,.cache_data_mem_pkt_yumi_i(icache_data_mem_pkt_yumi_lo)

    ,.cache_stat_mem_pkt_o(icache_stat_mem_pkt_li)
    ,.cache_stat_mem_pkt_v_o(icache_stat_mem_pkt_v_li)
    ,.cache_stat_mem_pkt_yumi_i(icache_stat_mem_pkt_yumi_lo)

    ,.pce_l15_req_v_o(pce_l15_req_v_lo[0])
    ,.pce_l15_req_o(pce_l15_req_lo[0])
    ,.pce_l15_req_ready_i(pce_l15_req_ready_li[0])

    ,.l15_pce_ret_v_i(l15_pce_ret_v_li[0])
    ,.l15_pce_ret_i(l15_pce_ret_li[0])
    ,.l15_pce_ret_yumi_o(l15_pce_ret_yumi_lo[0])
    );

  logic cfg_resp_ready_li;
  assign cfg_resp_yumi_li = cfg_resp_v_lo & cfg_resp_ready_li;
  bp_cce_mmio_cfg_loader
    #(.bp_params_p(bp_params_p)
     ,.inst_width_p($bits(bp_cce_inst_s))
     ,.inst_ram_addr_width_p(cce_instr_ram_addr_width_lp)
     ,.inst_ram_els_p(num_cce_instr_ram_els_p)
     ,.skip_ram_init_p(0)
     ,.clear_freeze_p(1)
     // Enabling all domains for parrotpiton
     ,.domain_mask_p(64'hff)
     )
     cfg_loader
     (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.lce_id_i('0)

     ,.io_cmd_o(cfg_cmd_li)
     ,.io_cmd_v_o(cfg_cmd_v_li)
     ,.io_cmd_yumi_i(cfg_cmd_v_li & cfg_cmd_ready_lo)

     ,.io_resp_i(cfg_resp_lo)
     ,.io_resp_v_i(cfg_resp_v_lo)
     ,.io_resp_ready_o(cfg_resp_ready_li)

     ,.done_o()
     );

  bp_cfg
   #(.bp_params_p(bp_params_p))
   cfg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_cmd_i(cfg_cmd_li)
     ,.mem_cmd_v_i(cfg_cmd_v_li)
     ,.mem_cmd_ready_o(cfg_cmd_ready_lo)

     ,.mem_resp_o(cfg_resp_lo)
     ,.mem_resp_v_o(cfg_resp_v_lo)
     ,.mem_resp_yumi_i(cfg_resp_yumi_li)

     ,.cfg_bus_o(cfg_bus_lo)
     ,.did_i('0)
     ,.host_did_i('0)
     ,.cord_i({coh_noc_y_cord_width_p'(config_coreid_y), coh_noc_x_cord_width_p'(config_coreid_x)})
     ,.cce_ucode_data_i('0)
     );

  // PCE -> L1.5 - Arbitration logic
  bp_pce_l15_req_s [1:0] fifo_lo;
  logic [1:0] fifo_v_lo, fifo_yumi_li;
  
  for (genvar i = 0; i < 2; i++)
    begin : fifo
      bsg_fifo_1r1w_small
       #(.width_p($bits(bp_pce_l15_req_s))
         ,.els_p(2)
         )
       mem_fifo
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.data_i(pce_l15_req_lo[i])
         ,.v_i(pce_l15_req_v_lo[i])
         ,.ready_o(pce_l15_req_ready_li[i])

         ,.data_o(fifo_lo[i])
         ,.v_o(fifo_v_lo[i])
         ,.yumi_i(fifo_yumi_li[i])
         );
    end

  logic [1:0] fifo_grants_lo;
  bsg_arb_fixed
   #(.inputs_p(2), .lo_to_hi_p(0))
   cmd_arbiter
    (.ready_i(1'b1)
     ,.reqs_i(fifo_v_lo)
     ,.grants_o(fifo_grants_lo)
     );

  bp_pce_l15_req_s fifo_selected_lo;
  bsg_mux_one_hot
   #(.width_p($bits(bp_pce_l15_req_s)), .els_p(2))
   cmd_select
    (.data_i(fifo_lo)
     ,.sel_one_hot_i(fifo_grants_lo)
     ,.data_o(fifo_selected_lo)
     );

  // PCE -> L1.5 signals
  assign transducer_l15_rqtype = fifo_selected_lo.rqtype;
  assign transducer_l15_nc = fifo_selected_lo.nc;
  assign transducer_l15_size = fifo_selected_lo.size;
  assign transducer_l15_address = fifo_selected_lo.address;
  assign transducer_l15_data = fifo_selected_lo.data;
  assign transducer_l15_l1rplway = fifo_selected_lo.l1rplway;
  assign transducer_l15_val = |fifo_grants_lo;
  assign transducer_l15_amo_op = fifo_selected_lo.amo_op;
  assign fifo_yumi_li[0] = fifo_grants_lo[0] & l15_transducer_ack;
  assign fifo_yumi_li[1] = fifo_grants_lo[1] & l15_transducer_ack;

  // Unused signals
  assign transducer_l15_threadid = '0;
  assign transducer_l15_prefetch = '0;
  assign transducer_l15_invalidate_cacheline = '0;
  assign transducer_l15_blockstore = '0;
  assign transducer_l15_blockinitstore = '0;
  assign transducer_l15_data_next_entry = '0;
  assign transducer_l15_csm_data = '0;

  // L1.5 -> PCE
  logic l15_fifo_v_li, l15_fifo_ready_lo;
  logic fifo_pce_v_lo, fifo_pce_yumi_li;
  bp_l15_pce_ret_s l15_fifo_li, fifo_pce_lo;

  bsg_fifo_1r1w_small
  #(.width_p($bits(bp_l15_pce_ret_s))
    ,.els_p(16)
    )
  resp_fifo
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.data_i(l15_fifo_li)
    ,.v_i(l15_fifo_v_li)
    ,.ready_o(l15_fifo_ready_lo)

    ,.data_o(fifo_pce_lo)
    ,.v_o(fifo_pce_v_lo)
    ,.yumi_i(fifo_pce_yumi_li)
    );

  assign l15_fifo_li.rtntype = bp_l15_pce_ret_type_e'(l15_transducer_returntype);
  assign l15_fifo_li.noncacheable = l15_transducer_noncacheable;
  assign l15_fifo_li.data_0 = l15_transducer_data_0;
  assign l15_fifo_li.data_1 = l15_transducer_data_1;
  assign l15_fifo_li.data_2 = l15_transducer_data_2;
  assign l15_fifo_li.data_3 = l15_transducer_data_3;
  assign l15_fifo_li.threadid = l15_transducer_threadid;
  assign l15_fifo_li.atomic = l15_transducer_atomic;
  assign l15_fifo_li.inval_address_15_4 = l15_transducer_inval_address_15_4;
  assign l15_fifo_li.inval_icache_inval = l15_transducer_inval_icache_inval;
  assign l15_fifo_li.inval_dcache_inval = l15_transducer_inval_dcache_inval;
  assign l15_fifo_li.inval_icache_all_way = l15_transducer_inval_icache_all_way;
  assign l15_fifo_li.inval_dcache_all_way = l15_transducer_inval_dcache_all_way;
  assign l15_fifo_li.inval_way = l15_transducer_inval_way;
  assign l15_fifo_v_li = l15_transducer_val;
  assign transducer_l15_req_ack = l15_fifo_ready_lo & l15_transducer_val;

  for (genvar i = 0; i < 2; i++) 
    begin : l15_pce_ret
      assign l15_pce_ret_li[i].rtntype = fifo_pce_lo.rtntype;
      assign l15_pce_ret_li[i].noncacheable = fifo_pce_lo.noncacheable;
      assign l15_pce_ret_li[i].data_0 = fifo_pce_lo.data_0;
      assign l15_pce_ret_li[i].data_1 = fifo_pce_lo.data_1;
      assign l15_pce_ret_li[i].data_2 = fifo_pce_lo.data_2;
      assign l15_pce_ret_li[i].data_3 = fifo_pce_lo.data_3;
      assign l15_pce_ret_li[i].threadid = fifo_pce_lo.threadid;
      assign l15_pce_ret_li[i].atomic = fifo_pce_lo.atomic;
      assign l15_pce_ret_li[i].inval_address_15_4 = fifo_pce_lo.inval_address_15_4;
      assign l15_pce_ret_li[i].inval_icache_inval = fifo_pce_lo.inval_icache_inval;
      assign l15_pce_ret_li[i].inval_dcache_inval = fifo_pce_lo.inval_dcache_inval;
      assign l15_pce_ret_li[i].inval_icache_all_way = fifo_pce_lo.inval_icache_all_way;
      assign l15_pce_ret_li[i].inval_dcache_all_way = fifo_pce_lo.inval_dcache_all_way;
      assign l15_pce_ret_li[i].inval_way = fifo_pce_lo.inval_way;
    end

  assign fifo_pce_yumi_li = l15_pce_ret_yumi_lo[0] | l15_pce_ret_yumi_lo[1];

  always_comb begin
    l15_pce_ret_v_li[0] = '0;
    l15_pce_ret_v_li[1] = '0;

    if (!((fifo_pce_lo.rtntype == e_load_ret) || (fifo_pce_lo.rtntype == e_st_ack) || (fifo_pce_lo.rtntype == e_atomic_ret))) begin
      l15_pce_ret_v_li[0] = fifo_pce_v_lo;
    end

    if (fifo_pce_lo.rtntype != e_ifill_ret) begin
      l15_pce_ret_v_li[1] = fifo_pce_v_lo;
    end
  end

endmodule

