/*
 * bp_me_cce_to_cache.v
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_cce_to_cache

  import bp_common_pkg::*;
  import bp_me_pkg::*;
  import bsg_cache_pkg::*;

  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)

    , localparam lg_sets_lp=`BSG_SAFE_CLOG2(l2_sets_p)
    , localparam lg_ways_lp=`BSG_SAFE_CLOG2(l2_assoc_p)
    , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(l2_block_size_in_words_p)
    , localparam data_mask_width_lp=(l2_data_width_p>>3)
    , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(l2_data_width_p>>3)
    , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)

    , localparam bsg_cache_pkt_width_lp=`bsg_cache_pkt_width(caddr_width_p, l2_data_width_p)
    , localparam counter_width_lp=`BSG_SAFE_CLOG2(l2_block_size_in_fill_p)
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

    , input [l2_data_width_p-1:0]          data_i
    , input                               v_i
    , output logic                        yumi_o
  );

  // at the reset, this module intializes all the tags and valid bits to zero.
  // After all the tags are completedly initialized, this module starts
  // accepting packets from manycore network.
  `declare_bsg_cache_pkt_s(caddr_width_p, l2_data_width_p);

  // cce logics
  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce);
  `declare_bp_memory_map(paddr_width_p, caddr_width_p);

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

  bp_bedrock_cce_mem_msg_s mem_cmd_cast_i, mem_resp_cast_o;

  assign mem_cmd_cast_i = mem_cmd_i;
  assign mem_resp_o = mem_resp_cast_o;

  logic mem_cmd_ready_lo;
  bp_bedrock_cce_mem_msg_s mem_cmd_lo;
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
  wire [caddr_width_p-1:0] cmd_addr = mem_cmd_lo.header.addr;
  wire [l2_block_size_in_words_p-1:0][l2_data_width_p-1:0] cmd_data = mem_cmd_lo.data;

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

  logic is_resp_ready;

  bp_local_addr_s local_addr_cast;
  assign local_addr_cast = mem_cmd_lo.header.addr;

  wire cmd_word_op = (mem_cmd_lo.header.size == e_bedrock_msg_size_4);

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
          {(caddr_width_p-lg_sets_lp-lg_ways_lp-block_offset_width_lp){1'b0}},
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
        if (mem_cmd_v_lo & is_resp_ready)
          begin
            case (mem_cmd_lo.header.size)
              e_bedrock_msg_size_1
              ,e_bedrock_msg_size_2
              ,e_bedrock_msg_size_4
              ,e_bedrock_msg_size_8: cmd_max_count_n = '0;
              e_bedrock_msg_size_16: cmd_max_count_n = counter_width_lp'(1);
              e_bedrock_msg_size_32: cmd_max_count_n = counter_width_lp'(3);
              e_bedrock_msg_size_64: cmd_max_count_n = counter_width_lp'(7);
              default: cmd_max_count_n = '0;
            endcase
            cmd_state_n = SEND;
          end
      end
      SEND: begin
        v_o = 1'b1;
        case (mem_cmd_lo.header.msg_type)
          e_bedrock_mem_rd
          ,e_bedrock_mem_uc_rd:
            case (mem_cmd_lo.header.size)
              e_bedrock_msg_size_1: cache_pkt.opcode = LB;
              e_bedrock_msg_size_2: cache_pkt.opcode = LH;
              e_bedrock_msg_size_4: cache_pkt.opcode = LW;
              e_bedrock_msg_size_8
              ,e_bedrock_msg_size_16
              ,e_bedrock_msg_size_32
              ,e_bedrock_msg_size_64: cache_pkt.opcode = LM;
              default: cache_pkt.opcode = LB;
            endcase
          e_bedrock_mem_uc_wr
          ,e_bedrock_mem_wr
          ,e_bedrock_mem_amo:
            case (mem_cmd_lo.header.size)
              e_bedrock_msg_size_1: cache_pkt.opcode = SB;
              e_bedrock_msg_size_2: cache_pkt.opcode = SH;
              e_bedrock_msg_size_4, e_bedrock_msg_size_8:
                case (mem_cmd_lo.header.subop)
                  e_bedrock_store  : cache_pkt.opcode = cmd_word_op ? SW : SD;
                  e_bedrock_amoswap: cache_pkt.opcode = cmd_word_op ? AMOSWAP_W : AMOSWAP_D;
                  e_bedrock_amoadd : cache_pkt.opcode = cmd_word_op ? AMOADD_W : AMOADD_D;
                  e_bedrock_amoxor : cache_pkt.opcode = cmd_word_op ? AMOXOR_W : AMOXOR_D;
                  e_bedrock_amoand : cache_pkt.opcode = cmd_word_op ? AMOAND_W : AMOAND_D;
                  e_bedrock_amoor  : cache_pkt.opcode = cmd_word_op ? AMOOR_W : AMOOR_D;
                  e_bedrock_amomin : cache_pkt.opcode = cmd_word_op ? AMOMIN_W : AMOMIN_D;
                  e_bedrock_amomax : cache_pkt.opcode = cmd_word_op ? AMOMAX_W : AMOMAX_D;
                  e_bedrock_amominu: cache_pkt.opcode = cmd_word_op ? AMOMINU_W : AMOMINU_D;
                  e_bedrock_amomaxu: cache_pkt.opcode = cmd_word_op ? AMOMAXU_W : AMOMAXU_D;
                  default : begin end
                endcase
              e_bedrock_msg_size_16
              ,e_bedrock_msg_size_32
              ,e_bedrock_msg_size_64: cache_pkt.opcode = SM;
              default: cache_pkt.opcode = LB;
            endcase
          default: cache_pkt.opcode = LB;
        endcase

        if ((mem_cmd_lo.header.addr < dram_base_addr_gp) && (local_addr_cast.dev == cache_tagfl_base_addr_gp))
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

  logic [l2_data_width_p-1:0] resp_data_n;
  logic [l2_block_size_in_words_p-1:0][l2_data_width_p-1:0] resp_data_r;

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

  wire [cce_block_width_p-1:0] resp_data_slice = resp_data_r;
  bsg_bus_pack
   #(.width_p(cce_block_width_p))
   repl_mux
    (.data_i(resp_data_slice)
     // Response data is always aggregated from zero in this module
     ,.sel_i('0)
     ,.size_i(mem_resp_cast_o.header.size)
     ,.data_o(mem_resp_cast_o.data)
     );

  always_comb begin
    yumi_o = 1'b0;
    is_resp_ready = 1'b0;

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
        is_resp_ready = 1'b1;
        if (mem_cmd_v_lo)
          begin
            case (mem_cmd_lo.header.size)
              e_bedrock_msg_size_1
              ,e_bedrock_msg_size_2
              ,e_bedrock_msg_size_4
              ,e_bedrock_msg_size_8: resp_max_count_n = '0;
              e_bedrock_msg_size_16: resp_max_count_n = counter_width_lp'(1);
              e_bedrock_msg_size_32: resp_max_count_n = counter_width_lp'(3);
              e_bedrock_msg_size_64: resp_max_count_n = counter_width_lp'(7);
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

  //synopsys translate_off
  always_ff @(negedge clk_i)
    begin
      if (mem_cmd_v_lo & mem_cmd_lo.header.msg_type inside {e_bedrock_mem_wr, e_bedrock_mem_uc_wr})
        assert (~(mem_cmd_lo.header.subop inside {e_bedrock_amolr, e_bedrock_amosc}))
          else $error("LR/SC not supported in bsg_cache");
    end
  //synopsys translate_on


endmodule
