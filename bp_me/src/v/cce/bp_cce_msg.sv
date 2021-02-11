/**
 *
 * Name:
 *   bp_cce_msg.v
 *
 * Description:
 *   This module handles sending and receiving of all messages in the CCE.
 *
 * Note: all cached accesses issued to memory using mem_cmd have their address masked
 *       and aligned by the CCE to match cce_block_width_p
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_msg
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p      = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    // Derived parameters
    , localparam block_size_in_bytes_lp    = (cce_block_width_p/8)
    , localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp)
    , localparam lg_num_lce_lp             = `BSG_SAFE_CLOG2(num_lce_p)

    // number of way groups managed by this CCE
    , localparam num_way_groups_lp         = `BSG_CDIV(cce_way_groups_p, num_cce_p)
    , localparam lg_num_way_groups_lp      = `BSG_SAFE_CLOG2(num_way_groups_lp)

    // counter width (used for e.g., stall and performance counters)
    , localparam counter_width_lp          = 64

    // Interface Widths
    , localparam mshr_width_lp             = `bp_cce_mshr_width(lce_id_width_p, lce_assoc_p, paddr_width_p)
    , localparam cfg_bus_width_lp          = `bp_cfg_bus_width(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
    `declare_bp_bedrock_lce_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)

  )
  (input                                               clk_i
   , input                                             reset_i

   // Configuration Interface
   , input [cfg_bus_width_lp-1:0]                      cfg_bus_i

   // LCE-CCE Interface
   , input [lce_req_msg_width_lp-1:0]                  lce_req_i
   , input                                             lce_req_v_i
   , output logic                                      lce_req_yumi_o

   , input [lce_resp_msg_width_lp-1:0]                 lce_resp_i
   , input                                             lce_resp_v_i
   , output logic                                      lce_resp_yumi_o

   // ready->valid
   , output logic [lce_cmd_msg_width_lp-1:0]           lce_cmd_o
   , output logic                                      lce_cmd_v_o
   , input                                             lce_cmd_ready_i

   // CCE-MEM Interface
   , input [cce_mem_msg_width_lp-1:0]                  mem_resp_i
   , input                                             mem_resp_v_i
   , output logic                                      mem_resp_yumi_o

   // ready->valid
   , output logic [cce_mem_msg_width_lp-1:0]           mem_cmd_o
   , output logic                                      mem_cmd_v_o
   , input                                             mem_cmd_ready_i

   // Input signals to feed output commands
   , input [lce_id_width_p-1:0]                        lce_i
   , input [paddr_width_p-1:0]                         addr_i
   , input [lce_assoc_width_p-1:0]                     way_i
   , input bp_coh_states_e                             coh_state_i
   , input                                             sharers_v_i
   , input [num_lce_p-1:0]                             sharers_hits_i
   , input [num_lce_p-1:0][lce_assoc_width_p-1:0]      sharers_ways_i

   , input bp_cce_inst_decoded_s                       decoded_inst_i
   , input [mshr_width_lp-1:0]                         mshr_i
   , input [`bp_cce_inst_gpr_width-1:0]                src_a_i
   , input                                             auto_fwd_msg_i

   // Pending bit write - only during auto-forward
   , output logic                                      pending_w_v_o
   , output logic [paddr_width_p-1:0]                  pending_w_addr_o
   , output logic                                      pending_w_addr_bypass_o
   , output logic                                      pending_o

   // Spec Read Output
   , output logic                                      spec_r_v_o
   , output logic [paddr_width_p-1:0]                  spec_r_addr_o
   , output logic                                      spec_r_addr_bypass_o
   , input bp_cce_spec_s                               spec_bits_i

   // Directory write interface - when sending invalidates
   , output logic [paddr_width_p-1:0]                  dir_addr_o
   , output logic                                      dir_addr_bypass_o
   , output logic [lce_id_width_p-1:0]                 dir_lce_o
   , output logic [lce_assoc_width_p-1:0]              dir_way_o
   , output bp_coh_states_e                            dir_coh_state_o
   , output bp_cce_inst_minor_dir_op_e                 dir_w_cmd_o
   , output logic                                      dir_w_v_o

   // Busy signals
   , output logic                                      lce_cmd_busy_o
   , output logic                                      lce_resp_busy_o
   , output logic                                      mem_resp_busy_o
   , output logic                                      busy_o

   , output logic                                      mem_credits_empty_o

  );

  // LCE-CCE and Mem-CCE Interface
  `declare_bp_bedrock_lce_if(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce);
  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce);

  // Config Interface
  `declare_bp_cfg_bus_s(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);

  // MSHR
  `declare_bp_cce_mshr_s(lce_id_width_p, lce_assoc_p, paddr_width_p);

  // Config bus casting
  bp_cfg_bus_s cfg_bus_cast;
  assign cfg_bus_cast = cfg_bus_i;

  // Message casting
  bp_bedrock_lce_req_msg_s  lce_req;
  bp_bedrock_lce_resp_msg_s lce_resp;
  bp_bedrock_lce_cmd_msg_s  lce_cmd;
  bp_bedrock_cce_mem_msg_s  mem_cmd, mem_resp;
  bp_bedrock_lce_req_payload_s lce_req_payload;
  bp_bedrock_lce_resp_payload_s lce_resp_payload;
  bp_bedrock_lce_cmd_payload_s lce_cmd_payload;
  bp_bedrock_cce_mem_payload_s mem_cmd_payload;
  bp_bedrock_cce_mem_payload_s mem_resp_payload;
  assign lce_req   = lce_req_i;
  assign lce_req_payload = lce_req.header.payload;
  assign lce_resp  = lce_resp_i;
  assign lce_resp_payload = lce_resp.header.payload;
  assign lce_cmd_o = lce_cmd;
  assign mem_cmd_o = mem_cmd;
  assign mem_resp  = mem_resp_i;
  assign mem_resp_payload = mem_resp.header.payload;

  // MSHR casting
  bp_cce_mshr_s mshr;
  assign mshr = mshr_i;

  // Cache block aligned address mask
  wire [paddr_width_p-1:0] addr_mask =
    {{(paddr_width_p-lg_block_size_in_bytes_lp){1'b1}}
     , {(lg_block_size_in_bytes_lp){1'b0}}
    };

  // Counter for message send/receive
  logic cnt_rst;
  //logic [`BSG_WIDTH(1)-1:0] cnt_inc, cnt_dec;
  logic cnt_inc, cnt_dec;
  logic [`BSG_WIDTH(num_lce_p+1)-1:0] cnt;
  bsg_counter_up_down
    #(.max_val_p(num_lce_p+1)
      ,.init_val_p(0)
      ,.max_step_p(1)
      )
    counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i | cnt_rst)
     ,.up_i(cnt_inc)
     ,.down_i(cnt_dec)
     ,.count_o(cnt)
     );

  // memory command/response counter
  logic [`BSG_WIDTH(mem_noc_max_credits_p)-1:0] mem_credit_count_lo;
  bsg_flow_counter
    #(.els_p(mem_noc_max_credits_p)
      // memory command handshake is r->v
      ,.ready_THEN_valid_p(1)
      )
    mem_credit_counter
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // memory commands consume credits
      ,.v_i(mem_cmd_v_o)
      ,.ready_i(mem_cmd_ready_i)
      // memory responses return credits
      ,.yumi_i(mem_resp_yumi_o)
      ,.count_o(mem_credit_count_lo)
      );

  wire mem_credits_empty = (mem_credit_count_lo == mem_noc_max_credits_p);
  wire mem_credits_full = (mem_credit_count_lo == 0);
  assign mem_credits_empty_o = mem_credits_empty;

  // Registers for inputs
  logic  [paddr_width_p-1:0] addr_r, addr_n;

  // One hot of request LCE ID
  logic [num_lce_p-1:0] req_lce_id_one_hot;
  bsg_decode
    #(.num_out_p(num_lce_p))
    req_lce_id_to_one_hot
    (.i(mshr.lce_id[0+:lg_num_lce_lp])
     ,.o(req_lce_id_one_hot)
     );

  // One hot of owner LCE ID
  logic [num_lce_p-1:0] owner_lce_id_one_hot;
  bsg_decode
    #(.num_out_p(num_lce_p))
    owner_lce_id_to_one_hot
    (.i(mshr.owner_lce_id[0+:lg_num_lce_lp])
     ,.o(owner_lce_id_one_hot)
     );

  // Extract index of first bit set in sharers hits
  // Provides LCE ID to send invalidation to
  logic [num_lce_p-1:0] pe_sharers_r, pe_sharers_n;
  logic [lg_num_lce_lp-1:0] pe_lce_id;
  logic pe_v;
  bsg_priority_encode
    #(.width_p(num_lce_p)
      ,.lo_to_hi_p(1)
      )
    sharers_pri_enc
    (.i(pe_sharers_r)
     ,.addr_o(pe_lce_id)
     ,.v_o(pe_v)
     );

  logic [num_lce_p-1:0][lce_assoc_width_p-1:0] sharers_ways_r, sharers_ways_n;

  // Convert first index back to one hot
  logic [num_lce_p-1:0] pe_lce_id_one_hot;
  bsg_decode
    #(.num_out_p(num_lce_p))
    pe_lce_id_to_one_hot
    (.i(pe_lce_id)
     ,.o(pe_lce_id_one_hot)
     );

  // CCE coherence PMA - Mem responses
  logic resp_pma_coherent_addr_lo;
  bp_cce_pma
    #(.bp_params_p(bp_params_p)
      )
    resp_pma
      (.paddr_i(mem_resp.header.addr)
       ,.paddr_v_i(mem_resp_v_i)
       ,.cacheable_addr_o(resp_pma_coherent_addr_lo)
       );

  // Uncached only mode FSM states
  typedef enum logic [1:0] {
    e_uc_reset
    ,e_uc_ready
  } uc_state_e;
  uc_state_e uc_state_r, uc_state_n;

  // Normal mode FSM states
  typedef enum logic [2:0] {
    e_normal_reset
    ,e_normal_ready
    ,e_normal_inv_cmd
    ,e_normal_inv_resp
  } normal_state_e;
  normal_state_e state_r, state_n;

  // Sequential Logic
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      uc_state_r     <= e_uc_reset;
      state_r        <= e_normal_reset;
      pe_sharers_r   <= '0;
      sharers_ways_r <= '0;
      addr_r         <= '0;
    end else begin
      uc_state_r     <= uc_state_n;
      state_r        <= state_n;
      pe_sharers_r   <= pe_sharers_n;
      sharers_ways_r <= sharers_ways_n;
      addr_r         <= addr_n;
    end
  end

  // State Machines
  //
  // Output messages use ready->valid
  // Input messages use valid->yumi
  //
  always_comb begin

    // Register next value defaults
    uc_state_n = uc_state_r;
    state_n = state_r;
    pe_sharers_n = pe_sharers_r;
    sharers_ways_n = sharers_ways_r;
    addr_n = addr_r;

    // defaults for output signals
    lce_req_yumi_o = '0;
    lce_resp_yumi_o = '0;
    lce_cmd_v_o = '0;
    lce_cmd = '0;
    lce_cmd_payload = '0;
    mem_resp_yumi_o = '0;
    mem_cmd_v_o = '0;
    mem_cmd = '0;
    mem_cmd_payload = '0;

    // Pending bit write - only during auto-forward
    pending_w_v_o = '0;
    pending_w_addr_o = '0;
    pending_w_addr_bypass_o = '0;
    pending_o = '0;

    // Spec Read Output
    spec_r_v_o = '0;
    spec_r_addr_o = '0;
    spec_r_addr_bypass_o = '0;

    // Directory write interface - when sending invalidates
    dir_addr_o = '0;
    dir_addr_bypass_o = '0;
    dir_lce_o = '0;
    dir_way_o = '0;
    dir_coh_state_o = e_COH_I;
    dir_w_cmd_o = e_wdp_op;
    dir_w_v_o = '0;

    // Busy signals
    lce_cmd_busy_o = '0;
    lce_resp_busy_o = '0;
    mem_resp_busy_o = '0;
    busy_o = '0;

    // Counter control
    cnt_inc = '0;
    cnt_dec = '0;
    cnt_rst = '0;

    // Uncached Mode FSM
    // The uncached mode FSM stops issuing requests as soon as the config bus sets the mode
    // to normal mode to ensure that the mode transition happens.
    // Any outstanding memory responses will be processed automatically by the normal mode FSM,
    // unless the auto-forwarding mechanism is disabled, in which case the ucode must process
    // the responses.
    // A global fence in the cores can be used to force completion of all requests from uncached
    // mode prior to the config bus setting the CCE to normal operating mode, but this is left to
    // software.
    if (cfg_bus_cast.cce_mode == e_cce_mode_uncached) begin
      // Assert the busy signal to block ucode instructions when transitioning
      // from uncached to normal modes.
      busy_o = 1'b1;

      // Command send state machine
      unique case (uc_state_r)
      e_uc_reset: begin
        uc_state_n = e_uc_ready;
      end
      e_uc_ready: begin

        // memory response forwarding logic
        if (mem_resp_v_i) begin
          unique case (mem_resp.header.msg_type.mem)
            e_bedrock_mem_uc_rd: begin
              // after load response is received, need to send data back to LCE
              lce_cmd_v_o = lce_cmd_ready_i;

              lce_cmd_payload.dst_id = mem_resp_payload.lce_id;
              lce_cmd.header.msg_type = e_bedrock_cmd_uc_data;
              lce_cmd.header.size = mem_resp.header.size;
              lce_cmd_payload.src_id = cfg_bus_cast.cce_id;
              lce_cmd.header.payload = lce_cmd_payload;
              lce_cmd.header.addr = mem_resp.header.addr;
              lce_cmd.data = mem_resp.data;

              // dequeue the mem data response if outbound lce data cmd is accepted
              mem_resp_yumi_o = lce_cmd_ready_i;

            end
            e_bedrock_mem_uc_wr: begin
              // after store response is received, need to send uncached store done command to LCE
              lce_cmd_v_o = lce_cmd_ready_i;

              lce_cmd_payload.dst_id = mem_resp_payload.lce_id;
              lce_cmd.header.msg_type = e_bedrock_cmd_uc_st_done;
              // leave size field as '0 equivalent - no data in this message
              lce_cmd_payload.src_id = cfg_bus_cast.cce_id;
              lce_cmd.header.payload = lce_cmd_payload;
              lce_cmd.header.addr = mem_resp.header.addr;

              // dequeue the mem data response if outbound lce data cmd is accepted
              mem_resp_yumi_o = lce_cmd_ready_i;

            end
            default: begin
            end
          endcase
        end // mem_resp

        // request logic
        // cached requests will stall on the input port until normal mode is entered
        if (lce_req_v_i) begin

          unique case (lce_req.header.msg_type.req)

            // uncached load, send a memory cmd
            e_bedrock_req_uc_rd: begin
              mem_cmd_v_o = lce_req_v_i & mem_cmd_ready_i & ~mem_credits_empty;
              lce_req_yumi_o = mem_cmd_v_o;

              mem_cmd.header.msg_type.mem = e_bedrock_mem_uc_rd;
              mem_cmd.header.addr = lce_req.header.addr;
              mem_cmd.header.size = lce_req.header.size;
              mem_cmd_payload.lce_id = lce_req_payload.src_id;
              mem_cmd_payload.uncached = 1'b1;
              mem_cmd.header.payload = mem_cmd_payload;
            end

            // uncached store, send memory data cmd
            e_bedrock_req_uc_wr: begin
              mem_cmd_v_o = lce_req_v_i & mem_cmd_ready_i & ~mem_credits_empty;
              lce_req_yumi_o = mem_cmd_v_o;

              mem_cmd.header.msg_type.mem = e_bedrock_mem_uc_wr;
              mem_cmd.header.addr = lce_req.header.addr;
              mem_cmd.header.size = lce_req.header.size;
              mem_cmd_payload.lce_id = lce_req_payload.src_id;
              mem_cmd_payload.uncached = 1'b1;
              mem_cmd.header.payload = mem_cmd_payload;
              mem_cmd.data = lce_req.data;
            end

            // default = stall
            default: begin
            end
          endcase
        end // lce_request
      end // e_uc_ready
      default: begin
        uc_state_n = e_uc_reset;
      end
      endcase // uc_state_r FSM

    end // Uncached Mode FSM

    // Normal Mode Operation
    else begin

      // Auto-forward mechanism
      if (auto_fwd_msg_i) begin
        if (mem_resp_v_i) begin
          // Uncached load response - forward data to LCE
          if (mem_resp.header.msg_type.mem == e_bedrock_mem_uc_rd) begin
            // handshaking
            lce_cmd_v_o = mem_resp_v_i & lce_cmd_ready_i;
            mem_resp_yumi_o = mem_resp_v_i & lce_cmd_ready_i;
            // inform ucode decode that this unit is using the LCE Command network
            lce_cmd_busy_o = 1'b1;
            mem_resp_busy_o = 1'b1;
            // output command message
            lce_cmd_payload.dst_id = mem_resp_payload.lce_id;
            lce_cmd.header.msg_type.cmd = e_bedrock_cmd_uc_data;
            lce_cmd.header.size = mem_resp.header.size;
            lce_cmd_payload.src_id = cfg_bus_cast.cce_id;
            lce_cmd.header.payload = lce_cmd_payload;
            lce_cmd.header.addr = mem_resp.header.addr;
            // Data is copied directly from the Mem Data Response
            lce_cmd.data = mem_resp.data;

            // decrement pending bit if uncached to cacheable/coherent memory
            pending_w_v_o = mem_resp_yumi_o & resp_pma_coherent_addr_lo;
            pending_w_addr_o = mem_resp.header.addr;
            pending_w_addr_bypass_o = 1'b0;
            pending_o = 1'b0;

          end // uncached read response

          // Uncached store response - send uncached store done command on LCE Command
          else if (mem_resp.header.msg_type.mem == e_bedrock_mem_uc_wr) begin
            // handshaking
            lce_cmd_v_o = mem_resp_v_i & lce_cmd_ready_i;
            mem_resp_yumi_o = mem_resp_v_i & lce_cmd_ready_i;
            // inform ucode decode that this unit is using the LCE Command network
            lce_cmd_busy_o = 1'b1;
            mem_resp_busy_o = 1'b1;
            // output command message
            // after store response is received, need to send uncached store done command to LCE
            lce_cmd_payload.dst_id = mem_resp_payload.lce_id;
            lce_cmd.header.msg_type.cmd = e_bedrock_cmd_uc_st_done;
            // leave size as '0 equivalent, no data in this message
            lce_cmd_payload.src_id = cfg_bus_cast.cce_id;
            lce_cmd.header.payload = lce_cmd_payload;
            lce_cmd.header.addr = mem_resp.header.addr;

            // decrement pending bit if uncached to cacheable/coherent memory
            pending_w_v_o = mem_resp_yumi_o & resp_pma_coherent_addr_lo;
            pending_w_addr_o = mem_resp.header.addr;
            pending_w_addr_bypass_o = 1'b0;
            pending_o = 1'b0;

          end // uncached store response

          // Writeback response - clears the pending bit
          else if (mem_resp.header.msg_type.mem == e_bedrock_mem_wr) begin
            mem_resp_yumi_o = mem_resp_v_i;
            pending_w_v_o = mem_resp_v_i;
            pending_w_addr_o = mem_resp.header.addr;
            pending_w_addr_bypass_o = 1'b0;
            pending_o = 1'b0;
          end // writeback

          // Speculative access response
          // Note: speculative access is only supported for cached requests
          else if (mem_resp_payload.speculative) begin
            spec_r_v_o = mem_resp_payload.speculative;
            spec_r_addr_o = mem_resp.header.addr;
            spec_r_addr_bypass_o = 1'b0;

            // speculation not resolved, request cannot be forwarded yet
            if (spec_bits_i.spec) begin
              // Note: this blocks memory responses behind the speculative response from being
              // forwarded. However, the CCE will not move on to a new LCE request until it
              // resolves the speculation for the current request.
            end
            // speculation resolved by squashing memory request
            // dequeue and decrement pending bit
            else if (spec_bits_i.squash) begin
              mem_resp_yumi_o = mem_resp_v_i;
              pending_w_v_o = mem_resp_v_i;
              pending_w_addr_o = mem_resp.header.addr;
              pending_w_addr_bypass_o = 1'b0;
              pending_o = 1'b0;
            end
            // speculation resolved by forwarding data from memory, but using a modified
            // coherence state than what was guessed at when sending the request
            // also decrement pending bits
            else if (spec_bits_i.fwd_mod) begin
              lce_cmd_v_o = lce_cmd_ready_i & mem_resp_v_i;
              mem_resp_yumi_o = lce_cmd_ready_i & mem_resp_v_i;
              lce_cmd_busy_o = 1'b1;
              mem_resp_busy_o = 1'b1;

              // output command message
              lce_cmd_payload.dst_id = mem_resp_payload.lce_id;
              lce_cmd.header.msg_type = e_bedrock_cmd_data;
              lce_cmd.header.size = mem_resp.header.size;
              lce_cmd_payload.way_id = mem_resp_payload.way_id;
              lce_cmd_payload.src_id = cfg_bus_cast.cce_id;
              lce_cmd.header.addr = mem_resp.header.addr;
              // modify the coherence state using the speculative bits read
              lce_cmd_payload.state = spec_bits_i.state;
              lce_cmd.header.payload = lce_cmd_payload;
              lce_cmd.data = mem_resp.data;

              // decrement pending bit
              pending_w_v_o = lce_cmd_ready_i & mem_resp_v_i;
              pending_w_addr_o = mem_resp.header.addr;
              pending_w_addr_bypass_o = 1'b0;
              pending_o = 1'b0;
            end
            // speculation resolved, forward unmodified
            // also decrement pending bits
            else begin
              lce_cmd_v_o = lce_cmd_ready_i & mem_resp_v_i;
              mem_resp_yumi_o = lce_cmd_ready_i & mem_resp_v_i;
              lce_cmd_busy_o = 1'b1;
              mem_resp_busy_o = 1'b1;

              // output command message
              lce_cmd_payload.dst_id = mem_resp_payload.lce_id;
              lce_cmd.header.msg_type.cmd = e_bedrock_cmd_data;
              lce_cmd.header.size = mem_resp.header.size;
              lce_cmd_payload.way_id = mem_resp_payload.way_id;
              lce_cmd_payload.src_id = cfg_bus_cast.cce_id;
              lce_cmd.header.addr = mem_resp.header.addr;
              lce_cmd_payload.state = mem_resp_payload.state;
              lce_cmd.header.payload = lce_cmd_payload;
              lce_cmd.data = mem_resp.data;

              // decrement pending bit
              pending_w_v_o = lce_cmd_ready_i & mem_resp_v_i;
              pending_w_addr_o = mem_resp.header.addr;
              pending_w_addr_bypass_o = 1'b0;
              pending_o = 1'b0;
            end

          end // speculative memory response

          // Non-speculative Memory Response with cached data
          else if (mem_resp.header.msg_type.mem == e_bedrock_mem_rd) begin

            lce_cmd_v_o = lce_cmd_ready_i & mem_resp_v_i;
            mem_resp_yumi_o = lce_cmd_ready_i & mem_resp_v_i;
            lce_cmd_busy_o = 1'b1;
            mem_resp_busy_o = 1'b1;

            // output command message
            lce_cmd_payload.dst_id = mem_resp_payload.lce_id;
            lce_cmd.header.msg_type.cmd = e_bedrock_cmd_data;
            lce_cmd.header.size = mem_resp.header.size;
            lce_cmd_payload.way_id = mem_resp_payload.way_id;
            lce_cmd_payload.src_id = cfg_bus_cast.cce_id;
            lce_cmd.header.addr = mem_resp.header.addr;
            lce_cmd_payload.state = mem_resp_payload.state;
            lce_cmd.header.payload = lce_cmd_payload;
            lce_cmd.data = mem_resp.data;

            // decrement pending bit
            pending_w_v_o = lce_cmd_ready_i & mem_resp_v_i;
            pending_w_addr_o = mem_resp.header.addr;
            pending_w_addr_bypass_o = 1'b0;
            pending_o = 1'b0;
          end // cached block fetch (read- or write-miss)

        end // mem_resp auto-forward

        // automatically dequeue coherence ack and decrement pending bit
        // memory response has priority for using the pending bit write port and will stall
        // the LCE Response if the port is busy
        if (lce_resp_v_i & (lce_resp.header.msg_type.resp == e_bedrock_resp_coh_ack) & ~pending_w_v_o) begin
          lce_resp_yumi_o = lce_resp_v_i;
          lce_resp_busy_o = 1'b1;
          // clear pending bit
          pending_w_v_o = 1'b1;
          pending_w_addr_o = lce_resp.header.addr;
          pending_w_addr_bypass_o = 1'b0;
          pending_o = 1'b0;
        end

      end // auto-fwd message

      // Normal Mode FSM
      unique case (state_r)
        e_normal_reset: begin
          state_n = e_normal_ready;
          cnt_rst = 1'b1;
        end // e_normal_reset;
        e_normal_ready: begin

          // Invalidation command
          if (decoded_inst_i.inv_cmd_v) begin
            // busy_o not raised this cycle, will raise next cycle after inv instruction is
            // executed and captured by the message module.
            state_n = e_normal_inv_cmd;
            // capture input address for use by invalidation routine
            addr_n = addr_i;
            // setup inputs for determining LCEs to invalidate
            // Requesting LCE and the owner LCE (if present) are excluded
            // Thus, only LCE's with the block in Shared (S) state are invalidated
            pe_sharers_n = sharers_hits_i & ~req_lce_id_one_hot;
            pe_sharers_n = (mshr.flags[e_opd_cof] | mshr.flags[e_opd_cff])
                           ? pe_sharers_n & ~owner_lce_id_one_hot
                           : pe_sharers_n;
            sharers_ways_n = sharers_ways_i;
            // reset counter
            cnt_rst = 1'b1;
          end

          // Inbound messages - popq

          // LCE Request
          else if (decoded_inst_i.lce_req_yumi) begin

            // Pop the request if it is valid and either not doing a pending bit write
            // or doing a pending bit write and this module is not using the pending bit
            // write port.
            lce_req_yumi_o = lce_req_v_i
                             & ((decoded_inst_i.pending_w_v & ~pending_w_v_o)
                                | ~decoded_inst_i.pending_w_v);

          end
          // LCE Response
          else if (decoded_inst_i.lce_resp_yumi) begin
            // Pop the response if it is valid and either not doing a pending bit write
            // or doing a pending bit write and this module is not using the pending bit
            // write port.
            lce_resp_yumi_o = lce_resp_v_i
                              & ((decoded_inst_i.pending_w_v & ~pending_w_v_o)
                                 | ~decoded_inst_i.pending_w_v);

          end
          // Mem Response
          else if (decoded_inst_i.mem_resp_yumi) begin
            // Pop the response if it is valid and either not doing a pending bit write
            // or doing a pending bit write and this module is not using the pending bit
            // write port.
            mem_resp_yumi_o = mem_resp_v_i
                              & ((decoded_inst_i.pending_w_v & ~pending_w_v_o)
                                 | ~decoded_inst_i.pending_w_v);

          end

          // Outbound messages - pushq

          // Memory Command
          else if (decoded_inst_i.mem_cmd_v) begin

            // Can only send Mem command if:
            // Write port for pending bits isn't in use if pushq will write pending bit
            if (mem_cmd_ready_i
                & ((decoded_inst_i.pending_w_v & ~pending_w_v_o)
                   | ~decoded_inst_i.pending_w_v)) begin

              mem_cmd_v_o = mem_cmd_ready_i & ~mem_credits_empty;

              // All commands use message type
              mem_cmd.header.msg_type.mem = decoded_inst_i.mem_cmd;
              // default address to full address
              mem_cmd.header.addr = addr_i;
              // default to size in MSHR
              mem_cmd.header.size = mshr.msg_size;

              // set speculative bit if instruction indicates it will be written
              if (decoded_inst_i.spec_w_v & decoded_inst_i.spec_v
                  & decoded_inst_i.spec_bits.spec) begin
                mem_cmd_payload.speculative = 1'b1;
              end

              // Custom command
              if (decoded_inst_i.pushq_custom) begin
                // NOTE: custom push does not align address to cache block boundary
                // either the address sent in the request or generated from
                // the microcode must be aligned as required by the destination
                mem_cmd.header.addr = addr_i;
                mem_cmd_payload.lce_id = lce_i;
                mem_cmd.header.size = decoded_inst_i.msg_size;
                // data comes from src_a_i, as selected by the src_a field of the instruction
                // this data is one of the GPRs
                mem_cmd.data[0+:`bp_cce_inst_gpr_width] = src_a_i;

                // set uncached bit based on uncached flag in MSHR
                // this bit indicates if the LCE should receive the data as cached or uncached
                // when it returns from memory
                mem_cmd_payload.uncached = mshr.flags[e_opd_ucf];

              // Standard coherence command
              end else begin
                // uncached request
                if ((decoded_inst_i.mem_cmd == e_bedrock_mem_uc_rd)
                    | (decoded_inst_i.mem_cmd == e_bedrock_mem_uc_wr)) begin
                  // set uncached bit
                  mem_cmd_payload.uncached = 1'b1;
                  // uncached access uses the full address, no masking
                  // NOTE: address must be aligned to request size
                  mem_cmd.header.addr = addr_i;
                  mem_cmd_payload.lce_id = lce_i;

                  if (decoded_inst_i.mem_cmd == e_bedrock_mem_uc_wr) begin
                    mem_cmd.data = {'0,lce_req.data};
                  end

                end // uncached

                // cached request
                else begin

                  // cached access masks the address to align to cache block
                  mem_cmd.header.addr = (addr_i & addr_mask);

                  // set uncached bit based on uncached flag in MSHR
                  // this bit indicates if the LCE should receive the data as cached or uncached
                  // when it returns from memory
                  mem_cmd_payload.uncached = mshr.flags[e_opd_ucf];

                  // Writeback command - override default command fields as needed
                  unique case (decoded_inst_i.mem_cmd)
                    e_bedrock_mem_wr: begin
                      mem_cmd.data = lce_resp.data;
                      mem_cmd_payload.lce_id = lce_i;
                      mem_cmd_payload.way_id = '0;
                      mem_cmd_payload.state = e_COH_I;
                    end
                    e_bedrock_mem_pre: begin
                      // TODO: implement prefetch functionality
                      mem_cmd_payload.prefetch = 1'b1;
                    end
                    default: begin
                      mem_cmd_payload.state = mshr.next_coh_state;
                      mem_cmd_payload.way_id = way_i;
                      mem_cmd_payload.lce_id = lce_i;
                    end
                  endcase

                end // cached

              end // standard coherence command

              // assign payload struct into memory command header
              mem_cmd.header.payload = mem_cmd_payload;
            end

          end // Memory Command

          // LCE Command
          else if (decoded_inst_i.lce_cmd_v) begin

            // Can only send LCE command if:
            // Auto-forward isn't using LCE Command port
            // write port for pending bits isn't in use if pushq will write pending bit
            if (lce_cmd_ready_i
                & ~lce_cmd_busy_o
                & ((decoded_inst_i.pending_w_v & ~pending_w_v_o)
                   | ~decoded_inst_i.pending_w_v)) begin

              lce_cmd_v_o = lce_cmd_ready_i;
              // all commands set src, dst, message type and address
              // defaults provided here, but may be overridden below
              lce_cmd_payload.dst_id = lce_i;
              lce_cmd.header.msg_type.cmd = decoded_inst_i.lce_cmd;
              lce_cmd_payload.src_id = cfg_bus_cast.cce_id;
              lce_cmd.header.addr = addr_i;

              if (decoded_inst_i.pushq_custom) begin
                lce_cmd.header.size = decoded_inst_i.msg_size;
                lce_cmd.data[0+:`bp_cce_inst_gpr_width] = src_a_i;
              end else begin
                // all commands set the way_id field
                lce_cmd_payload.way_id = way_i;

                // commands including a set state operation set the state field
                if ((decoded_inst_i.lce_cmd == e_bedrock_cmd_st)
                    | (decoded_inst_i.lce_cmd == e_bedrock_cmd_st_wakeup)
                    | (decoded_inst_i.lce_cmd == e_bedrock_cmd_st_wb)) begin
                  // decoder sets coh_state_i to mshr.next_coh_state so any ST_X command
                  // that doesn't include a transfer needs to set mshr.next_coh_state
                  // to the correct value before sending the command (pushq)
                  lce_cmd_payload.state = coh_state_i;
                end

                if ((decoded_inst_i.lce_cmd == e_bedrock_cmd_st_tr)
                    | (decoded_inst_i.lce_cmd == e_bedrock_cmd_st_tr_wb)) begin
                  // when doing a set state + transfer, the state field indicates the
                  // next state for the owner LCE, and target_state (set below) will provide
                  // the state for the LCE receiving the transfer
                  lce_cmd_payload.state = mshr.owner_coh_state;
                end

                // Transfer commands set target, target way, and target state fields
                // target is the requesting LCE in MSHR, and target_way is its LRU way
                // target_state comes from coh_state_i, which is set to mshr.next_coh_state
                if ((decoded_inst_i.lce_cmd == e_bedrock_cmd_tr)
                    | (decoded_inst_i.lce_cmd == e_bedrock_cmd_st_tr)
                    | (decoded_inst_i.lce_cmd == e_bedrock_cmd_st_tr_wb)) begin
                  lce_cmd_payload.target_state = coh_state_i;
                  lce_cmd_payload.target = mshr.lce_id;
                  lce_cmd_payload.target_way_id = mshr.lru_way_id;
                end
              end
              // assign the payload struct into the command
              lce_cmd.header.payload = lce_cmd_payload;
            end
          end // LCE Command

        end // e_normal_ready

        e_normal_inv_cmd: begin
          busy_o = 1'b1;

          // try to send additional commands, but give priority to mem_resp auto-forward
          if (~lce_cmd_busy_o) begin

            lce_cmd_v_o = lce_cmd_ready_i;
            lce_cmd.header.msg_type.cmd = e_bedrock_cmd_inv;

            // leave size as '0 equivalent, no data sent for invalidate

            // destination and way come from sharers information
            lce_cmd_payload.dst_id = pe_lce_id;
            lce_cmd_payload.way_id = sharers_ways_r[pe_lce_id];

            lce_cmd_payload.src_id = cfg_bus_cast.cce_id;
            lce_cmd.header.payload = lce_cmd_payload;

            lce_cmd.header.addr = addr_r;

            // Directory write command
            dir_w_v_o = lce_cmd_ready_i;
            dir_w_cmd_o = e_wds_op;
            dir_addr_o = addr_r;
            dir_addr_bypass_o = '0;
            dir_lce_o = {'0, pe_lce_id};
            dir_way_o = sharers_ways_r[pe_lce_id];
            dir_coh_state_o = e_COH_I;

            // message sent, increment count
            cnt_inc = lce_cmd_ready_i;
            // only remove current LCE from sharers if command sends
            pe_sharers_n = lce_cmd_ready_i
                           ? (pe_sharers_r & ~pe_lce_id_one_hot)
                           : pe_sharers_r;

            // move to response state if none of the new sharer bits are set
            // and the last command is sending this cycle
            state_n = (lce_cmd_ready_i & (pe_sharers_n == '0))
                      ? e_normal_inv_resp
                      : e_normal_inv_cmd;

          end // lce_cmd_busy

          // dequeue responses as they arrive
          if (lce_resp_v_i & (lce_resp.header.msg_type.resp == e_bedrock_resp_inv_ack)) begin
            lce_resp_yumi_o = lce_resp_v_i;
            cnt_dec = 1'b1;
          end

        end // e_normal_inv_cmd

        e_normal_inv_resp: begin
          busy_o = 1'b1;
          if (cnt == '0) begin
            state_n = e_normal_ready;
          end else begin
            if (lce_resp_v_i & (lce_resp.header.msg_type.resp == e_bedrock_resp_inv_ack)) begin
              lce_resp_yumi_o = lce_resp_v_i;
              if (cnt == 'd1) begin
                state_n = e_normal_ready;
                cnt_rst = 1'b1;
              end else begin
                cnt_dec = 1'b1;
              end
            end
          end
        end // e_normal_inv_resp

        default: begin
          state_n = e_normal_reset;
        end
      endcase


    end // normal operation

  end // always_comb

  //synopsys translate_off
  always_ff @(negedge clk_i) begin
    if (~reset_i) begin
      if (state_r == e_normal_inv_cmd & ~pe_v) begin
        $error("bp_cce_msg bad sharers list for invalidate command");
      end // error
    end // ~reset
  end // always_ff
  //synopsys translate_on

endmodule
