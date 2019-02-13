/**
 * bp_me_nonsynth_mock_cce.v
 *
 * This is a "mock" cce that can be used to test the coherence actions of a single LCE.
 *
 */

module bp_me_nonsynth_mock_cce
  import bp_common_pkg::*;
  import bp_cce_pkg::*;
  #(parameter cce_id_p=0
    ,parameter num_lce_p=1
    ,parameter num_cce_p=1
    ,parameter addr_width_p=22
    ,parameter lce_assoc_p=8
    ,parameter lce_sets_p=64
    ,parameter block_size_in_bytes_p=64
    ,parameter block_size_in_bits_lp=block_size_in_bytes_p*8

    ,parameter bp_lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p, num_lce_p, addr_width_p, lce_assoc_p)
    ,parameter bp_lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p, num_lce_p, addr_width_p)
    ,parameter bp_lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, addr_width_p, block_size_in_bits_lp)
    ,parameter bp_cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p, num_lce_p, addr_width_p, lce_assoc_p)
    ,parameter bp_cce_lce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p, num_lce_p, addr_width_p, block_size_in_bits_lp, lce_assoc_p)

    ,parameter bp_lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_p, addr_width_p, block_size_in_bits_lp, lce_assoc_p)

  )
  (
    input                                                  clk_i
    ,input                                                 reset_i

    // LCE-CCE Interface
    // inbound: ready_o->valid_i, helpful
    // outbound: ready_i->valid_o, demanding

    // Inbound
    ,input [bp_lce_cce_req_width_lp-1:0]                   lce_req_i
    ,input                                                 lce_req_v_i
    ,output logic                                          lce_req_ready_o

    ,input [bp_lce_cce_resp_width_lp-1:0]                  lce_resp_i
    ,input                                                 lce_resp_v_i
    ,output logic                                          lce_resp_ready_o

    ,input [bp_lce_cce_data_resp_width_lp-1:0]             lce_data_resp_i
    ,input                                                 lce_data_resp_v_i
    ,output logic                                          lce_data_resp_ready_o

    ,input [bp_lce_lce_tr_resp_width_lp-1:0]               lce_lce_tr_resp_i
    ,input                                                 lce_lce_tr_resp_i_v_i
    ,output logic                                          lce_lce_tr_resp_i_ready_o

    // Outbound
    ,output logic [bp_cce_lce_cmd_width_lp-1:0]            lce_cmd_o
    ,output logic                                          lce_cmd_v_o
    ,input                                                 lce_cmd_ready_i

    ,output logic [bp_cce_lce_data_cmd_width_lp-1:0]       lce_data_cmd_o
    ,output logic                                          lce_data_cmd_v_o
    ,input                                                 lce_data_cmd_ready_i

    ,output [bp_lce_lce_tr_resp_width_lp-1:0]              lce_lce_tr_resp_o
    ,output logic                                          lce_lce_tr_resp_o_v_o
    ,input logic                                           lce_lce_tr_resp_o_ready_i
  );

  logic [bp_lce_cce_req_width_lp-1:0]            lce_req_to_cce;
  logic                                          lce_req_v_to_cce;
  logic                                          lce_req_yumi_from_cce;
  logic [bp_lce_cce_resp_width_lp-1:0]           lce_resp_to_cce;
  logic                                          lce_resp_v_to_cce;
  logic                                          lce_resp_yumi_from_cce;
  logic [bp_lce_cce_data_resp_width_lp-1:0]      lce_data_resp_to_cce;
  logic                                          lce_data_resp_v_to_cce;
  logic                                          lce_data_resp_yumi_from_cce;
  logic [bp_lce_lce_tr_resp_width_lp-1:0]        lce_lce_tr_resp_to_cce;
  logic                                          lce_lce_tr_resp_v_to_cce;
  logic                                          lce_lce_tr_resp_yumi_from_cce;

  // Inbound LCE to CCE
  bsg_two_fifo
    #(.width_p(bp_lce_cce_req_width_lp)
      ,.ready_THEN_valid_p(1) // ready-then-valid
    )
    lce_cce_req_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.v_i(lce_req_v_i)
     ,.data_i(lce_req_i)
     ,.ready_o(lce_req_ready_o)
     ,.v_o(lce_req_v_to_cce)
     ,.data_o(lce_req_to_cce)
     ,.yumi_i(lce_req_yumi_from_cce)
    );

  bsg_two_fifo
    #(.width_p(bp_lce_cce_resp_width_lp)
      ,.ready_THEN_valid_p(1) // ready-then-valid
    )
    lce_cce_resp_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.v_i(lce_resp_v_i)
     ,.data_i(lce_resp_i)
     ,.ready_o(lce_resp_ready_o)
     ,.v_o(lce_resp_v_to_cce)
     ,.data_o(lce_resp_to_cce)
     ,.yumi_i(lce_resp_yumi_from_cce)
    );

  bsg_two_fifo
    #(.width_p(bp_lce_cce_data_resp_width_lp)
      ,.ready_THEN_valid_p(1) // ready-then-valid
    )
    lce_cce_data_resp_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.v_i(lce_data_resp_v_i)
     ,.data_i(lce_data_resp_i)
     ,.ready_o(lce_data_resp_ready_o)
     ,.v_o(lce_data_resp_v_to_cce)
     ,.data_o(lce_data_resp_to_cce)
     ,.yumi_i(lce_data_resp_yumi_from_cce)
    );

  bsg_two_fifo
    #(.width_p(bp_lce_lce_tr_resp_width_lp)
      ,.ready_THEN_valid_p(1) // ready-then-valid
    )
    lce_lce_tr_resp_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.v_i(lce_lce_tr_resp_i_v_i)
     ,.data_i(lce_lce_tr_resp_i)
     ,.ready_o(lce_lce_tr_resp_i_ready_o)
     ,.v_o(lce_lce_tr_resp_v_to_cce)
     ,.data_o(lce_lce_tr_resp_to_cce)
     ,.yumi_i(lce_lce_tr_resp_yumi_from_cce)
    );

  // CCE state machine
  // When an LCE sends a request, the LCE can receive one of three responses:
  // 1. data_cmd followed by set_tag_cmd (normal)
  // 2. set_tag_cmd and lce_lce_tr_response (transfer)
  // 3. set_tag_and_wakeup_cmd (upgrade)
  //
  // for cases 1 and 2, the requesting LCE may also be commanded to writeback the LRU way

  `declare_bp_lce_cce_req_s(num_cce_p, num_lce_p, addr_width_p, lce_assoc_p);
  `declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, addr_width_p);
  `declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_p, addr_width_p, block_size_in_bits_lp);
  `declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, addr_width_p, lce_assoc_p);
  `declare_bp_cce_lce_data_cmd_s(num_cce_p, num_lce_p, addr_width_p, block_size_in_bits_lp, lce_assoc_p);
  `declare_bp_lce_lce_tr_resp_s(num_lce_p, addr_width_p, block_size_in_bits_lp, lce_assoc_p);

  // Registers for LCE to CCE messages
  bp_lce_cce_req_s          lce_req_r;
  bp_lce_cce_resp_s         lce_resp_r;
  bp_lce_cce_data_resp_s    lce_data_resp_r;
  bp_lce_lce_tr_resp_s      lce_lce_tr_resp_i_r;

  // Registers for CCE to LCE messages
  bp_lce_lce_tr_resp_s      lce_lce_tr_resp_o_r;
  bp_cce_lce_cmd_s          lce_cmd_r;
  bp_cce_lce_data_cmd_s     lce_data_cmd_r;

  typedef enum logic [2:0] {
    READY             = 3'b000
    ,START_REQ        = 3'b001
  } cce_st_e;

  cce_st_e cce_st;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      cce_st <= READY;

      // inputs
      lce_req_r <= '0;
      lce_req_yumi_from_cce <= '0;
      lce_resp_r <= '0;
      lce_resp_yumi_from_cce <= '0;
      lce_data_resp_r <= '0;
      lce_data_resp_yumi_from_cce <= '0;
      lce_lce_tr_resp_i_r <= '0;
      lce_lce_tr_resp_yumi_from_cce <= '0;

      // outputs
      lce_lce_tr_resp_o_r <= '0;
      lce_lce_tr_resp_o_v_o <= '0;
      lce_cmd_r <= '0;
      lce_cmd_v_o <= '0;
      lce_data_cmd_r <= '0;
      lce_data_cmd_v_o <= '0;

    end

    case (cce_st)
      READY: begin
        lce_req_ready_o <= '1;
        if (lce_req_v_i) begin
          lce_req_r <= lce_req_i;
          lce_req_ready_o <= '0;
          cce_st <= START_REQ;
        end
      end
      START_REQ: begin

      end
      default: cce_st <= READY;
    endcase
  end


endmodule
