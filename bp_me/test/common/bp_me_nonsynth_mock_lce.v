/**
 * bp_me_nonsynth_mock_lce.v
 *
 * This mock LCE behaves like a mock D$. It connects to a trace replay module and to the BP ME.
 * The trace replay format is the same as the trace replay format for the D$.
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
   , output logic hit_o
   , output logic dirty_o
   , output logic [lg_lce_assoc_lp-1:0] way_o
   , input [lg_lce_assoc_lp-1:0] lru_way_i
   , output logic lru_dirty_o
  );
  typedef struct packed {
    logic [coh_bits_p-1:0] coh_st;
    logic [ptag_width_p-1:0] tag;
  } tag_s;

  tag_s [lce_assoc_p-1:0] tags;
  assign tags = tag_set_i;

  logic [lce_assoc_p-1:0] hits;
  int i;
  always_comb begin
    for (i = 0; i < lce_assoc_p; i=i+1) begin
      if (tags[i].tag == ptag_i && tags[i].coh_st != e_MESI_I) begin
        hits[i] = 1'b1;
      end else begin
        hits[i] = '0;
      end
    end
  end

  bsg_encode_one_hot
    #(.width_p(lce_assoc_p))
  hits_to_way_id
    (.i(hits)
     ,.addr_o(way_o)
     ,.v_o(hit_o)
    );

  assign dirty_o = (tags[way_o].coh_st == e_MESI_M);
  assign lru_dirty_o = (tags[lru_way_i].coh_st == e_MESI_M);

endmodule


module bp_me_nonsynth_mock_lce
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_be_dcache_pkg::*;
  #(parameter bp_cfg_e cfg_p = e_bp_half_core_cfg
    `declare_bp_proc_params(cfg_p)

    , localparam block_size_in_bytes_lp=(cce_block_width_p / 8)

    , localparam dcache_opcode_width_lp=$bits(bp_be_dcache_opcode_e)
    , localparam tr_ring_width_lp=(dcache_opcode_width_lp+paddr_width_p+dword_width_p)

    , localparam block_offset_bits_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_lp)

    , localparam lg_lce_sets_lp=`BSG_SAFE_CLOG2(lce_sets_p)
    , localparam lg_lce_assoc_lp=`BSG_SAFE_CLOG2(lce_assoc_p)
    , localparam lg_num_lce_lp=`BSG_SAFE_CLOG2(num_lce_p)
    , localparam lg_num_cce_lp=`BSG_SAFE_CLOG2(num_cce_p)

    , localparam ptag_width_lp=paddr_width_p-lg_lce_sets_lp-block_offset_bits_lp

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

  typedef struct packed {
    logic [`bp_cce_coh_bits-1:0] coh_st;
    logic [ptag_width_lp-1:0] tag;
  } tag_s;

  localparam tag_s_width_lp = $bits(tag_s);

  // Tag and Data Arrays
  tag_s [lce_sets_p-1:0][lce_assoc_p-1:0] tags;
  tag_s tag_n, tag_cur;
  logic tag_w, clear_set;
  logic [lg_lce_sets_lp-1:0] tag_set;
  logic [lg_lce_assoc_lp-1:0] tag_way;
  assign tag_cur = tags[tag_set][tag_way];

  logic [lce_sets_p-1:0][lce_assoc_p-1:0][cce_block_width_p-1:0] data;
  logic [cce_block_width_p-1:0] data_n, data_cur, data_mask;
  logic data_w;
  logic [lg_lce_sets_lp-1:0] data_set;
  logic [lg_lce_assoc_lp-1:0] data_way;
  assign data_cur = data[data_set][data_way];

  // current command from trace replay
  logic [tr_ring_width_lp-1:0] cmd_r, cmd_n;
  logic [dcache_opcode_width_lp-1:0] cmd_cmd;
  logic [paddr_width_p-1:0] cmd_paddr;
  logic [dword_width_p-1:0] cmd_data;
  assign cmd_cmd = cmd_r[tr_ring_width_lp-1 -: dcache_opcode_width_lp];
  assign cmd_paddr = cmd_r[dword_width_p +: paddr_width_p];
  assign cmd_data = cmd_r[0 +: dword_width_p];

  logic store_op, load_op, signed_op, byte_op, word_op, double_op, half_op;
  logic [1:0] op_size;
  assign store_op = cmd_cmd[3];
  assign load_op = ~cmd_cmd[3];
  assign signed_op = ~cmd_cmd[2];
  assign op_size = cmd_cmd[1:0];
  assign double_op = (cmd_cmd[1:0] == 2'b11);
  assign word_op = (cmd_cmd[1:0] == 2'b10);
  assign half_op = (cmd_cmd[1:0] == 2'b01);
  assign byte_op = (cmd_cmd[1:0] == 2'b00);

  logic [dword_width_p-1:0] load_data;
  logic [2:0] dword_offset;
  assign dword_offset = cmd_paddr[5:3];
  logic [2:0] byte_offset;
  assign byte_offset = cmd_paddr[2:0];
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

  tag_s [lce_assoc_p-1:0] tag_set_li;
  logic [ptag_width_lp-1:0] ptag_li;
  logic tag_hit, tag_dirty, lru_dirty;
  logic [lg_lce_assoc_lp-1:0] tag_hit_way, lru_way_r, lru_way_n, lru_way_li;
  tag_lookup
    #(.lce_assoc_p(lce_assoc_p)
      ,.ptag_width_p(ptag_width_lp)
      ,.coh_bits_p(`bp_cce_coh_bits)
      )
  lce_tag_lookup
    (.tag_set_i(tag_set_li)
     ,.ptag_i(ptag_li)
     ,.lru_way_i(lru_way_li)
     ,.hit_o(tag_hit)
     ,.dirty_o(tag_dirty)
     ,.way_o(tag_hit_way)
     ,.lru_dirty_o(lru_dirty)
     );

  typedef enum logic [7:0] {
    RESET
    ,INVALIDATE_CACHE
    ,SYNC
    ,READY
    ,TR_CMD
    ,FINISH_MISS
  } lce_state_e;

  lce_state_e lce_state, lce_state_n;

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

  logic [lg_lce_sets_lp:0] set_counter, set_counter_n;
  logic miss_r, miss_n;
  logic tag_received_r, tag_received_n;
  logic data_received_r, data_received_n;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      set_counter <= '0;

      lce_state <= RESET;

      lce_cmd_r <= '0;
      lce_data_cmd_r <= '0;

      cmd_r <= '0;

      lru_way_r <= '0;

      miss_r <= '0;
      tag_received_r <= '0;
      data_received_r <= '0;

    end else begin
      set_counter <= set_counter_n;

      lce_state <= lce_state_n;

      lce_cmd_r <= lce_cmd_n;
      lce_data_cmd_r <= lce_data_cmd_n;

      cmd_r <= cmd_n;

      lru_way_r <= lru_way_n;

      miss_r <= miss_n;
      tag_received_r <= tag_received_n;
      data_received_r <= data_received_n;

      if (tag_w) begin
        if (clear_set) begin
          tags[tag_set] <= '0;
        end else begin
          tags[tag_set][tag_way] <= tag_n;
        end
      end
      if (data_w) begin
        if (clear_set) begin
          data[data_set] <= '0;
        end else begin
          for (integer i = 0; i < cce_block_width_p; i=i+1) begin
            if (data_mask[i]) begin
              data[data_set][data_way] <= data_n;
            end
          end
        end
      end

    end
  end


  always_comb begin
    if (reset_i) begin
      set_counter_n = '0;
      lce_state_n = RESET;
      lce_cmd_n = '0;
      lce_cmd_yumi = '0;
      lce_data_cmd_n ='0;
      lce_data_cmd_yumi = '0;
      cmd_n = '0;
      lru_way_n = '0;
      miss_n = '0;
      tag_received_n = '0;
      data_received_n = '0;

      tag_n = '0;
      tag_set = '0;
      tag_way = '0;
      tag_w = '0;
      clear_set = '0;

      data_n = '0;
      data_set = '0;
      data_way = '0;
      data_w = '0;
      data_mask = '0;

      lce_req_v_o = '0;
      lce_req_s = '0;
      lce_resp_v_o = '0;
      lce_resp_s = '0;
      lce_data_resp_v_o = '0;
      lce_data_resp_s = '0;
      lce_data_cmd_v_o = '0;
      lce_data_cmd_s = '0;

      tag_set_li = '0;
      ptag_li = '0;
      lru_way_li = '0;

      load_data = '0;

      tr_pkt_yumi_o = '0;

      tr_pkt_o = '0;
      tr_pkt_v_o = '0;

    end else begin
      set_counter_n = set_counter;
      lce_state_n = lce_state;
      lce_cmd_n = lce_cmd_r;
      lce_cmd_yumi = '0;
      lce_data_cmd_n = lce_data_cmd_r;
      lce_data_cmd_yumi = '0;
      cmd_n = cmd_r;
      lru_way_n = lru_way_r;
      miss_n = miss_r;
      tag_received_n = tag_received_r;
      data_received_n = data_received_r;

      tag_n = '0;
      tag_set = '0;
      tag_way = '0;
      tag_w = '0;
      clear_set = '0;

      data_n = '0;
      data_set = '0;
      data_way = '0;
      data_w = '0;
      data_mask = '0;

      lce_req_v_o = '0;
      lce_req_s = '0;
      lce_resp_v_o = '0;
      lce_resp_s = '0;
      lce_data_resp_v_o = '0;
      lce_data_resp_s = '0;
      lce_data_cmd_v_o = '0;
      lce_data_cmd_s = '0;

      tag_set_li = '0;
      ptag_li = '0;
      lru_way_li = '0;

      load_data = '0;

      tr_pkt_yumi_o = '0;

      tr_pkt_o = '0;
      tr_pkt_v_o = '0;

      case (lce_state)
        RESET: begin
          lce_state_n = INVALIDATE_CACHE;
        end
        INVALIDATE_CACHE: begin
          if (lce_cmd_v && lce_cmd.msg_type == e_lce_cmd_set_clear) begin
            set_counter_n = set_counter + 'd1;

            // dequeue the command
            lce_cmd_yumi = 1'b1;
            lce_cmd_n = lce_cmd;
            // clear set in cache
            clear_set = 1'b1;
            tag_w = 1'b1;
            data_w = 1'b1;
            tag_set = lce_cmd.addr[block_offset_bits_lp +: lg_lce_sets_lp];
            data_set = lce_cmd.addr[block_offset_bits_lp +: lg_lce_sets_lp];

            lce_state_n = (set_counter_n == lce_sets_p) ? SYNC : INVALIDATE_CACHE;
          end
        end
        SYNC: begin
          if (lce_cmd_v && lce_resp_ready_i && lce_cmd.msg_type == e_lce_cmd_sync) begin
            lce_state_n = READY;

            lce_cmd_yumi = 1'b1;
            lce_cmd_n = lce_cmd;

            lce_resp_s.dst_id = lce_cmd.src_id;
            lce_resp_s.src_id = lce_id_i;
            lce_resp_s.msg_type = e_lce_cce_sync_ack;
            lce_resp_s.addr = '0;
            lce_resp_v_o = 1'b1;
          end
        end
        READY: begin
          if (lce_data_cmd_v) begin
            // response to miss - data
            if (lce_resp_ready_i) begin
              lce_data_cmd_yumi = 1'b1;
              lce_data_cmd_n = lce_data_cmd;
   
              data_w = 1'b1;
              // write the full cache block
              data_mask = '1;
              data_set = cmd_paddr[block_offset_bits_lp +: lg_lce_sets_lp];
              data_way = lce_data_cmd.way_id;
              data_n = lce_data_cmd.data;
              data_received_n = 1'b1;

              // miss resolved if data was already received
              // send response only if miss is resolved
              if (tag_received_r) begin
                miss_n = '0;

                lce_resp_s.dst_id = (num_cce_p == 1) ? '0 : cmd_paddr[block_offset_bits_lp +: lg_num_cce_lp];
                lce_resp_s.src_id = lce_id_i;
                lce_resp_s.msg_type = (lce_data_cmd.msg_type == e_lce_data_cmd_transfer) ? e_lce_cce_tr_ack : e_lce_cce_coh_ack;
                lce_resp_s.addr = cmd_paddr;
                lce_resp_v_o = 1'b1;

                tag_received_n = '0;
                data_received_n = '0;

                lce_state_n = FINISH_MISS;

              end
            end
          end else if (lce_cmd_v) begin
            if (lce_cmd.msg_type == e_lce_cmd_invalidate_tag) begin
              // invalidate cmd
              if (lce_resp_ready_i) begin
                lce_cmd_yumi = 1'b1;
                lce_cmd_n = lce_cmd;
    
                lce_resp_s.dst_id = lce_cmd.src_id;
                lce_resp_s.src_id = lce_id_i;
                lce_resp_s.msg_type = e_lce_cce_inv_ack;
                lce_resp_s.addr = lce_cmd.addr;
                lce_resp_v_o = 1'b1;

                tag_w = 1'b1;
                tag_set = lce_cmd.addr[block_offset_bits_lp +: lg_lce_sets_lp];
                tag_way = lce_cmd.way_id;
                tag_n.coh_st = e_MESI_I;
                tag_n.tag = tag_cur.tag;
              end
            end else if (lce_cmd.msg_type == e_lce_cmd_transfer) begin
              // transfer cmd
              lce_cmd_n = lce_cmd;

              tag_set = lce_cmd.addr[block_offset_bits_lp +: lg_lce_sets_lp];
              tag_way = lce_cmd.way_id;

              data_set = lce_cmd.addr[block_offset_bits_lp +: lg_lce_sets_lp];
              data_way = lce_cmd.way_id;

              lce_data_cmd_s.data = data_cur;
              lce_data_cmd_s.dst_id = lce_cmd.target;
              lce_data_cmd_s.msg_type = e_lce_data_cmd_transfer;
              lce_data_cmd_s.way_id = lce_cmd.target_way_id;
              lce_data_cmd_v_o = 1'b1;

              if (lce_data_cmd_ready_i) begin
                lce_cmd_yumi = 1'b1;
              end
            end else if (lce_cmd.msg_type == e_lce_cmd_writeback) begin
              // writeback cmd
              lce_cmd_n = lce_cmd;

              tag_set = lce_cmd.addr[block_offset_bits_lp +: lg_lce_sets_lp];
              tag_way = lce_cmd.way_id;

              data_set = lce_cmd.addr[block_offset_bits_lp +: lg_lce_sets_lp];
              data_way = lce_cmd.way_id;

              if (tag_cur.coh_st == e_MESI_M) begin
                lce_data_resp_s.data = data_cur;
                lce_data_resp_s.msg_type = e_lce_resp_wb;
              end else begin
                lce_data_resp_s.data = '0;
                lce_data_resp_s.msg_type = e_lce_resp_null_wb;
              end
              lce_data_resp_s.dst_id = lce_cmd.src_id;
              lce_data_resp_s.src_id = lce_id_i;
              lce_data_resp_s.addr = lce_cmd.addr;
              lce_data_resp_v_o = 1'b1;

              if (lce_data_resp_ready_i) begin
                lce_cmd_yumi = 1'b1;
              end
            end else if (lce_cmd.msg_type == e_lce_cmd_set_tag_wakeup) begin
              // response to miss - upgrade
              if (lce_resp_ready_i) begin
                lce_cmd_yumi = 1'b1;
                lce_cmd_n = lce_cmd;
    
                lce_resp_s.dst_id = lce_cmd.src_id;
                lce_resp_s.src_id = lce_id_i;
                lce_resp_s.msg_type = e_lce_cce_coh_ack;
                lce_resp_s.addr = lce_cmd.addr;
                lce_resp_v_o = 1'b1;

                tag_w = 1'b1;
                tag_set = lce_cmd.addr[block_offset_bits_lp +: lg_lce_sets_lp];
                tag_way = lce_cmd.way_id;
                tag_n.coh_st = lce_cmd.state;
                tag_n.tag = tag_cur.tag;

                // miss resolved
                miss_n = '0;

                lce_state_n = FINISH_MISS;
              end
            end else if (lce_cmd.msg_type == e_lce_cmd_set_tag) begin
              // response to miss - tag
              if (lce_resp_ready_i) begin
                lce_cmd_yumi = 1'b1;
                lce_cmd_n = lce_cmd;
    
                tag_w = 1'b1;
                tag_set = lce_cmd.addr[block_offset_bits_lp +: lg_lce_sets_lp];
                tag_way = lce_cmd.way_id;
                tag_n.coh_st = lce_cmd.state;
                tag_n.tag = tag_cur.tag;
                tag_received_n = 1'b1;

                // miss resolved if data was already received
                // send response only if miss is resolved
                if (data_received_r) begin
                  miss_n = '0;

                  lce_resp_s.dst_id = lce_cmd.src_id;
                  lce_resp_s.src_id = lce_id_i;
                  lce_resp_s.msg_type = (lce_data_cmd_r.msg_type == e_lce_data_cmd_transfer) ? e_lce_cce_tr_ack : e_lce_cce_coh_ack;
                  lce_resp_s.addr = lce_cmd.addr;
                  lce_resp_v_o = 1'b1;

                  tag_received_n = '0;
                  data_received_n = '0;

                  lce_state_n = FINISH_MISS;

                end
              end

            end
          end else if (tr_pkt_v_i & ~miss_r) begin
            // only process a new trace replay request if not already missing
            tr_pkt_yumi_o = 1'b1;
            cmd_n = tr_pkt_i;
            lce_state_n = TR_CMD;
          end
        end
        TR_CMD: begin
          // set up tag lookup
          tag_set = cmd_paddr[block_offset_bits_lp +: lg_lce_sets_lp];
          tag_set_li = tags[tag_set];
          ptag_li = cmd_paddr[paddr_width_p-1 -: ptag_width_lp];
          lru_way_li = lru_way_r;

          // consume output
          tag_way = tag_hit_way;

          // process the trace replay command
          data_set = cmd_paddr[block_offset_bits_lp +: lg_lce_sets_lp];
          data_way = tag_hit_way;

          if (tag_hit && load_op) begin
            // load hit
            if (tr_pkt_ready_i) begin
              tr_pkt_v_o = 1'b1;
              tr_pkt_o[tr_ring_width_lp-1:dword_width_p] = '0;
              // select data to return
              load_data = data_cur[dword_offset*dword_width_p +: dword_width_p];
              tr_pkt_o[0 +: dword_width_p] = double_op
                ? load_data
                : (word_op
                  ? {{32{word_sigext}}, load_word}
                  : (half_op
                    ? {{48{half_sigext}}, load_half}
                    : {{56{byte_sigext}}, load_byte}));

              lce_state_n = READY;
            end
          end else if (~tag_hit && load_op) begin
            // load miss, send lce request
            if (lce_req_ready_i) begin
              lce_req_v_o = 1'b1;

              lce_req_s.dst_id = '0;
              lce_req_s.src_id = lce_id_i;
              lce_req_s.data = '0;
              lce_req_s.msg_type = e_lce_req_type_rd;
              lce_req_s.non_exclusive = e_lce_req_excl;
              lce_req_s.addr = cmd_paddr;
              lce_req_s.lru_way_id = lru_way_r;
              lce_req_s.lru_dirty = (lru_dirty ? e_lce_req_lru_dirty : e_lce_req_lru_clean);
              lce_req_s.non_cacheable = e_lce_req_cacheable;
              lce_req_s.nc_size = e_lce_nc_req_1;

              lce_state_n = READY;

              miss_n = 1'b1;
              tag_received_n = '0;
              data_received_n = '0;
            end
          end else if (~tag_hit && store_op) begin
            // store miss - block present, not writable
            if (lce_req_ready_i) begin
              lce_req_v_o = 1'b1;

              lce_req_s.dst_id = '0;
              lce_req_s.src_id = lce_id_i;
              lce_req_s.data = '0;
              lce_req_s.msg_type = e_lce_req_type_wr;
              lce_req_s.non_exclusive = e_lce_req_excl;
              lce_req_s.addr = cmd_paddr;
              lce_req_s.lru_way_id = lru_way_r;
              lce_req_s.lru_dirty = (lru_dirty ? e_lce_req_lru_dirty : e_lce_req_lru_clean);
              lce_req_s.non_cacheable = e_lce_req_cacheable;
              lce_req_s.nc_size = e_lce_nc_req_1;

              lce_state_n = READY;

              miss_n = 1'b1;
              tag_received_n = '0;
              data_received_n = '0;
            end
          end else if (tag_hit && store_op && ((tag_cur.coh_st == e_MESI_M) || (tag_cur.coh_st == e_MESI_E))) begin
            // store hit
            if (tr_pkt_ready_i) begin
              tr_pkt_v_o = 1'b1;
              // stores return 0 to trace replay
              tr_pkt_o = '0;

              // store hit on Exclusive forces upgrade to Modified
              if (tag_cur.coh_st == e_MESI_E) begin
                tag_w = 1'b1;
                tag_n.coh_st = e_MESI_M;
                tag_n.tag = tag_cur.tag;
              end

              // do the store
              data_w = 1'b1;
              data_mask = double_op
                ? {{(cce_block_width_p-64){1'b0}}, {64{1'b1}}} << (dword_offset*64)
                : word_op
                  ? {{(cce_block_width_p-32){1'b0}}, {32{1'b1}}} << (dword_offset*64 + 32*byte_offset[2])
                  : half_op
                    ? {{(cce_block_width_p-16){1'b0}}, {16{1'b1}}} << (dword_offset*64 + 16*byte_offset[2:1])
                    : {{(cce_block_width_p-8){1'b0}}, {8{1'b1}}} << (dword_offset*64 + 8*byte_offset[2:0]);

              data_n = double_op
                ? {{(cce_block_width_p-64){1'b0}}, cmd_data} << (dword_offset*64)
                : word_op
                  ? {{(cce_block_width_p-32){1'b0}}, cmd_data[0+:32]} << (dword_offset*64 + 32*byte_offset[2])
                  : half_op
                    ? {{(cce_block_width_p-16){1'b0}}, cmd_data[0+:16]} << (dword_offset*64 + 16*byte_offset[2:1])
                    : {{(cce_block_width_p-8){1'b0}}, cmd_data[0+:8]} << (dword_offset*64 + 8*byte_offset[2:0]);

              lce_state_n = READY;
            end
          end else if (tag_hit && store_op && (tag_cur.coh_st == e_MESI_S)) begin
            // store miss - block present, not writable
            if (lce_req_ready_i) begin
              lce_req_v_o = 1'b1;

              lce_req_s.dst_id = '0;
              lce_req_s.src_id = lce_id_i;
              lce_req_s.data = '0;
              lce_req_s.msg_type = e_lce_req_type_wr;
              lce_req_s.non_exclusive = e_lce_req_excl;
              lce_req_s.addr = cmd_paddr;
              lce_req_s.lru_way_id = tag_hit_way;
              lce_req_s.lru_dirty = e_lce_req_lru_clean;
              lce_req_s.non_cacheable = e_lce_req_cacheable;
              lce_req_s.nc_size = e_lce_nc_req_1;

              lce_state_n = READY;

              miss_n = 1'b1;
              tag_received_n = '0;
              data_received_n = '0;
            end
          end
        end
        FINISH_MISS: begin

          // send return packet back to TR after CCE handles the LCE miss request
          if (tr_pkt_ready_i) begin
            // rotate lru way
            //lru_way_n = lru_way_r + 'd1;

            tr_pkt_v_o = 1'b1;
            tr_pkt_o[tr_ring_width_lp-1:dword_width_p] = '0;
            if (load_op) begin
              // select data to return
              tag_set = cmd_paddr[block_offset_bits_lp +: lg_lce_sets_lp];
              tag_set_li = tags[tag_set];
              tag_way = tag_hit_way;
              ptag_li = cmd_paddr[paddr_width_p-1 -: ptag_width_lp];
              data_set = cmd_paddr[block_offset_bits_lp +: lg_lce_sets_lp];
              data_way = (tag_hit && store_op) ? tag_hit_way : lru_way_r;
              //data_way = lru_way_r;
              load_data = data_cur[dword_offset*dword_width_p +: dword_width_p];
              tr_pkt_o[0 +: dword_width_p] = double_op
                ? load_data
                : (word_op
                  ? {{32{word_sigext}}, load_word}
                  : (half_op
                    ? {{48{half_sigext}}, load_half}
                    : {{56{byte_sigext}}, load_byte}));

            end else begin
              tr_pkt_o[0 +: dword_width_p] = '0;
            end
            lce_state_n = READY;

          end
        end
        default: begin
          lce_state_n = RESET;
        end
      endcase
    end
  end

endmodule


