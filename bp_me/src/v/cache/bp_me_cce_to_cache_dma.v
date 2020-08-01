// 
// bp_me_cce_to_cache_dma.v
// 
// 

`include "bp_common_mem_if.vh"

module bp_me_cce_to_cache_dma

  import bp_cce_pkg::*;
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_me_pkg::*;
  
  import bsg_cache_pkg::*;
  
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce_mem)
  
  ,localparam block_size_in_words_lp = cce_block_width_p / dword_width_p
  ,localparam block_offset_width_lp = `BSG_SAFE_CLOG2(cce_block_width_p >> 3)
  ,localparam bsg_cache_dma_pkt_width_lp = `bsg_cache_dma_pkt_width(paddr_width_p)
  )
  
  (// Cache DMA side
   input                                           clk_i
  ,input                                           reset_i
  // Sending address and write_en               
  ,output       [bsg_cache_dma_pkt_width_lp-1:0]   dma_pkt_o
  ,output                                          dma_pkt_v_o
  ,input                                           dma_pkt_yumi_i
  // Sending cache block                                          
  ,output       [dword_width_p-1:0]                dma_data_o
  ,output                                          dma_data_v_o
  ,input                                           dma_data_yumi_i
  // Receiving cache block                                        
  ,input        [dword_width_p-1:0]                dma_data_i
  ,input                                           dma_data_v_i
  ,output                                          dma_data_ready_o
  // Cmd input
  ,input        [cce_mem_msg_width_lp-1:0]         mem_cmd_i
  ,input                                           mem_cmd_v_i
  ,output                                          mem_cmd_yumi_o
  // Resp output
  ,output       [cce_mem_msg_width_lp-1:0]         mem_resp_o
  ,output                                          mem_resp_v_o
  ,input                                           mem_resp_ready_i
  );
  
  genvar i;
  localparam fifo_depth_lp = 16;
  localparam fifo_width_lp = cce_mem_msg_width_lp - cce_block_width_p;
  
  /********************* Packet definition *********************/
  
  // Define cache DMA packet
  `declare_bsg_cache_dma_pkt_s(paddr_width_p);
  
  // cce
  `declare_bp_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce_mem);
  
  
  /********************* Resp queue fifo *********************/
  
  // Stores CCE packet header information
  logic queue_fifo_valid_li, queue_fifo_ready_lo;
  logic [fifo_width_lp-1:0] queue_fifo_data_li;
  
  logic queue_fifo_valid_lo, queue_fifo_yumi_li;
  logic [fifo_width_lp-1:0] queue_fifo_data_lo;
  
  bsg_fifo_1r1w_small
 #(.width_p(fifo_width_lp)
  ,.els_p  (fifo_depth_lp)
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
  
  bsg_two_fifo
 #(.width_p(bsg_cache_dma_pkt_width_lp)
  ) dma_pkt_fifo
  (.clk_i  (clk_i  )
  ,.reset_i(reset_i)
  ,.ready_o(dma_pkt_fifo_ready_lo)
  ,.data_i (dma_pkt_fifo_data_li )
  ,.v_i    (dma_pkt_fifo_valid_li)
  ,.v_o    (dma_pkt_v_o          )
  ,.data_o (dma_pkt_o            )
  ,.yumi_i (dma_pkt_yumi_i       )
  );
  
  // dma data piso
  logic dma_data_fifo_valid_li, dma_data_fifo_ready_lo;
  logic [cce_block_width_p-1:0] dma_data_fifo_data_li;
  
  bsg_parallel_in_serial_out 
 #(.width_p(dword_width_p)
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
  logic mem_cmd_yumi_lo;
  
  assign mem_cmd_li = mem_cmd_i;
  assign mem_cmd_yumi_o = mem_cmd_yumi_lo;
  
  // combinational logics
  always_comb 
  begin
  
    mem_cmd_yumi_lo = 1'b0;
    dma_pkt_fifo_valid_li = 1'b0;
    dma_data_fifo_valid_li = 1'b0;
    queue_fifo_valid_li = 1'b0;
    
    dma_pkt_fifo_data_li.write_not_read = (mem_cmd_li.header.msg_type == e_mem_msg_wr);
    dma_pkt_fifo_data_li.addr = mem_cmd_li.header.addr;
    dma_data_fifo_data_li = mem_cmd_li.data;
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
                mem_cmd_yumi_lo = 1'b1;
              end
          end
        else
          begin
            dma_pkt_fifo_valid_li = 1'b1;
            queue_fifo_valid_li = 1'b1;
            mem_cmd_yumi_lo = 1'b1;
          end
      end
  
  end
  
  
  /********************* cache_dma -> cce *********************/
  
  // dma data sipof
  logic dma_data_fifo_valid_lo, dma_data_fifo_yumi_li;
  logic [cce_block_width_p-1:0] dma_data_fifo_data_lo;
  
  bsg_serial_in_parallel_out_full
 #(.width_p(dword_width_p         )
  ,.els_p  (block_size_in_words_lp)
  ) dma_data_sipof
  (.clk_i  (clk_i  )
  ,.reset_i(reset_i)
  
  ,.v_i    (dma_data_v_i)
  ,.ready_o(dma_data_ready_o)
  ,.data_i (dma_data_i)

  ,.data_o (dma_data_fifo_data_lo )
  ,.v_o    (dma_data_fifo_valid_lo)
  ,.yumi_i (dma_data_fifo_yumi_li)
  );
  
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
        if (mem_resp_lo.header.msg_type == e_mem_msg_wr)
          begin
            mem_resp_lo.data = '0;
            mem_resp_v_lo = 1'b1;
            if (mem_resp_ready_i)
              begin
                queue_fifo_yumi_li = 1'b1;
              end
          end
        else
          begin
            if (dma_data_fifo_valid_lo)
              begin
                mem_resp_v_lo = 1'b1;
                if (mem_resp_ready_i)
                  begin
                    queue_fifo_yumi_li = 1'b1;
                    dma_data_fifo_yumi_li = 1'b1;
                  end
              end
          end
      end
    
  end
  
endmodule
