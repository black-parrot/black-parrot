/**
 *
 * bp_fe_lce.v
 */

`ifndef BP_FE_ICACHE_VH
`define BP_FE_ICACHE_VH
`include "bp_fe_icache.vh"
`endif

`ifndef BP_FE_PC_GEN_VH
`define BP_FE_PC_GEN_VH
`include "bp_fe_pc_gen.vh"
`endif

`ifndef BP_FE_ITLB_VH
`define BP_FE_ITLB_VH
`include "bp_fe_itlb.vh"
`endif

`ifndef BP_CCE_MSG_VH
`define BP_CCE_MSG_VH
`include "bp_common_me_if.vh"
`endif

`ifndef BSG_DEFINES_V
`define BSG_DEFINES_V
`include "bsg_defines.v"
`endif

module bp_fe_lce
  #(parameter lce_id_p="inv"
    ,parameter data_width_p="inv"
    ,parameter lce_data_width_p="inv"
    ,parameter lce_addr_width_p="inv"
    ,parameter lce_sets_p="inv"
    ,parameter lce_assoc_p="inv"
    ,parameter tag_width_p="inv"
    ,parameter coh_states_p="inv"
    ,parameter num_cce_p="inv"
    ,parameter num_lce_p="inv"
    ,parameter block_size_in_bytes_p="inv"
    ,parameter lg_lce_sets_lp=`BSG_SAFE_CLOG2(lce_sets_p)
    ,parameter lg_lce_assoc_lp=`BSG_SAFE_CLOG2(lce_assoc_p)
    ,parameter block_size_in_bits_lp=block_size_in_bytes_p*8
    ,parameter lg_block_size_in_bytes_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_p)

    ,parameter timeout_max_limit_p=4

    ,parameter bp_fe_icache_lce_data_mem_pkt_width_lp=`bp_fe_icache_lce_data_mem_pkt_width(lce_sets_p, lce_assoc_p, lce_data_width_p)
    ,parameter bp_fe_icache_lce_tag_mem_pkt_width_lp=`bp_fe_icache_lce_tag_mem_pkt_width(lce_sets_p, lce_assoc_p, coh_states_p, tag_width_p)
    ,parameter bp_fe_icache_lce_meta_data_mem_pkt_width_lp=`bp_fe_icache_lce_meta_data_mem_pkt_width(lce_sets_p, lce_assoc_p)

    ,parameter bp_lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p, num_lce_p, lce_addr_width_p, lce_assoc_p)
    ,parameter bp_lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p, num_lce_p, lce_addr_width_p)
    ,parameter bp_lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p)
    ,parameter bp_cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p, num_lce_p, lce_addr_width_p, lce_assoc_p, coh_states_p)
    ,parameter bp_cce_lce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p, lce_assoc_p)
    ,parameter bp_lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_p, lce_addr_width_p, lce_data_width_p, lce_assoc_p)    
   )
   (
    input logic                                                clk_i
    ,input logic                                               reset_i

    ,output logic                                              ready_o
    ,output logic                                              cache_miss_o

    ,input logic                                               miss_i
    ,input logic [lce_addr_width_p-1:0]                        miss_addr_i

    ,input logic [lce_data_width_p-1:0] data_mem_data_i
    ,output logic [bp_fe_icache_lce_data_mem_pkt_width_lp-1:0] data_mem_pkt_o
    ,output logic                                              data_mem_pkt_v_o
    ,input logic                                               data_mem_pkt_yumi_i

    ,output logic [bp_fe_icache_lce_tag_mem_pkt_width_lp-1:0]  tag_mem_pkt_o
    ,output logic                                              tag_mem_pkt_v_o
    ,input logic                                               tag_mem_pkt_yumi_i
       
    ,output logic                                              meta_data_mem_pkt_v_o
    ,output logic [bp_fe_icache_lce_meta_data_mem_pkt_width_lp-1:0] meta_data_mem_pkt_o
    ,input logic [lg_lce_assoc_lp-1:0]                         lru_way_i
    ,input logic                                               meta_data_mem_pkt_yumi_i
       
    ,output logic [bp_lce_cce_req_width_lp-1:0]                lce_cce_req_o
    ,output logic                                              lce_cce_req_v_o
    ,input  logic                                              lce_cce_req_ready_i

    ,output logic [bp_lce_cce_resp_width_lp-1:0]               lce_cce_resp_o
    ,output logic                                              lce_cce_resp_v_o
    ,input  logic                                              lce_cce_resp_ready_i

    ,output logic [bp_lce_cce_data_resp_width_lp-1:0]          lce_cce_data_resp_o     
    ,output logic                                              lce_cce_data_resp_v_o 
    ,input logic                                               lce_cce_data_resp_ready_i

    ,input logic [bp_cce_lce_cmd_width_lp-1:0]                 cce_lce_cmd_i
    ,input logic                                               cce_lce_cmd_v_i
    ,output logic                                              cce_lce_cmd_ready_o

    ,input logic [bp_cce_lce_data_cmd_width_lp-1:0]            cce_lce_data_cmd_i
    ,input logic                                               cce_lce_data_cmd_v_i
    ,output logic                                              cce_lce_data_cmd_ready_o

    ,input logic [bp_lce_lce_tr_resp_width_lp-1:0]             lce_lce_tr_resp_i
    ,input logic                                               lce_lce_tr_resp_v_i
    ,output logic                                              lce_lce_tr_resp_ready_o

    ,output logic [bp_lce_lce_tr_resp_width_lp-1:0]            lce_lce_tr_resp_o
    ,output logic                                              lce_lce_tr_resp_v_o
    ,input logic                                               lce_lce_tr_resp_ready_i
   );

  `declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, lce_addr_width_p);
  `declare_bp_lce_cce_req_s(num_cce_p, num_lce_p, lce_addr_width_p, lce_assoc_p);
  `declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p);
  `declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, lce_addr_width_p, lce_assoc_p, coh_states_p);
  `declare_bp_cce_lce_data_cmd_s(num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p, lce_assoc_p);
  `declare_bp_lce_lce_tr_resp_s(num_lce_p, lce_addr_width_p, lce_data_width_p, lce_assoc_p);

  `declare_bp_fe_icache_lce_data_mem_pkt_s(lce_sets_p, lce_assoc_p, lce_data_width_p);
  `declare_bp_fe_icache_lce_tag_mem_pkt_s(lce_sets_p, lce_assoc_p, coh_states_p, tag_width_p);
  `declare_bp_fe_icache_lce_meta_data_mem_pkt_s(lce_sets_p, lce_assoc_p);

  bp_lce_cce_req_s lce_cce_req_lo;
  bp_lce_cce_resp_s lce_cce_resp_lo;
  bp_lce_cce_data_resp_s lce_cce_data_resp_lo;
  bp_cce_lce_cmd_s cce_lce_cmd_li;
  bp_cce_lce_data_cmd_s cce_lce_data_cmd_li;
  bp_lce_lce_tr_resp_s lce_lce_tr_resp_in_li;
  bp_lce_lce_tr_resp_s lce_lce_tr_resp_out_lo;

  bp_fe_icache_lce_data_mem_pkt_s data_mem_pkt_lo;
  bp_fe_icache_lce_tag_mem_pkt_s tag_mem_pkt_lo;
  bp_fe_icache_lce_meta_data_mem_pkt_s meta_data_mem_pkt_lo;

  assign lce_cce_req_o         = lce_cce_req_lo;
  assign lce_cce_resp_o        = lce_cce_resp_lo;
  assign lce_cce_data_resp_o   = lce_cce_data_resp_lo;
  assign cce_lce_cmd_li        = cce_lce_cmd_i;
  assign cce_lce_data_cmd_li   = cce_lce_data_cmd_i;
  assign lce_lce_tr_resp_in_li = lce_lce_tr_resp_i;
  assign lce_lce_tr_resp_o     = lce_lce_tr_resp_out_lo;

  assign data_mem_pkt_o        = data_mem_pkt_lo;
  assign tag_mem_pkt_o         = tag_mem_pkt_lo;
  assign meta_data_mem_pkt_o   = meta_data_mem_pkt_lo;

  // LCE_CCE_REQ
  bp_lce_cce_resp_s lce_cce_req_lce_cce_resp_lo;
  logic tr_received_li;
  logic cce_data_received_li;
  logic tag_set_li;
  logic tag_set_wakeup_li;
  logic lce_cce_req_lce_cce_resp_v_lo;
  logic lce_cce_req_lce_cce_resp_yumi_li;
  
  bp_fe_lce_cce_req #(
    .lce_id_p(lce_id_p)
    ,.data_width_p(data_width_p)
    ,.lce_addr_width_p(lce_addr_width_p)
    ,.num_cce_p(num_cce_p)
    ,.num_lce_p(num_lce_p)
    ,.lce_sets_p(lce_sets_p)
    ,.lce_assoc_p(lce_assoc_p)
    ,.block_size_in_bytes_p(block_size_in_bytes_p)
  ) lce_cce_req (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
  
    ,.miss_i(miss_i)
    ,.miss_addr_i(miss_addr_i)
    ,.lru_way_i(lru_way_i)
    ,.cache_miss_o(cache_miss_o)

    ,.tr_received_i(tr_received_li)
    ,.cce_data_received_i(cce_data_received_li)
    ,.tag_set_i(tag_set_li)
    ,.tag_set_wakeup_i(tag_set_wakeup_li)

    ,.lce_cce_req_o(lce_cce_req_lo)
    ,.lce_cce_req_v_o(lce_cce_req_v_o)
    ,.lce_cce_req_ready_i(lce_cce_req_ready_i)

    ,.lce_cce_resp_o(lce_cce_req_lce_cce_resp_lo)
    ,.lce_cce_resp_v_o(lce_cce_req_lce_cce_resp_v_lo)
    ,.lce_cce_resp_yumi_i(lce_cce_req_lce_cce_resp_yumi_li)
  );
 
   
  // CCE_LCE_CMD
  logic lce_ready_lo;
  bp_fe_icache_lce_data_mem_pkt_s cce_lce_cmd_data_mem_pkt_lo;
  logic cce_lce_cmd_data_mem_pkt_v_lo;
  logic cce_lce_cmd_data_mem_pkt_yumi_li;
  
  bp_lce_cce_resp_s cce_lce_cmd_lce_cce_resp_lo;
  logic cce_lce_cmd_lce_cce_resp_v_lo;
  logic cce_lce_cmd_lce_cce_resp_yumi_li;

  logic cce_lce_cmd_fifo_v_lo;
  logic cce_lce_cmd_fifo_yumi_li;
  bp_cce_lce_cmd_s cce_lce_cmd_fifo_data_lo;

  bsg_two_fifo #(
    .width_p(bp_cce_lce_cmd_width_lp)
  ) cce_lce_cmd_fifo (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.ready_o(cce_lce_cmd_ready_o)
    ,.data_i(cce_lce_cmd_li)
    ,.v_i(cce_lce_cmd_v_i)

    ,.v_o(cce_lce_cmd_fifo_v_lo)
    ,.data_o(cce_lce_cmd_fifo_data_lo)
    ,.yumi_i(cce_lce_cmd_fifo_yumi_li)
  );


  bp_fe_cce_lce_cmd #(
    .lce_id_p(lce_id_p)
    ,.data_width_p(data_width_p)
    ,.lce_addr_width_p(lce_addr_width_p)
    ,.lce_data_width_p(lce_data_width_p)
    ,.lce_sets_p(lce_sets_p)
    ,.lce_assoc_p(lce_assoc_p)
    ,.tag_width_p(tag_width_p)
    ,.coh_states_p(coh_states_p)
    ,.num_cce_p(num_cce_p)
    ,.num_lce_p(num_lce_p)
    ,.block_size_in_bytes_p(block_size_in_bytes_p)
  ) cce_lce_cmd (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.lce_ready_o(lce_ready_lo)
    ,.tag_set_o(tag_set_li)
    ,.tag_set_wakeup_o(tag_set_wakeup_li)

    ,.data_mem_pkt_o(cce_lce_cmd_data_mem_pkt_lo)
    ,.data_mem_pkt_v_o(cce_lce_cmd_data_mem_pkt_v_lo)
    ,.data_mem_pkt_yumi_i(cce_lce_cmd_data_mem_pkt_yumi_li)
    ,.data_mem_data_i(data_mem_data_i)

    ,.tag_mem_pkt_o(tag_mem_pkt_lo)
    ,.tag_mem_pkt_v_o(tag_mem_pkt_v_o)
    ,.tag_mem_pkt_yumi_i(tag_mem_pkt_yumi_i)                 

    ,.meta_data_mem_pkt_v_o(meta_data_mem_pkt_v_o)
    ,.meta_data_mem_pkt_o(meta_data_mem_pkt_lo)
    ,.meta_data_mem_pkt_yumi_i(meta_data_mem_pkt_yumi_i)
                 
    ,.cce_lce_cmd_i(cce_lce_cmd_fifo_data_lo)
    ,.cce_lce_cmd_v_i(cce_lce_cmd_fifo_v_lo)
    ,.cce_lce_cmd_yumi_o(cce_lce_cmd_fifo_yumi_li)

    ,.lce_cce_resp_o(cce_lce_cmd_lce_cce_resp_lo)
    ,.lce_cce_resp_v_o(cce_lce_cmd_lce_cce_resp_v_lo)
    ,.lce_cce_resp_yumi_i(cce_lce_cmd_lce_cce_resp_yumi_li)

    ,.lce_cce_data_resp_o(lce_cce_data_resp_lo)
    ,.lce_cce_data_resp_v_o(lce_cce_data_resp_v_o)
    ,.lce_cce_data_resp_ready_i(lce_cce_data_resp_ready_i)

    ,.lce_lce_tr_resp_o(lce_lce_tr_resp_out_lo)
    ,.lce_lce_tr_resp_v_o(lce_lce_tr_resp_v_o)
    ,.lce_lce_tr_resp_ready_i(lce_lce_tr_resp_ready_i)
  );
 
  // CCE_LCE_DATA_CMD
  bp_fe_icache_lce_data_mem_pkt_s cce_lce_data_cmd_data_mem_pkt_lo;
  logic cce_data_received_lo; 
  logic cce_lce_data_cmd_data_mem_pkt_v_lo;
  logic cce_lce_data_cmd_data_mem_pkt_yumi_li;

  logic cce_lce_data_cmd_fifo_v_lo;
  bp_cce_lce_data_cmd_s cce_lce_data_cmd_fifo_data_lo;
  logic cce_lce_data_cmd_fifo_yumi_li;

  bsg_two_fifo #(
    .width_p(bp_cce_lce_data_cmd_width_lp)
  ) cce_lce_data_cmd_fifo (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.ready_o(cce_lce_data_cmd_ready_o)
    ,.data_i(cce_lce_data_cmd_li)
    ,.v_i(cce_lce_data_cmd_v_i)

    ,.v_o(cce_lce_data_cmd_fifo_v_lo)
    ,.data_o(cce_lce_data_cmd_fifo_data_lo)
    ,.yumi_i(cce_lce_data_cmd_fifo_yumi_li)
  );

  bp_fe_cce_lce_data_cmd #(
    .lce_id_p(lce_id_p)
    ,.data_width_p(data_width_p)
    ,.lce_addr_width_p(lce_addr_width_p)
    ,.lce_data_width_p(lce_data_width_p)
    ,.lce_sets_p(lce_sets_p)
    ,.lce_assoc_p(lce_assoc_p)
    ,.num_cce_p(num_cce_p)
    ,.num_lce_p(num_lce_p)
    ,.block_size_in_bytes_p(block_size_in_bytes_p)
  ) cce_lce_data_cmd (
    .cce_data_received_o(cce_data_received_li)
     
    ,.cce_lce_data_cmd_i(cce_lce_data_cmd_fifo_data_lo)
    ,.cce_lce_data_cmd_v_i(cce_lce_data_cmd_fifo_v_lo)
    ,.cce_lce_data_cmd_yumi_o(cce_lce_data_cmd_fifo_yumi_li)
     
    ,.data_mem_pkt_o(cce_lce_data_cmd_data_mem_pkt_lo)
    ,.data_mem_pkt_v_o(cce_lce_data_cmd_data_mem_pkt_v_lo)
    ,.data_mem_pkt_yumi_i(cce_lce_data_cmd_data_mem_pkt_yumi_li)
  );

  // LCE_LCE_TR_RESP_IN
  bp_fe_icache_lce_data_mem_pkt_s lce_lce_tr_resp_in_data_mem_pkt_lo;
  logic lce_lce_tr_resp_in_data_mem_pkt_v_lo;
  logic lce_lce_tr_resp_in_data_mem_pkt_yumi_li;

  logic lce_lce_tr_resp_in_fifo_v_lo;
  bp_lce_lce_tr_resp_s lce_lce_tr_resp_in_fifo_data_lo;
  logic lce_lce_tr_resp_in_fifo_yumi_li;

  bsg_two_fifo #(
    .width_p(bp_lce_lce_tr_resp_width_lp)
  ) lce_lce_tr_resp_in_fifo (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.ready_o(lce_lce_tr_resp_ready_o)
    ,.data_i(lce_lce_tr_resp_in_li)
    ,.v_i(lce_lce_tr_resp_v_i)

    ,.v_o(lce_lce_tr_resp_in_fifo_v_lo)
    ,.data_o(lce_lce_tr_resp_in_fifo_data_lo)
    ,.yumi_i(lce_lce_tr_resp_in_fifo_yumi_li)
  );


  bp_fe_lce_lce_tr_resp_in #(
    .lce_id_p(lce_id_p)
    ,.data_width_p(data_width_p)
    ,.lce_addr_width_p(lce_addr_width_p)
    ,.lce_data_width_p(lce_data_width_p)
    ,.lce_sets_p(lce_sets_p)
    ,.lce_assoc_p(lce_assoc_p)
    ,.num_cce_p(num_cce_p)
    ,.num_lce_p(num_lce_p)
    ,.block_size_in_bytes_p(block_size_in_bytes_p)
  ) lce_lce_tr_resp_in (
    .tr_received_o(tr_received_li)

    ,.lce_lce_tr_resp_i(lce_lce_tr_resp_in_fifo_data_lo)
    ,.lce_lce_tr_resp_v_i(lce_lce_tr_resp_in_fifo_v_lo)
    ,.lce_lce_tr_resp_yumi_o(lce_lce_tr_resp_in_fifo_yumi_li)

    ,.data_mem_pkt_v_o(lce_lce_tr_resp_in_data_mem_pkt_v_lo)
    ,.data_mem_pkt_o(lce_lce_tr_resp_in_data_mem_pkt_lo)
    ,.data_mem_pkt_yumi_i(lce_lce_tr_resp_in_data_mem_pkt_yumi_li)
  );
   
  // data_mem arbiter
  always_comb begin
    lce_lce_tr_resp_in_data_mem_pkt_yumi_li = 1'b0;
    cce_lce_data_cmd_data_mem_pkt_yumi_li   = 1'b0;
    cce_lce_cmd_data_mem_pkt_yumi_li = 1'b0;
    if (lce_lce_tr_resp_in_data_mem_pkt_v_lo) begin
      data_mem_pkt_v_o                        = 1'b1;
      data_mem_pkt_lo                         = lce_lce_tr_resp_in_data_mem_pkt_lo;
      lce_lce_tr_resp_in_data_mem_pkt_yumi_li = data_mem_pkt_yumi_i;
    end
    else if (cce_lce_data_cmd_data_mem_pkt_v_lo) begin
      data_mem_pkt_v_o                        = 1'b1;
      data_mem_pkt_lo                         = cce_lce_data_cmd_data_mem_pkt_lo;
      cce_lce_data_cmd_data_mem_pkt_yumi_li   = data_mem_pkt_yumi_i;
    end
    else begin
      data_mem_pkt_v_o                        = cce_lce_cmd_data_mem_pkt_v_lo;
      data_mem_pkt_lo                         = cce_lce_cmd_data_mem_pkt_lo;
      cce_lce_cmd_data_mem_pkt_yumi_li        = data_mem_pkt_yumi_i;
    end
  end

  // LCE_CCE_RESP arbiter
  // (transfer from lce_cce_req) vs (sync ack or invalidate ack from cce_lce_cmd)
  assign lce_cce_resp_v_o                 = lce_cce_req_lce_cce_resp_v_lo
    ? 1'b1
    : cce_lce_cmd_lce_cce_resp_v_lo;

  assign lce_cce_resp_lo                  = lce_cce_req_lce_cce_resp_v_lo
    ? lce_cce_req_lce_cce_resp_lo
    : cce_lce_cmd_lce_cce_resp_lo;

  assign lce_cce_req_lce_cce_resp_yumi_li = lce_cce_req_lce_cce_resp_v_lo
    ? lce_cce_resp_ready_i
    : 1'b0;

  assign cce_lce_cmd_lce_cce_resp_yumi_li = cce_lce_cmd_lce_cce_resp_v_lo
    ? lce_cce_resp_ready_i
    : 1'b0;   

  // timeout logic (similar to dcache timeout logic)
  logic [`BSG_SAFE_CLOG2(timeout_max_limit_p)-1:0] timeout_cnt_r, timeout_cnt_n;
  logic timeout;

  always_comb begin
    timeout       = 1'b0;
    timeout_cnt_n = timeout_cnt_r;
    
    if (timeout_cnt_r == timeout_max_limit_p) begin
      timeout = 1'b1;
      timeout_cnt_n = '0;
    end
    else begin
      if (data_mem_pkt_v_o | tag_mem_pkt_v_o | meta_data_mem_pkt_v_o) begin
        timeout_cnt_n = ~(data_mem_pkt_yumi_i | tag_mem_pkt_yumi_i | meta_data_mem_pkt_yumi_i)
          ? (timeout_cnt_r + 1)
          : '0;
      end
      else begin
        timeout_cnt_n = '0;
      end
    end
  end

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      timeout_cnt_r   <= '0;
    end
    else begin
      timeout_cnt_r   <= timeout_cnt_n;
    end
  end
  assign ready_o = lce_ready_lo & ~timeout & ~cache_miss_o;
 
endmodule
