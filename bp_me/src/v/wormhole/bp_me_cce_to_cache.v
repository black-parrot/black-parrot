/*
 * bp_me_cce_to_cache.v
 *
 * Paul Gao   10/2019
 *
 */
 
`include "bp_me_cce_mem_if.vh"

module bp_me_cce_to_cache

  import bp_cce_pkg::*;
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_me_pkg::*;
  import bsg_cache_pkg::*;

  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

    , parameter addr_width_p=paddr_width_p
    , parameter data_width_p=dword_width_p
    , parameter sets_p="inv"
    , parameter ways_p="inv"
    , parameter block_size_in_words_p=cce_block_width_p/dword_width_p

    , parameter lg_sets_lp=`BSG_SAFE_CLOG2(sets_p)
    , parameter lg_ways_lp=`BSG_SAFE_CLOG2(ways_p)
    , parameter word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_p)
    , parameter data_mask_width_lp=(data_width_p>>3)
    , parameter byte_offset_width_lp=`BSG_SAFE_CLOG2(data_width_p>>3)
    , parameter cache_addr_width_lp=addr_width_p
    , parameter block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
    
    , parameter bsg_cache_pkt_width_lp=`bsg_cache_pkt_width(cache_addr_width_lp,data_width_p)
    , parameter counter_width_lp=`BSG_SAFE_CLOG2(cce_block_width_p/dword_width_p)
  )
  (
    input clk_i
    , input reset_i

    // manycore-side
    , input  [cce_mem_msg_width_lp-1:0]   mem_cmd_i
    , input                               mem_cmd_v_i
    , output                              mem_cmd_yumi_o
                                          
    , output [cce_mem_msg_width_lp-1:0]   mem_resp_o
    , output                              mem_resp_v_o
    , input                               mem_resp_ready_i

    // cache-side
    , output [bsg_cache_pkt_width_lp-1:0] cache_pkt_o
    , output logic                        v_o
    , input                               ready_i

    , input [data_width_p-1:0]            data_i
    , input                               v_i
    , output logic                        yumi_o
  );

  // at the reset, this module intializes all the tags and valid bits to zero.
  // After all the tags are completedly initialized, this module starts
  // accepting packets from manycore network.
  `declare_bsg_cache_pkt_s(cache_addr_width_lp, data_width_p);
  
  // cce logics
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p);
  
  bsg_cache_pkt_s cache_pkt;
  assign cache_pkt_o = cache_pkt;

  typedef enum logic [1:0] {
    RESET
    ,CLEAR_TAG
    ,READY
    ,SEND
  } cmd_state_e;

  cmd_state_e cmd_state_r, cmd_state_n;
  logic [lg_sets_lp+lg_ways_lp:0] tagst_sent_r, tagst_sent_n;
  logic [lg_sets_lp+lg_ways_lp:0] tagst_received_r, tagst_received_n;
  logic [counter_width_lp-1:0] cmd_counter_r, cmd_counter_n;
  logic [counter_width_lp-1:0] cmd_max_count_r, cmd_max_count_n;
  
  bp_cce_mem_msg_s mem_cmd;
  logic mem_cmd_yumi_lo;
  
  assign mem_cmd = mem_cmd_i;
  assign mem_cmd_yumi_o = mem_cmd_yumi_lo;
  
  logic [block_size_in_words_p-1:0][dword_width_p-1:0] cmd_data;
  assign cmd_data = mem_cmd.data;
  
  
  logic small_fifo_v_li, small_fifo_ready_lo;
  logic small_fifo_v_lo, small_fifo_yumi_li;
  bp_cce_mem_msg_s mem_resp;
  
  bsg_fifo_1r1w_small
 #(.width_p(cce_mem_msg_width_lp-cce_block_width_p)
  ,.els_p(8)
  ) small_fifo
  (.clk_i(clk_i)
  ,.reset_i(reset_i)
  ,.v_i(small_fifo_v_li)
  ,.data_i({mem_cmd.msg_type, mem_cmd.addr, mem_cmd.size, mem_cmd.payload})
  ,.ready_o(small_fifo_ready_lo)
  ,.v_o(small_fifo_v_lo)
  ,.data_o({mem_resp.msg_type, mem_resp.addr, mem_resp.size, mem_resp.payload})
  ,.yumi_i(small_fifo_yumi_li)
  );
  

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      cmd_state_r      <= RESET;
      tagst_sent_r     <= '0;
      tagst_received_r <= '0;
      cmd_counter_r    <= '0;
      cmd_max_count_r  <= '0;
    end
    else begin
      cmd_state_r      <= cmd_state_n;
      tagst_sent_r     <= tagst_sent_n;
      tagst_received_r <= tagst_received_n;
      cmd_counter_r    <= cmd_counter_n;
      cmd_max_count_r  <= cmd_max_count_n;
    end
  end

  always_comb begin
    cache_pkt.mask = '0;
    cache_pkt.data = '0;
    cache_pkt.addr = '0;
    cache_pkt.opcode = TAGST;
    tagst_sent_n = tagst_sent_r;
    tagst_received_n = tagst_received_r;
    v_o = 1'b0;
    mem_cmd_yumi_lo = 1'b0;
    small_fifo_v_li = 1'b0;
    
    cmd_state_n = cmd_state_r;
    cmd_counter_n = cmd_counter_r;
    cmd_max_count_n = cmd_max_count_r;

    case (cmd_state_r)
      RESET: begin
        cmd_state_n = CLEAR_TAG;
      end
      CLEAR_TAG: begin
        v_o = tagst_sent_r != (ways_p*sets_p);
        
        cache_pkt.opcode = TAGST;
        cache_pkt.data = '0;
        cache_pkt.addr = {
          {(cache_addr_width_lp-lg_sets_lp-lg_ways_lp-block_offset_width_lp){1'b0}},
          tagst_sent_r[0+:lg_sets_lp+lg_ways_lp],
          {(block_offset_width_lp){1'b0}}
        };

        tagst_sent_n = (v_o & ready_i)
          ? tagst_sent_r + 1
          : tagst_sent_r;
        tagst_received_n = v_i
          ? tagst_received_r + 1
          : tagst_received_r;

        cmd_state_n = (tagst_sent_r == ways_p*sets_p) & (tagst_received_r == ways_p*sets_p)
          ? READY
          : CLEAR_TAG;
      end
      READY: begin
        if (mem_cmd_v_i & small_fifo_ready_lo)
          begin
            case (mem_cmd.size)
              e_mem_size_1
              ,e_mem_size_2
              ,e_mem_size_4
              ,e_mem_size_8: cmd_max_count_n = '0;
              e_mem_size_16: cmd_max_count_n = counter_width_lp'(1);
              e_mem_size_32: cmd_max_count_n = counter_width_lp'(3);
              e_mem_size_64: cmd_max_count_n = counter_width_lp'(7);
              default: cmd_max_count_n = '0;
            endcase
            small_fifo_v_li = 1'b1;
            cmd_state_n = SEND;
          end
      end
      SEND: begin
        v_o = 1'b1;
        case (mem_cmd.msg_type)
          e_cce_mem_rd
          ,e_cce_mem_wr
          ,e_cce_mem_uc_rd: cache_pkt.opcode = LM;
          e_cce_mem_uc_wr
          ,e_cce_mem_wb   : cache_pkt.opcode = SM;
          default: cache_pkt.opcode = LB;
        endcase
        cache_pkt.data = cmd_data[cmd_counter_r];
        cache_pkt.addr = mem_cmd.addr + cmd_counter_r*data_mask_width_lp;
        case (mem_cmd.size)
          e_mem_size_1: cache_pkt.mask = data_mask_width_lp'(1'b1);
          e_mem_size_2: cache_pkt.mask = data_mask_width_lp'(2'b11);
          e_mem_size_4: cache_pkt.mask = data_mask_width_lp'(4'b1111);
          e_mem_size_8
          ,e_mem_size_16
          ,e_mem_size_32
          ,e_mem_size_64: cache_pkt.mask = '1;
          default: cache_pkt.mask = '0;
        endcase
        if (ready_i)
          begin
            cmd_counter_n = cmd_counter_r + 1;
            if (cmd_counter_r == cmd_max_count_r)
              begin
                mem_cmd_yumi_lo = 1'b1;
                cmd_counter_n = '0;
                cmd_state_n = READY;
              end
          end
      end
    endcase
  end
  
  
  typedef enum logic [1:0] {
    RESP_RESET
    ,RESP_READY
    ,RESP_RECEIVE
    ,RESP_SEND
  } resp_state_e;

  resp_state_e resp_state_r, resp_state_n;
  logic [counter_width_lp-1:0] resp_counter_r, resp_counter_n;
  logic [counter_width_lp-1:0] resp_max_count_r, resp_max_count_n;
  
  logic mem_resp_v_lo;
  
  assign mem_resp_o = mem_resp;
  assign mem_resp_v_o = mem_resp_v_lo;
  
  logic [dword_width_p-1:0] resp_data_n;
  logic [block_size_in_words_p-1:0][dword_width_p-1:0] resp_data_r;
  assign mem_resp.data = resp_data_r;
  

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      resp_state_r      <= RESP_RESET;
      resp_counter_r    <= '0;
      resp_max_count_r  <= '0;
    end
    else begin
      resp_state_r      <= resp_state_n;
      resp_counter_r    <= resp_counter_n;
      resp_max_count_r  <= resp_max_count_n;
      resp_data_r[resp_counter_r] <= resp_data_n;
    end
  end

  always_comb begin
    mem_resp_v_lo = 1'b0;
    yumi_o = 1'b0;
    small_fifo_yumi_li = 1'b0;
    
    resp_state_n = resp_state_r;
    resp_counter_n = resp_counter_r;
    resp_max_count_n = resp_max_count_r;
    resp_data_n = resp_data_r[resp_counter_r];

    case (resp_state_r)
      RESP_RESET: begin
        resp_state_n = RESP_READY;
      end
      RESP_READY: begin
        if (small_fifo_v_lo)
          begin
            case (mem_resp.size)
              e_mem_size_1
              ,e_mem_size_2
              ,e_mem_size_4
              ,e_mem_size_8: resp_max_count_n = '0;
              e_mem_size_16: resp_max_count_n = counter_width_lp'(1);
              e_mem_size_32: resp_max_count_n = counter_width_lp'(3);
              e_mem_size_64: resp_max_count_n = counter_width_lp'(7);
              default: resp_max_count_n = '0;
            endcase
            resp_state_n = RESP_RECEIVE;
          end
        else
          begin
            yumi_o = v_i;
          end
      end
      RESP_RECEIVE: begin
        if (v_i)
          begin
            yumi_o = 1'b1;
            resp_data_n = data_i;
            resp_counter_n = resp_counter_r + 1;
            if (resp_counter_r == resp_max_count_r)
              begin
                resp_counter_n = '0;
                resp_state_n = RESP_SEND;
              end
          end
      end
      RESP_SEND: begin
        mem_resp_v_lo = 1'b1;
        if (mem_resp_ready_i)
          begin
            small_fifo_yumi_li = 1'b1;
            resp_state_n = RESP_READY;
          end
      end
    endcase
  end
  

endmodule
