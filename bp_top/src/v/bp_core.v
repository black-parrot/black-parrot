/**
 *  bp_core.v
 *
 *  icache is connected to 0.
 *  dcache is connected to 1.
 */

module bp_core
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
  #(parameter core_els_p                    = "inv"
    , parameter num_lce_p                   = "inv"
    , parameter num_cce_p                   = "inv" 
    , parameter lce_assoc_p                 = "inv"
    , parameter lce_sets_p                  = "inv"
    , parameter cce_block_size_in_bytes_p   = "inv"
    , parameter data_width_p = "inv"
    , parameter vaddr_width_p               = "inv"
    , parameter paddr_width_p               = "inv"
    , parameter branch_metadata_fwd_width_p = "inv"
    , parameter asid_width_p                = "inv"
    , parameter btb_indx_width_p            = "inv"
    , parameter bht_indx_width_p            = "inv"
    , parameter ras_addr_width_p            = "inv"

    , parameter fe_queue_fifo_els_p = 16
    , parameter fe_cmd_fifo_els_p = 8
    , parameter trace_p=0

    , localparam cce_block_size_in_bits_lp =  8*cce_block_size_in_bytes_p
    , localparam proc_cfg_width_lp =          `bp_proc_cfg_width(core_els_p, num_lce_p)

    , localparam fe_queue_width_lp =  `bp_fe_queue_width(vaddr_width_p, branch_metadata_fwd_width_p)
    , localparam fe_cmd_width_lp =    `bp_fe_cmd_width(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)

    , localparam lce_cce_req_width_lp =
      `bp_lce_cce_req_width(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, data_width_p)
    , localparam lce_cce_resp_width_lp =
      `bp_lce_cce_resp_width(num_cce_p, num_lce_p, paddr_width_p)
    , localparam lce_cce_data_resp_width_lp =
      `bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, paddr_width_p, cce_block_size_in_bits_lp)
    , localparam cce_lce_cmd_width_lp =
      `bp_cce_lce_cmd_width(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p)
    , localparam lce_data_cmd_width_lp =
      `bp_lce_data_cmd_width(num_lce_p,cce_block_size_in_bits_lp, lce_assoc_p)

    , localparam fu_op_width_lp=`bp_be_fu_op_width
    , localparam reg_data_width_lp = rv64_reg_data_width_gp
    , localparam reg_addr_width_lp = rv64_reg_addr_width_gp
    , localparam eaddr_width_lp    = rv64_eaddr_width_gp
  )
  (
    input clk_i
    , input reset_i

    , input [proc_cfg_width_lp-1:0] proc_cfg_i

    // LCE-CCE interface
    , output [1:0][lce_cce_req_width_lp-1:0]  lce_req_o
    , output [1:0]                            lce_req_v_o
    , input [1:0]                             lce_req_ready_i

    , output [1:0][lce_cce_resp_width_lp-1:0] lce_resp_o
    , output [1:0]                            lce_resp_v_o
    , input [1:0]                             lce_resp_ready_i

    , output [1:0][lce_cce_data_resp_width_lp-1:0]  lce_data_resp_o
    , output [1:0]                                  lce_data_resp_v_o
    , input [1:0]                                   lce_data_resp_ready_i

    // CCE-LCE interface
    , input [1:0][cce_lce_cmd_width_lp-1:0] lce_cmd_i
    , input [1:0]                           lce_cmd_v_i
    , output [1:0]                          lce_cmd_ready_o

    , input [1:0][lce_data_cmd_width_lp-1:0]  lce_data_cmd_i
    , input [1:0]                             lce_data_cmd_v_i
    , output [1:0]                            lce_data_cmd_ready_o

    , output [1:0][lce_data_cmd_width_lp-1:0]  lce_data_cmd_o
    , output [1:0]                             lce_data_cmd_v_o
    , input [1:0]                              lce_data_cmd_ready_i

    // Commit tracer for trace replay
    , output                                  cmt_rd_w_v_o
    , output [reg_addr_width_lp-1:0]          cmt_rd_addr_o
    , output                                  cmt_mem_w_v_o
    , output [eaddr_width_lp-1:0]             cmt_mem_addr_o
    , output [fu_op_width_lp-1:0]             cmt_mem_op_o
    , output [reg_data_width_lp-1:0]          cmt_data_o
    );

  `declare_bp_common_proc_cfg_s(core_els_p, num_lce_p)
  bp_proc_cfg_s proc_cfg;
  assign proc_cfg = proc_cfg_i;

`declare_bp_common_fe_be_if_structs(vaddr_width_p
                                    , paddr_width_p
                                    , asid_width_p
                                    , branch_metadata_fwd_width_p
                                    );
  bp_fe_queue_s fe_fe_queue, be_fe_queue;
  logic fe_fe_queue_v, be_fe_queue_v, fe_fe_queue_ready, be_fe_queue_ready;

  logic [core_els_p-1:0] fe_queue_clr, fe_queue_dequeue, fe_queue_rollback;

  bp_fe_cmd_s [core_els_p-1:0] fe_fe_cmd, be_fe_cmd;
  logic [core_els_p-1:0] fe_fe_cmd_v, be_fe_cmd_v, fe_fe_cmd_ready, be_fe_cmd_ready;

  bp_fe_top
    #(.vaddr_width_p(vaddr_width_p)
      ,.paddr_width_p(paddr_width_p)
      ,.btb_indx_width_p(btb_indx_width_p)
      ,.bht_indx_width_p(bht_indx_width_p)
      ,.ras_addr_width_p(ras_addr_width_p)
      ,.asid_width_p(asid_width_p)
      ,.bp_first_pc_p(bp_pc_entry_point_gp) /* TODO: Not ideal to couple to RISCV-tests */

      ,.lce_sets_p(lce_sets_p)
      ,.lce_assoc_p(lce_assoc_p)
      ,.num_cce_p(num_cce_p)
      ,.num_lce_p(num_lce_p)
      ,.cce_block_size_in_bytes_p(cce_block_size_in_bytes_p) 
    ) fe (
      .clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.icache_id_i(proc_cfg.icache_id)

      ,.fe_queue_o(fe_fe_queue)
      ,.fe_queue_v_o(fe_fe_queue_v)
      ,.fe_queue_ready_i(fe_fe_queue_ready)

      ,.fe_cmd_i(fe_fe_cmd)
      ,.fe_cmd_v_i(fe_fe_cmd_v)
      ,.fe_cmd_ready_o(fe_fe_cmd_ready)

      ,.lce_req_o(lce_req_o[0])
      ,.lce_req_v_o(lce_req_v_o[0])
      ,.lce_req_ready_i(lce_req_ready_i[0])

      ,.lce_resp_o(lce_resp_o[0])
      ,.lce_resp_v_o(lce_resp_v_o[0])
      ,.lce_resp_ready_i(lce_resp_ready_i[0])

      ,.lce_data_resp_o(lce_data_resp_o[0])
      ,.lce_data_resp_v_o(lce_data_resp_v_o[0])
      ,.lce_data_resp_ready_i(lce_data_resp_ready_i[0])

      ,.lce_cmd_i(lce_cmd_i[0])
      ,.lce_cmd_v_i(lce_cmd_v_i[0])
      ,.lce_cmd_ready_o(lce_cmd_ready_o[0])

      ,.lce_data_cmd_i(lce_data_cmd_i[0])
      ,.lce_data_cmd_v_i(lce_data_cmd_v_i[0])
      ,.lce_data_cmd_ready_o(lce_data_cmd_ready_o[0])

      ,.lce_data_cmd_o(lce_data_cmd_o[0])
      ,.lce_data_cmd_v_o(lce_data_cmd_v_o[0])
      ,.lce_data_cmd_ready_i(lce_data_cmd_ready_i[0])
    );

    bsg_fifo_1r1w_rolly 
     #(.width_p(fe_queue_width_lp)
       ,.els_p(fe_queue_fifo_els_p)
       ,.ready_THEN_valid_p(1)
       )
     fe_queue_fifo
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.clr_v_i(fe_queue_clr)
       ,.ckpt_v_i(fe_queue_dequeue)
       ,.roll_v_i(fe_queue_rollback)

       ,.data_i(fe_fe_queue)
       ,.v_i(fe_fe_queue_v)
       ,.ready_o(fe_fe_queue_ready)

       ,.data_o(be_fe_queue)
       ,.v_o(be_fe_queue_v)
       ,.yumi_i(be_fe_queue_ready)
       );

    bsg_fifo_1r1w_small 
     #(.width_p(fe_cmd_width_lp)
       ,.els_p(fe_cmd_fifo_els_p)
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

    bp_be_top 
     #(.vaddr_width_p(vaddr_width_p)
       ,.paddr_width_p(paddr_width_p)
       ,.asid_width_p(asid_width_p)
       ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
       ,.core_els_p(core_els_p)
       ,.num_cce_p(num_cce_p)
       ,.num_lce_p(num_lce_p)
       ,.lce_assoc_p(lce_assoc_p)
       ,.lce_sets_p(lce_sets_p)
       ,.cce_block_size_in_bytes_p(cce_block_size_in_bytes_p)
       ,.trace_p(trace_p)
       )
     be
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.proc_cfg_i(proc_cfg_i)

       ,.fe_queue_i(be_fe_queue)
       ,.fe_queue_v_i(be_fe_queue_v)
       ,.fe_queue_ready_o(be_fe_queue_ready)

       ,.fe_queue_clr_o(fe_queue_clr)
       ,.fe_queue_dequeue_o(fe_queue_dequeue)
       ,.fe_queue_rollback_o(fe_queue_rollback)

       ,.fe_cmd_o(be_fe_cmd)
       ,.fe_cmd_v_o(be_fe_cmd_v)
       ,.fe_cmd_ready_i(be_fe_cmd_ready)

       ,.lce_req_o(lce_req_o[1])
       ,.lce_req_v_o(lce_req_v_o[1])
       ,.lce_req_ready_i(lce_req_ready_i[1])

       ,.lce_resp_o(lce_resp_o[1])
       ,.lce_resp_v_o(lce_resp_v_o[1])
       ,.lce_resp_ready_i(lce_resp_ready_i[1])

       ,.lce_data_resp_o(lce_data_resp_o[1])
       ,.lce_data_resp_v_o(lce_data_resp_v_o[1])
       ,.lce_data_resp_ready_i(lce_data_resp_ready_i[1])

       ,.lce_cmd_i(lce_cmd_i[1])
       ,.lce_cmd_v_i(lce_cmd_v_i[1])
       ,.lce_cmd_ready_o(lce_cmd_ready_o[1])

       ,.lce_data_cmd_i(lce_data_cmd_i[1])
       ,.lce_data_cmd_v_i(lce_data_cmd_v_i[1])
       ,.lce_data_cmd_ready_o(lce_data_cmd_ready_o[1])

       ,.lce_data_cmd_o(lce_data_cmd_o[1])
       ,.lce_data_cmd_v_o(lce_data_cmd_v_o[1])
       ,.lce_data_cmd_ready_i(lce_data_cmd_ready_i[1])

       ,.cmt_rd_w_v_o(cmt_rd_w_v_o)
       ,.cmt_rd_addr_o(cmt_rd_addr_o)
       ,.cmt_mem_w_v_o(cmt_mem_w_v_o)
       ,.cmt_mem_addr_o(cmt_mem_addr_o)
       ,.cmt_mem_op_o(cmt_mem_op_o)
       ,.cmt_data_o(cmt_data_o)
       );

endmodule : bp_core

