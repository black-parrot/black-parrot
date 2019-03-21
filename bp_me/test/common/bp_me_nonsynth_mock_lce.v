/**
 * bp_me_nonsynth_mock_lce.v
 *
 */

module bp_me_nonsynth_mock_lce
  import bp_common_pkg::*;
  import bp_cce_pkg::*;
  import bp_be_dcache_pkg::*;
  #(parameter num_lce_p="inv"
    ,parameter num_cce_p="inv"
    ,parameter paddr_width_p="inv"
    ,parameter lce_assoc_p="inv"
    ,parameter lce_sets_p="inv"
    ,parameter block_size_in_bytes_p="inv"

    ,localparam block_size_in_bits_lp=(block_size_in_bytes_p*8)
    ,localparam block_offset_bits_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_p)
    ,localparam lg_lce_sets_lp=`BSG_SAFE_CLOG2(lce_sets_p)
    ,localparam lg_lce_assoc_lp=`BSG_SAFE_CLOG2(lce_assoc_p)

    ,localparam lg_num_lce_lp=`BSG_SAFE_CLOG2(num_lce_p)
    ,localparam lg_num_cce_lp=`BSG_SAFE_CLOG2(num_cce_p)

    ,localparam bp_lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p)
    ,localparam bp_lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p, num_lce_p, paddr_width_p)
    ,localparam bp_lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, paddr_width_p, block_size_in_bits_lp)
    ,localparam bp_cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p)
    ,localparam bp_cce_lce_data_cmd_width_lp=`bp_lce_data_cmd_width(num_lce_p, block_size_in_bits_lp, lce_assoc_p)

    // TODO: 4 is for dcache cmd, 64 is for word-size, which will be 64 unless we go crazy
    ,localparam dcache_cmd_width_lp=(4+paddr_width_p+64)
  )
  (
    input                                                   clk_i
    ,input                                                  reset_i

    // TODO: this interface will conform to the trace replay format
    // the input packets are the same as the dcache trace replay packets: {dcache_cmd, paddr, data}
    ,input [dcache_cmd_width_lp-1:0]                        cmd_i
    ,input                                                  cmd_v_i
    ,output logic                                           cmd_yumi_o

    ,output logic [63:0]                                    data_o
    ,output logic                                           data_v_o
    ,input                                                  data_ready_i

    // LCE-CCE Interface
    // inbound: valid->ready (a.k.a. valid->yumi), demanding
    // outbound: ready->valid, demanding
    ,output logic [bp_lce_cce_req_width_lp-1:0]             lce_req_o
    ,output logic                                           lce_req_v_o
    ,input                                                  lce_req_ready_i

    ,output logic [bp_lce_cce_resp_width_lp-1:0]            lce_resp_o
    ,output logic                                           lce_resp_v_o
    ,input                                                  lce_resp_ready_i

    ,output logic [bp_lce_cce_data_resp_width_lp-1:0]       lce_data_resp_o
    ,output logic                                           lce_data_resp_v_o
    ,input                                                  lce_data_resp_ready_i

    ,input [bp_cce_lce_cmd_width_lp-1:0]                    lce_cmd_i
    ,input                                                  lce_cmd_v_i
    ,output logic                                           lce_cmd_ready_o

    ,input [bp_lce_data_cmd_width_lp-1:0]                   lce_data_cmd_i
    ,input                                                  lce_data_cmd_v_i
    ,output logic                                           lce_data_cmd_ready_o
  );

  `declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, block_size_in_bits_lp);

  typedef struct {
    logic [ptag_width_lp-1:0] tag;
    logic [bp_cce_coh_bits-1:0] coh_st;
  } tag_s;

  localparam tag_s_width_lp = $bits(tag_s);

  // Tag and Data Arrays
  logic [lg_lce_sets_lp-1:0][lg_lce_assoc_lp-1:0][tag_s_width_lp-1:0] tags;
  logic [lg_lce_sets_lp-1:0][lg_lce_assoc_lp-1:0][block_size_in_bits_lp-1:0] data;

  // current command decode
  logic [dcache_cmd_width_lp-1:0] cmd_r;
  logic [3:0] cmd_cmd_r;
  logic [paddr_width_p-1:0] cmd_paddr_r;
  logic [63:0] cmd_data_r;

  logic store_cmd, load_unsigned;
  assign store_cmd = cmd_cmd_r[3];
  assign load_unsigned = cmd_cmd_r[2] & ~store_cmd;

  typedef enum [7:0] {
    RESET
    ,INVALIDATE_CACHE
    ,READY
    ,SEND_REQ
    ,WAIT_TAG_OR_DATA
    ,WAIT_DATA
    ,WAIT_TAG
    ,SEND_DATA_RESP
    ,SEND_RESP
    ,RETURN_DATA
  } lce_state_e;

  always_ff @(posedge clk_i) begin

  end

endmodule
