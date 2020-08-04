
module bp_mem_to_dram

  import bp_cce_pkg::*;
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_me_pkg::*;
  
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce_mem)
  , parameter channel_addr_width_p = "inv"
  , parameter data_width_p = "inv"
  , parameter dram_base_p = "inv"
  , parameter fifo_els_p = "inv"

  , localparam write_mask_width_lp = (data_width_p>>3)
  , localparam cce_write_mask_width_lp = (cce_block_width_p >> 3)
  , localparam byte_offset_width_lp =`BSG_SAFE_CLOG2(data_width_p>>3) 
  , localparam block_size_in_words_lp = cce_block_width_p / data_width_p
  , localparam lg_block_size_in_words_lp = `BSG_SAFE_CLOG2(block_size_in_words_lp)
  , localparam reorder_fifo_els_lp = fifo_els_p * block_size_in_words_lp
  , localparam lg_reorder_fifo_els_lp = `BSG_SAFE_CLOG2(reorder_fifo_els_lp)
  )
  
  (
   // Core Side
   input                                           clk_i
  ,input                                           reset_i

  ,input        [cce_mem_msg_width_lp-1:0]         mem_cmd_i
  ,input                                           mem_cmd_v_i
  ,output                                          mem_cmd_ready_o

  ,output       [cce_mem_msg_width_lp-1:0]         mem_resp_o
  ,output                                          mem_resp_v_o
  ,input                                           mem_resp_yumi_i

  // DRAM Side
  ,input                                           dram_clk_i
  ,input                                           dram_reset_i 

  ,output       [channel_addr_width_p-1:0]         dram_ch_addr_o
  ,output                                          dram_write_not_read_o
  ,output                                          dram_v_o
  ,input                                           dram_yumi_i

  ,output       [data_width_p-1:0]                 dram_data_o
  ,output       [write_mask_width_lp-1:0]          dram_mask_o
  ,output                                          dram_data_v_o
  ,input                                           dram_data_yumi_i

  ,input        [data_width_p-1:0]                 dram_data_i
  ,input        [channel_addr_width_p-1:0]         dram_ch_addr_i
  ,input                                           dram_data_v_i
  ,output                                          dram_data_ready_o
  );

  localparam fifo_width_lp = cce_mem_msg_width_lp - cce_block_width_p;
  
  /********************* Packet definition *********************/
  
  // cce
  `declare_bp_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce_mem);
  
  
  /********************* Resp queue fifo *********************/
  
  // Stores CCE packet header information
  logic queue_fifo_v_li, queue_fifo_ready_lo;
  logic [fifo_width_lp-1:0] queue_fifo_data_li;
  
  logic queue_fifo_v_lo, queue_fifo_yumi_li;
  logic [fifo_width_lp-1:0] queue_fifo_data_lo;
  
  bsg_fifo_1r1w_small
 #(.width_p(fifo_width_lp)
  ,.els_p  (fifo_els_p)
  ) queue_fifo
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)
  ,.ready_o(queue_fifo_ready_lo)
  ,.data_i (queue_fifo_data_li)
  ,.v_i    (queue_fifo_v_li)
  ,.v_o    (queue_fifo_v_lo)
  ,.data_o (queue_fifo_data_lo)
  ,.yumi_i (queue_fifo_yumi_li)
  );
  
  
  /********************* core -> dram *********************/
  
  // Address Channel
  logic dma_fifo_v_li, dma_fifo_ready_lo, dma_fifo_write_not_read_li;
  logic [channel_addr_width_p-1:0] dma_fifo_ch_addr_li;

  logic dma_fifo_v_lo, dma_fifo_yumi_li, dma_fifo_write_not_read_lo;
  logic [channel_addr_width_p-1:0] dma_fifo_ch_addr_lo;

  logic req_afifo_enq_li, req_afifo_full_lo;

  logic [lg_block_size_in_words_lp-1:0] word_cnt_r;
  logic [channel_addr_width_p-1:0] word_addr_lo;
 
  bsg_two_fifo
 #(.width_p(1+channel_addr_width_p)
  ) dma_fifo
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)
  ,.ready_o(dma_fifo_ready_lo)
  ,.data_i ({dma_fifo_write_not_read_li, dma_fifo_ch_addr_li})
  ,.v_i    (dma_fifo_v_li)
  ,.v_o    (dma_fifo_v_lo)
  ,.data_o ({dma_fifo_write_not_read_lo, dma_fifo_ch_addr_lo})
  ,.yumi_i (dma_fifo_yumi_li)
  );

  bsg_async_fifo
  #(.lg_size_p(2)
    ,.width_p(1+channel_addr_width_p)
  ) req_afifo (
    .w_clk_i(clk_i)
    ,.w_reset_i(reset_i)
    ,.w_enq_i(req_afifo_enq_li)
    ,.w_data_i({dma_fifo_write_not_read_lo, word_addr_lo})
    ,.w_full_o(req_afifo_full_lo)

    ,.r_clk_i(dram_clk_i)
    ,.r_reset_i(dram_reset_i)
    ,.r_deq_i(dram_yumi_i)
    ,.r_data_o({dram_write_not_read_o, dram_ch_addr_o})
    ,.r_valid_o(dram_v_o)
  );

  bsg_counter_clear_up
 #(.max_val_p(block_size_in_words_lp-1)
  ,.init_val_p(0)
  ) word_counter
  (.clk_i(clk_i)
  ,.reset_i(reset_i)
  ,.clear_i(dma_fifo_yumi_li)
  ,.up_i(req_afifo_enq_li & ~dma_fifo_yumi_li)
  ,.count_o(word_cnt_r)
  );
 
  // Data Channel
  logic dma_data_piso_v_li, dma_data_piso_ready_lo;
  logic [cce_block_width_p-1:0] dma_data_piso_data_li;
  logic [cce_write_mask_width_lp-1:0] dma_data_piso_mask_li;
  logic dma_data_piso_v_lo, dma_data_piso_yumi_li;
  logic [data_width_p-1:0] dma_data_piso_data_lo;
  logic [write_mask_width_lp-1:0] dma_data_piso_mask_lo;

  logic req_data_afifo_full_lo;

  bsg_parallel_in_serial_out 
 #(.width_p(data_width_p)
  ,.els_p  (block_size_in_words_lp)
  ) dma_data_piso
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)
  ,.valid_i(dma_data_piso_v_li)
  ,.data_i (dma_data_piso_data_li)
  ,.ready_o(dma_data_piso_ready_lo)
  ,.valid_o(dma_data_piso_v_lo)
  ,.data_o (dma_data_piso_data_lo)
  ,.yumi_i (dma_data_piso_yumi_li)
  );

  bsg_parallel_in_serial_out
 #(.width_p(write_mask_width_lp)
  ,.els_p  (block_size_in_words_lp)
  ) dma_mask_piso
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)
  ,.valid_i(dma_data_piso_v_li)
  ,.data_i (dma_data_piso_mask_li)
  ,.ready_o()
  ,.valid_o()
  ,.data_o (dma_data_piso_mask_lo)
  ,.yumi_i (dma_data_piso_yumi_li)
  );

  bsg_async_fifo
  #(.lg_size_p(2)
    ,.width_p(write_mask_width_lp+data_width_p)
  ) req_data_afifo (
    .w_clk_i(clk_i)
    ,.w_reset_i(reset_i)
    ,.w_enq_i(dma_data_piso_yumi_li)
    ,.w_data_i({dma_data_piso_mask_lo, dma_data_piso_data_lo})
    ,.w_full_o(req_data_afifo_full_lo)

    ,.r_clk_i(dram_clk_i)
    ,.r_reset_i(dram_reset_i)
    ,.r_deq_i(dram_data_yumi_i)
    ,.r_data_o({dram_mask_o, dram_data_o})
    ,.r_valid_o(dram_data_v_o)
  );

  // input mem cmd
  bp_cce_mem_msg_s mem_cmd_li , mem_resp_lo;
  assign mem_cmd_li = mem_cmd_i;
  assign mem_resp_o = mem_resp_lo;
  assign mem_cmd_ready_o = ~reset_i & ~dram_reset_i & queue_fifo_ready_lo & dma_fifo_ready_lo & dma_data_piso_ready_lo;

  // cmd queue
  assign queue_fifo_v_li = mem_cmd_v_i & mem_cmd_ready_o;
  assign queue_fifo_data_li = mem_cmd_li.header;

  // address channel
  assign dma_fifo_v_li = mem_cmd_v_i & mem_cmd_ready_o;
  assign dma_fifo_yumi_li =  req_afifo_enq_li & (word_cnt_r == (block_size_in_words_lp-1));
  assign dma_fifo_write_not_read_li = (mem_cmd_li.header.msg_type inside {e_mem_msg_uc_wr, e_mem_msg_wr});
  assign dma_fifo_ch_addr_li = (mem_cmd_li.header.addr - dram_base_p) & ({channel_addr_width_p{1'b1}} << byte_offset_width_lp);
  assign req_afifo_enq_li = dma_fifo_v_lo & ~req_afifo_full_lo;
  assign word_addr_lo = dma_fifo_ch_addr_lo + (word_cnt_r << byte_offset_width_lp);

  // data channel
  assign dma_data_piso_v_li = mem_cmd_v_i & mem_cmd_ready_o & dma_fifo_write_not_read_li;
  assign dma_data_piso_yumi_li = dma_data_piso_v_lo & ~req_data_afifo_full_lo;
  assign dma_data_piso_data_li = mem_cmd_li.data << cce_block_width_p'(mem_cmd_li.header.addr[0+:byte_offset_width_lp] << 3);
  assign dma_data_piso_mask_li = ((1 << (1 << mem_cmd_li.header.size)) - 1) << mem_cmd_li.header.addr[0+:byte_offset_width_lp];

  /********************* dram -> core *********************/

  // dma data sipo
  logic dma_data_sipo_v_lo, dma_data_sipo_yumi_li, dma_data_sipo_ready_lo;
  logic [cce_block_width_p-1:0] dma_data_sipo_data_lo;

  // resp async FIFO
  logic resp_afifo_v_lo, resp_afifo_deq_li, resp_afifo_full_lo;
  logic [data_width_p-1:0] resp_afifo_data_lo;
  logic [channel_addr_width_p-1:0] resp_afifo_ch_addr_lo;

  // data reorder FIFO
  logic reorder_alloc_v_lo, reorder_alloc_yumi_li;
  logic [lg_reorder_fifo_els_lp-1:0] reorder_alloc_id_lo;

  logic reorder_deq_v_lo, reorder_deq_yumi_li;
  logic [data_width_p-1:0] reorder_deq_data_lo;

  // reordering CAM
  logic cam_w_set_not_clear_i;
  logic [reorder_fifo_els_lp-1:0] cam_w_v_li, cam_r_match_lo;
  logic [channel_addr_width_p-1:0] cam_w_tag_li;

  // id decoder
  logic [reorder_fifo_els_lp-1:0] id_decode_lo;

  // id encoder
  logic id_encode_v_lo;
  logic [lg_reorder_fifo_els_lp-1:0] id_encode_lo;

  bsg_async_fifo
  #(.lg_size_p(2)
    ,.width_p(channel_addr_width_p+data_width_p)
  ) resp_afifo (
    .w_clk_i(dram_clk_i)
    ,.w_reset_i(dram_reset_i)
    ,.w_enq_i(dram_data_v_i)
    ,.w_data_i({dram_ch_addr_i, dram_data_i})
    ,.w_full_o(resp_afifo_full_lo)

    ,.r_clk_i(clk_i)
    ,.r_reset_i(reset_i)
    ,.r_deq_i(resp_afifo_deq_li)
    ,.r_data_o({resp_afifo_ch_addr_lo, resp_afifo_data_lo})
    ,.r_valid_o(resp_afifo_v_lo)
  );

  bsg_cam_1r1w_tag_array
 #(.els_p(reorder_fifo_els_lp)
  ,.width_p(channel_addr_width_p)
  ) id_cam
  (.clk_i(clk_i)
  ,.reset_i(reset_i)

  ,.w_v_i(cam_w_v_li)
  ,.w_set_not_clear_i(cam_w_set_not_clear_i)
  ,.w_tag_i(cam_w_tag_li)
  ,.w_empty_o()

  ,.r_v_i(resp_afifo_deq_li)
  ,.r_tag_i(resp_afifo_ch_addr_lo)
  ,.r_match_o(cam_r_match_lo)
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

  ,.write_v_i(id_encode_v_lo)
  ,.write_id_i(id_encode_lo)
  ,.write_data_i(resp_afifo_data_lo)

  ,.fifo_deq_v_o(reorder_deq_v_lo)
  ,.fifo_deq_data_o(reorder_deq_data_lo)
  ,.fifo_deq_yumi_i(reorder_deq_yumi_li)

  ,.empty_o()
  );

  bsg_serial_in_parallel_out_full
 #(.width_p(data_width_p)
  ,.els_p  (block_size_in_words_lp)
  ) dma_data_sipo
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)
  
  ,.v_i    (reorder_deq_v_lo)
  ,.ready_o(dma_data_sipo_ready_lo)
  ,.data_i (reorder_deq_data_lo)

  ,.data_o (dma_data_sipo_data_lo)
  ,.v_o    (dma_data_sipo_v_lo)
  ,.yumi_i (dma_data_sipo_yumi_li)
  );

  logic [cce_block_width_p-1:0] dma_data_packed_lo;
  bsg_bus_pack
   #(.width_p(cce_block_width_p))
   pack
    (.data_i(dma_data_sipo_data_lo)
     ,.sel_i(mem_resp_lo.header.addr[0+:`BSG_SAFE_CLOG2(cce_block_width_p/8)])
     ,.size_i(mem_resp_lo.header.size)
     ,.data_o(dma_data_packed_lo)
     );

  bsg_encode_one_hot
 #(.width_p(reorder_fifo_els_lp)
  ) id_enc
  (.i(cam_r_match_lo)
  ,.addr_o(id_encode_lo)
  ,.v_o(id_encode_v_lo)
  );

  bsg_decode
 #(.num_out_p(reorder_fifo_els_lp)
  ) id_dec
  (.i(reorder_alloc_id_lo)
  ,.o(id_decode_lo)
  );

  // queue FIFO
  wire is_write = mem_resp_lo.header.msg_type inside {e_mem_msg_uc_wr, e_mem_msg_wr};
  assign queue_fifo_yumi_li = mem_resp_v_o & mem_resp_yumi_i;

  // resp async FIFO
  // Cannot accept data when sending read requests
  assign resp_afifo_deq_li = ~reset_i & ~dram_reset_i & resp_afifo_v_lo & ~reorder_alloc_yumi_li;

  // ID -> address CAM
  assign cam_w_v_li = reorder_alloc_yumi_li
                      ? id_decode_lo
                      : resp_afifo_deq_li
                        ? cam_r_match_lo
                        : '0;
  assign cam_w_set_not_clear_i = reorder_alloc_yumi_li;
  assign cam_w_tag_li = word_addr_lo;

  // reorder FIFO
  assign reorder_alloc_yumi_li = req_afifo_enq_li & ~dma_fifo_write_not_read_lo;
  assign reorder_deq_yumi_li = reorder_deq_v_lo & dma_data_sipo_ready_lo;

  // data sipo
  assign dma_data_sipo_yumi_li = queue_fifo_yumi_li & ~is_write;

  // mem resp output
  assign mem_resp_lo.header = queue_fifo_data_lo;
  assign mem_resp_lo.data = is_write ? '0 : dma_data_packed_lo;
  assign mem_resp_v_o = queue_fifo_v_lo & (is_write | dma_data_sipo_v_lo);

  // resp data
  assign dram_data_ready_o = ~reset_i & ~dram_reset_i & ~resp_afifo_full_lo;

endmodule
