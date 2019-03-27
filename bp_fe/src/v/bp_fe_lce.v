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
  #(parameter data_width_p="inv"
    , parameter paddr_width_p="inv"
    , parameter lce_data_width_p="inv"
    , parameter sets_p="inv"
    , parameter ways_p="inv"
    , parameter num_cce_p="inv"
    , parameter num_lce_p="inv"

    , parameter timeout_max_limit_p=4

    , localparam way_id_width_lp=`BSG_SAFE_CLOG2(ways_p)
    , localparam lce_id_width_lp=`BSG_SAFE_CLOG2(num_lce_p)

    , localparam block_size_in_words_lp=ways_p
    , localparam data_mask_width_lp=(data_width_p>>3)
    , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)
    , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)
    , localparam index_width_lp=`BSG_SAFE_CLOG2(sets_p)
    , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
    , localparam tag_width_lp=(paddr_width_p-block_offset_width_lp-index_width_lp)

    , localparam lce_data_mem_pkt_width_lp=
      `bp_fe_icache_lce_data_mem_pkt_width(sets_p,ways_p,lce_data_width_p)
    , localparam lce_tag_mem_pkt_width_lp=
      `bp_fe_icache_lce_tag_mem_pkt_width(sets_p,ways_p,tag_width_lp)
    , localparam lce_metadata_mem_pkt_width_lp=
      `bp_fe_icache_lce_metadata_mem_pkt_width(sets_p,ways_p)

    , localparam lce_cce_req_width_lp=
      `bp_lce_cce_req_width(num_cce_p, num_lce_p, paddr_width_p, ways_p, data_width_p)
    , localparam lce_cce_resp_width_lp=
      `bp_lce_cce_resp_width(num_cce_p, num_lce_p, paddr_width_p)
    , localparam lce_cce_data_resp_width_lp=
      `bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, paddr_width_p, lce_data_width_p)
    , localparam cce_lce_cmd_width_lp=
      `bp_cce_lce_cmd_width(num_cce_p, num_lce_p, paddr_width_p, ways_p)
    , localparam lce_data_cmd_width_lp=
      `bp_lce_data_cmd_width(num_lce_p, lce_data_width_p, ways_p)
  )
  (
    input                                                        clk_i
    , input                                                      reset_i

    , input [lce_id_width_lp-1:0]                                id_i

    , output logic                                               ready_o
    , output logic                                               cache_miss_o

    , input                                                      miss_i
    , input [paddr_width_p-1:0]                                  miss_addr_i

    , input [lce_data_width_p-1:0] data_mem_data_i
    , output logic [lce_data_mem_pkt_width_lp-1:0]              data_mem_pkt_o
    , output logic                                               data_mem_pkt_v_o
    , input                                                      data_mem_pkt_yumi_i

    , output logic [lce_tag_mem_pkt_width_lp-1:0]               tag_mem_pkt_o
    , output logic                                               tag_mem_pkt_v_o
    , input                                                      tag_mem_pkt_yumi_i
       
    , output logic                                               metadata_mem_pkt_v_o
    , output logic [lce_metadata_mem_pkt_width_lp-1:0]           metadata_mem_pkt_o
    , input [way_id_width_lp-1:0]                                lru_way_i
    , input                                                      metadata_mem_pkt_yumi_i
      
    // LCE-CCE interface 
    , output logic [lce_cce_req_width_lp-1:0] lce_req_o
    , output logic lce_req_v_o
    , input lce_req_ready_i

    , output logic [lce_cce_resp_width_lp-1:0] lce_resp_o
    , output logic lce_resp_v_o
    , input lce_resp_ready_i

    , output logic [lce_cce_data_resp_width_lp-1:0] lce_data_resp_o     
    , output logic lce_data_resp_v_o 
    , input lce_data_resp_ready_i

    , input [cce_lce_cmd_width_lp-1:0] lce_cmd_i
    , input lce_cmd_v_i
    , output logic lce_cmd_ready_o

    , input [lce_data_cmd_width_lp-1:0] lce_data_cmd_i
    , input lce_data_cmd_v_i
    , output logic lce_data_cmd_ready_o

    , output logic [lce_data_cmd_width_lp-1:0] lce_data_cmd_o
    , output logic lce_data_cmd_v_o
    , input lce_data_cmd_ready_i
  );

  `declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, paddr_width_p);
  `declare_bp_lce_cce_req_s(num_cce_p, num_lce_p, paddr_width_p, ways_p, data_width_p);
  `declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_p, paddr_width_p, lce_data_width_p);
  `declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, paddr_width_p, ways_p);
  `declare_bp_lce_data_cmd_s(num_lce_p, lce_data_width_p, ways_p);

  `declare_bp_fe_icache_lce_data_mem_pkt_s(sets_p, ways_p, lce_data_width_p);
  `declare_bp_fe_icache_lce_tag_mem_pkt_s(sets_p, ways_p, tag_width_lp);
  `declare_bp_fe_icache_lce_metadata_mem_pkt_s(sets_p, ways_p);

  bp_lce_cce_req_s lce_req;
  bp_lce_cce_resp_s lce_resp;
  bp_lce_cce_data_resp_s lce_data_resp;
  bp_cce_lce_cmd_s lce_cmd;
  bp_lce_data_cmd_s lce_data_cmd_in;
  bp_lce_data_cmd_s lce_data_cmd_out;

  bp_fe_icache_lce_data_mem_pkt_s data_mem_pkt;
  bp_fe_icache_lce_tag_mem_pkt_s tag_mem_pkt;
  bp_fe_icache_lce_metadata_mem_pkt_s metadata_mem_pkt;

  assign lce_req_o           = lce_req;
  assign lce_resp_o          = lce_resp;
  assign lce_data_resp_o     = lce_data_resp;
  assign lce_cmd          = lce_cmd_i;
  assign lce_data_cmd_o    = lce_data_cmd_out;
  assign lce_data_cmd_in   = lce_data_cmd_i;

  assign data_mem_pkt_o        = data_mem_pkt;
  assign tag_mem_pkt_o         = tag_mem_pkt;
  assign metadata_mem_pkt_o    = metadata_mem_pkt;

  // lce_REQ
  bp_lce_cce_resp_s lce_req_lce_resp_lo;
  logic tr_data_received;
  logic cce_data_received;
  logic set_tag_received;
  logic set_tag_wakeup_received;
  logic lce_req_lce_resp_v_lo;
  logic lce_req_lce_resp_yumi_li;
  logic [paddr_width_p-1:0] miss_addr_lo; 

  bp_fe_lce_req #(
    .data_width_p(data_width_p)
    ,.paddr_width_p(paddr_width_p)
    ,.num_cce_p(num_cce_p)
    ,.num_lce_p(num_lce_p)
    ,.sets_p(sets_p)
    ,.ways_p(ways_p)
  ) lce_req_inst (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
  
    ,.id_i(id_i)

    ,.miss_i(miss_i)
    ,.miss_addr_i(miss_addr_i)
    ,.lru_way_i(lru_way_i)
    ,.cache_miss_o(cache_miss_o)
    ,.miss_addr_o(miss_addr_lo)

    ,.tr_data_received_i(tr_data_received)
    ,.cce_data_received_i(cce_data_received)
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
  bp_fe_icache_lce_data_mem_pkt_s lce_cmd_data_mem_pkt_lo;
  logic lce_cmd_data_mem_pkt_v_lo;
  logic lce_cmd_data_mem_pkt_yumi_li;
  
  bp_lce_cce_resp_s lce_cmd_lce_resp_lo;
  logic lce_cmd_lce_resp_v_lo;
  logic lce_cmd_lce_resp_yumi_li;

  bp_fe_lce_cmd #(
    .data_width_p(data_width_p)
    ,.paddr_width_p(paddr_width_p)
    ,.lce_data_width_p(lce_data_width_p)
    ,.sets_p(sets_p)
    ,.ways_p(ways_p)
    ,.num_cce_p(num_cce_p)
    ,.num_lce_p(num_lce_p)
  ) lce_cmd_inst (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.id_i(id_i)

    ,.lce_ready_o(lce_ready_lo)
    ,.set_tag_received_o(set_tag_received)
    ,.set_tag_wakeup_received_o(set_tag_wakeup_received)

    ,.data_mem_pkt_o(lce_cmd_data_mem_pkt_lo)
    ,.data_mem_pkt_v_o(lce_cmd_data_mem_pkt_v_lo)
    ,.data_mem_pkt_yumi_i(lce_cmd_data_mem_pkt_yumi_li)
    ,.data_mem_data_i(data_mem_data_i)

    ,.tag_mem_pkt_o(tag_mem_pkt)
    ,.tag_mem_pkt_v_o(tag_mem_pkt_v_o)
    ,.tag_mem_pkt_yumi_i(tag_mem_pkt_yumi_i)                 

    ,.metadata_mem_pkt_v_o(metadata_mem_pkt_v_o)
    ,.metadata_mem_pkt_o(metadata_mem_pkt)
    ,.metadata_mem_pkt_yumi_i(metadata_mem_pkt_yumi_i)

    ,.lce_cmd_i(lce_cmd)
    ,.lce_cmd_v_i(lce_cmd_v_i)
    ,.lce_cmd_yumi_o(lce_cmd_ready_o)

    ,.lce_resp_o(lce_cmd_lce_resp_lo)
    ,.lce_resp_v_o(lce_cmd_lce_resp_v_lo)
    ,.lce_resp_yumi_i(lce_cmd_lce_resp_yumi_li)

    ,.lce_data_resp_o(lce_data_resp)
    ,.lce_data_resp_v_o(lce_data_resp_v_o)
    ,.lce_data_resp_ready_i(lce_data_resp_ready_i)

    ,.lce_data_cmd_o(lce_data_cmd_out)
    ,.lce_data_cmd_v_o(lce_data_cmd_v_o)
    ,.lce_data_cmd_ready_i(lce_data_cmd_ready_i)
  );
 
  // lce_DATA_CMD
  bp_fe_icache_lce_data_mem_pkt_s lce_data_cmd_data_mem_pkt_lo;
  logic lce_data_cmd_data_mem_pkt_v_lo;
  logic lce_data_cmd_data_mem_pkt_yumi_li;

  bp_fe_lce_data_cmd #(
    .data_width_p(data_width_p)
    ,.paddr_width_p(paddr_width_p)
    ,.lce_data_width_p(lce_data_width_p)
    ,.sets_p(sets_p)
    ,.ways_p(ways_p)
    ,.num_cce_p(num_cce_p)
    ,.num_lce_p(num_lce_p)
  ) lce_data_cmd (
    .cce_data_received_o(cce_data_received)
    ,.tr_data_received_o(tr_data_received)

    ,.miss_addr_i(miss_addr_lo)
     
    ,.lce_data_cmd_i(lce_data_cmd_in)
    ,.lce_data_cmd_v_i(lce_data_cmd_v_i)
    ,.lce_data_cmd_yumi_o(lce_data_cmd_ready_o)
     
    ,.data_mem_pkt_o(lce_data_cmd_data_mem_pkt_lo)
    ,.data_mem_pkt_v_o(lce_data_cmd_data_mem_pkt_v_lo)
    ,.data_mem_pkt_yumi_i(lce_data_cmd_data_mem_pkt_yumi_li)
  );

   
  // data_mem_pkt arbiter
  always_comb begin
    lce_data_cmd_data_mem_pkt_yumi_li   = 1'b0;
    lce_cmd_data_mem_pkt_yumi_li = 1'b0;

    if (lce_data_cmd_data_mem_pkt_v_lo) begin
      data_mem_pkt_v_o = 1'b1;
      data_mem_pkt = lce_data_cmd_data_mem_pkt_lo;
      lce_data_cmd_data_mem_pkt_yumi_li = data_mem_pkt_yumi_i;      
    end
    else begin
      data_mem_pkt_v_o = lce_cmd_data_mem_pkt_v_lo;
      data_mem_pkt = lce_cmd_data_mem_pkt_lo;
      lce_cmd_data_mem_pkt_yumi_li = data_mem_pkt_yumi_i;
    end
  end

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
      if (data_mem_pkt_v_o | tag_mem_pkt_v_o | metadata_mem_pkt_v_o) begin
        timeout_cnt_n = ~(data_mem_pkt_yumi_i | tag_mem_pkt_yumi_i | metadata_mem_pkt_yumi_i)
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
