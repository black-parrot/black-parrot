/*
 * bp_me_cce_to_cache.v
 *
 * 
  Data width conversion diagram
                    -----------------------------------------
      mem_cmd_i -->| --> pump_in --->  cache_pkt_sel --->    |--> cache_pkt_p
                   |                       |                 |
  (mem_data_width) |   (mem_data_width)    | (l2_data_width) |  (l2_data_width)
                   |                       |                 |
     mem_resp_o <--| <-- pump_out <--  bsg_bus_pack <----    |<-- data_i
                    -----------------------------------------
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

    , parameter mem_data_width_p = cce_block_width_p

    , localparam lg_sets_lp=`BSG_SAFE_CLOG2(l2_sets_p)
    , localparam lg_ways_lp=`BSG_SAFE_CLOG2(l2_assoc_p)
    , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(l2_block_size_in_words_p)
    , localparam data_mask_width_lp=(l2_data_width_p>>3)
    , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(l2_data_width_p>>3)
    , localparam block_offset_width_lp= (l2_block_size_in_words_p>1) ? (word_offset_width_lp+byte_offset_width_lp) : byte_offset_width_lp
    
    , localparam bsg_cache_pkt_width_lp=`bsg_cache_pkt_width(caddr_width_p, l2_data_width_p)

    , localparam min_fill_width_lp = `BSG_MIN(`BSG_MIN(icache_fill_width_p, dcache_fill_width_p), `BSG_MIN(acache_fill_width_p, mem_data_width_p)) 
  )
  (
    input clk_i
    , input reset_i

    // Stream interface
    , input  [cce_mem_msg_header_width_lp-1:0] mem_cmd_header_i
    , input  [mem_data_width_p-1:0]            mem_cmd_data_i
    , input                                    mem_cmd_v_i
    , output logic                             mem_cmd_ready_and_o
    , input                                    mem_cmd_last_i

    , output [cce_mem_msg_header_width_lp-1:0] mem_resp_header_o
    , output [mem_data_width_p-1:0]            mem_resp_data_o
    , output logic                             mem_resp_v_o
    , input                                    mem_resp_ready_and_i
    , output logic                             mem_resp_last_o

    // cache-side
    , output [bsg_cache_pkt_width_lp-1:0]      cache_pkt_o
    , output logic                             cache_pkt_v_o
    , input                                    cache_pkt_ready_i

    , input [l2_data_width_p-1:0]              cache_data_i
    , input                                    cache_v_i
    , output logic                             cache_yumi_o
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
    ,STREAM
  } cmd_state_e;

  cmd_state_e cmd_state_r, cmd_state_n;
  wire is_reset  = (cmd_state_r == RESET);
  wire is_clear  = (cmd_state_r == CLEAR_TAG);
  wire is_ready  = (cmd_state_r == READY);
  wire is_stream = (cmd_state_r == STREAM);

  logic [lg_sets_lp+lg_ways_lp:0] tagst_sent_r, tagst_sent_n;
  logic [lg_sets_lp+lg_ways_lp:0] tagst_received_r, tagst_received_n;

  bp_bedrock_cce_mem_msg_header_s mem_cmd_header_lo;
  logic [mem_data_width_p-1:0] mem_cmd_data_lo, mem_resp_data_lo;
  logic [l2_data_width_p-1:0] cache_pkt_data_lo;
  logic mem_cmd_v_lo, mem_cmd_ready_and_li;
  logic mem_cmd_stream_new_lo, mem_cmd_done_lo;
  logic [paddr_width_p-1:0] mem_cmd_stream_addr_lo;
  logic [data_mask_width_lp-1:0] cache_pkt_mask_lo;
  bp_stream_pump_in
   #(.bp_params_p(bp_params_p)
   ,.stream_data_width_p(mem_data_width_p)
   ,.block_width_p(cce_block_width_p)
   ,.stream_mask_p(mem_stream_wr_mask_gp | mem_stream_rd_mask_gp))
   cce_to_cache_pump_in
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.mem_header_i(mem_cmd_header_i)
    ,.mem_data_i(mem_cmd_data_i)
    ,.mem_v_i(mem_cmd_v_i)
    ,.mem_last_i(mem_cmd_last_i)
    ,.mem_ready_and_o(mem_cmd_ready_and_o)

    ,.fsm_base_header_o(mem_cmd_header_lo)
    ,.fsm_addr_o(mem_cmd_stream_addr_lo)
    ,.fsm_data_o(mem_cmd_data_lo)
    ,.fsm_v_o(mem_cmd_v_lo)
    ,.fsm_ready_and_i(mem_cmd_ready_and_li)

    ,.stream_new_o(mem_cmd_stream_new_lo)
    ,.stream_done_o(mem_cmd_done_lo)
    );

  bp_local_addr_s local_addr_cast;
  assign local_addr_cast = mem_cmd_header_lo.addr;

  wire cmd_word_op = (mem_cmd_header_lo.size == e_bedrock_msg_size_4);

  wire is_read  = mem_cmd_header_lo.msg_type inside {e_bedrock_mem_uc_rd, e_bedrock_mem_rd};
  wire is_write = mem_cmd_header_lo.msg_type inside {e_bedrock_mem_uc_wr, e_bedrock_mem_wr};
  wire is_csr   = (mem_cmd_header_lo.addr < dram_base_addr_gp);
  wire is_tagfl = is_csr && (local_addr_cast.dev == cache_tagfl_base_addr_gp);
  wire [caddr_width_p-1:0] tagfl_addr = {mem_cmd_data_lo[0+:lg_sets_lp+lg_ways_lp], block_offset_width_lp'(0)};


  // Replicate data & Generate mask for partial SM
  // cache_pkt_data_lo = '1 & cache_pkt_mask_lo = ‘1 when min_fill_width_lp == l2_data_width_p
  localparam fill_offset_lp = `BSG_SAFE_CLOG2(min_fill_width_lp >> 3);
  localparam cache_size_in_fill_lp = l2_data_width_p/min_fill_width_lp;
  localparam lg_cache_size_in_fill_lp = (cache_size_in_fill_lp > 1) ? $clog2(cache_size_in_fill_lp) : 0;
  localparam data_sel_mux_els_lp = lg_cache_size_in_fill_lp+1;

  logic [data_sel_mux_els_lp-1:0][data_mask_width_lp-1:0] cache_pkt_mask_mux_li;
  logic [data_sel_mux_els_lp-1:0][l2_data_width_p-1:0] cache_pkt_data_mux_li;
  for (genvar i = 0; i < data_sel_mux_els_lp; i++) 
    begin:cache_pkt_sel
      localparam slice_width_lp = (min_fill_width_lp*(2**i));

      // Data
      logic [slice_width_lp-1:0] slice_data;
      assign slice_data = mem_cmd_data_lo[0+:slice_width_lp];
      assign cache_pkt_data_mux_li[i] = {(l2_data_width_p/slice_width_lp){slice_data}};

      // Mask
      if (i == data_sel_mux_els_lp-1) 
        begin: max_size
          assign cache_pkt_mask_mux_li[i] = {data_mask_width_lp{1'b1}};    
        end 
      else 
        begin: non_max_size
          
          logic [(l2_data_width_p/slice_width_lp)-1:0] decode_lo;
          bsg_decode 
           #(.num_out_p(l2_data_width_p/slice_width_lp)) 
           mask_decode 
            (.i(mem_cmd_stream_addr_lo[(i+fill_offset_lp)+:`BSG_MAX(lg_cache_size_in_fill_lp-i,1)])
            ,.o(decode_lo)
            );

          bsg_expand_bitmask 
           #(.in_width_p(l2_data_width_p/slice_width_lp)
           ,.expand_p(2**(i+fill_offset_lp))) 
           mask_expand 
            (.i(decode_lo)
            ,.o(cache_pkt_mask_mux_li[i])
          );
        end
    end

  wire [`BSG_SAFE_CLOG2(data_sel_mux_els_lp)-1:0] cache_pkt_data_sel_li = `BSG_MAX(mem_cmd_header_lo.size - fill_offset_lp, 1'b0);
  bsg_mux 
   #(.width_p(data_mask_width_lp)
   ,.els_p(data_sel_mux_els_lp)) 
   cache_pkt_mask_mux 
    (.data_i(cache_pkt_mask_mux_li)
    ,.sel_i(cache_pkt_data_sel_li)
    ,.data_o(cache_pkt_mask_lo)
    );

  bsg_mux 
   #(.width_p(l2_data_width_p)
   ,.els_p(data_sel_mux_els_lp))
   cache_pkt_data_mux 
    (.data_i(cache_pkt_data_mux_li)
    ,.sel_i(cache_pkt_data_sel_li)
    ,.data_o(cache_pkt_data_lo)
    );

  bp_bedrock_cce_mem_msg_header_s mem_resp_header_li, mem_resp_header_lo;
  logic mem_resp_v_li, mem_resp_ready_lo;
  logic mem_resp_v_lo, mem_resp_ready_and_lo; 
  logic mem_resp_done_lo;
  bsg_fifo_1r1w_small
   #(.width_p($bits(bp_bedrock_cce_mem_msg_header_s)), .els_p(4))
   stream_fifo
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.data_i(mem_resp_header_li)
    ,.v_i(mem_resp_v_li)
    ,.ready_o(mem_resp_ready_lo)

    ,.data_o(mem_resp_header_lo)
    ,.v_o(mem_resp_v_lo)
    ,.yumi_i(mem_resp_done_lo)
    );
  
  bp_stream_pump_out
   #(.bp_params_p(bp_params_p)
   ,.stream_data_width_p(mem_data_width_p)
   ,.block_width_p(cce_block_width_p)
   ,.payload_mask_p(mem_resp_payload_mask_gp)
   ,.stream_mask_p(mem_stream_wr_mask_gp | mem_stream_rd_mask_gp))
   cce_to_cache_pump_out
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.mem_header_o(mem_resp_header_o)
    ,.mem_data_o(mem_resp_data_o)
    ,.mem_v_o(mem_resp_v_o)
    ,.mem_last_o(mem_resp_last_o)
    ,.mem_ready_and_i(mem_resp_ready_and_i)
    
    ,.fsm_base_header_i(mem_resp_header_lo)
    ,.fsm_data_i(mem_resp_data_lo)
    ,.fsm_v_i(mem_resp_v_lo & cache_v_i)
    ,.fsm_ready_and_o(mem_resp_ready_and_lo)

    ,.stream_cnt_o(/* unused */)
    ,.stream_done_o(mem_resp_done_lo)
    );
  assign cache_yumi_o = mem_resp_ready_and_lo | (is_clear & cache_v_i);

  // For B/H/W/D ops, returned data is aligned to the LSB, but it may not for M op
  wire [byte_offset_width_lp-1:0] resp_data_sel_li = (mem_resp_header_lo.size inside {e_bedrock_msg_size_1, e_bedrock_msg_size_2, e_bedrock_msg_size_4, e_bedrock_msg_size_8})
                                                     ? byte_offset_width_lp'(0)
                                                     : mem_resp_header_lo.addr[0+:byte_offset_width_lp];
  wire [`BSG_WIDTH(byte_offset_width_lp)-1:0] mem_resp_size_li = `BSG_MIN(mem_resp_header_lo.size, `BSG_SAFE_CLOG2(l2_data_width_p>>3)); //TODO
  bsg_bus_pack
   #(.in_width_p(l2_data_width_p)
   ,.out_width_p(mem_data_width_p))
   resp_data_bus_pack
    (.data_i(cache_data_i)
    ,.sel_i(resp_data_sel_li)
    ,.size_i(mem_resp_size_li)
    ,.data_o(mem_resp_data_lo)
    );

  //   At the reset, this module intializes all the tags and valid bits to zero.
  //   After all the tags are completedly initialized, this module starts
  //   accepting incoming commands
  always_comb
    begin
      cache_pkt     = '0;
      cache_pkt_v_o = 1'b0;
     
      mem_cmd_ready_and_li = 1'b0;

      mem_resp_header_li = '0;
      mem_resp_v_li      = 1'b0;

      tagst_sent_n     = tagst_sent_r;
      tagst_received_n = tagst_received_r;

      cmd_state_n  = cmd_state_r;

      case (cmd_state_r)
        RESET: 
          begin
            cmd_state_n = CLEAR_TAG; 
          end
        CLEAR_TAG:
          begin
            cache_pkt.opcode = TAGST;
            cache_pkt.data = '0;
            cache_pkt.addr = {
              {(caddr_width_p-lg_sets_lp-lg_ways_lp-block_offset_width_lp){1'b0}},
              tagst_sent_r[0+:lg_sets_lp+lg_ways_lp],
              {(block_offset_width_lp){1'b0}}
            };
            cache_pkt.mask = '1;

            cache_pkt_v_o = cache_pkt_ready_i & (tagst_sent_r != (l2_assoc_p*l2_sets_p));
            tagst_sent_n = tagst_sent_r + cache_pkt_v_o;
            tagst_received_n = tagst_received_r + cache_yumi_o;
            cmd_state_n = (tagst_sent_r == l2_assoc_p*l2_sets_p) & (tagst_received_r == l2_assoc_p*l2_sets_p) 
              ? READY 
              : CLEAR_TAG;
          end 
        READY:
          begin
            case (mem_cmd_header_lo.msg_type)
              e_bedrock_mem_rd
              ,e_bedrock_mem_uc_rd:
                case (mem_cmd_header_lo.size)
                  e_bedrock_msg_size_1: cache_pkt.opcode = LB;
                  e_bedrock_msg_size_2: cache_pkt.opcode = LH;
                  e_bedrock_msg_size_4: cache_pkt.opcode = LW;
                  e_bedrock_msg_size_8: cache_pkt.opcode = LD;
                  e_bedrock_msg_size_16
                  ,e_bedrock_msg_size_32
                  ,e_bedrock_msg_size_64: cache_pkt.opcode = LM;
                  default: cache_pkt.opcode = LB;
                endcase
              e_bedrock_mem_uc_wr
              ,e_bedrock_mem_wr
              ,e_bedrock_mem_amo:
                case (mem_cmd_header_lo.size)
                  e_bedrock_msg_size_1: cache_pkt.opcode = SB;
                  e_bedrock_msg_size_2: cache_pkt.opcode = SH;
                  e_bedrock_msg_size_4, e_bedrock_msg_size_8:
                    case (mem_cmd_header_lo.subop)
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
            
            if (is_tagfl)
              begin
                cache_pkt.opcode = TAGFL;
                cache_pkt.addr = tagfl_addr;
              end
            else
              begin
                cache_pkt.addr = mem_cmd_header_lo.addr[0+:caddr_width_p];
                cache_pkt.data = cache_pkt_data_lo;
                // This mask is only used for the LM/SM operations for >64 bit mask operations
                cache_pkt.mask = cache_pkt_mask_lo;
              end
            cache_pkt_v_o  = cache_pkt_ready_i & mem_cmd_v_lo;
            // send ready_and signal back to pump_out
            mem_cmd_ready_and_li = cache_pkt_ready_i;

            mem_resp_header_li = mem_cmd_header_lo; // return the same critical addr back to stream_fifo
            mem_resp_v_li      = cache_pkt_v_o;

            cmd_state_n = (mem_cmd_stream_new_lo & mem_cmd_v_lo & mem_cmd_ready_and_li) ? STREAM : READY;
          end
        STREAM:
          begin
            cache_pkt.opcode = is_read ? LM : SM;
            cache_pkt.addr = mem_cmd_stream_addr_lo[0+:caddr_width_p];
            cache_pkt.mask = cache_pkt_mask_lo;
            cache_pkt.data = cache_pkt_data_lo;
            // send ready_and signal back to pump_out
            mem_cmd_ready_and_li = cache_pkt_ready_i;
            cache_pkt_v_o = mem_cmd_ready_and_li & mem_cmd_v_lo;

            // Transition back to ready once we've completely sent out the stream
            cmd_state_n = mem_cmd_done_lo ? READY : STREAM;
          end
        default: begin end
      endcase
    end

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      begin
        cmd_state_r          <= RESET;
        tagst_sent_r         <= '0;
        tagst_received_r     <= '0;
      end
    else
      begin
        cmd_state_r          <= cmd_state_n;
        tagst_sent_r         <= tagst_sent_n;
        tagst_received_r     <= tagst_received_n;
      end

  //synopsys translate_off
  always_ff @(negedge clk_i)
    begin
      if (mem_cmd_v_lo & mem_cmd_header_lo.msg_type inside {e_bedrock_mem_wr, e_bedrock_mem_uc_wr})
        assert (~(mem_cmd_header_lo.subop inside {e_bedrock_amolr, e_bedrock_amosc}))
          else $error("LR/SC not supported in bsg_cache");
    end

  initial
    begin
        if (mem_data_width_p > l2_data_width_p)
          $error("Mem bus data with should be leass than or equal to L2 data width");
    end
  //synopsys translate_on


endmodule

