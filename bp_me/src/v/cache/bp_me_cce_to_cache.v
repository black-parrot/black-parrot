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
    `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

    , parameter block_size_in_words_lp=cce_block_width_p/dword_width_p
    , parameter lg_sets_lp=`BSG_SAFE_CLOG2(l2_sets_p)
    , parameter lg_ways_lp=`BSG_SAFE_CLOG2(l2_assoc_p)
    , parameter word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)
    , parameter data_mask_width_lp=(dword_width_p>>3)
    , parameter byte_offset_width_lp=`BSG_SAFE_CLOG2(dword_width_p>>3)
    , parameter block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
    
    , parameter bsg_cache_pkt_width_lp=`bsg_cache_pkt_width(paddr_width_p,dword_width_p)
    , parameter counter_width_lp=`BSG_SAFE_CLOG2(cce_block_width_p/dword_width_p)
  )
  (
    input clk_i
    , input reset_i

    // manycore-side
    , input  [cce_mem_msg_width_lp-1:0]   mem_cmd_i
    , input                               mem_cmd_v_i
    , output logic                        mem_cmd_ready_o
                                          
    , output [cce_mem_msg_width_lp-1:0]   mem_resp_o
    , output logic                        mem_resp_v_o
    , input                               mem_resp_yumi_i

    // cache-side
    , output [bsg_cache_pkt_width_lp-1:0] cache_pkt_o
    , output logic                        v_o
    , input                               ready_i

    , input [dword_width_p-1:0]           data_i
    , input                               v_i
    , output logic                        yumi_o
  );

  // at the reset, this module intializes all the tags and valid bits to zero.
  // After all the tags are completedly initialized, this module starts
  // accepting packets from manycore network.
  `declare_bsg_cache_pkt_s(paddr_width_p, dword_width_p);
  
  // cce logics
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);
  
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
  
  bp_cce_mem_msg_s mem_cmd_cast_i, mem_resp_cast_o;
  
  assign mem_cmd_cast_i = mem_cmd_i;
  assign mem_resp_o = mem_resp_cast_o;
  
  logic mem_cmd_ready_lo;
  bp_cce_mem_msg_s mem_cmd_lo;
  logic mem_cmd_v_lo, mem_cmd_yumi_li;
  bsg_fifo_1r1w_small
   #(.width_p(cce_mem_msg_width_lp), .els_p(l2_outstanding_reqs_p))
   cmd_fifo
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.data_i(mem_cmd_i)
    ,.v_i(mem_cmd_v_i)
    ,.ready_o(mem_cmd_ready_lo)

    ,.data_o(mem_cmd_lo)
    ,.v_o(mem_cmd_v_lo)
    ,.yumi_i(mem_cmd_yumi_li)
    );
  wire [paddr_width_p-1:0] cmd_addr = mem_cmd_lo.header.addr;
  wire [block_size_in_words_lp-1:0][dword_width_p-1:0] cmd_data = mem_cmd_lo.data;

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

    mem_cmd_ready_o = mem_cmd_ready_lo;
    mem_cmd_yumi_li = 1'b0;
    
    cmd_state_n = cmd_state_r;
    cmd_counter_n = cmd_counter_r;
    cmd_max_count_n = cmd_max_count_r;

    case (cmd_state_r)
      RESET: begin
        mem_cmd_ready_o = 1'b0;

        cmd_state_n = CLEAR_TAG;
      end
      CLEAR_TAG: begin
        mem_cmd_ready_o = 1'b0;

        v_o = tagst_sent_r != (l2_assoc_p*l2_sets_p);
        
        cache_pkt.opcode = TAGST;
        cache_pkt.data = '0;
        cache_pkt.addr = {
          {(paddr_width_p-lg_sets_lp-lg_ways_lp-block_offset_width_lp){1'b0}},
          tagst_sent_r[0+:lg_sets_lp+lg_ways_lp],
          {(block_offset_width_lp){1'b0}}
        };

        tagst_sent_n = (v_o & ready_i)
          ? tagst_sent_r + 1
          : tagst_sent_r;
        tagst_received_n = v_i
          ? tagst_received_r + 1
          : tagst_received_r;

        cmd_state_n = (tagst_sent_r == l2_assoc_p*l2_sets_p) & (tagst_received_r == l2_assoc_p*l2_sets_p)
          ? READY
          : CLEAR_TAG;
      end
      READY: begin
        // Technically possible to bypass and save a cycle
        if (mem_cmd_v_lo)
          begin
            case (mem_cmd_lo.header.size)
              e_mem_size_1
              ,e_mem_size_2
              ,e_mem_size_4
              ,e_mem_size_8: cmd_max_count_n = '0;
              e_mem_size_16: cmd_max_count_n = counter_width_lp'(1);
              e_mem_size_32: cmd_max_count_n = counter_width_lp'(3);
              e_mem_size_64: cmd_max_count_n = counter_width_lp'(7);
              default: cmd_max_count_n = '0;
            endcase
            cmd_state_n = SEND;
          end
      end
      SEND: begin
        v_o = 1'b1;
        case (mem_cmd_lo.header.msg_type)
          e_cce_mem_rd
          ,e_cce_mem_wr
          ,e_cce_mem_uc_rd:
            case (mem_cmd_lo.header.size)
              e_mem_size_1: cache_pkt.opcode = LB;
              e_mem_size_2: cache_pkt.opcode = LH;
              e_mem_size_4: cache_pkt.opcode = LW;
              e_mem_size_8
              ,e_mem_size_16
              ,e_mem_size_32
              ,e_mem_size_64: cache_pkt.opcode = LM;
              default: cache_pkt.opcode = LB;
            endcase
          e_cce_mem_uc_wr
          ,e_cce_mem_wb   :
            case (mem_cmd_lo.header.size)
              e_mem_size_1: cache_pkt.opcode = SB;
              e_mem_size_2: cache_pkt.opcode = SH;
              e_mem_size_4: cache_pkt.opcode = SW;
              e_mem_size_8
              ,e_mem_size_16
              ,e_mem_size_32
              ,e_mem_size_64: cache_pkt.opcode = SM;
              default: cache_pkt.opcode = LB;
            endcase
          default: cache_pkt.opcode = LB;
        endcase

        if ((mem_cmd_lo.header.addr < 32'h8000_0000) && (mem_cmd_lo.header.addr[0+:20] == cache_tagfl_base_addr_gp))
          begin
            cache_pkt.opcode = TAGFL;
            cache_pkt.addr = {cmd_data[0][0+:lg_sets_lp+lg_ways_lp], block_offset_width_lp'(0)};
          end
        else
          begin
            cache_pkt.data = cmd_data[cmd_counter_r];
            cache_pkt.addr = cmd_addr + cmd_counter_r*data_mask_width_lp;
            cache_pkt.mask = '1;
          end

        if (ready_i)
          begin
            cmd_counter_n = cmd_counter_r + 1;
            if (cmd_counter_r == cmd_max_count_r)
              begin
                cmd_counter_n = '0;
                cmd_state_n = READY;
                mem_cmd_yumi_li = 1'b1;
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
  
  logic [dword_width_p-1:0] resp_data_n;
  logic [block_size_in_words_lp-1:0][dword_width_p-1:0] resp_data_r;

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

  bsg_dff_en
   #(.width_p(cce_mem_msg_width_lp-cce_block_width_p))
   resp_header_reg
    (.clk_i(clk_i)
     ,.en_i(mem_cmd_yumi_li)

     ,.data_i(mem_cmd_lo.header)
     ,.data_o(mem_resp_cast_o.header)
     );
  assign mem_resp_cast_o.data = resp_data_r;

  always_comb begin
    yumi_o = 1'b0;
    
    resp_state_n = resp_state_r;
    resp_counter_n = resp_counter_r;
    resp_max_count_n = resp_max_count_r;
    resp_data_n = resp_data_r[resp_counter_r];

    mem_resp_v_o = 1'b0;

    case (resp_state_r)
      RESP_RESET: begin
        resp_state_n = RESP_READY;
      end
      RESP_READY: begin
        if (mem_cmd_v_lo)
          begin
            case (mem_cmd_lo.header.size)
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
        mem_resp_v_o = 1'b1;
        if (mem_resp_yumi_i)
          begin
            resp_state_n = RESP_READY;
          end
      end
    endcase
  end
  

endmodule
