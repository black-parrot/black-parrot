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
    , localparam cfg_bus_width_lp          = `bp_cfg_bus_width(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
    `declare_bp_bedrock_lce_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)

    , localparam burst_packets_128_lp = (((8*128) / dword_width_gp) - 1)
    , localparam burst_packets_64_lp = (((8*64) / dword_width_gp) - 1)
    , localparam burst_packets_32_lp = (((8*32) / dword_width_gp) - 1)
    , localparam burst_packets_16_lp = (((8*16) / dword_width_gp) - 1)
    , localparam burst_packets_8_lp = (((8*8) / dword_width_gp) - 1)
  )
  (input                                            clk_i
   , input                                          reset_i

   // Configuration Interface
   , input [cfg_bus_width_lp-1:0]                   cfg_bus_i

   // LCE-CCE Interface
   // BedRock Burst protocol: ready&valid
   // inbound headers use valid->yumi
   , input [lce_req_msg_header_width_lp-1:0]        lce_req_header_i
   , input                                          lce_req_header_v_i
   , output logic                                   lce_req_header_yumi_o
   , input                                          lce_req_has_data_i
   , input [dword_width_gp-1:0]                     lce_req_data_i
   , input                                          lce_req_data_v_i
   , output logic                                   lce_req_data_ready_and_o
   , input                                          lce_req_last_i

   , input [lce_resp_msg_header_width_lp-1:0]       lce_resp_header_i
   , input                                          lce_resp_header_v_i
   , output logic                                   lce_resp_header_yumi_o
   , input                                          lce_resp_has_data_i
   , input [dword_width_gp-1:0]                     lce_resp_data_i
   , input                                          lce_resp_data_v_i
   , output logic                                   lce_resp_data_ready_and_o
   , input                                          lce_resp_last_i

   , output logic [lce_cmd_msg_header_width_lp-1:0] lce_cmd_header_o
   , output logic                                   lce_cmd_header_v_o
   , input                                          lce_cmd_header_ready_and_i
   , output logic                                   lce_cmd_has_data_o
   , output logic [dword_width_gp-1:0]              lce_cmd_data_o
   , output logic                                   lce_cmd_data_v_o
   , input                                          lce_cmd_data_ready_and_i
   , output logic                                   lce_cmd_last_o

   // CCE-MEM Interface
   // BedRock Burst protocol: ready&valid
   // inbound headers use valid->yumi
   , input [cce_mem_msg_header_width_lp-1:0]        mem_resp_header_i
   , input                                          mem_resp_header_v_i
   , output logic                                   mem_resp_header_yumi_o
   , input                                          mem_resp_has_data_i
   , input [dword_width_gp-1:0]                     mem_resp_data_i
   , input                                          mem_resp_data_v_i
   , output logic                                   mem_resp_data_ready_and_o
   , input                                          mem_resp_last_i

   , output logic [cce_mem_msg_header_width_lp-1:0] mem_cmd_header_o
   , output logic                                   mem_cmd_header_v_o
   , input                                          mem_cmd_header_ready_and_i
   , output logic                                   mem_cmd_has_data_o
   , output logic [dword_width_gp-1:0]              mem_cmd_data_o
   , output logic                                   mem_cmd_data_v_o
   , input                                          mem_cmd_data_ready_and_i
   , output logic                                   mem_cmd_last_o

   // Input signals to feed output commands
   , input [lce_id_width_p-1:0]                     lce_i
   , input [paddr_width_p-1:0]                      addr_i
   , input [lce_assoc_width_p-1:0]                  way_i
   , input bp_coh_states_e                          coh_state_i
   , input                                          sharers_v_i
   , input [num_lce_p-1:0]                          sharers_hits_i
   , input [num_lce_p-1:0][lce_assoc_width_p-1:0]   sharers_ways_i

   , input bp_cce_inst_decoded_s                    decoded_inst_i
   , input [mshr_width_lp-1:0]                      mshr_i
   , input [`bp_cce_inst_gpr_width-1:0]             src_a_i
   , input                                          auto_fwd_msg_i

   // Pending bit write - only during auto-forward
   , output logic                                   pending_w_v_o
   , output logic [paddr_width_p-1:0]               pending_w_addr_o
   , output logic                                   pending_w_addr_bypass_o
   , output logic                                   pending_o

   // Spec Read Output
   , output logic                                   spec_r_v_o
   , output logic [paddr_width_p-1:0]               spec_r_addr_o
   , output logic                                   spec_r_addr_bypass_o
   , input bp_cce_spec_s                            spec_bits_i

   // Directory write interface - when sending invalidates
   , output logic [paddr_width_p-1:0]               dir_addr_o
   , output logic                                   dir_addr_bypass_o
   , output logic [lce_id_width_p-1:0]              dir_lce_o
   , output logic [lce_assoc_width_p-1:0]           dir_way_o
   , output bp_coh_states_e                         dir_coh_state_o
   , output bp_cce_inst_minor_dir_op_e              dir_w_cmd_o
   , output logic                                   dir_w_v_o

   // Busy signals
   , output logic                                   lce_cmd_busy_o
   , output logic                                   lce_resp_busy_o
   , output logic                                   mem_resp_busy_o
   , output logic                                   busy_o

   , output logic                                   mem_credits_empty_o

  );

  // LCE-CCE and Mem-CCE Interface
  `declare_bp_bedrock_lce_if(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce);
  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce);

  // Config Interface
  `declare_bp_cfg_bus_s(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);

  // MSHR
  `declare_bp_cce_mshr_s(lce_id_width_p, lce_assoc_p, paddr_width_p);

  // LCE-CCE Interface structs
  bp_bedrock_lce_req_msg_header_s  lce_req;
  bp_bedrock_lce_resp_msg_header_s lce_resp;
  bp_bedrock_lce_cmd_msg_header_s  lce_cmd;
  assign lce_cmd_header_o = lce_cmd;
  assign lce_req = lce_req_header_i;
  assign lce_resp = lce_resp_header_i;
  bp_bedrock_lce_req_payload_s lce_req_payload;
  bp_bedrock_lce_resp_payload_s lce_resp_payload;
  bp_bedrock_lce_cmd_payload_s lce_cmd_payload;
  assign lce_req_payload = lce_req.payload;
  assign lce_resp_payload = lce_resp.payload;

  // CCE-MEM Interface structs
  bp_bedrock_cce_mem_msg_header_s  mem_cmd, mem_resp;
  bp_bedrock_cce_mem_payload_s mem_cmd_payload;
  bp_bedrock_cce_mem_payload_s mem_resp_payload;
  assign mem_cmd_header_o = mem_cmd;
  assign mem_resp = mem_resp_header_i;
  assign mem_resp_payload = mem_resp.payload;

  // Config bus casting
  bp_cfg_bus_s cfg_bus_cast;
  assign cfg_bus_cast = cfg_bus_i;
  wire cce_normal_mode_li = (cfg_bus_cast.cce_mode == e_cce_mode_normal);
  logic cce_normal_mode_r, cce_normal_mode_n;

  // MSHR casting
  bp_cce_mshr_s mshr;
  assign mshr = mshr_i;

  // Cache block aligned address mask
  // TODO: should CCE ever align the address?
  wire [paddr_width_p-1:0] addr_mask =
    {{(paddr_width_p-lg_block_size_in_bytes_lp){1'b1}}
     , {(lg_block_size_in_bytes_lp){1'b0}}
    };

  // Counter for message send/receive
  logic cnt_rst;
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
      // memory command handshake is r&v
      ,.ready_THEN_valid_p(0)
      )
    mem_credit_counter
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // memory commands consume credits
      ,.v_i(mem_cmd_header_v_o)
      ,.ready_i(mem_cmd_header_ready_and_i)
      // memory responses return credits
      ,.yumi_i(mem_resp_header_yumi_o)
      ,.count_o(mem_credit_count_lo)
      );

  wire mem_credits_empty = (mem_credit_count_lo == mem_noc_max_credits_p);
  wire mem_credits_full = (mem_credit_count_lo == 0);
  assign mem_credits_empty_o = mem_credits_empty;

  // Memory response data packets
  wire [counter_width_lp-1:0] mem_resp_size_in_packets =
    (mem_resp.size == e_bedrock_msg_size_128)
    ? counter_width_lp'(burst_packets_128_lp)
    : (mem_resp.size == e_bedrock_msg_size_64)
      ? counter_width_lp'(burst_packets_64_lp)
      : (mem_resp.size == e_bedrock_msg_size_32)
        ? counter_width_lp'(burst_packets_32_lp)
        : (mem_resp.size == e_bedrock_msg_size_16)
          ? counter_width_lp'(burst_packets_16_lp)
          : counter_width_lp'(burst_packets_8_lp);

  // LCE request data packets
  wire [counter_width_lp-1:0] lce_req_size_in_packets =
    (lce_req.size == e_bedrock_msg_size_128)
    ? counter_width_lp'(burst_packets_128_lp)
    : (lce_req.size == e_bedrock_msg_size_64)
      ? counter_width_lp'(burst_packets_64_lp)
      : (lce_req.size == e_bedrock_msg_size_32)
        ? counter_width_lp'(burst_packets_32_lp)
        : (lce_req.size == e_bedrock_msg_size_16)
          ? counter_width_lp'(burst_packets_16_lp)
          : counter_width_lp'(burst_packets_8_lp);

  // LCE response data packets
  wire [counter_width_lp-1:0] lce_resp_size_in_packets =
    (lce_resp.size == e_bedrock_msg_size_128)
    ? counter_width_lp'(burst_packets_128_lp)
    : (lce_resp.size == e_bedrock_msg_size_64)
      ? counter_width_lp'(burst_packets_64_lp)
      : (lce_resp.size == e_bedrock_msg_size_32)
        ? counter_width_lp'(burst_packets_32_lp)
        : (lce_resp.size == e_bedrock_msg_size_16)
          ? counter_width_lp'(burst_packets_16_lp)
          : counter_width_lp'(burst_packets_8_lp);

  // Memory Response Data Forwarding Counter
  logic [counter_width_lp-1:0] mrdc_val, mrdc_cnt;
  logic mrdc_set, mrdc_down;
  bsg_counter_set_down
    #(.width_p(counter_width_lp)
      ,.init_val_p('0)
      ,.set_and_down_exclusive_p(1)
      )
    memory_response_data_counter
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.set_i(mrdc_set)
      ,.val_i(mrdc_val)
      ,.down_i(mrdc_down)
      ,.count_r_o(mrdc_cnt)
      );

  // Memory Command Data Forwarding Counter
  logic [counter_width_lp-1:0] mcdc_val, mcdc_cnt;
  logic mcdc_set, mcdc_down;
  bsg_counter_set_down
    #(.width_p(counter_width_lp)
      ,.init_val_p('0)
      ,.set_and_down_exclusive_p(1)
      )
    memory_command_data_counter
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.set_i(mcdc_set)
      ,.val_i(mcdc_val)
      ,.down_i(mcdc_down)
      ,.count_r_o(mcdc_cnt)
      );

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

  // CCE PMA - Mem responses
  logic resp_pma_cacheable_addr_lo;
  bp_cce_pma
    #(.bp_params_p(bp_params_p)
      )
    resp_pma
      (.paddr_i(mem_resp.addr)
       ,.paddr_v_i(mem_resp_header_v_i)
       ,.cacheable_addr_o(resp_pma_cacheable_addr_lo)
       );

  // Normal mode FSM states
  typedef enum logic [3:0] {
    e_reset
    ,e_uncached_only
    ,e_uncached_only_data
    ,e_ready
    ,e_inv_cmd
    ,e_inv_resp
    ,e_send_data_req_to_mem_cmd
    ,e_send_data_resp_to_mem_cmd
    ,e_error
  } state_e;
  state_e state_r, state_n;

  typedef enum logic [1:0] {
    e_mem_resp_reset
    , e_mem_resp_ready
    , e_mem_resp_send_data
    , e_mem_resp_drain_data
  } mem_resp_state_e;
  mem_resp_state_e mem_resp_state_r, mem_resp_state_n;

  // Sequential Logic
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      state_r           <= e_reset;
      mem_resp_state_r  <= e_mem_resp_reset;
      pe_sharers_r      <= '0;
      sharers_ways_r    <= '0;
      addr_r            <= '0;
      cce_normal_mode_r <= '0;
    end else begin
      state_r           <= state_n;
      mem_resp_state_r  <= mem_resp_state_n;
      pe_sharers_r      <= pe_sharers_n;
      sharers_ways_r    <= sharers_ways_n;
      addr_r            <= addr_n;
      cce_normal_mode_r <= cce_normal_mode_n;
    end
  end

  // State Machines
  //
  // Output messages use ready->valid
  // Input messages use valid->yumi
  //
  always_comb begin

    // Register next value defaults
    state_n = state_r;
    mem_resp_state_n = mem_resp_state_r;
    pe_sharers_n = pe_sharers_r;
    sharers_ways_n = sharers_ways_r;
    addr_n = addr_r;
    cce_normal_mode_n = cce_normal_mode_r;

    // defaults for output signals
    lce_req_header_yumi_o = '0;
    lce_req_data_ready_and_o = '0;
    lce_resp_header_yumi_o = '0;
    lce_resp_data_ready_and_o = '0;
    lce_cmd_header_v_o = '0;
    lce_cmd = '0;
    lce_cmd_payload = '0;
    lce_cmd_payload.src_id = cfg_bus_cast.cce_id;
    lce_cmd_data_v_o = '0;
    lce_cmd_data_o = '0;
    lce_cmd_last_o = '0;
    lce_cmd_has_data_o = '0;
    mem_resp_header_yumi_o = '0;
    mem_resp_data_ready_and_o = '0;
    mem_cmd_header_v_o = '0;
    mem_cmd = '0;
    mem_cmd_payload = '0;
    mem_cmd_data_v_o = '0;
    mem_cmd_data_o = '0;
    mem_cmd_last_o = '0;
    mem_cmd_has_data_o = '0;

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
    // raised in uncached mode or during invalidate cmd/resp states
    busy_o = '0;

    // Counter control
    cnt_inc = '0;
    cnt_dec = '0;
    cnt_rst = '0;

    // memory response data packet counter
    mrdc_set = '0;
    mrdc_down = '0;
    mrdc_val = '0;
    // memory command data packet counter
    mcdc_set = '0;
    mcdc_down = '0;
    mcdc_val = '0;

    // Mem Response auto-processing and forwarding to LCE Command logic
    // The pending bit is written when the LCE Command header sends.
    // The main FSM will stall if it wants to write to the pending bits in the same cycle.

    if (auto_fwd_msg_i | ~cce_normal_mode_r) begin
      case (mem_resp_state_r)
        e_mem_resp_reset: begin
          mem_resp_state_n = e_mem_resp_ready;
        end
        e_mem_resp_ready: begin
          if (mem_resp_header_v_i) begin

            // Speculative access response
            // Note: speculative access is only supported for cached requests
            if (mem_resp_payload.speculative) begin
              // read from the speculative bits
              spec_r_v_o = 1'b1;
              spec_r_addr_o = mem_resp.addr;

              if (spec_bits_i.spec) begin // speculation not resolved yet
                // do nothing, wait for speculation to be resolved
                // Note: this blocks memory responses behind the speculative response from being
                // forwarded. However, the CCE will not move on to a new LCE request until it
                // resolves the speculation for the current request.
              end // speculative bit sill set

              else if (spec_bits_i.squash) begin // speculation resolved, squash
                // dequeue the command and do nothing with it
                mem_resp_header_yumi_o = mem_resp_header_v_i;

                mem_resp_busy_o = 1'b1;

                // decrement pending bit on mem response dequeue
                pending_w_v_o = mem_resp_header_yumi_o;
                pending_w_addr_o = mem_resp.addr;
                pending_o = 1'b0;

                mem_resp_state_n = mem_resp_header_yumi_o ? e_mem_resp_drain_data : e_mem_resp_ready;

                mrdc_set = mem_resp_header_yumi_o;
                mrdc_val = mem_resp_size_in_packets;

              end // squash

              else if (spec_bits_i.fwd_mod) begin // speculation resolved, forward with modified state
                // forward the header this cycle
                // forward data next cycle(s)

                // inform ucode decode that this unit is using the LCE Command network
                lce_cmd_busy_o = 1'b1;
                mem_resp_busy_o = 1'b1;

                // handshaking
                // r&v for LCE command header
                // valid->yumi for mem response header
                lce_cmd_header_v_o = mem_resp_header_v_i;
                lce_cmd_has_data_o = 1'b1;
                mem_resp_header_yumi_o = mem_resp_header_v_i & lce_cmd_header_ready_and_i;

                // command header
                lce_cmd.msg_type = e_bedrock_cmd_data;
                lce_cmd.addr = mem_resp.addr;
                lce_cmd.size = mem_resp.size;

                // command payload
                // modify the coherence state
                lce_cmd_payload.dst_id = mem_resp_payload.lce_id;
                lce_cmd_payload.way_id = mem_resp_payload.way_id;
                lce_cmd_payload.state = bp_coh_states_e'(spec_bits_i.state);
                lce_cmd.payload = lce_cmd_payload;

                // decrement pending bit on mem response dequeue
                pending_w_v_o = mem_resp_header_yumi_o;
                pending_w_addr_o = mem_resp.addr;
                pending_o = 1'b0;

                // send data next cycle, after header sends
                mem_resp_state_n = (mem_resp_header_yumi_o)
                                   ? e_mem_resp_send_data
                                   : e_mem_resp_ready;

                mrdc_set = mem_resp_header_yumi_o;
                mrdc_val = mem_resp_size_in_packets;

              end // fwd_mod

              else begin // speculation resolved, forward unmodified
                // forward the header this cycle
                // forward data next cycle(s)

                // inform ucode decode that this unit is using the LCE Command network
                lce_cmd_busy_o = 1'b1;
                mem_resp_busy_o = 1'b1;

                // handshaking
                // r&v for LCE command header
                // valid->yumi for mem response header
                lce_cmd_header_v_o = mem_resp_header_v_i;
                lce_cmd_has_data_o = 1'b1;
                mem_resp_header_yumi_o = mem_resp_header_v_i & lce_cmd_header_ready_and_i;

                // command header
                lce_cmd.msg_type = e_bedrock_cmd_data;
                lce_cmd.addr = mem_resp.addr;
                lce_cmd.size = mem_resp.size;

                // command payload
                lce_cmd_payload.dst_id = mem_resp_payload.lce_id;
                lce_cmd_payload.way_id = mem_resp_payload.way_id;
                lce_cmd_payload.state = mem_resp_payload.state;
                lce_cmd.payload = lce_cmd_payload;

                // decrement pending bit on mem response dequeue (same as lce cmd send)
                pending_w_v_o = mem_resp_header_yumi_o;
                pending_w_addr_o = mem_resp.addr;
                pending_o = 1'b0;

                // send data next cycle, after header sends
                mem_resp_state_n = (mem_resp_header_yumi_o)
                                   ? e_mem_resp_send_data
                                   : e_mem_resp_ready;

                mrdc_set = mem_resp_header_yumi_o;
                mrdc_val = mem_resp_size_in_packets;

              end // forward unmodified

            end // speculative response

            // non-speculative memory access, forward directly to LCE
            else if (mem_resp.msg_type == e_bedrock_mem_rd) begin
              // forward the header this cycle
              // forward data next cycle(s)

              // inform ucode decode that this unit is using the LCE Command network
              lce_cmd_busy_o = 1'b1;
              mem_resp_busy_o = 1'b1;

              // handshaking
              // r&v for LCE command header
              // valid->yumi for mem response header
              lce_cmd_header_v_o = mem_resp_header_v_i;
              lce_cmd_has_data_o = 1'b1;
              mem_resp_header_yumi_o = mem_resp_header_v_i & lce_cmd_header_ready_and_i;

              // command header
              lce_cmd.msg_type = e_bedrock_cmd_data;
              lce_cmd.addr = mem_resp.addr;
              lce_cmd.size = mem_resp.size;

              // command payload
              lce_cmd_payload.dst_id = mem_resp_payload.lce_id;
              lce_cmd_payload.way_id = mem_resp_payload.way_id;
              lce_cmd_payload.state = mem_resp_payload.state;
              lce_cmd.payload = lce_cmd_payload;

              // decrement pending bit on mem response dequeue (same as lce cmd send)
              pending_w_v_o = mem_resp_header_yumi_o;
              pending_w_addr_o = mem_resp.addr;
              pending_o = 1'b0;

              // send data next cycle, after header sends
              mem_resp_state_n = (mem_resp_header_yumi_o)
                                 ? e_mem_resp_send_data
                                 : e_mem_resp_ready;

              mrdc_set = mem_resp_header_yumi_o;
              mrdc_val = mem_resp_size_in_packets;

            end // rd, wr miss from LCE

            // Uncached load response - forward data to LCE
            else if (mem_resp.msg_type == e_bedrock_mem_uc_rd) begin
              // forward the header this cycle
              // forward data next cycle(s)

              // inform ucode decode that this unit is using the LCE Command network
              lce_cmd_busy_o = 1'b1;
              mem_resp_busy_o = 1'b1;

              // handshaking
              // r&v for LCE command header
              // valid->yumi for mem response header
              lce_cmd_header_v_o = mem_resp_header_v_i;
              lce_cmd_has_data_o = 1'b1;
              mem_resp_header_yumi_o = mem_resp_header_v_i & lce_cmd_header_ready_and_i;

              // command header
              lce_cmd.msg_type = e_bedrock_cmd_uc_data;
              lce_cmd.addr = mem_resp.addr;
              lce_cmd.size = mem_resp.size;

              // command payload
              lce_cmd_payload.dst_id = mem_resp_payload.lce_id;
              lce_cmd.payload = lce_cmd_payload;

              // send data next cycle, after header sends
              mem_resp_state_n = (mem_resp_header_yumi_o)
                                 ? e_mem_resp_send_data
                                 : e_mem_resp_ready;

              mrdc_set = mem_resp_header_yumi_o;
              mrdc_val = mem_resp_size_in_packets;

              // decrement pending bits if operating in normal mode and request was made
              // to coherent memory space
              pending_w_v_o = mem_resp_header_yumi_o & cce_normal_mode_r & resp_pma_cacheable_addr_lo;
              pending_w_addr_o = mem_resp.addr;
              pending_o = 1'b0;

            end // uc_rd

            // Uncached store response, send UC Store Done to requesting LCE
            else if (mem_resp.msg_type == e_bedrock_mem_uc_wr) begin
              // forward the header this cycle
              // forward data next cycle(s)

              // inform ucode decode that this unit is using the LCE Command network
              lce_cmd_busy_o = 1'b1;
              mem_resp_busy_o = 1'b1;

              // handshaking
              // r&v for LCE command header
              // valid->yumi for mem response header
              lce_cmd_header_v_o = mem_resp_header_v_i;
              mem_resp_header_yumi_o = mem_resp_header_v_i & lce_cmd_header_ready_and_i;

              // command header
              lce_cmd.msg_type = e_bedrock_cmd_uc_st_done;
              lce_cmd.addr = mem_resp.addr;
              // leave size as '0 equivalent, no data in this message

              // command payload
              lce_cmd_payload.dst_id = mem_resp_payload.lce_id;
              lce_cmd.payload = lce_cmd_payload;

              // decrement pending bits if operating in normal mode and request was made
              // to coherent memory space
              pending_w_v_o = mem_resp_header_yumi_o & cce_normal_mode_r & resp_pma_cacheable_addr_lo;
              pending_w_addr_o = mem_resp.addr;
              pending_o = 1'b0;


            end // uc_wr

            // Dequeue memory writeback response, don't do anything with it
            // decrement pending bit
            else if (mem_resp.msg_type == e_bedrock_mem_wr) begin

              mem_resp_header_yumi_o = mem_resp_header_v_i;
              pending_w_v_o = mem_resp_header_yumi_o;
              pending_w_addr_o = mem_resp.addr;
              pending_o = 1'b0;

            end // wb

          end // mem_resp handling
        end
        e_mem_resp_send_data: begin
          // send data
          // last send occurs when cnt is zero
          lce_cmd_busy_o = 1'b1;
          mem_resp_busy_o = 1'b1;
          lce_cmd_data_o = mem_resp_data_i;
          lce_cmd_data_v_o = mem_resp_data_v_i;
          lce_cmd_last_o = mem_resp_last_i;
          mem_resp_data_ready_and_o = lce_cmd_data_ready_and_i;
          mrdc_down = mem_resp_data_v_i & mem_resp_data_ready_and_o & !(mrdc_cnt == '0);
          mem_resp_state_n = (mem_resp_data_v_i & mem_resp_data_ready_and_o & (mrdc_cnt == '0))
                             ? e_mem_resp_ready
                             : e_mem_resp_send_data;

        end
        e_mem_resp_drain_data: begin
          // when a speculative read is squashed, its data must be drained
          mem_resp_busy_o = 1'b1;
          mem_resp_data_ready_and_o = 1'b1;
          mrdc_down = mem_resp_data_v_i & mem_resp_data_ready_and_o & !(mrdc_cnt == '0);
          mem_resp_state_n = (mem_resp_data_v_i & mem_resp_data_ready_and_o & (mrdc_cnt == '0))
                             ? e_mem_resp_ready
                             : e_mem_resp_drain_data;

        end
        default: begin
          // do nothing
        end
      endcase // memory response auto forwarding
    end // auto_fwd_i enabled or uncached only mode

    // Dequeue coherence ack when it arrives
    // Does not conflict with other dequeues of LCE Response
    // Decrements pending bit on arrival, so arbitrate with memory ports for access
    if (lce_resp_header_v_i & (lce_resp.msg_type.resp == e_bedrock_resp_coh_ack) & ~pending_w_v_o) begin
        lce_resp_header_yumi_o = lce_resp_header_v_i;
        lce_resp_busy_o = 1'b1;
        // inform FSM that pending bit is being used
        pending_w_v_o = lce_resp_header_yumi_o;
        pending_w_addr_o = lce_resp.addr;
        pending_o = 1'b0;
    end

    // Message FSM
    unique case (state_r)

      e_reset: begin
        state_n = e_uncached_only;
        cce_normal_mode_n = 1'b0;
        cnt_rst = 1'b1;
        busy_o = 1'b1;
      end // e_reset;

      // Uncached only mode
      // This mode supports uncached rd/wr operations
      // All of memory is treated as globally uncacheable in this mode
      e_uncached_only: begin
        // block ucode engine while in uncached only mode
        busy_o = 1'b1;

        // clear the counters
        cnt_rst = 1'b1;

        state_n = e_uncached_only;

        // transition to normal/coherent operation as soon as config bus indicates
        if (cce_normal_mode_li) begin
          // register that normal mode is active and all outstanding
          // uncached accesses are complete
          if (~cce_normal_mode_r & mem_credits_full) begin
            cce_normal_mode_n = 1'b1;
            state_n = e_ready;
          end

        // only issue memory command if memory credit is available
        // only process uncached requests
        // cached requests will stall on the input port
        // cached requests not allowed, go to error state and stall
        end else if (lce_req_header_v_i
            & ((lce_req.msg_type.req == e_bedrock_req_rd_miss)
               | (lce_req.msg_type.req == e_bedrock_req_wr_miss))) begin
          state_n = e_error;

        // uncached load/store
        end else if (lce_req_header_v_i
                     & ((lce_req.msg_type.req == e_bedrock_req_uc_wr)
                        | (lce_req.msg_type.req == e_bedrock_req_uc_rd))) begin

          // handshaking
          // r&v on mem cmd header
          // v->y on lce req header
          mem_cmd_header_v_o = lce_req_header_v_i & ~mem_credits_empty;
          lce_req_header_yumi_o = lce_req_header_v_i & mem_cmd_header_v_o & mem_cmd_header_ready_and_i;

          mem_cmd.addr = lce_req.addr;
          mem_cmd.size = lce_req.size;
          mem_cmd_payload.lce_id = lce_req_payload.src_id;
          mem_cmd_payload.uncached = 1'b1;
          mem_cmd.payload = mem_cmd_payload;

          // Uncached Store
          if (lce_req.msg_type.req == e_bedrock_req_uc_wr) begin
            mem_cmd.msg_type.mem = e_bedrock_mem_uc_wr;
            state_n = lce_req_header_yumi_o ? e_uncached_only_data : e_uncached_only;
            mcdc_set = 1'b1;
            mcdc_val = lce_req_size_in_packets;
            mem_cmd_has_data_o = 1'b1;
          // Uncached Load
          end else begin
            mem_cmd.msg_type.mem = e_bedrock_mem_uc_rd;
          end

        end // uncached request

        // TODO: add amo support here

      end // e_uncached_only

      e_uncached_only_data: begin
        // send data
        // last send occurs when cnt is zero
        // r&v on mem cmd data
        // r&v on lce req data
        mem_cmd_data_o = lce_req_data_i;
        mem_cmd_data_v_o = lce_req_data_v_i;
        mem_cmd_last_o = lce_req_last_i;
        lce_req_data_ready_and_o = mem_cmd_data_ready_and_i;

        mcdc_down = lce_req_data_v_i & lce_req_data_ready_and_o & !(mcdc_cnt == '0);
        state_n = (lce_req_data_v_i & lce_req_data_ready_and_o & (mcdc_cnt == '0))
                  ? e_uncached_only
                  : e_uncached_only_data;

      end // e_uncached_only_data


      // This state processes ucode commands
      e_ready: begin

        // Invalidation command
        if (decoded_inst_i.inv_cmd_v) begin
          // busy_o not raised this cycle, will raise next cycle after inv instruction is
          // executed and captured by the message module.
          state_n = e_inv_cmd;
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
        // TODO: popq assumes that inbound message data was drained

        // LCE Request
        else if (decoded_inst_i.lce_req_yumi) begin

          // Pop the request if it is valid and either not doing a pending bit write
          // or doing a pending bit write and this module is not using the pending bit
          // write port.
          lce_req_header_yumi_o = lce_req_header_v_i
                           & ((decoded_inst_i.pending_w_v & ~pending_w_v_o)
                              | ~decoded_inst_i.pending_w_v);

        end
        // LCE Response
        else if (decoded_inst_i.lce_resp_yumi) begin
          // Pop the response if it is valid and either not doing a pending bit write
          // or doing a pending bit write and this module is not using the pending bit
          // write port.
          lce_resp_header_yumi_o = lce_resp_header_v_i
                            & ((decoded_inst_i.pending_w_v & ~pending_w_v_o)
                               | ~decoded_inst_i.pending_w_v);

        end
        // Mem Response
        else if (decoded_inst_i.mem_resp_yumi) begin
          // Pop the response if it is valid and either not doing a pending bit write
          // or doing a pending bit write and this module is not using the pending bit
          // write port.
          mem_resp_header_yumi_o = mem_resp_header_v_i
                            & ((decoded_inst_i.pending_w_v & ~pending_w_v_o)
                               | ~decoded_inst_i.pending_w_v);

        end

        // Outbound messages - pushq

        // Memory Command
        else if (decoded_inst_i.mem_cmd_v) begin

          // Can only send Mem command if:
          // Write port for pending bits isn't in use if pushq will write pending bit
          if ((decoded_inst_i.pending_w_v & ~pending_w_v_o)
              | ~decoded_inst_i.pending_w_v) begin

            // handshake
            // mem command header is r&v
            mem_cmd_header_v_o = ~mem_credits_empty;

            // All commands use message type
            mem_cmd.msg_type.mem = decoded_inst_i.mem_cmd;

            // default field values
            mem_cmd.addr = addr_i;
            mem_cmd.size = mshr.msg_size;

            // set speculative bit if instruction indicates it will be written
            if (decoded_inst_i.spec_w_v & decoded_inst_i.spec_v
                & decoded_inst_i.spec_bits.spec) begin
              mem_cmd_payload.speculative = 1'b1;
            end

            unique case (decoded_inst_i.mem_cmd)
              e_bedrock_mem_uc_rd: begin
                // set uncached bit
                mem_cmd_payload.uncached = 1'b1;
                // uncached access uses the full address, no masking
                // NOTE: address must be aligned to request size
                mem_cmd.addr = addr_i;
                mem_cmd_payload.lce_id = lce_i;
              end

              e_bedrock_mem_uc_wr: begin
                // set uncached bit
                mem_cmd_payload.uncached = 1'b1;
                // uncached access uses the full address, no masking
                // NOTE: address must be aligned to request size
                mem_cmd.addr = addr_i;
                mem_cmd_payload.lce_id = lce_i;
                state_n = (mem_cmd_header_v_o & mem_cmd_header_ready_and_i)
                          ? e_send_data_req_to_mem_cmd
                          : state_r;
                mcdc_set = 1'b1;
                mcdc_val = lce_req_size_in_packets;
                mem_cmd_has_data_o = 1'b1;
              end

              e_bedrock_mem_rd: begin
                // cached access masks the address to align to cache block
                mem_cmd.addr = (addr_i & addr_mask);

                // set uncached bit based on uncached flag in MSHR
                // this bit indicates if the LCE should receive the data as cached or uncached
                // when it returns from memory
                mem_cmd_payload.uncached = mshr.flags[e_opd_ucf];
                mem_cmd_payload.state = mshr.next_coh_state;
                mem_cmd_payload.way_id = way_i;
                mem_cmd_payload.lce_id = lce_i;
              end

              e_bedrock_mem_wr: begin
                // cached access masks the address to align to cache block
                mem_cmd.addr = (addr_i & addr_mask);

                // set uncached bit based on uncached flag in MSHR
                // this bit indicates if the LCE should receive the data as cached or uncached
                // when it returns from memory
                mem_cmd_payload.uncached = mshr.flags[e_opd_ucf];
                mem_cmd_payload.lce_id = lce_i;
                mem_cmd_payload.way_id = '0;
                mem_cmd_payload.state = e_COH_I;
                state_n = (mem_cmd_header_v_o & mem_cmd_header_ready_and_i)
                          ? e_send_data_resp_to_mem_cmd
                          : state_r;
                mcdc_set = 1'b1;
                mcdc_val = lce_resp_size_in_packets;
                mem_cmd_has_data_o = 1'b1;
              end

              e_bedrock_mem_pre: begin
                // TODO: implement prefetch functionality
                mem_cmd_payload.prefetch = 1'b1;
              end

              default: begin
              end
            endcase

            // assign payload struct into memory command header
            mem_cmd.payload = mem_cmd_payload;
          end

        end // Memory Command

        // LCE Command
        else if (decoded_inst_i.lce_cmd_v) begin

          // Can only send LCE command if:
          // Auto-forward isn't using LCE Command port
          // write port for pending bits isn't in use if pushq will write pending bit
          if (~lce_cmd_busy_o
              & ((decoded_inst_i.pending_w_v & ~pending_w_v_o)
                 | ~decoded_inst_i.pending_w_v)) begin

            // handshake
            // lce cmd header is r&v
            lce_cmd_header_v_o = 1'b1;
            // TODO: support sending data or uc_data commands
            lce_cmd_has_data_o = 1'b0;

            // all commands set src, dst, message type and address
            // defaults provided here, but may be overridden below
            lce_cmd_payload.dst_id = lce_i;
            lce_cmd.msg_type.cmd = decoded_inst_i.lce_cmd;
            lce_cmd.addr = addr_i;

            if (decoded_inst_i.pushq_custom) begin
              // TODO: implement custom push
              lce_cmd.size = decoded_inst_i.msg_size;
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
            lce_cmd.payload = lce_cmd_payload;
          end
        end // LCE Command

      end // e_ready

      e_inv_cmd: begin
        busy_o = 1'b1;

        // try to send additional commands, but give priority to mem_resp auto-forward
        if (~lce_cmd_busy_o) begin

          // handshaking
          // r&v for LCE command header
          lce_cmd_header_v_o = 1'b1;

          lce_cmd.msg_type.cmd = e_bedrock_cmd_inv;

          // leave size as '0 equivalent, no data sent for invalidate

          // destination and way come from sharers information
          lce_cmd_payload.dst_id = pe_lce_id;
          lce_cmd_payload.way_id = sharers_ways_r[pe_lce_id];

          lce_cmd.payload = lce_cmd_payload;

          lce_cmd.addr = addr_r;

          // Directory write command
          dir_w_v_o = lce_cmd_header_v_o & lce_cmd_header_ready_and_i;
          dir_w_cmd_o = e_wds_op;
          dir_addr_o = addr_r;
          dir_addr_bypass_o = '0;
          dir_lce_o = {'0, pe_lce_id};
          dir_way_o = sharers_ways_r[pe_lce_id];
          dir_coh_state_o = e_COH_I;

          // message sent, increment count
          cnt_inc = lce_cmd_header_v_o & lce_cmd_header_ready_and_i;
          // only remove current LCE from sharers if command sends
          pe_sharers_n = lce_cmd_header_v_o & lce_cmd_header_ready_and_i
                         ? (pe_sharers_r & ~pe_lce_id_one_hot)
                         : pe_sharers_r;

          // move to response state if none of the new sharer bits are set
          // and the last command is sending this cycle
          state_n = (lce_cmd_header_v_o & lce_cmd_header_ready_and_i & (pe_sharers_n == '0))
                    ? e_inv_resp
                    : e_inv_cmd;

        end // lce_cmd_busy

        // dequeue responses as they arrive
        if (lce_resp_header_v_i & (lce_resp.msg_type.resp == e_bedrock_resp_inv_ack)) begin
          lce_resp_header_yumi_o = lce_resp_header_v_i;
          cnt_dec = 1'b1;
        end

      end // e_inv_cmd

      e_inv_resp: begin
        busy_o = 1'b1;
        if (cnt == '0) begin
          state_n = e_ready;
        end else begin
          if (lce_resp_header_v_i & (lce_resp.msg_type.resp == e_bedrock_resp_inv_ack)) begin
            lce_resp_header_yumi_o = lce_resp_header_v_i;
            if (cnt == 'd1) begin
              state_n = e_ready;
              cnt_rst = 1'b1;
            end else begin
              cnt_dec = 1'b1;
            end
          end
        end
      end // e_inv_resp

      e_send_data_req_to_mem_cmd: begin
        // stall ucode engine while sending data
        busy_o = 1'b1;
        // send data
        // last send occurs when cnt is zero
        // r&v on mem cmd data
        // r&v on lce req data
        mem_cmd_data_o = lce_req_data_i;
        mem_cmd_data_v_o = lce_req_data_v_i;
        mem_cmd_last_o = lce_req_last_i;
        lce_req_data_ready_and_o = mem_cmd_data_ready_and_i;

        mcdc_down = lce_req_data_v_i & lce_req_data_ready_and_o & !(mcdc_cnt == '0);
        state_n = (lce_req_data_v_i & lce_req_data_ready_and_o & (mcdc_cnt == '0))
                  ? e_ready
                  : state_r;

      end // e_send_data_req_to_mem_cmd

      e_send_data_resp_to_mem_cmd: begin
        // stall ucode engine while sending data
        busy_o = 1'b1;
        // send data
        // last send occurs when cnt is zero
        // r&v on mem cmd data
        // r&v on lce resp data
        mem_cmd_data_o = lce_resp_data_i;
        mem_cmd_data_v_o = lce_resp_data_v_i;
        mem_cmd_last_o = lce_resp_last_i;
        lce_resp_data_ready_and_o = mem_cmd_data_ready_and_i;

        mcdc_down = lce_resp_data_v_i & lce_resp_data_ready_and_o & !(mcdc_cnt == '0);
        state_n = (lce_resp_data_v_i & lce_resp_data_ready_and_o & (mcdc_cnt == '0))
                  ? e_ready
                  : state_r;

      end // e_send_data_resp_to_mem_cmd

      e_error: begin
        // message unit error, stall ucode engine
        busy_o = 1'b1;
        state_n = e_error;
      end // e_error

      default: begin
        state_n = e_reset;
      end
    endcase


  end // always_comb

  //synopsys translate_off
  always_ff @(negedge clk_i) begin
    if (~reset_i) begin
      if (state_r == e_inv_cmd & ~pe_v) begin
        $error("bp_cce_msg bad sharers list for invalidate command");
      end // error
      if (state_r == e_ready & decoded_inst_i.pushq_custom) begin
        $error("custom push commands not yet supported");
      end
    end // ~reset
  end // always_ff
  //synopsys translate_on

endmodule
