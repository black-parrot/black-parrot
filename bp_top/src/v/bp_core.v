/**
 *  bp_core.v
 *
 *  icache is connected to 0.
 *  dcache is connected to 1.
 */

module bp_core
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_common_cfg_link_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_fe_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
    `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

    , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
    )
   (
    input                                          clk_i
    , input                                        reset_i

    , input [cfg_bus_width_lp-1:0]                 cfg_bus_i
    , output [vaddr_width_p-1:0]                   cfg_npc_data_o
    , output [dword_width_p-1:0]                   cfg_irf_data_o
    , output [dword_width_p-1:0]                   cfg_csr_data_o
    , output [1:0]                                 cfg_priv_data_o

    // LCE-CCE interface
    , output [1:0][lce_cce_req_width_lp-1:0]       lce_req_o
    , output [1:0]                                 lce_req_v_o
    , input [1:0]                                  lce_req_ready_i

    , output [1:0][lce_cce_resp_width_lp-1:0]      lce_resp_o
    , output [1:0]                                 lce_resp_v_o
    , input [1:0]                                  lce_resp_ready_i

    // CCE-LCE interface
    , input [1:0][lce_cmd_width_lp-1:0]            lce_cmd_i
    , input [1:0]                                  lce_cmd_v_i
    , output [1:0]                                 lce_cmd_yumi_o

    , output [1:0][lce_cmd_width_lp-1:0]           lce_cmd_o
    , output [1:0]                                 lce_cmd_v_o
    , input [1:0]                                  lce_cmd_ready_i

    , input                                        timer_irq_i
    , input                                        software_irq_i
    , input                                        external_irq_i
    );

  `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
  `declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  bp_cfg_bus_s cfg_bus_cast_i;
  assign cfg_bus_cast_i = cfg_bus_i;

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

     ,.lce_req_o(lce_req_o[0])
     ,.lce_req_v_o(lce_req_v_o[0])
     ,.lce_req_ready_i(lce_req_ready_i[0])

     ,.lce_resp_o(lce_resp_o[0])
     ,.lce_resp_v_o(lce_resp_v_o[0])
     ,.lce_resp_ready_i(lce_resp_ready_i[0])

     ,.lce_cmd_i(lce_cmd_i[0])
     ,.lce_cmd_v_i(lce_cmd_v_i[0])
     ,.lce_cmd_yumi_o(lce_cmd_yumi_o[0])

     ,.lce_cmd_o(lce_cmd_o[0])
     ,.lce_cmd_v_o(lce_cmd_v_o[0])
     ,.lce_cmd_ready_i(lce_cmd_ready_i[0])
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

     ,.fe_queue_i(fe_queue_lo)
     ,.fe_queue_v_i(fe_queue_v_lo)
     ,.fe_queue_yumi_o(fe_queue_yumi_li)
     ,.fe_queue_clr_o(fe_queue_clr_li)
     ,.fe_queue_deq_o(fe_queue_deq_li)
     ,.fe_queue_roll_o(fe_queue_roll_li)

     ,.fe_cmd_o(fe_cmd_li)
     ,.fe_cmd_v_o(fe_cmd_v_li)
     ,.fe_cmd_ready_i(fe_cmd_ready_lo)
     ,.fe_cmd_fence_i(fe_cmd_fence_li)

     ,.lce_req_o(lce_req_o[1])
     ,.lce_req_v_o(lce_req_v_o[1])
     ,.lce_req_ready_i(lce_req_ready_i[1])

     ,.lce_resp_o(lce_resp_o[1])
     ,.lce_resp_v_o(lce_resp_v_o[1])
     ,.lce_resp_ready_i(lce_resp_ready_i[1])

     ,.lce_cmd_i(lce_cmd_i[1])
     ,.lce_cmd_v_i(lce_cmd_v_i[1])
     ,.lce_cmd_yumi_o(lce_cmd_yumi_o[1])

     ,.lce_cmd_o(lce_cmd_o[1])
     ,.lce_cmd_v_o(lce_cmd_v_o[1])
     ,.lce_cmd_ready_i(lce_cmd_ready_i[1])

     ,.timer_irq_i(timer_irq_i)
     ,.software_irq_i(software_irq_i)
     ,.external_irq_i(external_irq_i)
     );

endmodule

