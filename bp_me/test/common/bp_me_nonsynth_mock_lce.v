/**
 * bp_me_nonsynth_mock_lce.v
 *
 * This mock LCE behaves like a mock D$. It connects to a trace replay module and to the BP ME.
 * The trace replay format is the same as the trace replay format for the D$.
 */

module bp_me_nonsynth_mock_lce
  import bp_common_pkg::*;
  import bp_cce_pkg::*;
  import bp_be_dcache_pkg::*;
  #(parameter num_lce_p="inv"
    ,parameter num_cce_p="inv"
    ,parameter paddr_width_p="inv" // must match paddr width used when generating trace replay
    ,parameter lce_assoc_p="inv"
    ,parameter lce_sets_p="inv"
    ,parameter block_size_in_bytes_p="inv"

    ,localparam block_size_in_bits_lp=(block_size_in_bytes_p*8)
    ,localparam block_offset_bits_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_p)
    ,localparam lg_lce_sets_lp=`BSG_SAFE_CLOG2(lce_sets_p)
    ,localparam lg_lce_assoc_lp=`BSG_SAFE_CLOG2(lce_assoc_p)

    ,localparam ptag_width_lp=paddr_width_p-lg_lce_sets_lp-block_offset_bits_lp

    ,localparam lg_num_lce_lp=`BSG_SAFE_CLOG2(num_lce_p)
    ,localparam lg_num_cce_lp=`BSG_SAFE_CLOG2(num_cce_p)

    ,parameter dcache_word_size_bits_p=64
    ,localparam dcache_opcode_width_lp=$bits(bp_be_dcache_opcode_e)
    ,localparam tr_ring_width_lp=(dcache_opcode_width_lp+paddr_width_p+dcache_word_size_bits_p)

`declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dcache_word_size_bits_p, block_size_in_bits_lp)
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
    logic [ptag_width_lp-1:0] tag;
    logic [`bp_cce_coh_bits-1:0] coh_st;
  } tag_s;

  localparam tag_s_width_lp = $bits(tag_s);

  // Tag and Data Arrays
  tag_s [lg_lce_sets_lp-1:0][lg_lce_assoc_lp-1:0] tags;
  logic [lg_lce_sets_lp-1:0][lg_lce_assoc_lp-1:0][block_size_in_bits_lp-1:0] data;

  // current command from trace replay
  logic [tr_ring_width_lp-1:0] cmd_r, cmd_n;
  logic [dcache_opcode_width_lp-1:0] cmd_cmd;
  logic [paddr_width_p-1:0] cmd_paddr;
  logic [dcache_word_size_bits_p-1:0] cmd_data;
  assign cmd_cmd = cmd_r[tr_ring_width_lp-1 -: dcache_opcode_width_lp];
  assign cmd_paddr = cmd_r[dcache_word_size_bits_p +: paddr_width_p];
  assign cmd_data = cmd_r[0 +: dcache_word_size_bits_p];

  logic store_op, load_op, signed_op;
  logic [1:0] op_size;
  assign store_op = cmd_cmd[3];
  assign load_op = ~cmd_cmd[3];
  assign signed_op = ~cmd_cmd[2];
  assign op_size = cmd_cmd[1:0];

  typedef enum logic [7:0] {
    RESET
    ,INVALIDATE_CACHE
    ,SYNC
    ,READY
  } lce_state_e;

  lce_state_e lce_state, lce_state_n;

  // LCE-CCE interface structs
  `declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dcache_word_size_bits_p, block_size_in_bits_lp);

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

  logic [lg_lce_sets_lp-1:0] set_counter, set_counter_n;

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
    end else begin
      set_counter_n = '0;
      lce_state_n = RESET;
      lce_cmd_n = '0;
      lce_cmd_yumi = '0;
      lce_data_cmd_n = '0;
      lce_data_cmd_yumi = '0;
      cmd_n = '0;

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
            //tags[lce_cmd.addr[block_offset_bits_lp +: lg_lce_sets_lp]] = '0;
            //data[lce_cmd.addr[block_offset_bits_lp +: lg_lce_sets_lp]] = '0;

            lce_state_n = (set_counter < lce_sets_p-1) ? INVALIDATE_CACHE : RESET;
          end
        end
        SYNC: begin
          if (lce_cmd_v && lce_resp_ready_i && lce_cmd.msg_type == e_lce_cmd_sync) begin
            lce_state_n = RESET;

            lce_cmd_yumi = 1'b1;
            lce_cmd_n = lce_cmd;

            lce_resp_s.dst_id = lce_cmd.src_id;
            lce_resp_s.src_id = lce_id_i;
            lce_resp_s.msg_type = e_lce_cce_sync_ack;
            lce_resp_s.addr = '0;
            lce_resp_v_o = 1'b1;
          end
        end
        /*
        READY: begin
          // accept lce cmd or trace replay cmd
          if (tr_pkt_v_i) begin
            tr_pkt_yumi_o <= 1'b1;
            cmd_r <= tr_pkt_i;
            lce_state <= TR_PKT;
          end
        end
        TR_PKT: begin
          // hit
          // miss
        end
        LCE_CMD: begin
        end
        */
        default: begin
          lce_state_n = RESET;
        end
      endcase
    end
  end

endmodule
