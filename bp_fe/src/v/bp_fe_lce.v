/**
 *
 * Name:
 *   bp_fe_lce.v
 *
 * Description:
 *   To	be updated
 *
 * Parameters:
 *
 * Inputs:
 *
 * Outputs:
 *
 * Keywords:
 *
 * Notes:
 *
 */


module bp_fe_lce
  import bp_common_pkg::*;
  import bp_fe_pkg::*;
  import bp_fe_icache_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cfg_link_pkg::*;
  #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_lce_cce_if_widths(num_cce_p
                                 ,num_lce_p
                                 ,paddr_width_p
                                 ,lce_assoc_p
                                 ,dword_width_p
                                 ,cce_block_width_p
                                 )

    , parameter timeout_max_limit_p=4

   `declare_bp_fe_tag_widths(lce_assoc_p, lce_sets_p, num_lce_p, num_cce_p, dword_width_p, paddr_width_p)
   `declare_bp_fe_lce_widths(lce_assoc_p, lce_sets_p, tag_width_lp, cce_block_width_p) 
  )
  (
    input                                                        clk_i
    , input                                                      reset_i
    , input                                                      freeze_i

    // Config channel
    , input                                                      cfg_w_v_i
    , input [cfg_addr_width_p-1:0]                               cfg_addr_i
    , input [cfg_data_width_p-1:0]                               cfg_data_i

    , input [lce_id_width_lp-1:0]                                lce_id_i

    , output logic                                               ready_o
    , output logic                                               cache_miss_o

    , input                                                      miss_i
    , input [paddr_width_p-1:0]                                  miss_addr_i

    , input                                                      uncached_req_i

    , input [cce_block_width_p-1:0]                              data_mem_data_i
    , output logic [data_mem_pkt_width_lp-1:0]                   data_mem_pkt_o
    , output logic                                               data_mem_pkt_v_o
    , input                                                      data_mem_pkt_yumi_i

    , output logic [tag_mem_pkt_width_lp-1:0]                    tag_mem_pkt_o
    , output logic                                               tag_mem_pkt_v_o
    , input                                                      tag_mem_pkt_yumi_i
       
    , output logic                                               stat_mem_pkt_v_o
    , output logic [stat_mem_pkt_width_lp-1:0]                   stat_mem_pkt_o
    , input [way_id_width_lp-1:0]                                lru_way_i
    , input                                                      stat_mem_pkt_yumi_i
      
    // LCE-CCE interface 
    , output logic [lce_cce_req_width_lp-1:0] lce_req_o
    , output logic lce_req_v_o
    , input lce_req_ready_i

    , output logic [lce_cce_resp_width_lp-1:0] lce_resp_o
    , output logic lce_resp_v_o
    , input lce_resp_ready_i

    , input [lce_cmd_width_lp-1:0] lce_cmd_i
    , input lce_cmd_v_i
    , output logic lce_cmd_ready_o

    , output logic [lce_cmd_width_lp-1:0] lce_cmd_o
    , output logic lce_cmd_v_o
    , input lce_cmd_ready_i

    , output bp_fe_icache_lce_mode_e                  lce_mode_o
  );

  // LCE Mode control
  bp_fe_icache_lce_mode_e lce_mode_r, lce_mode_n;
  assign lce_mode_o = lce_mode_r;

  logic lce_mode_w_v, lce_mode_addr_v;
  assign lce_mode_addr_v = (cfg_addr_i == bp_cfg_reg_icache_mode_gp);
  assign lce_mode_w_v = freeze_i & cfg_w_v_i & lce_mode_addr_v;
  assign lce_mode_n = bp_fe_icache_lce_mode_e'(cfg_data_i[0+:`bp_fe_icache_lce_mode_bits]);

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      lce_mode_r <= e_icache_lce_mode_uncached;
    end else begin
      if (lce_mode_w_v) begin
        lce_mode_r <= lce_mode_n;
      end
    end
  end


  `declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p);

  `declare_bp_fe_icache_lce_data_mem_pkt_s(lce_sets_p, lce_assoc_p, cce_block_width_p);
  `declare_bp_fe_icache_lce_tag_mem_pkt_s(lce_sets_p, lce_assoc_p, tag_width_lp);
  `declare_bp_fe_icache_lce_stat_mem_pkt_s(lce_sets_p, lce_assoc_p);

  bp_lce_cce_req_s lce_req;
  bp_lce_cce_resp_s lce_resp;
  bp_lce_cmd_s lce_cmd;
  bp_lce_cmd_s lce_cmd_out;

  bp_fe_icache_lce_data_mem_pkt_s data_mem_pkt;
  bp_fe_icache_lce_tag_mem_pkt_s tag_mem_pkt;
  bp_fe_icache_lce_stat_mem_pkt_s stat_mem_pkt;

  assign lce_req_o           = lce_req;
  assign lce_resp_o          = lce_resp;
  assign lce_cmd          = lce_cmd_i;
  assign lce_cmd_o    = lce_cmd_out;

  assign data_mem_pkt_o        = data_mem_pkt;
  assign tag_mem_pkt_o         = tag_mem_pkt;
  assign stat_mem_pkt_o    = stat_mem_pkt;

  // lce_REQ
  bp_lce_cce_resp_s lce_req_lce_resp_lo;
  logic cce_data_received;
  logic uncached_data_received;
  logic set_tag_received;
  logic set_tag_wakeup_received;
  logic lce_req_lce_resp_v_lo;
  logic lce_req_lce_resp_yumi_li;
  logic [paddr_width_p-1:0] miss_addr_lo;

  bp_fe_lce_req #(.cfg_p(cfg_p))
    lce_req_inst (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
  
    ,.lce_id_i(lce_id_i)

    ,.miss_i(miss_i)
    ,.miss_addr_i(miss_addr_i)
    ,.lru_way_i(lru_way_i)
    ,.uncached_req_i(uncached_req_i)

    ,.cache_miss_o(cache_miss_o)
    ,.miss_addr_o(miss_addr_lo)

    ,.cce_data_received_i(cce_data_received)
    ,.uncached_data_received_i(uncached_data_received)
    ,.set_tag_received_i(set_tag_received)
    ,.set_tag_wakeup_received_i(set_tag_wakeup_received)

    ,.lce_req_o(lce_req)
    ,.lce_req_v_o(lce_req_v_o)
    ,.lce_req_ready_i(lce_req_ready_i)

    ,.lce_resp_o(lce_req_lce_resp_lo)
    ,.lce_resp_v_o(lce_req_lce_resp_v_lo)
    ,.lce_resp_yumi_i(lce_req_lce_resp_yumi_li)
  );
 
   
  // lce_CMD
  logic lce_ready_lo;
  
  bp_lce_cce_resp_s lce_cmd_lce_resp_lo;
  logic lce_cmd_lce_resp_v_lo;
  logic lce_cmd_lce_resp_yumi_li;

  bp_fe_lce_cmd #(.cfg_p(cfg_p))
    lce_cmd_inst (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.lce_id_i(lce_id_i)
    ,.miss_addr_i(miss_addr_lo)

    ,.lce_ready_o(lce_ready_lo)
    ,.set_tag_received_o(set_tag_received)
    ,.set_tag_wakeup_received_o(set_tag_wakeup_received)
    ,.cce_data_received_o(cce_data_received)
    ,.uncached_data_received_o(uncached_data_received)

    ,.data_mem_pkt_o(data_mem_pkt)
    ,.data_mem_pkt_v_o(data_mem_pkt_v_o)
    ,.data_mem_pkt_yumi_i(data_mem_pkt_yumi_i)
    ,.data_mem_data_i(data_mem_data_i)

    ,.tag_mem_pkt_o(tag_mem_pkt)
    ,.tag_mem_pkt_v_o(tag_mem_pkt_v_o)
    ,.tag_mem_pkt_yumi_i(tag_mem_pkt_yumi_i)                 

    ,.stat_mem_pkt_v_o(stat_mem_pkt_v_o)
    ,.stat_mem_pkt_o(stat_mem_pkt)
    ,.stat_mem_pkt_yumi_i(stat_mem_pkt_yumi_i)

    ,.lce_cmd_i(lce_cmd)
    ,.lce_cmd_v_i(lce_cmd_v_i)
    ,.lce_cmd_ready_o(lce_cmd_ready_o)

    ,.lce_resp_o(lce_cmd_lce_resp_lo)
    ,.lce_resp_v_o(lce_cmd_lce_resp_v_lo)
    ,.lce_resp_yumi_i(lce_cmd_lce_resp_yumi_li)

    ,.lce_cmd_o(lce_cmd_out)
    ,.lce_cmd_v_o(lce_cmd_v_o)
    ,.lce_cmd_ready_i(lce_cmd_ready_i)
  );
 
  // lce_RESP arbiter
  // (transfer from lce_req) vs (sync ack or invalidate ack from lce_cmd)
 
  always_comb begin
    lce_req_lce_resp_yumi_li = 1'b0; 
    lce_cmd_lce_resp_yumi_li = 1'b0; 

    if (lce_req_lce_resp_v_lo) begin
      lce_resp_v_o = 1'b1;
      lce_resp = lce_req_lce_resp_lo;
      lce_req_lce_resp_yumi_li = lce_resp_ready_i;
    end
    else begin
      lce_resp_v_o = lce_cmd_lce_resp_v_lo;
      lce_resp = lce_cmd_lce_resp_lo;
      lce_cmd_lce_resp_yumi_li = lce_cmd_lce_resp_v_lo & lce_resp_ready_i;
    end
  end

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
      if (data_mem_pkt_v_o | tag_mem_pkt_v_o | stat_mem_pkt_v_o) begin
        timeout_cnt_n = ~(data_mem_pkt_yumi_i | tag_mem_pkt_yumi_i | stat_mem_pkt_yumi_i)
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

  logic lce_ready;
  assign lce_ready = (lce_mode_r == e_icache_lce_mode_uncached) ? ~freeze_i : lce_ready_lo;
  assign ready_o = lce_ready & ~timeout & ~cache_miss_o;
 
endmodule
