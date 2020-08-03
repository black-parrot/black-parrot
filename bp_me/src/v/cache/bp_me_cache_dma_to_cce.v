// 
// bp_me_cache_dma_to_cce.v
// 
// 

module bp_me_cache_dma_to_cce

  import bp_cce_pkg::*;
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_me_pkg::*;
  
  import bsg_cache_pkg::*;
  
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce_mem)
  
  ,localparam block_size_in_words_lp = cce_block_width_p / dword_width_p
  ,localparam block_size_in_bytes_lp = (cce_block_width_p / 8)
  ,localparam block_offset_width_lp = `BSG_SAFE_CLOG2(cce_block_width_p >> 3)
  ,localparam bsg_cache_dma_pkt_width_lp = `bsg_cache_dma_pkt_width(paddr_width_p)
  // TODO: This module should be 1:1, not N:1
  ,localparam num_mem_p = 1
  ,localparam lg_num_mem_lp = `BSG_SAFE_CLOG2(num_mem_p)
  )
  
  (// Cache DMA side
   input                                                          clk_i
  ,input                                                          reset_i
  // Sending address and write_en               
  ,input        [num_mem_p-1:0][bsg_cache_dma_pkt_width_lp-1:0]   dma_pkt_i
  ,input        [num_mem_p-1:0]                                   dma_pkt_v_i
  ,output logic [num_mem_p-1:0]                                   dma_pkt_yumi_o
  // Sending cache block                                          
  ,input        [num_mem_p-1:0][dword_width_p-1:0]                dma_data_i
  ,input        [num_mem_p-1:0]                                   dma_data_v_i
  ,output logic [num_mem_p-1:0]                                   dma_data_yumi_o
  // Receiving cache block                                        
  ,output logic [num_mem_p-1:0][dword_width_p-1:0]                dma_data_o
  ,output logic [num_mem_p-1:0]                                   dma_data_v_o
  ,input        [num_mem_p-1:0]                                   dma_data_ready_i

  ,output       [cce_mem_msg_width_lp-1:0]                        mem_cmd_o
  ,output                                                         mem_cmd_v_o
  ,input                                                          mem_cmd_yumi_i
  
  ,input        [cce_mem_msg_width_lp-1:0]                        mem_resp_i
  ,input                                                          mem_resp_v_i
  ,output                                                         mem_resp_ready_o
  );
  
  localparam lg_fifo_depth_lp = 3;
  genvar i;
  
  /********************* Packet definition *********************/
  
  // Define cache DMA packet
  `declare_bsg_cache_dma_pkt_s(paddr_width_p);
  
  // cce
  `declare_bp_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce_mem);
  
  
  /********************* dma packet fifo *********************/
  
  // This two-element fifo is necessary to avoid bubble between address flit
  // and data flit for cache evict operation
  
  logic [num_mem_p-1:0] dma_pkt_fifo_valid_lo, dma_pkt_fifo_yumi_li;
  bsg_cache_dma_pkt_s [num_mem_p-1:0] dma_pkt_fifo_data_lo;
  
  logic [num_mem_p-1:0] dma_pkt_fifo_ready_lo;
  assign dma_pkt_yumi_o = dma_pkt_v_i & dma_pkt_fifo_ready_lo;
  
  for (i = 0; i < num_mem_p; i++)
  begin: fifo
    bsg_two_fifo
   #(.width_p(bsg_cache_dma_pkt_width_lp))
    dma_pkt_fifo
    (.clk_i  (clk_i  )
    ,.reset_i(reset_i)
    ,.ready_o(dma_pkt_fifo_ready_lo[i])
    ,.data_i (dma_pkt_i            [i])
    ,.v_i    (dma_pkt_v_i          [i])
    ,.v_o    (dma_pkt_fifo_valid_lo[i])
    ,.data_o (dma_pkt_fifo_data_lo [i])
    ,.yumi_i (dma_pkt_fifo_yumi_li [i])
    );
  end


  /********************* Packet arbitration *********************/
  
  logic dma_pkt_rr_v_lo;
  bsg_cache_dma_pkt_s dma_pkt_rr_lo;
  logic [lg_num_mem_lp-1:0] dma_pkt_rr_tag_n, dma_pkt_rr_tag_r;
  logic dma_pkt_rr_yumi_li;

  bsg_round_robin_n_to_1 
 #(.width_p (bsg_cache_dma_pkt_width_lp)
  ,.num_in_p(num_mem_p)
  ,.strict_p(0)
  ) dma_pkt_rr 
  (.clk_i   (clk_i)
  ,.reset_i (reset_i)
            
  ,.data_i  (dma_pkt_fifo_data_lo)
  ,.v_i     (dma_pkt_fifo_valid_lo)
  ,.yumi_o  (dma_pkt_fifo_yumi_li)
            
  ,.v_o     (dma_pkt_rr_v_lo)
  ,.data_o  (dma_pkt_rr_lo)
  ,.tag_o   (dma_pkt_rr_tag_n)
  ,.yumi_i  (dma_pkt_rr_yumi_li)
  );
  
  bsg_dff_reset_en
 #(.width_p(lg_num_mem_lp)
  ) dffre
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)
  ,.en_i   (dma_pkt_rr_yumi_li)
  ,.data_i (dma_pkt_rr_tag_n)
  ,.data_o (dma_pkt_rr_tag_r)
  );
  
  logic arbiter_fifo_ready_lo, arbiter_fifo_valid_lo, arbiter_fifo_yumi_li;
  logic [lg_num_mem_lp-1:0] arbiter_fifo_data_lo;
  
  bsg_fifo_1r1w_small
 #(.width_p(lg_num_mem_lp)
  ,.els_p  (8)
  ) arbiter_fifo
  (.clk_i  (clk_i  )
  ,.reset_i(reset_i)
  ,.ready_o(arbiter_fifo_ready_lo)
  ,.data_i (dma_pkt_rr_tag_n)
  ,.v_i    (~dma_pkt_rr_lo.write_not_read & dma_pkt_rr_yumi_li)
  ,.v_o    (arbiter_fifo_valid_lo)
  ,.data_o (arbiter_fifo_data_lo)
  ,.yumi_i (arbiter_fifo_yumi_li)
  );
            
  logic [dword_width_p-1:0] dma_data_li, dma_data_lo;
  logic dma_data_v_li, dma_data_v_lo, dma_data_ready_li, dma_data_yumi_lo;
  
  always_comb
  begin
    dma_data_yumi_o = '0;
    dma_data_v_o = '0;
    dma_data_o = '0;
    
    dma_data_li = dma_data_i[dma_pkt_rr_tag_r];
    dma_data_v_li = dma_data_v_i[dma_pkt_rr_tag_r];
    dma_data_yumi_o[dma_pkt_rr_tag_r] = dma_data_yumi_lo;
    
    dma_data_o[arbiter_fifo_data_lo] = dma_data_lo;
    dma_data_v_o[arbiter_fifo_data_lo] = dma_data_v_lo;
    dma_data_ready_li = dma_data_ready_i[arbiter_fifo_data_lo];
  end
  
  
  /********************* cache DMA -> cce *********************/
  
  // send cache DMA packet
  bsg_cache_dma_pkt_s send_dma_pkt_n, send_dma_pkt_r;
  logic [dword_width_p-1:0] data_n;
  logic [block_size_in_words_lp-1:0][dword_width_p-1:0] data_r ;

  // coherence message block size
  // block size smaller than 8-bytes not supported
  bp_mem_msg_size_e mem_cmd_block_size =
    (block_size_in_bytes_lp == 128)
    ? e_mem_msg_size_128
    : (block_size_in_bytes_lp == 64)
      ? e_mem_msg_size_64
      : (block_size_in_bytes_lp == 32)
        ? e_mem_msg_size_32
        : (block_size_in_bytes_lp == 16)
          ? e_mem_msg_size_16
          : e_mem_msg_size_8;

  logic mem_cmd_v_lo;
  bp_cce_mem_msg_s mem_cmd_lo;
  
  assign mem_cmd_lo.header.msg_type = (send_dma_pkt_r.write_not_read)? 
                                       e_mem_msg_wr : e_mem_msg_rd;
  assign mem_cmd_lo.header.addr = (num_mem_p == 1)? send_dma_pkt_r.addr : 
                                {send_dma_pkt_r.addr[paddr_width_p-1:block_offset_width_lp], 
                                dma_pkt_rr_tag_r, send_dma_pkt_r.addr[block_offset_width_lp-1:0]};
  assign mem_cmd_lo.header.payload  = '0;
  assign mem_cmd_lo.header.size     = mem_cmd_block_size;
  assign mem_cmd_lo.data     = (send_dma_pkt_r.write_not_read)? data_r : '0;
  
  assign mem_cmd_o           = mem_cmd_lo;
  assign mem_cmd_v_o         = mem_cmd_v_lo;

  logic [7:0] count_r, count_n;
  
  // State machine
  typedef enum logic [2:0] {
    RESET
   ,READY
   ,SEND_DATA
   ,SEND
  } dma_state_e;
  
  dma_state_e dma_state_r, dma_state_n;
  
  //synopsys sync_set_reset reset_i
  always_ff @(posedge clk_i)
    if (reset_i)
      begin
        dma_state_r <= RESET;
        count_r     <= '0;
        send_dma_pkt_r <= '0;
      end
    else
      begin
        dma_state_r <= dma_state_n;
        count_r     <= count_n;
        send_dma_pkt_r <= send_dma_pkt_n;
        data_r[count_r] <= data_n;
      end
  
  always_comb
  begin
    // internal control
    dma_state_n            = dma_state_r;
    count_n                = count_r;
    // send control
    dma_pkt_rr_yumi_li     = 1'b0;
    dma_data_yumi_lo       = 1'b0;
    mem_cmd_v_lo           = 1'b0;
    
    send_dma_pkt_n = send_dma_pkt_r;
    data_n = data_r[count_r];
    
    case (dma_state_r)
    RESET:
      begin
        dma_state_n = READY;
      end
    READY:
      begin
        if (dma_pkt_rr_v_lo & arbiter_fifo_ready_lo)
          begin
            send_dma_pkt_n = dma_pkt_rr_lo;
            dma_pkt_rr_yumi_li = 1'b1;
            dma_state_n = (dma_pkt_rr_lo.write_not_read)? SEND_DATA : SEND;
          end
      end
    SEND_DATA:
      begin
        if (dma_data_v_li)
          begin
            dma_data_yumi_lo = 1'b1;
            data_n = dma_data_li;
            count_n = count_r + 1;
            if (count_r == block_size_in_words_lp-1)
              begin
                count_n = 0;
                dma_state_n = SEND;
              end
          end
      end
    SEND:
      begin
        mem_cmd_v_lo = 1'b1;
        if (mem_cmd_yumi_i)
          begin
            dma_state_n = READY;
          end
      end
    default:
      begin
      end
    endcase
  end
  
  
  /********************* cce -> Cache DMA *********************/
  
  logic piso_v_li, piso_ready_lo, two_fifo_v_lo, two_fifo_yumi_li;
  bp_cce_mem_msg_s mem_resp_li;
  
  bsg_two_fifo
 #(.width_p(cce_mem_msg_width_lp)
  ) two_fifo
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)
  ,.v_i    (mem_resp_v_i)
  ,.data_i (mem_resp_i)
  ,.ready_o(mem_resp_ready_o)
  ,.v_o    (two_fifo_v_lo)
  ,.data_o (mem_resp_li)
  ,.yumi_i (two_fifo_yumi_li)
  );

  assign piso_v_li = two_fifo_v_lo & (mem_resp_li.header.msg_type == e_mem_msg_rd);
  assign two_fifo_yumi_li = two_fifo_v_lo & ((mem_resp_li.header.msg_type == e_mem_msg_wr) | piso_ready_lo);
  
  bsg_parallel_in_serial_out 
 #(.width_p(dword_width_p)
  ,.els_p  (block_size_in_words_lp)
  ) piso
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)
  ,.valid_i(piso_v_li)
  ,.data_i (mem_resp_li.data)
  ,.ready_o(piso_ready_lo)
  ,.valid_o(dma_data_v_lo)
  ,.data_o (dma_data_lo)
  ,.yumi_i (dma_data_v_lo & dma_data_ready_li)
  );
  
  logic [7:0] resp_count_r, resp_count_n;
  
  always_ff @(posedge clk_i)
    if (reset_i) resp_count_r <= '0;
    else         resp_count_r <= resp_count_n;
  
  always_comb
  begin
    arbiter_fifo_yumi_li = 1'b0;
    resp_count_n = resp_count_r;
    if (dma_data_v_lo & dma_data_ready_li)
      begin
        resp_count_n = resp_count_r + 1;
        if (resp_count_r == block_size_in_words_lp-1)
          begin
            resp_count_n = '0;
            arbiter_fifo_yumi_li = 1'b1;
          end
      end
  end
  
endmodule
