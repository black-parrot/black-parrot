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
 import bp_cfg_link_pkg::*;
  #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
    `declare_bp_proc_params(cfg_p)
    `declare_bp_fe_be_if_widths(vaddr_width_p
                                ,paddr_width_p
                                ,asid_width_p
                                ,branch_metadata_fwd_width_p
                                )
    `declare_bp_lce_cce_if_widths(num_cce_p
                                  ,num_lce_p
                                  ,paddr_width_p
                                  ,lce_assoc_p
                                  ,dword_width_p
                                  ,cce_block_width_p
                                  )

    // Should go away with manycore bridge 
    , localparam proc_cfg_width_lp = `bp_proc_cfg_width(num_core_p, num_cce_p, num_lce_p)
    )
   (
    input                                          clk_i
    , input                                        reset_i
    , input                                        freeze_i

    , input [proc_cfg_width_lp-1:0]                proc_cfg_i

    // Config channel
    , input                                        cfg_w_v_i
    , input [cfg_addr_width_p-1:0]                 cfg_addr_i
    , input [cfg_data_width_p-1:0]                 cfg_data_i

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
    , output [1:0]                                 lce_cmd_ready_o

    , output [1:0][lce_cmd_width_lp-1:0]           lce_cmd_o
    , output [1:0]                                 lce_cmd_v_o
    , input [1:0]                                  lce_cmd_ready_i

    , input                                        timer_int_i
    , input                                        software_int_i
    , input                                        external_int_i
    );

  `declare_bp_common_proc_cfg_s(num_core_p, num_cce_p, num_lce_p)
  `declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  bp_proc_cfg_s proc_cfg_cast_i;
  assign proc_cfg_cast_i = proc_cfg_i;

  bp_fe_queue_s fe_queue_li, fe_queue_lo;
  logic fe_queue_v_li, fe_queue_ready_lo;
  logic fe_queue_v_lo, fe_queue_yumi_li;

  bp_fe_cmd_s fe_cmd_li, fe_cmd_lo;
  logic fe_cmd_v_li, fe_cmd_ready_lo;
  logic fe_cmd_v_lo, fe_cmd_yumi_li;

  logic fe_cmd_processed_li;

  bp_fe_top
   #(.cfg_p(cfg_p))
   fe 
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.freeze_i(freeze_i)

     ,.lce_id_i(proc_cfg_cast_i.icache_id)

     ,.cfg_w_v_i(cfg_w_v_i)
     ,.cfg_addr_i(cfg_addr_i)
     ,.cfg_data_i(cfg_data_i)

     ,.fe_queue_o(fe_queue_li)
     ,.fe_queue_v_o(fe_queue_v_li)
     ,.fe_queue_ready_i(fe_queue_ready_lo)

     ,.fe_cmd_i(fe_cmd_lo)
     ,.fe_cmd_v_i(fe_cmd_v_lo)
     ,.fe_cmd_yumi_o(fe_cmd_yumi_li)
     ,.fe_cmd_processed_o(fe_cmd_processed_li)

     ,.lce_req_o(lce_req_o[0])
     ,.lce_req_v_o(lce_req_v_o[0])
     ,.lce_req_ready_i(lce_req_ready_i[0])

     ,.lce_resp_o(lce_resp_o[0])
     ,.lce_resp_v_o(lce_resp_v_o[0])
     ,.lce_resp_ready_i(lce_resp_ready_i[0])

     ,.lce_cmd_i(lce_cmd_i[0])
     ,.lce_cmd_v_i(lce_cmd_v_i[0])
     ,.lce_cmd_ready_o(lce_cmd_ready_o[0])

     ,.lce_cmd_o(lce_cmd_o[0])
     ,.lce_cmd_v_o(lce_cmd_v_o[0])
     ,.lce_cmd_ready_i(lce_cmd_ready_i[0])
     );

  logic fe_fence_r;
  wire fe_cmd_nonattaboy_v_li = fe_cmd_v_li & (fe_cmd_li.opcode != e_op_attaboy);
  bsg_fifo_1r1w_fence
   #(.width_p(fe_cmd_width_lp)
     ,.els_p(fe_cmd_fifo_els_p)
     ,.ready_THEN_valid_p(1)
     )
   fe_cmd_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.fence_set_i(fe_cmd_nonattaboy_v_li)
     ,.fence_clr_i(fe_cmd_processed_li)
     ,.fence_o(fe_fence_r)
      
     ,.data_i(fe_cmd_li)
     ,.v_i(fe_cmd_v_li)
     ,.ready_o(fe_cmd_ready_lo)
                  
     ,.data_o(fe_cmd_lo)
     ,.v_o(fe_cmd_v_lo)
     ,.yumi_i(fe_cmd_yumi_li)
     );

  logic fe_queue_deq_li, fe_queue_roll_li;
  wire fe_queue_clr_li = fe_fence_r & fe_cmd_processed_li;
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
   #(.cfg_p(cfg_p))
   be
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.freeze_i(freeze_i)
     
     ,.proc_cfg_i(proc_cfg_i)

     ,.cfg_w_v_i(cfg_w_v_i)
     ,.cfg_addr_i(cfg_addr_i)
     ,.cfg_data_i(cfg_data_i)

     ,.fe_queue_deq_o(fe_queue_deq_li)
     ,.fe_queue_roll_o(fe_queue_roll_li)

     ,.fe_queue_i(fe_queue_lo)
     ,.fe_queue_v_i(~fe_fence_r & fe_queue_v_lo)
     ,.fe_queue_yumi_o(fe_queue_yumi_li)

     ,.fe_cmd_o(fe_cmd_li)
     ,.fe_cmd_v_o(fe_cmd_v_li)
     ,.fe_cmd_ready_i(~fe_fence_r & fe_cmd_ready_lo)

     ,.lce_req_o(lce_req_o[1])
     ,.lce_req_v_o(lce_req_v_o[1])
     ,.lce_req_ready_i(lce_req_ready_i[1])

     ,.lce_resp_o(lce_resp_o[1])
     ,.lce_resp_v_o(lce_resp_v_o[1])
     ,.lce_resp_ready_i(lce_resp_ready_i[1])

     ,.lce_cmd_i(lce_cmd_i[1])
     ,.lce_cmd_v_i(lce_cmd_v_i[1])
     ,.lce_cmd_ready_o(lce_cmd_ready_o[1])

     ,.lce_cmd_o(lce_cmd_o[1])
     ,.lce_cmd_v_o(lce_cmd_v_o[1])
     ,.lce_cmd_ready_i(lce_cmd_ready_i[1])

     ,.timer_int_i(timer_int_i)
     ,.software_int_i(software_int_i)
     ,.external_int_i(external_int_i)
     );

endmodule : bp_core

