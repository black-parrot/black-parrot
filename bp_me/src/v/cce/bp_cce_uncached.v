/**
 *
 * Name:
 *   bp_cce_uncached.v
 *
 * Description:
 *   This module handles the forwarding of uncached memory accesses from the LCEs to the Memory
 *   when the CCE is in the uncached only access mode (i.e., executing prior to the microcode
 *   being loaded).
 *
 * Uncached Request Flow:
 *   Load: LCE REQ -> MEM CMD -> MEM DATA RESP -> LCE DATA CMD
 *   Store: LCE REQ -> MEM DATA CMD -> MEM RESP
 *
 * Priority ordering
 * 1. Mem Data Cmd
 * 2. Mem Resp
 * 3. LCE Req
 *
 */

module bp_cce_uncached
  import bp_common_pkg::*;
  import bp_cce_pkg::*;
  #(parameter num_lce_p                    = "inv"
    , parameter num_cce_p                  = "inv"
    , parameter paddr_width_p              = "inv"
    , parameter lce_assoc_p                = "inv"
    , parameter lce_sets_p                 = "inv"
    , parameter block_size_in_bytes_p      = "inv"
    , parameter lce_req_data_width_p       = "inv"

    // Derived parameters
    , localparam lg_num_cce_lp             = `BSG_SAFE_CLOG2(num_cce_p)
    , localparam block_size_in_bits_lp     = (block_size_in_bytes_p*8)
    `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, lce_req_data_width_p, block_size_in_bits_lp)
    `declare_bp_me_if_widths(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p)

  )
  (input                                               clk_i
   , input                                             reset_i

   , input [lg_num_cce_lp-1:0]                         cce_id_i
   , input bp_cce_mode_e                               cce_mode_i

   // LCE-CCE Interface
   // inbound: valid->ready (a.k.a., valid->yumi), demanding consumer (connects to FIFO)
   // outbound: ready&valid (connects directly to ME network)
   , input [lce_cce_req_width_lp-1:0]                  lce_req_i
   , input                                             lce_req_v_i
   , output logic                                      lce_req_yumi_o

   , output logic [cce_lce_cmd_width_lp-1:0]           lce_cmd_o
   , output logic                                      lce_cmd_v_o
   , input                                             lce_cmd_ready_i

   , output logic [lce_data_cmd_width_lp-1:0]          lce_data_cmd_o
   , output logic                                      lce_data_cmd_v_o
   , input                                             lce_data_cmd_ready_i

   // CCE-MEM Interface
   // inbound: valid->ready (a.k.a., valid->yumi), demanding consumer (connects to FIFO)
   // outbound: ready&valid (connects to FIFO)
   , input [mem_cce_resp_width_lp-1:0]                 mem_resp_i
   , input                                             mem_resp_v_i
   , output logic                                      mem_resp_yumi_o

   , input [mem_cce_data_resp_width_lp-1:0]            mem_data_resp_i
   , input                                             mem_data_resp_v_i
   , output logic                                      mem_data_resp_yumi_o

   , output logic [cce_mem_cmd_width_lp-1:0]           mem_cmd_o
   , output logic                                      mem_cmd_v_o
   , input                                             mem_cmd_ready_i

   , output logic [cce_mem_data_cmd_width_lp-1:0]      mem_data_cmd_o
   , output logic                                      mem_data_cmd_v_o
   , input                                             mem_data_cmd_ready_i
  );

  `declare_bp_me_if(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p);
  `declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, lce_req_data_width_p, block_size_in_bits_lp);

  // structures for casting
  // inbound
  bp_lce_cce_req_s lce_req, lce_req_r, lce_req_n;
  bp_mem_cce_resp_s mem_resp;
  bp_mem_cce_data_resp_s mem_data_resp;

  // outbound
  bp_cce_lce_cmd_s lce_cmd;
  bp_lce_data_cmd_s lce_data_cmd;
  bp_cce_mem_cmd_s mem_cmd;
  bp_cce_mem_data_cmd_s mem_data_cmd;

  // cast output queue messages from structure variables
  assign lce_cmd_o = lce_cmd;
  assign lce_data_cmd_o = lce_data_cmd;
  assign mem_cmd_o = mem_cmd;
  assign mem_data_cmd_o = mem_data_cmd;

  // cast input queue messages to structure variables
  assign lce_req = lce_req_i;
  assign mem_resp = mem_resp_i;
  assign mem_data_resp = mem_data_resp_i;

  typedef enum logic [1:0] {
    READY
    ,SEND_MEM_CMD
    ,SEND_MEM_DATA_CMD
  } uc_state_e;

  uc_state_e uc_state, uc_state_n;

  always_ff @(posedge clk_i) begin
    // This module only operates when reset is low and CCE is in uncached mode
    if (reset_i | (cce_mode_i != e_cce_mode_uncached)) begin
      uc_state <= READY;
      lce_req_r <= '0;
    end else begin
      uc_state <= uc_state_n;
      lce_req_r <= lce_req_n;
    end
  end

  // Input messages to the CCE are buffered by two element FIFOs in bp_cce_top.v, thus
  // the outbound valid signal is a yumi.
  //
  // Outbound queues all use ready&valid handshaking. Outbound messages going to LCEs are not
  // buffered by bp_cce_top.v, but messages to memory are.
  always_comb begin
    // defaults for output signals
    lce_req_yumi_o = '0;
    mem_resp_yumi_o = '0;
    mem_data_resp_yumi_o = '0;

    lce_cmd_v_o = '0;
    lce_cmd = '0;
    lce_data_cmd_v_o = '0;
    lce_data_cmd = '0;
    mem_cmd_v_o = '0;
    mem_cmd = '0;
    mem_data_cmd_v_o = '0;
    mem_data_cmd = '0;

    // register next value defaults
    lce_req_n = lce_req_r;

    uc_state_n = READY;

    // only operate if not in reset and cce mode is uncached
    if (~reset_i & (cce_mode_i == e_cce_mode_uncached)) begin
      case (uc_state)
      READY: begin
        uc_state_n = READY;

        if (mem_data_resp_v_i & lce_data_cmd_ready_i) begin
          // after load response is received, need to send data back to LCE
          lce_data_cmd_v_o = 1'b1;
          lce_data_cmd.data = mem_data_resp.data;
          lce_data_cmd.dst_id = mem_data_resp.payload.lce_id;
          lce_data_cmd.msg_type = e_lce_data_cmd_non_cacheable;
          lce_data_cmd.way_id = mem_data_resp.payload.way_id;

          // dequeue the mem data response if outbound lce data cmd is accepted
          mem_data_resp_yumi_o = lce_data_cmd_ready_i;

        end else if (mem_resp_v_i & lce_cmd_ready_i) begin
          // after store response is received, need to send uncached store done command to LCE
          lce_cmd_v_o = 1'b1;
          lce_cmd.dst_id = mem_resp.payload.lce_id;
          lce_cmd.src_id = (lg_num_cce_lp)'(cce_id_i);
          lce_cmd.msg_type = e_lce_cmd_uc_st_done;
          lce_cmd.addr = mem_resp.payload.req_addr;

          // dequeue the mem data response if outbound lce data cmd is accepted
          mem_resp_yumi_o = lce_cmd_ready_i;

        end else if (lce_req_v_i) begin
          lce_req_n = lce_req;
          lce_req_yumi_o = lce_req_v_i;
          // uncached read first sends a memory cmd, uncached store sends memory data cmd
          uc_state_n = (lce_req.msg_type == e_lce_req_type_rd)
                       ? SEND_MEM_CMD
                       : SEND_MEM_DATA_CMD;
        end
      end
      SEND_MEM_CMD: begin
        // uncached load, send a memory cmd
        mem_cmd_v_o = 1'b1;
        mem_cmd.msg_type = lce_req_r.msg_type;
        mem_cmd.addr = lce_req_r.addr;
        mem_cmd.payload.lce_id = lce_req_r.src_id;
        mem_cmd.payload.way_id = lce_req_r.lru_way_id;
        mem_cmd.non_cacheable = lce_req_r.non_cacheable;
        mem_cmd.nc_size = lce_req_r.nc_size;

        lce_req_n = (mem_cmd_ready_i) ? '0 : lce_req_r;

        uc_state_n = (mem_cmd_ready_i) ? READY : SEND_MEM_CMD;
      end
      SEND_MEM_DATA_CMD: begin
        // uncached store, send memory data cmd
        mem_data_cmd_v_o = 1'b1;
        mem_data_cmd.msg_type = lce_req_r.msg_type;
        mem_data_cmd.addr = lce_req_r.addr;
        mem_data_cmd.payload.lce_id = lce_req_r.src_id;
        mem_data_cmd.payload.way_id = '0;
        mem_data_cmd.payload.req_addr = lce_req_r.addr;
        mem_data_cmd.payload.tr_lce_id = '0;
        mem_data_cmd.payload.tr_way_id = '0;
        mem_data_cmd.payload.transfer = '0;
        mem_data_cmd.payload.replacement = '0;
        mem_data_cmd.non_cacheable = lce_req_r.non_cacheable;
        mem_data_cmd.nc_size = lce_req_r.nc_size;
        mem_data_cmd.data = {(block_size_in_bits_lp-lce_req_data_width_p)'('0),lce_req_r.data};

        lce_req_n = (mem_data_cmd_ready_i) ? '0 : lce_req_r;

        uc_state_n = (mem_data_cmd_ready_i) ? READY : SEND_MEM_DATA_CMD;
      end
      default: begin
        uc_state_n = READY;
      end
      endcase
    end
  end

endmodule
