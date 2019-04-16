/**
 * bp_me_nonsynth_mock_lce.v
 *
 * This mock LCE behaves like a mock D$. It connects to a trace replay module and to the BP ME.
 * The trace replay format is the same as the trace replay format for the D$.
 */

module tag_lookup
  #(parameter lce_assoc_p="inv"
    , parameter ptag_width_p="inv"
    , parameter coh_bits_p="inv"
    , localparam tag_s_width_lp=(coh_bits_p+ptag_width_p)
    , localparam lg_lce_assoc_lp=`BSG_SAFE_CLOG2(lce_assoc_p)
   )
  (input [lg_lce_assoc_lp-1:0][tag_s_width_lp-1:0] tag_set_i
   , input [ptag_width_p-1:0] ptag_i
   , output logic hit_o
   , output logic [lg_lce_assoc_lp-1:0] way_o
  );
  typedef struct packed {
    logic [coh_bits_p-1:0] coh_st;
    logic [ptag_width_p-1:0] tag;
  } tag_s;

  tag_s [lg_lce_assoc_lp-1:0] tags;
  assign tags = tag_set_i;

  logic [lg_lce_assoc_lp-1:0] hits;
  int i;
  always_comb begin
    for (i = 0; i < lce_assoc_p; i=i+1) begin
      if (tags[i].tag == ptag_i && tags[i].coh_st != '0) begin
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

endmodule


module bp_me_nonsynth_mock_lce
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_be_dcache_pkg::*;
  #(parameter bp_cfg_e cfg_p = "inv"
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
  tag_s [lg_lce_sets_lp-1:0][lg_lce_assoc_lp-1:0] tags;
  tag_s tag_n, tag_cur;
  logic tag_w, clear_set;
  logic [lg_lce_sets_lp-1:0] tag_set;
  logic [lg_lce_assoc_lp-1:0] tag_way;
  assign tag_cur = tags[tag_set][tag_way];

  logic [lg_lce_sets_lp-1:0][lg_lce_assoc_lp-1:0][cce_block_width_p-1:0] data;
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

  logic store_op, load_op, signed_op;
  logic [1:0] op_size;
  assign store_op = cmd_cmd[3];
  assign load_op = ~cmd_cmd[3];
  assign signed_op = ~cmd_cmd[2];
  assign op_size = cmd_cmd[1:0];

  tag_s [lg_lce_assoc_lp-1:0] tag_set_li;
  logic [ptag_width_lp-1:0] ptag_li;
  logic tag_hit;
  logic [lg_lce_assoc_lp-1:0] tag_hit_way;
  tag_lookup
    #(.lce_assoc_p(lce_assoc_p)
      ,.ptag_width_p(ptag_width_lp)
      ,.coh_bits_p(`bp_cce_coh_bits)
      )
  lce_tag_lookup
    (.tag_set_i(tag_set_li)
     ,.ptag_i(ptag_li)
     ,.hit_o(tag_hit)
     ,.way_o(tag_hit_way)
     );

  typedef enum logic [7:0] {
    RESET
    ,INVALIDATE_CACHE
    ,SYNC
    ,READY
    ,TR_CMD
    ,WAIT_TAG_OR_DATA
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

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      set_counter <= '0;

      lce_state <= RESET;

      lce_cmd_r <= '0;
      lce_data_cmd_r <= '0;

      cmd_r <= '0;

    end else begin
      set_counter <= set_counter_n;

      lce_state <= lce_state_n;

      lce_cmd_r <= lce_cmd_n;
      lce_data_cmd_r <= lce_data_cmd_n;

      cmd_r <= cmd_n;

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
      lce_data_cmd_n = '0;
      lce_data_cmd_yumi = '0;
      cmd_n = '0;

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

      lce_resp_v_o = '0;
      lce_resp_s = '0;

      tag_set_li = '0;
      ptag_li = '0;

    end else begin
      set_counter_n = set_counter;
      lce_state_n = lce_state;
      lce_cmd_n = '0;
      lce_cmd_yumi = '0;
      lce_data_cmd_n = '0;
      lce_data_cmd_yumi = '0;
      cmd_n = '0;

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

      lce_resp_v_o = '0;
      lce_resp_s = '0;

      tag_set_li = '0;
      ptag_li = '0;

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
          // In READY, handle either unsolicited command from CCE, or a new trace replay packet
          if (lce_cmd_v) begin
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
              if (lce_data_cmd_ready_i) begin
                lce_cmd_yumi = 1'b1;
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
              end
            end else if (lce_cmd.msg_type == e_lce_cmd_writeback) begin
              // writeback cmd
              if (lce_data_resp_ready_i) begin
                lce_cmd_yumi = 1'b1;
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
              end
            end
          end else
          if (tr_pkt_v_i) begin
            tr_pkt_yumi_o = 1'b1;
            cmd_n = tr_pkt_i;
            lce_state_n = TR_CMD;
          end
        end
        TR_CMD: begin
          tag_set = cmd_paddr[block_offset_bits_lp +: lg_lce_sets_lp];
          tag_set_li = tags[tag_set];
          ptag_li = cmd_paddr[paddr_width_p-1 -: ptag_width_lp];

          if (tag_hit) begin
            // hit, do load or store
            // TODO: return correct packet to trace replay
            if (tr_pkt_ready_i) begin
              tr_pkt_v_o = 1'b1;
              tr_pkt_o[tr_ring_width_lp-1:dword_width_p] = '0;
              if (load_op) begin
                tr_pkt_o[0 +: dword_width_p] = '0;
              end else begin
                tr_pkt_o[0 +: dword_width_p] = '0;
              end
            end
            lce_state_n = READY;
          end else begin
            // miss, send lce request
            if (lce_req_ready_i) begin
              lce_req_v_o = 1'b1;

              lce_req_s.dst_id = '0;
              lce_req_s.src_id = lce_id_i;
              lce_req_s.data = '0;
              lce_req_s.msg_type = (store_op) ? e_lce_req_type_wr : e_lce_req_type_rd;
              lce_req_s.non_exclusive = e_lce_req_excl;
              lce_req_s.addr = cmd_paddr;
              lce_req_s.lru_way_id = '0;
              lce_req_s.lru_dirty = 1'b1;
              lce_req_s.non_cacheable = e_lce_req_cacheable;
              lce_req_s.nc_size = '0;

              lce_state_n = WAIT_TAG_OR_DATA;
            end
          end
        end
        WAIT_TAG_OR_DATA: begin
          lce_state_n = READY;
        end
        default: begin
          lce_state_n = RESET;
        end
      endcase
    end
  end

endmodule


