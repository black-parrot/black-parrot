/**
 * bp_me_nonsynth_mock_lce.v
 *
 * This mock LCE behaves like a mock D$. It connects to a trace replay module and to the BP ME.
 * The trace replay format is the same as the trace replay format for the D$.
 *
 * Uncached access is determined by the memory address. If the MSB of the address is set, the
 * access is for uncached memory, otherwise it is a cached access.
 *
 */

module tag_lookup
  import bp_common_pkg::*;
  #(parameter lce_assoc_p="inv"
    , parameter ptag_width_p="inv"
    , parameter coh_bits_p="inv"
    , localparam tag_s_width_lp=(coh_bits_p+ptag_width_p)
    , localparam lg_lce_assoc_lp=`BSG_SAFE_CLOG2(lce_assoc_p)
   )
  (input [lce_assoc_p-1:0][tag_s_width_lp-1:0] tag_set_i
   , input [ptag_width_p-1:0] ptag_i
   , input [lg_lce_assoc_lp-1:0] lru_way_i
   , input [lce_assoc_p-1:0] dirty_bits_i
   , output logic hit_o
   , output logic dirty_o
   , output logic [lg_lce_assoc_lp-1:0] way_o
   , output logic lru_dirty_o
   , output logic [coh_bits_p-1:0] state_o
  );

  typedef struct packed {
    logic [coh_bits_p-1:0] coh_st;
    logic [ptag_width_p-1:0] tag;
  } tag_s;

  tag_s [lce_assoc_p-1:0] tags;
  assign tags = tag_set_i;

  logic [lce_assoc_p-1:0] hits;
  genvar i;
  generate
  for (i = 0; i < lce_assoc_p; i=i+1) begin
    assign hits[i] = ((tags[i].tag == ptag_i) && (tags[i].coh_st != e_MESI_I));
  end
  endgenerate

  logic hit_lo;
  logic [lg_lce_assoc_lp-1:0] addr_lo;
  bsg_encode_one_hot
    #(.width_p(lce_assoc_p))
  hits_to_way_id
    (.i(hits)
     ,.addr_o(addr_lo)
     ,.v_o(hit_lo)
    );

  assign hit_o = |hits;
  assign way_o = addr_lo;
  assign dirty_o = (tags[way_o].coh_st == e_MESI_M);
  assign state_o = tags[way_o].coh_st;
  // TODO: needs fixing?
  assign lru_dirty_o = dirty_bits_i[lru_way_i];//(tags[lru_way_i].coh_st == e_MESI_M);

endmodule


module bp_me_nonsynth_mock_lce
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_be_dcache_pkg::*;
  #(parameter bp_cfg_e cfg_p = e_bp_half_core_cfg
    `declare_bp_proc_params(cfg_p)

    , parameter axe_trace_p = 0

    , localparam block_size_in_bytes_lp=(cce_block_width_p / 8)

    , localparam dcache_opcode_width_lp=$bits(bp_be_dcache_opcode_e)
    , localparam tr_ring_width_lp=(dcache_opcode_width_lp+paddr_width_p+dword_width_p)

    , localparam block_offset_bits_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_lp)

    , localparam lg_lce_sets_lp=`BSG_SAFE_CLOG2(lce_sets_p)
    , localparam lg_lce_assoc_lp=`BSG_SAFE_CLOG2(lce_assoc_p)
    , localparam lg_num_lce_lp=`BSG_SAFE_CLOG2(num_lce_p)
    , localparam lg_num_cce_lp=`BSG_SAFE_CLOG2(num_cce_p)

    , localparam ptag_width_lp=paddr_width_p-lg_lce_sets_lp-block_offset_bits_lp

    , localparam lg_dword_bytes_lp=`BSG_SAFE_CLOG2(dword_width_p/8)

`declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
  )
  (
    input                                                   clk_i
    ,input                                                  reset_i

    ,input [lg_num_lce_lp-1:0]                              lce_id_i

    // the input packets are the same as the dcache trace replay packets: {dcache_cmd, paddr, data}
    ,input [tr_ring_width_lp-1:0]                           tr_pkt_i
    ,input                                                  tr_pkt_v_i
    ,output logic                                           tr_pkt_yumi_o

    ,output logic [tr_ring_width_lp-1:0]                    tr_pkt_o
    ,output logic                                           tr_pkt_v_o
    ,input                                                  tr_pkt_ready_i

    // LCE-CCE Interface
    // inbound: valid->ready (a.k.a. valid->yumi), demanding
    // outbound: ready->valid, demanding
    ,output logic [lce_cce_req_width_lp-1:0]                lce_req_o
    ,output logic                                           lce_req_v_o
    ,input                                                  lce_req_ready_i

    ,output logic [lce_cce_resp_width_lp-1:0]               lce_resp_o
    ,output logic                                           lce_resp_v_o
    ,input                                                  lce_resp_ready_i

    ,output logic [lce_cce_data_resp_width_lp-1:0]          lce_data_resp_o
    ,output logic                                           lce_data_resp_v_o
    ,input                                                  lce_data_resp_ready_i

    ,input [cce_lce_cmd_width_lp-1:0]                       lce_cmd_i
    ,input                                                  lce_cmd_v_i
    ,output logic                                           lce_cmd_ready_o

    ,input [lce_data_cmd_width_lp-1:0]                      lce_data_cmd_i
    ,input                                                  lce_data_cmd_v_i
    ,output logic                                           lce_data_cmd_ready_o

    ,output logic [lce_data_cmd_width_lp-1:0]               lce_data_cmd_o
    ,output logic                                           lce_data_cmd_v_o
    ,input                                                  lce_data_cmd_ready_i
  );

  // LCE-CCE interface structs
  `declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p);

  // Structs for output messages
  bp_lce_cce_req_s lce_req_s;
  bp_lce_cce_resp_s lce_resp_s;
  bp_lce_cce_data_resp_s lce_data_resp_s;
  bp_lce_data_cmd_s lce_data_cmd_s;
  assign lce_req_o = lce_req_s;
  assign lce_resp_o = lce_resp_s;
  assign lce_data_resp_o = lce_data_resp_s;
  assign lce_data_cmd_o = lce_data_cmd_s;

  // FIFO to buffer LCE commands from ME
  logic lce_cmd_v, lce_cmd_yumi;
  logic [cce_lce_cmd_width_lp-1:0] lce_cmd_bits;
  bp_cce_lce_cmd_s lce_cmd, lce_cmd_r, lce_cmd_n;
  assign lce_cmd = lce_cmd_bits;

  bsg_two_fifo
    #(.width_p(cce_lce_cmd_width_lp))
  lce_cmd_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     // to/from ME
     ,.ready_o(lce_cmd_ready_o)
     ,.data_i(lce_cmd_i)
     ,.v_i(lce_cmd_v_i)
     // to/from mock LCE
     ,.v_o(lce_cmd_v)
     ,.data_o(lce_cmd_bits)
     ,.yumi_i(lce_cmd_yumi)
    );

  // FIFO to buffer LCE Data commands from ME
  logic lce_data_cmd_v, lce_data_cmd_yumi;
  logic [lce_data_cmd_width_lp-1:0] lce_data_cmd_bits;
  bp_lce_data_cmd_s lce_data_cmd, lce_data_cmd_r, lce_data_cmd_n;
  assign lce_data_cmd = lce_data_cmd_bits;

  bsg_two_fifo
    #(.width_p(lce_data_cmd_width_lp))
  lce_data_cmd_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     // to/from ME
     ,.ready_o(lce_data_cmd_ready_o)
     ,.data_i(lce_data_cmd_i)
     ,.v_i(lce_data_cmd_v_i)
     // to/from mock LCE
     ,.v_o(lce_data_cmd_v)
     ,.data_o(lce_data_cmd_bits)
     ,.yumi_i(lce_data_cmd_yumi)
    );

  typedef struct packed {
    logic [`bp_cce_coh_bits-1:0] coh_st;
    logic [ptag_width_lp-1:0] tag;
  } tag_s;

  localparam tag_s_width_lp = $bits(tag_s);

  // Current set and way for tag, dirty bits, and data array operations
  logic [lg_lce_sets_lp-1:0] cur_set, cur_set_n;
  logic [lg_lce_assoc_lp-1:0] cur_way, cur_way_n;

  // Tags
  tag_s [lce_sets_p-1:0][lce_assoc_p-1:0] tags, tag_next, tag_next_n;
  logic [lce_sets_p-1:0][lce_assoc_p-1:0] tag_w, tag_w_n;

  // Dirty bits
  logic [lce_sets_p-1:0][lce_assoc_p-1:0] dirty_w, dirty_w_n;
  logic [lce_sets_p-1:0][lce_assoc_p-1:0] dirty_bits, dirty_bits_next, dirty_bits_n;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      cur_set <= '0;
      cur_way <= '0;
      tag_w <= '0;
      tag_next <= '0;
      tags <= '0;
      dirty_w <= '0;
      dirty_bits <= '0;
      dirty_bits_next <= '0;
    end else begin
      cur_set <= cur_set_n;
      cur_way <= cur_way_n;
      tag_w <= tag_w_n;
      tag_next <= tag_next_n;
      dirty_w <= dirty_w_n;
      dirty_bits_next <= dirty_bits_n;
      for (integer i = 0; i < lce_sets_p; i=i+1) begin
        for (integer j = 0; j < lce_assoc_p; j=j+1) begin
          if (tag_w[i][j]) begin
            tags[i][j] <= tag_next[i][j];
          end
          if (dirty_w[i][j]) begin
            dirty_bits[i][j] <= dirty_bits_next[i][j];
          end
        end
      end
    end
  end

  // async read of tags at specified set and way
  tag_s tag_cur;
  assign tag_cur = tags[cur_set][cur_way];

  // Data
  logic [lce_sets_p-1:0][lce_assoc_p-1:0][cce_block_width_p-1:0] data;
  logic [lce_sets_p-1:0][lce_assoc_p-1:0] data_w, data_w_n;
  logic [cce_block_width_p-1:0] data_next, data_next_n, data_mask, data_mask_n;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      data_w <= '0;
      data_mask <= '0;
      data_next <= '0;
      data <= '0;
    end else begin
      data_w <= data_w_n;
      data_mask <= data_mask_n;
      data_next <= data_next_n;
      for (integer i = 0; i < lce_sets_p; i=i+1) begin
        for (integer j = 0; j < lce_assoc_p; j=j+1) begin
          if (data_w[i][j]) begin
            for (integer k = 0; k < cce_block_width_p; k=k+1) begin
              if (data_mask[k]) begin
                data[i][j][k] <= data_next[k];
              end else begin
                data[i][j][k] <= data[i][j][k];
              end
            end
          end
        end
      end
    end
  end

  // async read of data at specified set and way
  logic [cce_block_width_p-1:0] data_cur;
  assign data_cur = data[cur_set][cur_way];

  // current command from trace replay
  typedef struct packed {
    logic [dcache_opcode_width_lp-1:0] cmd;
    logic [paddr_width_p-1:0]          paddr;
    logic [dword_width_p-1:0]          data;
  } tr_cmd_s;

  // miss status handling register definition for current trace replay command
  typedef struct packed {
    logic miss;
    logic [lg_num_cce_lp-1:0] cce;
    logic [paddr_width_p-1:0] paddr;
    logic uncached;
    logic dirty;
    logic store_op;
    logic upgrade;
    logic [lg_lce_assoc_lp-1:0] lru_way;
    logic lru_dirty;
    logic tag_received;
    logic data_received;
    logic transfer_received;
  } mshr_s;

  `define mshr_width $bits(mshr_s)

  // miss status handling register
  mshr_s mshr_r, mshr_n;

  // current command being processed
  tr_cmd_s cmd, cmd_n, tr_cmd_pkt;
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      cmd <= '0;
      mshr_r <= '0;
    end else begin
      cmd <= cmd_n;
      mshr_r <= mshr_n;
    end
  end
  assign tr_cmd_pkt = tr_pkt_i;

  // some useful signals from the current trace replay command
  logic store_op, load_op, signed_op, byte_op, word_op, double_op, half_op;
  logic uncached_op;
  logic [1:0] op_size;
  logic [2:0] dword_offset;
  logic [2:0] byte_offset;
  assign store_op = cmd.cmd[3];
  assign load_op = ~cmd.cmd[3];
  assign signed_op = ~cmd.cmd[2];
  assign op_size = cmd.cmd[1:0];
  assign double_op = (cmd.cmd[1:0] == 2'b11);
  assign word_op = (cmd.cmd[1:0] == 2'b10);
  assign half_op = (cmd.cmd[1:0] == 2'b01);
  assign byte_op = (cmd.cmd[1:0] == 2'b00);
  assign dword_offset = cmd.paddr[5:3];
  assign byte_offset = cmd.paddr[2:0];
  assign uncached_op = cmd.paddr[paddr_width_p-1];

  // Data word (64-bit) targeted by current trace replay command
  logic [dword_width_p-1:0] load_data;
  assign load_data = data_cur[dword_width_p*dword_offset +: dword_width_p];
  logic word_sigext, half_sigext, byte_sigext;
  logic [31:0] load_word;
  logic [15:0] load_half;
  logic [7:0] load_byte;

  bsg_mux #(
    .width_p(32)
    ,.els_p(2)
  ) word_mux (
    .data_i(load_data)
    ,.sel_i(byte_offset[2])
    ,.data_o(load_word)
  );
  
  bsg_mux #(
    .width_p(16)
    ,.els_p(4)
  ) half_mux (
    .data_i(load_data)
    ,.sel_i(byte_offset[2:1])
    ,.data_o(load_half)
  );

  bsg_mux #(
    .width_p(8)
    ,.els_p(8)
  ) byte_mux (
    .data_i(load_data)
    ,.sel_i(byte_offset[2:0])
    ,.data_o(load_byte)
  );

  assign word_sigext = signed_op & load_word[31]; 
  assign half_sigext = signed_op & load_half[15]; 
  assign byte_sigext = signed_op & load_byte[7]; 

  // Tag lookup
  // inputs
  tag_s [lce_assoc_p-1:0] tag_set_li;
  logic [ptag_width_lp-1:0] ptag_li;
  logic [lg_lce_assoc_lp-1:0] lru_way_r, lru_way_n, lru_way_li;
  logic [lce_assoc_p-1:0] dirty_bits_li;
  // set up tag lookup inputs
  assign tag_set_li = tags[cmd.paddr[block_offset_bits_lp +: lg_lce_sets_lp]];
  assign ptag_li = cmd.paddr[paddr_width_p-1 -: ptag_width_lp];
  assign lru_way_li = lru_way_r;
  assign dirty_bits_li = dirty_bits[cmd.paddr[block_offset_bits_lp +: lg_lce_sets_lp]];

  // outputs
  logic tag_hit_lo;
  logic tag_dirty_lo;
  logic [lg_lce_assoc_lp-1:0] tag_hit_way_r, tag_hit_way_n, tag_hit_way_lo;
  logic lru_dirty_lo;
  logic [`bp_cce_coh_bits-1:0] tag_hit_state_r, tag_hit_state_n, tag_hit_state_lo;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      lru_way_r <= '0;
      tag_hit_way_r <= '0;
      tag_hit_state_r <= '0;
    end else begin
      lru_way_r <= lru_way_n;
      tag_hit_way_r <= tag_hit_way_n;
      tag_hit_state_r <= tag_hit_state_n;
    end
  end

  tag_lookup
    #(.lce_assoc_p(lce_assoc_p)
      ,.ptag_width_p(ptag_width_lp)
      ,.coh_bits_p(`bp_cce_coh_bits)
      )
  lce_tag_lookup
    (.tag_set_i(tag_set_li)
     ,.ptag_i(ptag_li)
     ,.lru_way_i(lru_way_li)
     ,.dirty_bits_i(dirty_bits_li)
     ,.hit_o(tag_hit_lo)
     ,.dirty_o(tag_dirty_lo)
     ,.way_o(tag_hit_way_lo)
     ,.lru_dirty_o(lru_dirty_lo)
     ,.state_o(tag_hit_state_lo)
     );

  typedef enum logic [7:0] {
    RESET
    ,INIT
    ,SEND_SYNC
    ,READY

    ,UNCACHED_ONLY
    ,UNCACHED_TR_CMD
    ,UNCACHED_SEND_REQ
    ,UNCACHED_SEND_TR_RESP

    ,LCE_DATA_CMD

    ,LCE_CMD
    ,LCE_CMD_TR_RD
    ,LCE_CMD_TR
    ,LCE_CMD_WB_RD
    ,LCE_CMD_WB
    ,LCE_CMD_INV
    ,LCE_CMD_INV_RESP
    ,LCE_CMD_ST
    ,LCE_CMD_STW
    ,LCE_CMD_STW_RESP

    ,LCE_CMD_ST_DATA_RESP

    ,TR_CMD
    ,TR_CMD_SWITCH
    ,TR_CMD_TAG
    ,TR_CMD_LD_HIT
    ,TR_CMD_LD_HIT_RESP
    ,TR_CMD_LD_MISS
    ,TR_CMD_ST_HIT
    ,TR_CMD_ST_HIT_WR_TAG
    ,TR_CMD_ST_HIT_RESP
    ,TR_CMD_ST_MISS

    ,FINISH_MISS
    ,FINISH_MISS_SEND
  } lce_state_e;

  lce_state_e lce_state, lce_state_n;



  // init sync counter
  logic [lg_num_cce_lp:0] sync_counter_r, sync_counter_n;
  logic lce_init_r, lce_init_n;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      lce_state <= RESET;
      lce_init_r <= '0;

      lce_cmd_r <= '0;
      lce_data_cmd_r <= '0;

      sync_counter_r <= '0;

    end else begin
      lce_state <= lce_state_n;
      lce_init_r <= lce_init_n;

      lce_cmd_r <= lce_cmd_n;
      lce_data_cmd_r <= lce_data_cmd_n;

      sync_counter_r <= sync_counter_n;

    end
  end


  always_comb begin
    if (reset_i) begin
      lce_state_n = RESET;
      lce_init_n = '0;

      // sync counter
      sync_counter_n = '0;

      // trace replay command inbound
      cmd_n = '0;
      tr_pkt_yumi_o = '0;

      // trace replay response out
      tr_pkt_o = '0;
      tr_pkt_v_o = '0;

      // outbound queues
      lce_req_v_o = '0;
      lce_req_s = '0;
      lce_resp_v_o = '0;
      lce_resp_s = '0;
      lce_data_resp_v_o = '0;
      lce_data_resp_s = '0;
      lce_data_cmd_v_o = '0;
      lce_data_cmd_s = '0;

      // inbound queues
      lce_cmd_n = '0;
      lce_cmd_yumi = '0;
      lce_data_cmd_n ='0;
      lce_data_cmd_yumi = '0;

      // miss handling
      lru_way_n = '0;
      mshr_n = '0;

      // tag, data, and dirty bit arrays
      tag_next_n = '0;
      tag_w_n = '0;
      data_next_n = '0;
      data_w_n = '0;
      data_mask_n = '0;
      dirty_w_n = '0;
      dirty_bits_n = '0;

      // tag lookup module
      lru_way_n = '0;
      tag_hit_way_n = '0;
      tag_hit_state_n = '0;

      // tag and data select
      cur_set_n = '0;
      cur_way_n = '0;

    end else begin
      lce_state_n = RESET;
      lce_init_n = lce_init_r;

      // sync counter
      sync_counter_n = sync_counter_r;

      // trace replay command inbound
      cmd_n = cmd;
      tr_pkt_yumi_o = '0;

      // trace replay response out
      tr_pkt_o = '0;
      tr_pkt_v_o = '0;

      // outbound queues
      lce_req_v_o = '0;
      lce_req_s = '0;
      lce_resp_v_o = '0;
      lce_resp_s = '0;
      lce_data_resp_v_o = '0;
      lce_data_resp_s = '0;
      lce_data_cmd_v_o = '0;
      lce_data_cmd_s = '0;

      // inbound queues
      lce_cmd_n = lce_cmd_r;
      lce_cmd_yumi = '0;
      lce_data_cmd_n =lce_data_cmd_r;
      lce_data_cmd_yumi = '0;

      // miss handling
      mshr_n = mshr_r;
      lru_way_n = lru_way_r;

      // tag, data, and dirty bit arrays
      tag_next_n = '0;
      tag_w_n = '0;
      data_next_n = '0;
      data_w_n = '0;
      data_mask_n = '0;
      dirty_w_n = '0;
      dirty_bits_n = '0;

      // tag lookup module
      tag_hit_way_n = tag_hit_way_r;
      tag_hit_state_n = tag_hit_state_r;

      // tag and data select
      cur_set_n = cur_set;
      cur_way_n = cur_way;

      case (lce_state)
        RESET: begin
          lce_state_n = UNCACHED_ONLY;
        end
        UNCACHED_ONLY: begin
          lce_state_n = UNCACHED_ONLY;
          if (lce_cmd_v && lce_cmd.msg_type == e_lce_cmd_set_clear) begin
            // INIT routine starting, stop accepting uncached accesses and initialize
            lce_state_n = INIT;
          end else if (tr_pkt_v_i & ~mshr_r.miss) begin
            // only process a new trace replay request if not already missing
            // AND address is for uncached memory
            if (tr_cmd_pkt.paddr[paddr_width_p-1]) begin
              tr_pkt_yumi_o = 1'b1;
              cmd_n = tr_pkt_i;
              lce_state_n = UNCACHED_TR_CMD;
              // new trace replay command, clear the mshr
              mshr_n = '0;
            end
          end
        end
        UNCACHED_TR_CMD: begin
          // uncached access - treat as miss
          mshr_n.miss = 1'b1;
          mshr_n.uncached = uncached_op;
          assert(uncached_op) else $error("LCE received cached access command while uncached only");
          // TODO: CCE selection only works for power of two number of CCEs
          mshr_n.cce = (num_cce_p == 1) ? '0 : cmd.paddr[block_offset_bits_lp +: lg_num_cce_lp];
          mshr_n.paddr = cmd.paddr;
          mshr_n.dirty = '0;
          mshr_n.store_op = store_op;
          mshr_n.upgrade = '0;
          mshr_n.lru_way = '0;
          mshr_n.lru_dirty = '0;
          mshr_n.tag_received = '0;
          mshr_n.data_received = '0;
          mshr_n.transfer_received = '0;

          lce_state_n = UNCACHED_SEND_REQ;
        end
        UNCACHED_SEND_REQ: begin
          // uncached access - send LCE request
          lce_req_v_o = 1'b1;

          lce_req_s.dst_id = mshr_r.cce;
          lce_req_s.src_id = lce_id_i;
          lce_req_s.data = (mshr_r.store_op) ? cmd.data : '0;
          lce_req_s.msg_type = (mshr_r.store_op) ? e_lce_req_type_wr : e_lce_req_type_rd;
          lce_req_s.non_exclusive = e_lce_req_excl;
          lce_req_s.addr = mshr_r.paddr;
          lce_req_s.lru_way_id = '0;
          lce_req_s.lru_dirty = e_lce_req_lru_clean;
          lce_req_s.non_cacheable = e_lce_req_non_cacheable;
          lce_req_s.nc_size =
            (double_op)
            ? e_lce_nc_req_8
            : (word_op)
              ? e_lce_nc_req_4
              : (half_op)
                ? e_lce_nc_req_2
                : e_lce_nc_req_1;

          // wait for LCE req outbound to be ready (r&v), then wait for responses
          lce_state_n = (lce_req_ready_i)
                        ? UNCACHED_SEND_TR_RESP
                        : UNCACHED_SEND_REQ; // not accepted, try again next cycle

        end
        UNCACHED_SEND_TR_RESP: begin
          lce_state_n = UNCACHED_SEND_TR_RESP;
          // send return packet to TR
          if (mshr_r.store_op) begin
            // store sends back null packet
            tr_pkt_v_o = 1'b1;
            tr_pkt_o = '0;
            lce_state_n = (tr_pkt_ready_i)
                          ? (lce_init_r)
                            ? READY
                            : UNCACHED_ONLY
                          : UNCACHED_SEND_TR_RESP;

            // clear miss handling state
            mshr_n = (tr_pkt_ready_i) ? '0 : mshr_r;

          end else if (lce_data_cmd_v) begin
            // load returns the data, and must wait for lce_data_cmd to return
            tr_pkt_v_o = 1'b1;
            tr_pkt_o[tr_ring_width_lp-1:dword_width_p] = '0;
            tr_pkt_o[0 +: dword_width_p] = lce_data_cmd.data[0 +: dword_width_p];

            lce_state_n = (tr_pkt_ready_i)
                          ? (lce_init_r)
                            ? READY
                            : UNCACHED_ONLY
                          : UNCACHED_SEND_TR_RESP;

            // dequeue data cmd if TR accepts the outbound packet
            lce_data_cmd_yumi = tr_pkt_ready_i;

            // clear miss handling state
            mshr_n = (tr_pkt_ready_i) ? '0 : mshr_r;

          end
        end
        INIT: begin
          // by default, stay in INIT, waiting for all set clear commands and sync commands to
          // arrive. The only ordering guarantee is that the sync command from CCE N will arrive
          // after all set clear commands from CCE N. Commands from different CCEs can be
          // interleaved in any order.
          lce_state_n = (sync_counter_r == num_cce_p) ? READY : INIT;
          // register that LCE is initialized after sending all sync acks
          lce_init_n = (sync_counter_r == num_cce_p) ? 1'b1 : 1'b0;
          if (lce_cmd_v && lce_cmd.msg_type == e_lce_cmd_set_clear) begin
            // set clear command - LCE sinks the command and clears that set in the cache

            // dequeue the command
            lce_cmd_yumi = 1'b1;
            lce_cmd_n = lce_cmd;

            // clear set in cache
            cur_set_n = lce_cmd.addr[block_offset_bits_lp +: lg_lce_sets_lp];
            tag_w_n[cur_set_n] = '1;
            tag_next_n[cur_set_n] = '0;
            // also clear the dirty bits
            dirty_w_n[cur_set_n] = '1;
            dirty_bits_n[cur_set_n] = '0;

            lce_state_n = INIT;
          end else if (lce_cmd_v && lce_cmd.msg_type == e_lce_cmd_sync) begin
            // dequeue the command, go to SEND_SYNC
            lce_cmd_yumi = 1'b1;
            lce_cmd_n = lce_cmd;
            lce_state_n = SEND_SYNC;
            sync_counter_n = sync_counter_r + 'd1;
          end
        end
        SEND_SYNC: begin
          // create the LCE response and make it valid for output
          lce_resp_s.dst_id = lce_cmd_r.src_id;
          lce_resp_s.src_id = lce_id_i;
          lce_resp_s.msg_type = e_lce_cce_sync_ack;
          lce_resp_s.addr = '0;
          lce_resp_v_o = 1'b1;

          // response goes out if inbound ready signal is high (ready&valid)
          lce_state_n = (lce_resp_ready_i) ? INIT : SEND_SYNC;
        end
        READY: begin
          lce_state_n = READY;
          if (lce_data_cmd_v) begin
            lce_data_cmd_yumi = 1'b1;
            lce_data_cmd_n = lce_data_cmd;
            lce_state_n = LCE_DATA_CMD;
          end else if (lce_cmd_v) begin
            // dequeue the command and save
            lce_cmd_yumi = 1'b1;
            lce_cmd_n = lce_cmd;
            if (lce_cmd.msg_type == e_lce_cmd_invalidate_tag) begin
              lce_state_n = LCE_CMD_INV;
            end else if (lce_cmd.msg_type == e_lce_cmd_transfer) begin
              lce_state_n = LCE_CMD_TR_RD;
            end else if (lce_cmd.msg_type == e_lce_cmd_writeback) begin
              lce_state_n = LCE_CMD_WB_RD;
            end else if (lce_cmd.msg_type == e_lce_cmd_set_tag) begin
              lce_state_n = LCE_CMD_ST;
            end else if (lce_cmd.msg_type == e_lce_cmd_set_tag_wakeup) begin
              lce_state_n = LCE_CMD_STW;
            end else begin
              lce_state_n = RESET;
              $error("unrecognized LCE command received");
            end

          end else if (tr_pkt_v_i & ~mshr_r.miss) begin
            // only process a new trace replay request if not already missing
            tr_pkt_yumi_o = 1'b1;
            cmd_n = tr_pkt_i;
            lce_state_n = TR_CMD;
            // new trace replay command, clear the mshr
            mshr_n = '0;
          end

        end
        LCE_DATA_CMD: begin
          // data only arrives in response to an outstanding miss

          // write the full cache block to data array
          data_mask_n = '1;
          // use the address stored in the mshr
          cur_set_n = mshr_r.paddr[block_offset_bits_lp +: lg_lce_sets_lp];
          // way comes from the data command
          cur_way_n = lce_data_cmd_r.way_id;
          data_w_n[cur_set_n][cur_way_n] = '1;
          // data comes from the data command
          data_next_n = lce_data_cmd_r.data;

          // update mshr
          mshr_n.data_received = 1'b1;
          mshr_n.transfer_received = (lce_data_cmd_r.msg_type == e_lce_data_cmd_transfer);

          // if tag was already received, go to next state to send the response, else go to 
          // ready to wait for more commands
          lce_state_n = (mshr_r.tag_received) ? LCE_CMD_ST_DATA_RESP : READY;

        end
        LCE_CMD_INV: begin
          // invalidate cmd received - update tags
          // lce_cmd contains all the necessary information to update tags
          cur_set_n = lce_cmd_r.addr[block_offset_bits_lp +: lg_lce_sets_lp];
          cur_way_n = lce_cmd_r.way_id;
          tag_w_n[cur_set_n][cur_way_n] = 1'b1;
          tag_next_n[cur_set_n][cur_way_n].coh_st = e_MESI_I;
          tag_next_n[cur_set_n][cur_way_n].tag = lce_cmd_r.addr[paddr_width_p-1 -: ptag_width_lp];

          // send inv_ack next
          lce_state_n = LCE_CMD_INV_RESP;

        end
        LCE_CMD_INV_RESP: begin
          // make the LCE response valid
          lce_resp_v_o = 1'b1;
          // lce_cmd contains all the necessary information to send invalidation ack
          lce_resp_s.dst_id = lce_cmd_r.src_id;
          lce_resp_s.src_id = lce_id_i;
          lce_resp_s.msg_type = e_lce_cce_inv_ack;
          lce_resp_s.addr = lce_cmd_r.addr;

          // wait until response accepted (r&v) then go to READY
          lce_state_n = (lce_resp_ready_i) ? READY : LCE_CMD_INV_RESP;

        end
        LCE_CMD_TR_RD: begin
          // data select
          cur_set_n = lce_cmd_r.addr[block_offset_bits_lp +: lg_lce_sets_lp];
          cur_way_n = lce_cmd_r.way_id;

          lce_state_n = LCE_CMD_TR;
        end
        LCE_CMD_TR: begin
          // transfer cmd
          lce_data_cmd_s.data = data_cur;
          lce_data_cmd_s.dst_id = lce_cmd_r.target;
          lce_data_cmd_s.msg_type = e_lce_data_cmd_transfer;
          lce_data_cmd_s.way_id = lce_cmd_r.target_way_id;
          lce_data_cmd_v_o = 1'b1;

          // wait until data commmand out accepted (r&v), then go to ready
          lce_state_n = (lce_data_cmd_ready_i) ? READY : LCE_CMD_TR;

        end
        LCE_CMD_WB_RD: begin
          // tag and data select
          cur_set_n = lce_cmd_r.addr[block_offset_bits_lp +: lg_lce_sets_lp];
          cur_way_n = lce_cmd_r.way_id;

          lce_state_n = LCE_CMD_WB;

        end
        LCE_CMD_WB: begin
          // writeback cmd
          if (dirty_bits[cur_set][cur_way]) begin
            lce_data_resp_s.data = data_cur;
            lce_data_resp_s.msg_type = e_lce_resp_wb;
            // clear the dirty bit - but only do the write if the data response is accepted
            // (this prevents the dirty bit from being cleared before the response is sent, which
            //  could result in a null_wb being sent when an actual wb should have been)
            dirty_w_n[cur_set][cur_way] = (lce_data_resp_ready_i) ? 1'b1 : 1'b0;
            dirty_bits_n[cur_set][cur_way] = 1'b0;
          end else begin
            lce_data_resp_s.data = '0;
            lce_data_resp_s.msg_type = e_lce_resp_null_wb;
          end
          lce_data_resp_s.dst_id = lce_cmd_r.src_id;
          lce_data_resp_s.src_id = lce_id_i;
          lce_data_resp_s.addr = lce_cmd_r.addr;
          lce_data_resp_v_o = 1'b1;

          // wait until data response accepted (r&v), then go to ready
          lce_state_n = (lce_data_resp_ready_i) ? READY : LCE_CMD_WB;

        end
        LCE_CMD_ST: begin
          // response to miss - tag
          cur_set_n = lce_cmd_r.addr[block_offset_bits_lp +: lg_lce_sets_lp];
          cur_way_n = lce_cmd_r.way_id;
          tag_w_n[cur_set_n][cur_way_n] = 1'b1;
          tag_next_n[cur_set_n][cur_way_n].coh_st = lce_cmd_r.state;
          tag_next_n[cur_set_n][cur_way_n].tag = lce_cmd_r.addr[paddr_width_p-1 -: ptag_width_lp];

          // TODO: remove assert
          assert(lce_cmd_r.addr == mshr_r.paddr) else $error("set tag does not match mshr");
          // tag only comes in response to a miss, update the mshr
          mshr_n.tag_received = 1'b1;

          // if data already received, send coh_ack or tr_ack next, else wait for data
          lce_state_n = (mshr_r.data_received) ? LCE_CMD_ST_DATA_RESP : READY;

        end
        LCE_CMD_ST_DATA_RESP: begin
          // respond to the miss - tag and data both received
          // all information needed to respond is stored in mshr
          lce_resp_s.dst_id = mshr_r.cce;
          lce_resp_s.src_id = lce_id_i;
          lce_resp_s.msg_type = (mshr_r.transfer_received) ? e_lce_cce_tr_ack : e_lce_cce_coh_ack;
          lce_resp_s.addr = mshr_r.paddr;
          lce_resp_v_o = 1'b1;

          // send ack in response to tag and data both received
          // then, send response back to trace replay
          lce_state_n = (lce_resp_ready_i) ? FINISH_MISS : LCE_CMD_ST_DATA_RESP;
        end
        LCE_CMD_STW: begin
          // set tag and wakeup command - response to a miss

          // update tag array
          cur_set_n = lce_cmd_r.addr[block_offset_bits_lp +: lg_lce_sets_lp];
          cur_way_n = lce_cmd_r.way_id;

          tag_w_n[cur_set_n][cur_way_n] = 1'b1;
          tag_next_n[cur_set_n][cur_way_n].coh_st = lce_cmd_r.state;
          tag_next_n[cur_set_n][cur_way_n].tag = lce_cmd_r.addr[paddr_width_p-1 -: ptag_width_lp];

          // send coh_ack next cycle
          lce_state_n = LCE_CMD_STW_RESP;

        end
        LCE_CMD_STW_RESP: begin
          // Send coherence ack in response to set tag and wakeup
          lce_resp_s.dst_id = lce_cmd_r.src_id;
          lce_resp_s.src_id = lce_id_i;
          lce_resp_s.msg_type = e_lce_cce_coh_ack;
          lce_resp_s.addr = lce_cmd_r.addr;
          lce_resp_v_o = 1'b1;

          // wait until response accepted (r&v), then finish the miss
          lce_state_n = (lce_resp_ready_i) ? FINISH_MISS : LCE_CMD_STW_RESP;

        end
        FINISH_MISS: begin
          // select data to return
          cur_set_n = mshr_r.paddr[block_offset_bits_lp +: lg_lce_sets_lp];
          cur_way_n = mshr_r.lru_way;

          if (store_op) begin
            // do the store
            data_w_n[cur_set_n][cur_way_n] = 1'b1;
            data_mask_n = double_op
              ? {{(cce_block_width_p-64){1'b0}}, {64{1'b1}}} << (dword_offset*64)
              : word_op
                ? {{(cce_block_width_p-32){1'b0}}, {32{1'b1}}} << (dword_offset*64 + 32*byte_offset[2])
                : half_op
                  ? {{(cce_block_width_p-16){1'b0}}, {16{1'b1}}} << (dword_offset*64 + 16*byte_offset[2:1])
                  : {{(cce_block_width_p-8){1'b0}}, {8{1'b1}}} << (dword_offset*64 + 8*byte_offset[2:0]);

            data_next_n = double_op
              ? {{(cce_block_width_p-64){1'b0}}, cmd.data} << (dword_offset*64)
              : word_op
                ? {{(cce_block_width_p-32){1'b0}}, cmd.data[0+:32]} << (dword_offset*64 + 32*byte_offset[2])
                : half_op
                  ? {{(cce_block_width_p-16){1'b0}}, cmd.data[0+:16]} << (dword_offset*64 + 16*byte_offset[2:1])
                  : {{(cce_block_width_p-8){1'b0}}, cmd.data[0+:8]} << (dword_offset*64 + 8*byte_offset[2:0]);

            // this is a store, so set the dirty bit for the block
            dirty_w_n[cur_set_n][cur_way_n] = 1'b1;
            dirty_bits_n[cur_set_n][cur_way_n] = 1'b1;
          end else begin
            // this is a load, so clear the dirty bit for the block
            dirty_w_n[cur_set_n][cur_way_n] = 1'b1;
            dirty_bits_n[cur_set_n][cur_way_n] = 1'b0;
          end

          lce_state_n = FINISH_MISS_SEND;
        end
        FINISH_MISS_SEND: begin
          // send return packet back to TR after CCE handles the LCE miss request
          tr_pkt_v_o = 1'b1;
          tr_pkt_o[tr_ring_width_lp-1:dword_width_p] = '0;

          if (mshr_r.store_op && tag_cur.coh_st == e_MESI_E) begin
            tag_w_n[cur_set][cur_way] = 1'b1;
            tag_next_n[cur_set][cur_way].coh_st = e_MESI_M;
            tag_next_n[cur_set][cur_way].tag = mshr_r.paddr[paddr_width_p-1 -: ptag_width_lp];
          end

          tr_pkt_o[0 +: dword_width_p] = '0;
          if (load_op) begin
            tr_pkt_o[0 +: dword_width_p] = double_op
              ? load_data
              : (word_op
                ? {{32{word_sigext}}, load_word}
                : (half_op
                  ? {{48{half_sigext}}, load_half}
                  : {{56{byte_sigext}}, load_byte}));
          end

          // wait until TR accepts packet (r&v), then go to READY
          lce_state_n = (tr_pkt_ready_i) ? READY : FINISH_MISS_SEND;

          // clear miss handling state, only if TR packet accepted
          mshr_n = (tr_pkt_ready_i) ? '0 : mshr_r;

          // update lru_way - global round robin, only if TR packet accepted
          //lru_way_n = (tr_pkt_ready_i) ? (lru_way_r + 'd1) : lru_way_r;

        end
        TR_CMD: begin
          // set up tag lookup
          cur_set_n = cmd.paddr[block_offset_bits_lp +: lg_lce_sets_lp];

          // cur_way depends on if there was a hit or not when it is a store
          cur_way_n = (tag_hit_lo) ? tag_hit_way_lo : '0;

          // capture tag lookup outputs
          tag_hit_way_n = tag_hit_way_lo;
          tag_hit_state_n = tag_hit_state_lo;

          // setup miss handling information
          mshr_n.miss = ~tag_hit_lo;
          // TODO: CCE selection only works for power of two number of CCEs
          mshr_n.cce = (num_cce_p == 1) ? '0 : cmd.paddr[block_offset_bits_lp +: lg_num_cce_lp];
          mshr_n.paddr = cmd.paddr;
          mshr_n.uncached = uncached_op;
          mshr_n.dirty = tag_dirty_lo;
          mshr_n.store_op = store_op;
          mshr_n.upgrade = '0;
          mshr_n.lru_way = lru_way_r;
          mshr_n.lru_dirty = lru_dirty_lo;
          mshr_n.tag_received = '0;
          mshr_n.data_received = '0;
          mshr_n.transfer_received = '0;

          lce_state_n = TR_CMD_SWITCH;
        end
        TR_CMD_SWITCH: begin
          // process the trace replay command
          if (mshr_r.uncached) begin
              lce_state_n = UNCACHED_TR_CMD;
          end else if (~mshr_r.store_op) begin
            if (mshr_r.miss) begin
              lce_state_n = TR_CMD_LD_MISS;
            end else begin
              lce_state_n = TR_CMD_LD_HIT;
            end
          end else begin
            if (mshr_r.miss) begin
              lce_state_n = TR_CMD_ST_MISS;
            end else if (~mshr_r.miss && ((tag_hit_state_r == e_MESI_M) || (tag_hit_state_r == e_MESI_E))) begin
              lce_state_n = TR_CMD_ST_HIT;
            end else if (~mshr_r.miss && (tag_hit_state_r == e_MESI_S)) begin
              // upgrade counts as a miss - update the mshr
              mshr_n.miss = 1'b1;
              mshr_n.upgrade = 1'b1;
              lce_state_n = TR_CMD_ST_MISS;
            end else begin
              lce_state_n = RESET;
            end
          end
        end
        TR_CMD_LD_HIT: begin
          // load hit
          cur_set_n = cmd.paddr[block_offset_bits_lp +: lg_lce_sets_lp];
          cur_way_n = tag_hit_way_r;

          // reset some state
          tag_hit_way_n = '0;
          tag_hit_state_n = '0;

          lce_state_n = TR_CMD_LD_HIT_RESP;

        end
        TR_CMD_LD_HIT_RESP: begin
          tr_pkt_v_o = 1'b1;
          tr_pkt_o[tr_ring_width_lp-1:dword_width_p] = '0;
          // select data to return
          tr_pkt_o[0 +: dword_width_p] = double_op
            ? load_data
            : (word_op
              ? {{32{word_sigext}}, load_word}
              : (half_op
                ? {{48{half_sigext}}, load_half}
                : {{56{byte_sigext}}, load_byte}));

          lce_state_n = (tr_pkt_ready_i) ? READY : TR_CMD_LD_HIT_RESP;
          mshr_n = (tr_pkt_ready_i) ? '0 : mshr_r;
        end
        TR_CMD_LD_MISS: begin
          // load miss, send lce request
          lce_req_v_o = 1'b1;

          lce_req_s.dst_id = mshr_r.cce;
          lce_req_s.src_id = lce_id_i;
          lce_req_s.data = '0;
          lce_req_s.msg_type = e_lce_req_type_rd;
          lce_req_s.non_exclusive = e_lce_req_excl;
          lce_req_s.addr = mshr_r.paddr;
          lce_req_s.lru_way_id = mshr_r.lru_way;
          lce_req_s.lru_dirty = (mshr_r.lru_dirty ? e_lce_req_lru_dirty : e_lce_req_lru_clean);
          lce_req_s.non_cacheable = e_lce_req_cacheable;
          lce_req_s.nc_size = e_lce_nc_req_1;

          // wait for LCE req outbound to be ready (r&v), then wait for responses
          lce_state_n = (lce_req_ready_i) ? READY : TR_CMD_LD_MISS;

        end
        TR_CMD_ST_HIT: begin
          // set up tag lookup
          cur_set_n = cmd.paddr[block_offset_bits_lp +: lg_lce_sets_lp];
          cur_way_n = tag_hit_way_r;
          // do the store
          data_w_n[cur_set_n][cur_way_n] = 1'b1;
          data_mask_n = double_op
            ? {{(cce_block_width_p-64){1'b0}}, {64{1'b1}}} << (dword_offset*64)
            : word_op
              ? {{(cce_block_width_p-32){1'b0}}, {32{1'b1}}} << (dword_offset*64 + 32*byte_offset[2])
              : half_op
                ? {{(cce_block_width_p-16){1'b0}}, {16{1'b1}}} << (dword_offset*64 + 16*byte_offset[2:1])
                : {{(cce_block_width_p-8){1'b0}}, {8{1'b1}}} << (dword_offset*64 + 8*byte_offset[2:0]);

          data_next_n = double_op
            ? {{(cce_block_width_p-64){1'b0}}, cmd.data} << (dword_offset*64)
            : word_op
              ? {{(cce_block_width_p-32){1'b0}}, cmd.data[0+:32]} << (dword_offset*64 + 32*byte_offset[2])
              : half_op
                ? {{(cce_block_width_p-16){1'b0}}, cmd.data[0+:16]} << (dword_offset*64 + 16*byte_offset[2:1])
                : {{(cce_block_width_p-8){1'b0}}, cmd.data[0+:8]} << (dword_offset*64 + 8*byte_offset[2:0]);


          lce_state_n = TR_CMD_ST_HIT_WR_TAG;
        end
        TR_CMD_ST_HIT_WR_TAG: begin
          // store hit on Exclusive forces upgrade to Modified
          if (tag_cur.coh_st == e_MESI_E) begin
            tag_w_n[cur_set][cur_way] = 1'b1;
            tag_next_n[cur_set][cur_way].coh_st = e_MESI_M;
            tag_next_n[cur_set][cur_way].tag = cmd.paddr[paddr_width_p-1 -: ptag_width_lp];
            // set the dirty bit when writing to a block in Exclusive (first write)
            dirty_w_n[cur_set][cur_way] = 1'b1;
            dirty_bits_n[cur_set][cur_way] = 1'b1;
          end
          lce_state_n = TR_CMD_ST_HIT_RESP;
        end
        TR_CMD_ST_HIT_RESP: begin
          // reset some state
          tag_hit_way_n = '0;
          tag_hit_state_n = '0;

          // reset the mshr since this is the ack to the transaction
          mshr_n = '0;

          // output valid trace replay return packet
          tr_pkt_v_o = 1'b1;
          tr_pkt_o = '0;
          // wait until packet consumed, then go to ready
          lce_state_n = (tr_pkt_ready_i) ? READY : TR_CMD_ST_HIT_RESP;

        end
        TR_CMD_ST_MISS: begin
          // store miss - block present, not writable
          lce_req_v_o = 1'b1;

          lce_req_s.dst_id = mshr_r.cce;
          lce_req_s.src_id = lce_id_i;
          lce_req_s.data = '0;
          lce_req_s.msg_type = e_lce_req_type_wr;
          lce_req_s.non_exclusive = e_lce_req_excl;
          lce_req_s.addr = mshr_r.paddr;

          lce_req_s.lru_way_id = mshr_r.lru_way;//(mshr_r.upgrade) ? tag_hit_way_r : mshr_r.lru_way;
          lce_req_s.lru_dirty = (mshr_r.upgrade) ? e_lce_req_lru_clean :
            ((mshr_r.lru_dirty) ? e_lce_req_lru_dirty : e_lce_req_lru_clean);
          
          lce_req_s.non_cacheable = e_lce_req_cacheable;
          lce_req_s.nc_size = e_lce_nc_req_1;

          lce_state_n = (lce_req_ready_i) ? READY : TR_CMD_ST_MISS;

        end
        default: begin
          lce_state_n = RESET;
        end
      endcase
    end
  end

  /*
  always_ff @(negedge clk_i) begin
      case (lce_state)
        TR_CMD: begin
          if (tag_hit_lo && load_op) begin
            $display("LCE[%0d] Load hit: M[%d]", lce_id_i, cmd.paddr);
          end else if (~tag_hit_lo && load_op) begin
            $display("LCE[%0d] Load miss: M[%d]", lce_id_i, cmd.paddr);
          end else if (~tag_hit_lo && store_op) begin
            $display("LCE[%0d] Store miss: M[%d] := %d", lce_id_i, cmd.paddr, cmd.data);
          end else if (tag_hit_lo && store_op && ((tag_cur.coh_st == e_MESI_M) || (tag_cur.coh_st == e_MESI_E))) begin
            $display("LCE[%0d] Store hit: M[%d] := %d", lce_id_i, cmd.paddr, cmd.data);
          end else if (tag_hit_lo && store_op && (tag_cur.coh_st == e_MESI_S)) begin
            $display("LCE[%0d] Store miss: M[%d] := %d", lce_id_i, cmd.paddr, cmd.data);
          end
        end
      endcase
  end
  */

  always_ff @(posedge clk_i) begin
    if (axe_trace_p) begin
    case (lce_state)
      TR_CMD_LD_HIT_RESP: begin
        if (tr_pkt_ready_i) begin
          $display("#AXE %0d: M[%0d] == %0d", lce_id_i, (cmd.paddr >> lg_dword_bytes_lp), load_data);
        end
      end
      TR_CMD_ST_HIT_WR_TAG: begin
        $display("#AXE %0d: M[%0d] := %0d", lce_id_i, (cmd.paddr >> lg_dword_bytes_lp), cmd.data);
      end
      FINISH_MISS_SEND: begin
        if (tr_pkt_ready_i) begin
          if (store_op) begin
            $display("#AXE %0d: M[%0d] := %0d", lce_id_i, (cmd.paddr >> lg_dword_bytes_lp), cmd.data);
          end else begin
            $display("#AXE %0d: M[%0d] == %0d", lce_id_i, (cmd.paddr >> lg_dword_bytes_lp), load_data);
          end
        end
      end
    endcase
    end
  end


endmodule


