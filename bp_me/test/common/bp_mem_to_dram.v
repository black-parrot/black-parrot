
module bp_mem_to_dram

  import bp_cce_pkg::*;
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_me_pkg::*;
  
  import bsg_cache_pkg::*;
  
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
  , parameter data_width_p = "inv"
  , parameter dram_base_p = "inv"
  , parameter fifo_els_p = "inv"

  , localparam write_mask_width_lp = (data_width_p>>3)
  , localparam cce_write_mask_width_lp = (cce_block_width_p >> 3)
  , localparam byte_offset_width_lp =`BSG_SAFE_CLOG2(data_width_p>>3) 
  , localparam block_size_in_words_lp = cce_block_width_p / data_width_p
  , localparam lg_block_size_in_words_lp = `BSG_SAFE_CLOG2(block_size_in_words_lp)
  , localparam bsg_cache_dma_pkt_width_lp = `bsg_cache_dma_pkt_width(paddr_width_p)
  , localparam reorder_fifo_els_lp = fifo_els_p * block_size_in_words_lp
  , localparam lg_reorder_fifo_els_lp = `BSG_SAFE_CLOG2(reorder_fifo_els_lp)
  )
  
  (// Cache DMA side
   input                                           clk_i
  ,input                                           reset_i
  // Sending address and write_en               
  ,output       [bsg_cache_dma_pkt_width_lp-1:0]   dma_pkt_o
  ,output                                          dma_pkt_v_o
  ,input                                           dma_pkt_yumi_i
  // Sending cache block                                          
  ,output       [data_width_p-1:0]                 dma_data_o
  ,output       [write_mask_width_lp-1:0]          dma_mask_o
  ,output                                          dma_data_v_o
  ,input                                           dma_data_yumi_i
  // Receiving cache block                                        
  ,input        [data_width_p-1:0]                 dma_data_i
  ,input        [paddr_width_p-1:0]                dma_addr_i
  ,input                                           dma_data_v_i
  ,output                                          dma_data_ready_o
  // Cmd input
  ,input        [cce_mem_msg_width_lp-1:0]         mem_cmd_i
  ,input                                           mem_cmd_v_i
  ,output                                          mem_cmd_ready_o
  // Resp output
  ,output       [cce_mem_msg_width_lp-1:0]         mem_resp_o
  ,output                                          mem_resp_v_o
  ,input                                           mem_resp_yumi_i
  );

  localparam fifo_width_lp = cce_mem_msg_width_lp - cce_block_width_p;
  
  /********************* Packet definition *********************/
  
  // Define cache DMA packet
  `declare_bsg_cache_dma_pkt_s(paddr_width_p);
  
  // cce
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);
  
  
  /********************* Resp queue fifo *********************/
  
  // Stores CCE packet header information
  logic queue_fifo_valid_li, queue_fifo_ready_lo;
  logic[fifo_width_lp-1:0] queue_fifo_data_li;
  
  logic queue_fifo_valid_lo, queue_fifo_yumi_li;
  logic[fifo_width_lp-1:0] queue_fifo_data_lo;
  
  bsg_fifo_1r1w_small
 #(.width_p(fifo_width_lp)
  ,.els_p  (fifo_els_p)
  ) queue_fifo
  (.clk_i  (clk_i  )
  ,.reset_i(reset_i)
  ,.ready_o(queue_fifo_ready_lo)
  ,.data_i (queue_fifo_data_li )
  ,.v_i    (queue_fifo_valid_li)
  ,.v_o    (queue_fifo_valid_lo)
  ,.data_o (queue_fifo_data_lo )
  ,.yumi_i (queue_fifo_yumi_li )
  );
  
  
  /********************* cce -> cache_dma *********************/
  
  // dma pkt fifo
  logic dma_pkt_fifo_valid_li, dma_pkt_fifo_ready_lo;
  bsg_cache_dma_pkt_s dma_pkt_fifo_data_li;
  logic[cce_write_mask_width_lp-1:0] mem_cmd_mask_li;

  logic dma_pkt_fifo_valid_lo, dma_pkt_fifo_yumi_li;
  bsg_cache_dma_pkt_s dma_pkt_fifo_data_lo;
  logic[cce_write_mask_width_lp-1:0] mem_cmd_mask_lo;
 
  bsg_two_fifo
 #(.width_p(bsg_cache_dma_pkt_width_lp+cce_write_mask_width_lp)
  ) dma_pkt_fifo
  (.clk_i  (clk_i  )
  ,.reset_i(reset_i)
  ,.ready_o(dma_pkt_fifo_ready_lo)
  ,.data_i ({mem_cmd_mask_li, dma_pkt_fifo_data_li})
  ,.v_i    (dma_pkt_fifo_valid_li)
  ,.v_o    (dma_pkt_fifo_valid_lo)
  ,.data_o ({mem_cmd_mask_lo, dma_pkt_fifo_data_lo})
  ,.yumi_i (dma_pkt_fifo_yumi_li )
  );

  logic [lg_block_size_in_words_lp-1:0] word_cnt_r;
  bsg_counter_clear_up
 #(.max_val_p(block_size_in_words_lp-1)
  ,.init_val_p(0)
  ) word_counter
  (.clk_i(clk_i)
  ,.reset_i(reset_i)
  ,.clear_i(dma_pkt_fifo_yumi_li)
  ,.up_i(dma_pkt_yumi_i & ~dma_pkt_fifo_yumi_li)
  ,.count_o(word_cnt_r)
  );
 
  // dma data piso
  logic dma_data_fifo_valid_li, dma_data_fifo_ready_lo;
  logic [cce_block_width_p-1:0] dma_data_fifo_data_li;
  
  bsg_parallel_in_serial_out 
 #(.width_p(data_width_p)
  ,.els_p  (block_size_in_words_lp)
  ) dma_data_piso
  (.clk_i  (clk_i  )
  ,.reset_i(reset_i)
  ,.valid_i(dma_data_fifo_valid_li)
  ,.data_i (dma_data_fifo_data_li)
  ,.ready_o(dma_data_fifo_ready_lo)
  ,.valid_o(dma_data_v_o)
  ,.data_o (dma_data_o)
  ,.yumi_i (dma_data_yumi_i)
  );

  // input mem cmd
  bp_cce_mem_msg_s mem_cmd_li;
  
  assign mem_cmd_li = mem_cmd_i;
  assign mem_cmd_ready_o = queue_fifo_ready_lo & dma_pkt_fifo_ready_lo & dma_data_fifo_ready_lo;

  bsg_cache_dma_pkt_s dma_pkt_lo;

  assign dma_pkt_v_o = dma_pkt_fifo_valid_lo;
  assign dma_pkt_o = dma_pkt_lo;

  assign dma_pkt_fifo_yumi_li = dma_pkt_yumi_i & (word_cnt_r == (block_size_in_words_lp-1));
  assign dma_pkt_lo.write_not_read = dma_pkt_fifo_data_lo.write_not_read;
  assign dma_pkt_lo.addr = dma_pkt_fifo_data_lo.addr + (word_cnt_r << byte_offset_width_lp) - dram_base_p;
  
  assign dma_mask_o = mem_cmd_mask_lo >> cce_write_mask_width_lp'(word_cnt_r << byte_offset_width_lp);

  // combinational logics
  always_comb 
  begin
  
    dma_pkt_fifo_valid_li = 1'b0;
    dma_data_fifo_valid_li = 1'b0;
    queue_fifo_valid_li = 1'b0;
    
    dma_pkt_fifo_data_li.write_not_read = (mem_cmd_li.header.msg_type inside {e_cce_mem_uc_wr, e_cce_mem_wr});
    dma_pkt_fifo_data_li.addr = mem_cmd_li.header.addr;
    mem_cmd_mask_li = ((1 << (1 << mem_cmd_li.header.size)) - 1) << mem_cmd_li.header.addr[0+:byte_offset_width_lp];
    dma_data_fifo_data_li = mem_cmd_li.data << cce_block_width_p'(mem_cmd_li.header.addr[0+:byte_offset_width_lp] << 3);
    queue_fifo_data_li = mem_cmd_li.header;

    if (mem_cmd_v_i & dma_pkt_fifo_ready_lo & queue_fifo_ready_lo)
      begin
        if (dma_pkt_fifo_data_li.write_not_read)
          begin
            if (dma_data_fifo_ready_lo)
              begin
                dma_pkt_fifo_valid_li = 1'b1;
                queue_fifo_valid_li = 1'b1;
                dma_data_fifo_valid_li = 1'b1;
              end
          end
        else
          begin
            dma_pkt_fifo_valid_li = 1'b1;
            queue_fifo_valid_li = 1'b1;
          end
      end
  
  end
  
  
  /********************* cache_dma -> cce *********************/

  // dma data sipof
  logic dma_data_fifo_valid_lo, dma_data_fifo_yumi_li,
  dma_data_sipo_ready_lo;
  logic [cce_block_width_p-1:0] dma_data_fifo_data_lo;

  // data reorder FIFO
  logic reorder_alloc_v_lo, reorder_alloc_yumi_li;
  logic [lg_reorder_fifo_els_lp-1:0] reorder_alloc_id_lo;

  logic reorder_w_v_li;
  logic [lg_reorder_fifo_els_lp-1:0] reorder_w_id_li;
  logic [data_width_p-1:0] reorder_w_data_li;

  logic reorder_deq_v_lo, reorder_deq_yumi_li;
  logic [data_width_p-1:0] reorder_deq_data_lo;

  // reordering CAM
  logic cam_w_set_not_clear_i, cam_r_v_li;
  logic [reorder_fifo_els_lp-1:0] cam_w_v_li, cam_r_match_lo;
  logic [paddr_width_p-1:0] cam_w_tag_li, cam_r_tag_li;

  // id decoder
  logic [reorder_fifo_els_lp-1:0] id_decode_lo;

  bsg_serial_in_parallel_out_full
 #(.width_p(data_width_p)
  ,.els_p  (block_size_in_words_lp)
  ) dma_data_sipof
  (.clk_i  (clk_i  )
  ,.reset_i(reset_i)
  
  ,.v_i    (reorder_deq_v_lo)
  ,.ready_o(dma_data_sipo_ready_lo)
  ,.data_i (reorder_deq_data_lo)

  ,.data_o (dma_data_fifo_data_lo )
  ,.v_o    (dma_data_fifo_valid_lo)
  ,.yumi_i (dma_data_fifo_yumi_li)
  );

  bsg_fifo_reorder
 #(.width_p(data_width_p)
  ,.els_p(reorder_fifo_els_lp)
  ) reorder_fifo
  (.clk_i(clk_i)
  ,.reset_i(reset_i)

  ,.fifo_alloc_v_o(reorder_alloc_v_lo)
  ,.fifo_alloc_id_o(reorder_alloc_id_lo)
  ,.fifo_alloc_yumi_i(reorder_alloc_yumi_li)

  ,.write_v_i(reorder_w_v_li)
  ,.write_id_i(reorder_w_id_li)
  ,.write_data_i(reorder_w_data_li)

  ,.fifo_deq_v_o(reorder_deq_v_lo)
  ,.fifo_deq_data_o(reorder_deq_data_lo)
  ,.fifo_deq_yumi_i(reorder_deq_yumi_li)

  ,.empty_o()
  );

  bsg_cam_1r1w_tag_array
 #(.els_p(reorder_fifo_els_lp)
  ,.width_p(paddr_width_p)
  ) id_cam
  (.clk_i(clk_i)
  ,.reset_i(reset_i)

  ,.w_v_i(cam_w_v_li)
  ,.w_set_not_clear_i(cam_w_set_not_clear_i)
  ,.w_tag_i(cam_w_tag_li)
  ,.w_empty_o()

  ,.r_v_i(cam_r_v_li)
  ,.r_tag_i(cam_r_tag_li)
  ,.r_match_o(cam_r_match_lo)
  );

  bsg_encode_one_hot
 #(.width_p(reorder_fifo_els_lp)
  ) id_enc
  (.i(cam_r_match_lo)
  ,.addr_o(reorder_w_id_li)
  ,.v_o(reorder_w_v_li)
  );

  bsg_decode
 #(.num_out_p(reorder_fifo_els_lp)
  ) id_dec
  (.i(reorder_alloc_id_lo)
  ,.o(id_decode_lo)
  );

  // Reordering logic
  assign cam_w_v_li = reorder_alloc_yumi_li
                      ? id_decode_lo
                      : dma_data_v_i
                        ? cam_r_match_lo
                        : '0;
  assign cam_w_set_not_clear_i = reorder_alloc_yumi_li;
  assign cam_w_tag_li = dma_pkt_lo.addr;
  assign cam_r_v_li = dma_data_v_i;
  assign cam_r_tag_li = dma_addr_i;

  assign reorder_alloc_yumi_li = dma_pkt_v_o & ~dma_pkt_lo.write_not_read;
  assign reorder_w_data_li = dma_data_i;
  assign reorder_deq_yumi_li = dma_data_sipo_ready_lo & reorder_deq_v_lo;

  // Cannot accept data when sendign read requests
  assign dma_data_ready_o = ~reorder_alloc_yumi_li;
 
  // mem resp output
  bp_cce_mem_msg_s mem_resp_lo;
  logic mem_resp_v_lo;
  
  assign mem_resp_o = mem_resp_lo;
  assign mem_resp_v_o = mem_resp_v_lo;
  
  // combinational logics
  always_comb
  begin
  
    mem_resp_v_lo = 1'b0;
    dma_data_fifo_yumi_li = 1'b0;
    queue_fifo_yumi_li = 1'b0;
    
    mem_resp_lo.header = queue_fifo_data_lo;
    mem_resp_lo.data = dma_data_fifo_data_lo;
    
    if (~reset_i & queue_fifo_valid_lo)
      begin
        if (mem_resp_lo.header.msg_type inside {e_cce_mem_uc_wr, e_cce_mem_wr})
          begin
            mem_resp_lo.data = '0;
            mem_resp_v_lo = 1'b1;
            if (mem_resp_yumi_i)
              begin
                queue_fifo_yumi_li = 1'b1;
              end
          end
        else
          begin
            if (dma_data_fifo_valid_lo)
              begin
                mem_resp_v_lo = 1'b1;
                if (mem_resp_yumi_i)
                  begin
                    queue_fifo_yumi_li = 1'b1;
                    dma_data_fifo_yumi_li = 1'b1;
                  end
              end
          end
      end
    
  end
  
endmodule
