/**
 *
 * Name:
 *   bp_cce_fsm.v
 *
 * Description:
 *   This is an FSM based CCE
 *
 *   It has two modes of operation:
 *   1. uncached only - all requests are treated as uncached
 *   2. normal - requests obey coherence and cacheability properties. The following accesses are
 *        supported:
 *        - locally cached from globally cacheable memory
 *        - locally uncached from globally uncacheable memory
 *        - locally uncached from globally cacheable memory
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_fsm
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    // Derived parameters
    , localparam block_size_in_bytes_lp    = (cce_block_width_p/8)
    , localparam lg_num_lce_lp             = `BSG_SAFE_CLOG2(num_lce_p)
    , localparam lg_num_cce_lp             = `BSG_SAFE_CLOG2(num_cce_p)
    , localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp)
    , localparam lg_lce_assoc_lp           = `BSG_SAFE_CLOG2(lce_assoc_p)
    , localparam lg_lce_sets_lp            = `BSG_SAFE_CLOG2(lce_sets_p)
    , localparam num_way_groups_lp         = `BSG_CDIV(cce_way_groups_p, num_cce_p)
    , localparam lg_num_way_groups_lp      = `BSG_SAFE_CLOG2(num_way_groups_lp)
    , localparam inst_ram_addr_width_lp    = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)
    , localparam cfg_bus_width_lp          = `bp_cfg_bus_width(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)

    // maximal number of tag sets stored in the directory for all LCE types
    , localparam max_tag_sets_lp           = `BSG_CDIV(lce_sets_p, num_cce_p)
    , localparam lg_max_tag_sets_lp        = `BSG_SAFE_CLOG2(max_tag_sets_lp)

    // interface widths
    `declare_bp_bedrock_lce_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)

    , localparam counter_max = 256
    , localparam hash_index_width_lp=$clog2((2**lg_lce_sets_lp+num_cce_p-1)/num_cce_p)
  )
  (input                                               clk_i
   , input                                             reset_i

   // Config channel
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

  );

  //synopsys translate_off
  initial begin
    assert (lce_sets_p > 1) else $error("Number of LCE sets must be greater than 1");
    assert (counter_max > num_way_groups_lp) else $error("Counter max value not large enough");
    assert (counter_max > max_tag_sets_lp) else $error("Counter max value not large enough");
    assert (icache_block_width_p == cce_block_width_p) else $error("icache block width must match cce block width");
    assert (dcache_block_width_p == cce_block_width_p) else $error("dcache block width must match cce block width");
    assert (acache_block_width_p == cce_block_width_p) else $error("acache block width must match cce block width");
    assert (block_size_in_bytes_lp inside {8, 16, 32, 64, 128}) else $error("invalid CCE block width");
  end
  //synopsys translate_on

  // Define structure variables for output queues
  `declare_bp_bedrock_lce_if(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce);
  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce);

  bp_bedrock_lce_req_msg_s  lce_req;
  bp_bedrock_lce_resp_msg_s lce_resp;
  bp_bedrock_lce_cmd_msg_s  lce_cmd;
  bp_bedrock_cce_mem_msg_s  mem_cmd, mem_resp;
  bp_bedrock_cce_mem_payload_s mem_cmd_payload, mem_resp_payload;
  bp_bedrock_lce_req_payload_s lce_req_payload;
  bp_bedrock_lce_cmd_payload_s lce_cmd_payload;
  bp_bedrock_lce_resp_payload_s lce_resp_payload;

  // assign output queue ports to structure variables
  assign lce_cmd_o = lce_cmd;
  assign mem_cmd_o = mem_cmd;

  // cast input messages with data
  assign mem_resp = mem_resp_i;
  assign mem_resp_payload = mem_resp.header.payload;
  assign lce_resp = lce_resp_i;
  assign lce_resp_payload = lce_resp.header.payload;
  assign lce_req = lce_req_i;
  assign lce_req_payload = lce_req.header.payload;

  // Config bus
  `declare_bp_cfg_bus_s(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  bp_cfg_bus_s cfg_bus_cast_i;
  assign cfg_bus_cast_i = cfg_bus_i;
  wire cce_normal_mode_li = (cfg_bus_cast_i.cce_mode == e_cce_mode_normal);
  logic cce_normal_mode_r, cce_normal_mode_n;

  // CCE FSM

  // MSHR
  `declare_bp_cce_mshr_s(lce_id_width_p, lce_assoc_p, paddr_width_p);
  bp_cce_mshr_s mshr_r, mshr_n;

  // Pending Bits
  logic pending_li, pending_clear_li, pending_lo;
  logic pending_w_v, pending_r_v;
  logic [paddr_width_p-1:0] pending_w_addr, pending_r_addr;
  // The read address always comes from the MSHR
  assign pending_r_addr = mshr_r.paddr;

  // bit to tell FSM that it can't use pending bit module write port
  logic pending_busy;

  // bit to tell FSM that it can't use LCE Command network because memory response is using it
  logic lce_cmd_busy;

  bp_cce_pending_bits
    #(.num_way_groups_p(num_way_groups_lp) // number of way groups managed in this CCE
      ,.cce_way_groups_p(cce_way_groups_p) // total number of way groups in system
      ,.num_cce_p(num_cce_p)
      ,.paddr_width_p(paddr_width_p)
      ,.addr_offset_p(lg_block_size_in_bytes_lp)
     )
    pending_bits
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.w_v_i(pending_w_v)
      ,.w_addr_i(pending_w_addr)
      ,.w_addr_bypass_hash_i('0)
      ,.pending_i(pending_li)
      ,.clear_i(pending_clear_li)
      ,.r_v_i(pending_r_v)
      ,.r_addr_i(pending_r_addr)
      ,.r_addr_bypass_hash_i('0)
      ,.pending_o(pending_lo)
      );

  // Directory signals
  logic dir_r_v, dir_w_v;
  bp_cce_inst_minor_dir_op_e dir_cmd;
  logic sharers_v_lo;
  logic [num_lce_p-1:0] sharers_hits_lo;
  logic [num_lce_p-1:0][lg_lce_assoc_lp-1:0] sharers_ways_lo;
  bp_coh_states_e [num_lce_p-1:0] sharers_coh_states_lo;
  logic dir_lru_v_lo;
  logic [paddr_width_p-1:0] dir_lru_addr_lo, dir_addr_lo;
  bp_coh_states_e dir_lru_coh_state_lo;
  logic dir_busy_lo;

  logic [paddr_width_p-1:0] dir_addr_li;
  logic dir_addr_bypass_li;
  logic [lce_id_width_p-1:0] dir_lce_li;
  logic [lg_lce_assoc_lp-1:0] dir_way_li, dir_lru_way_li;
  bp_coh_states_e dir_coh_state_li;

  // GAD signals
  logic [lg_lce_assoc_lp-1:0] gad_req_addr_way_lo;
  logic [lce_id_width_p-1:0] gad_owner_lce_lo;
  logic [lg_lce_assoc_lp-1:0] gad_owner_lce_way_lo;
  bp_coh_states_e gad_owner_coh_state_lo;
  logic gad_replacement_flag_lo;
  logic gad_upgrade_flag_lo;
  logic gad_cached_shared_flag_lo;
  logic gad_cached_exclusive_flag_lo;
  logic gad_cached_modified_flag_lo;
  logic gad_cached_owned_flag_lo;
  logic gad_cached_forward_flag_lo;

  // Directory
  bp_cce_dir
    #(.bp_params_p(bp_params_p)
      )
    directory
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // Inputs
      ,.addr_i(dir_addr_li)
      ,.addr_bypass_i(dir_addr_bypass_li)
      ,.lce_i(dir_lce_li)
      ,.way_i(dir_way_li)
      ,.lru_way_i(mshr_r.lru_way_id)
      ,.coh_state_i(dir_coh_state_li)
      ,.addr_dst_gpr_i(e_opd_r0) // only used for RDE
      ,.cmd_i(dir_cmd)
      ,.r_v_i(dir_r_v)
      ,.w_v_i(dir_w_v)
      // Outputs
      ,.busy_o(dir_busy_lo)
      ,.sharers_v_o(sharers_v_lo)
      ,.sharers_hits_o(sharers_hits_lo)
      ,.sharers_ways_o(sharers_ways_lo)
      ,.sharers_coh_states_o(sharers_coh_states_lo)
      ,.lru_v_o(dir_lru_v_lo)
      ,.lru_coh_state_o(dir_lru_coh_state_lo)
      ,.lru_addr_o(dir_lru_addr_lo)
      ,.addr_v_o() // only for RDE, can be left unconnected in FSM CCE
      ,.addr_o()
      ,.addr_dst_gpr_o()
      // Debug
      ,.cce_id_i(cfg_bus_cast_i.cce_id)
      );

  // GAD logic - auxiliary directory information logic
  bp_cce_gad
    #(.bp_params_p(bp_params_p)
      )
    gad
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.gad_v_i(sharers_v_lo & ~dir_busy_lo)

      ,.sharers_v_i(sharers_v_lo)
      ,.sharers_hits_i(sharers_hits_lo)
      ,.sharers_ways_i(sharers_ways_lo)
      ,.sharers_coh_states_i(sharers_coh_states_lo)

      ,.req_lce_i(mshr_r.lce_id)
      ,.req_type_flag_i(mshr_r.flags[e_opd_rqf])
      ,.lru_coh_state_i(mshr_r.lru_coh_state)
      ,.atomic_req_flag_i(mshr_r.flags[e_opd_arf])
      ,.uncached_req_flag_i(mshr_r.flags[e_opd_ucf])

      ,.req_addr_way_o(gad_req_addr_way_lo)
      ,.owner_lce_o(gad_owner_lce_lo)
      ,.owner_way_o(gad_owner_lce_way_lo)
      ,.owner_coh_state_o(gad_owner_coh_state_lo)
      ,.replacement_flag_o(gad_replacement_flag_lo)
      ,.upgrade_flag_o(gad_upgrade_flag_lo)
      ,.cached_shared_flag_o(gad_cached_shared_flag_lo)
      ,.cached_exclusive_flag_o(gad_cached_exclusive_flag_lo)
      ,.cached_modified_flag_o(gad_cached_modified_flag_lo)
      ,.cached_owned_flag_o(gad_cached_owned_flag_lo)
      ,.cached_forward_flag_o(gad_cached_forward_flag_lo)
      );

  // CCE coherence PMA - LCE requests
  logic req_pma_coherent_addr_lo;
  bp_cce_pma
    #(.bp_params_p(bp_params_p)
      )
    req_pma
      (.paddr_i(lce_req.header.addr)
       ,.paddr_v_i(lce_req_v_i)
       ,.cacheable_addr_o(req_pma_coherent_addr_lo)
       );

  //synopsys translate_off
  always @(negedge clk_i) begin
    if (~reset_i) begin
      // Cacheable requests must target cacheable memory
      assert(!(lce_req_v_i && ~req_pma_coherent_addr_lo
               && ((lce_req.header.msg_type.req == e_bedrock_req_rd_miss)
                   || (lce_req.header.msg_type.req == e_bedrock_req_wr_miss))
              )
            ) else
      $error("CCE PMA violation - cacheable requests must target cacheable memory");
    end
  end
  //synopsys translate_on

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

  typedef enum logic [5:0] {
    e_reset
    , e_clear_dir
    , e_uncached_only
    , e_send_sync
    , e_sync_ack
    , e_ready

    , e_uncached_req
    , e_read_pending
    , e_coherent_req
    , e_read_mem_spec
    , e_read_dir
    , e_wait_dir_gad

    , e_write_next_state

    , e_inv_cmd
    , e_inv_ack

    , e_replacement
    , e_replacement_wb_resp

    , e_uc_coherent_cmd
    , e_uc_coherent_resp
    , e_uc_coherent_mem_cmd

    , e_upgrade_stw_cmd

    , e_transfer
    , e_transfer_cmd
    , e_transfer_st_cmd
    , e_transfer_wb_cmd
    , e_transfer_wb_resp

    , e_resolve_speculation

    , e_error

  } state_e;

  state_e state_r, state_n;

  // Counter for message send/receive
  logic cnt_rst;
  logic [`BSG_WIDTH(1)-1:0] cnt_inc, cnt_dec;
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

  // General use counter
  logic cnt_0_clr, cnt_0_inc;
  logic [`BSG_SAFE_CLOG2(counter_max+1)-1:0] cnt_0;
  bsg_counter_clear_up
    #(.max_val_p(counter_max)
      ,.init_val_p(0)
     )
    counter_0
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.clear_i(cnt_0_clr)
      ,.up_i(cnt_0_inc)
      ,.count_o(cnt_0)
      );

  // General use counter
  logic cnt_1_clr, cnt_1_inc;
  logic [`BSG_SAFE_CLOG2(counter_max+1)-1:0] cnt_1;
  bsg_counter_clear_up
    #(.max_val_p(counter_max)
      ,.init_val_p(0)
     )
    counter_1
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.clear_i(cnt_1_clr)
      ,.up_i(cnt_1_inc)
      ,.count_o(cnt_1)
      );

  // ACK counter
  logic ack_cnt_clr, ack_cnt_inc;
  logic [`BSG_SAFE_CLOG2(counter_max+1)-1:0] ack_cnt;
  bsg_counter_clear_up
    #(.max_val_p(counter_max)
      ,.init_val_p(0)
     )
    ack_counter
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.clear_i(ack_cnt_clr)
      ,.up_i(ack_cnt_inc)
      ,.count_o(ack_cnt)
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

  // Speculative memory access management
  bp_cce_spec_s spec_bits_li, spec_bits_lo;
  logic spec_w_v;
  logic spec_v_li, squash_v_li, fwd_mod_v_li, state_v_li;

  bp_cce_spec_bits
    #(.num_way_groups_p(num_way_groups_lp)
      ,.cce_way_groups_p(cce_way_groups_p)
      ,.num_cce_p(num_cce_p)
      ,.paddr_width_p(paddr_width_p)
      ,.addr_offset_p(lg_block_size_in_bytes_lp)
      )
    spec_bits
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       // write-port
       ,.w_v_i(spec_w_v)
       ,.w_addr_i(mshr_r.paddr)
       ,.w_addr_bypass_hash_i('0)

       ,.spec_v_i(spec_v_li)
       ,.squash_v_i(squash_v_li)
       ,.fwd_mod_v_i(fwd_mod_v_li)
       ,.state_v_i(state_v_li)
       ,.spec_i(spec_bits_li)

       // read-port
       ,.r_v_i(mem_resp_v_i & mem_resp_payload.speculative)
       ,.r_addr_i(mem_resp.header.addr)
       ,.r_addr_bypass_hash_i('0)

       // output
       ,.spec_o(spec_bits_lo)
       );


  // One hot of request LCE ID
  logic [num_lce_p-1:0] req_lce_id_one_hot;
  bsg_decode
    #(.num_out_p(num_lce_p))
    req_lce_id_to_one_hot
    (.i(mshr_r.lce_id[0+:lg_num_lce_lp])
     ,.o(req_lce_id_one_hot)
     );

  // One hot of owner LCE ID
  logic [num_lce_p-1:0] owner_lce_id_one_hot;
  bsg_decode
    #(.num_out_p(num_lce_p))
    owner_lce_id_to_one_hot
    (.i(mshr_r.owner_lce_id[0+:lg_num_lce_lp])
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

  logic [num_lce_p-1:0][lg_lce_assoc_lp-1:0] sharers_ways_r, sharers_ways_n;
  logic [num_lce_p-1:0] sharers_hits_r, sharers_hits_n;

  // Convert first index back to one hot
  logic [num_lce_p-1:0] pe_lce_id_one_hot;
  bsg_decode
    #(.num_out_p(num_lce_p))
    pe_lce_id_to_one_hot
    (.i(pe_lce_id)
     ,.o(pe_lce_id_one_hot)
     );

  wire lce_resp_coh_ack_yumi = lce_resp_v_i & (lce_resp.header.msg_type.resp == e_bedrock_resp_coh_ack) & ~pending_busy;

  // transfer occurs if any cache has block in E, M, O, or F (ownerhsip states)
  wire transfer_flag = (mshr_r.flags[e_opd_cef] | mshr_r.flags[e_opd_cmf]
                        | mshr_r.flags[e_opd_cof] | mshr_r.flags[e_opd_cff]);
  // invalidations occur if write request and any blcok in S state (shared, not owner)
  // owner does not need to be invalidated; owner state is changed by the st_tr or st_tr_wb command
  wire invalidate_flag = (mshr_r.flags[e_opd_rqf] & mshr_r.flags[e_opd_csf]);

  always_comb begin
    state_n = state_r;
    mshr_n = mshr_r;
    sharers_ways_n = sharers_ways_r;
    sharers_hits_n = sharers_hits_r;
    pe_sharers_n = pe_sharers_r;
    cce_normal_mode_n = cce_normal_mode_r;

    lce_req_yumi_o = '0;
    lce_resp_yumi_o = '0;
    lce_cmd = '0;
    lce_cmd_payload = '0;
    lce_cmd_payload.src_id = cfg_bus_cast_i.cce_id;
    lce_cmd_v_o = '0;

    mem_cmd = '0;
    mem_cmd_payload = '0;
    mem_cmd_v_o = '0;
    mem_resp_yumi_o = '0;

    // up down counter
    cnt_inc = '0;
    cnt_dec = '0;
    cnt_rst = '0;

    cnt_1_clr = '0;
    cnt_1_inc = '0;
    cnt_0_clr = '0;
    cnt_0_inc = '0;
    ack_cnt_clr = '0;
    ack_cnt_inc = '0;

    pending_li = '0;
    pending_clear_li = '0;
    pending_r_v = '0;
    pending_w_v = '0;
    pending_w_addr = '0;

    dir_r_v = '0;
    dir_w_v = '0;
    dir_cmd = e_rdw_op;
    dir_lce_li = mshr_r.lce_id;
    dir_way_li = mshr_r.way_id;
    dir_lru_way_li = mshr_r.lru_way_id;
    dir_addr_li = mshr_r.paddr;
    dir_addr_bypass_li = '0;
    dir_coh_state_li = mshr_r.next_coh_state;

    // speculative memory access
    spec_w_v = '0;
    spec_bits_li = '0;
    spec_v_li = '0;
    squash_v_li = '0;
    fwd_mod_v_li = '0;
    state_v_li = '0;

    // By default, pending write port is available
    pending_busy = '0;
    lce_cmd_busy = '0;

    // Mem Response (Data) to LCE Command (Data)

    // LCE Command feeds a wormhole router, so v_o must be held high until the wormhole router raises
    // lce_cmd_ready_i signal. The pending bit is written on the cycle that lce_cmd_ready_i goes
    // high. The main FSM will stall if it wants to write to the pending bits in the same cycle.
    if (mem_resp_v_i) begin

      // Speculative access response
      // Note: speculative access is only supported for cached requests
      if (mem_resp_payload.speculative) begin

        if (spec_bits_lo.spec) begin // speculation not resolved yet
          // do nothing, wait for speculation to be resolved
          // Note: this blocks memory responses behind the speculative response from being
          // forwarded. However, the CCE will not move on to a new LCE request until it
          // resolves the speculation for the current request.
        end // speculative bit sill set

        else if (spec_bits_lo.squash) begin // speculation resolved, squash
          // dequeue the command and do nothing with it
          mem_resp_yumi_o = mem_resp_v_i;

          // decrement pending bit on mem response dequeue
          pending_busy = mem_resp_yumi_o;
          pending_w_v = mem_resp_yumi_o;
          pending_w_addr = mem_resp.header.addr;
          pending_li = 1'b0;

        end // squash

        else if (spec_bits_lo.fwd_mod) begin // speculation resolved, forward with modified state
          // handshaking
          lce_cmd_v_o = lce_cmd_ready_i & mem_resp_v_i;
          mem_resp_yumi_o = lce_cmd_ready_i & mem_resp_v_i;

          // inform ucode decode that this unit is using the LCE Command network
          lce_cmd_busy = lce_cmd_v_o;

          // output command message
          lce_cmd_payload.dst_id = mem_resp_payload.lce_id;

          // Data is copied directly from the Mem Data Response
          lce_cmd.header.msg_type.cmd = e_bedrock_cmd_data;
          lce_cmd_payload.way_id = mem_resp_payload.way_id;
          lce_cmd.data = mem_resp.data;
          lce_cmd.header.addr = mem_resp.header.addr;
          lce_cmd.header.size = mem_resp.header.size;
          // modify the coherence state
          lce_cmd_payload.state = bp_coh_states_e'(spec_bits_lo.state);
          lce_cmd.header.payload = lce_cmd_payload;

          // decrement pending bit on mem response dequeue (same as lce cmd send)
          pending_busy = mem_resp_yumi_o;
          pending_w_v = mem_resp_yumi_o;
          pending_w_addr = mem_resp.header.addr;
          pending_li = 1'b0;

        end // fwd_mod

        else begin // speculation resolved, forward unmodified
          // handshaking
          lce_cmd_v_o = lce_cmd_ready_i & mem_resp_v_i;
          mem_resp_yumi_o = lce_cmd_ready_i & mem_resp_v_i;

          // inform ucode decode that this unit is using the LCE Command network
          lce_cmd_busy = lce_cmd_v_o;

          // output command message
          lce_cmd_payload.dst_id = mem_resp_payload.lce_id;

          // Data is copied directly from the Mem Data Response
          lce_cmd.header.msg_type.cmd = e_bedrock_cmd_data;
          lce_cmd_payload.way_id = mem_resp_payload.way_id;
          lce_cmd.data = mem_resp.data;
          lce_cmd.header.addr = mem_resp.header.addr;
          lce_cmd.header.size = mem_resp.header.size;
          lce_cmd_payload.state = mem_resp_payload.state;
          lce_cmd.header.payload = lce_cmd_payload;

          // decrement pending bit on mem response dequeue (same as lce cmd send)
          pending_busy = mem_resp_yumi_o;
          pending_w_v = mem_resp_yumi_o;
          pending_w_addr = mem_resp.header.addr;
          pending_li = 1'b0;

        end // forward unmodified

      end // speculative response

      // non-speculative memory access, forward directly to LCE
      else if (mem_resp.header.msg_type.mem == e_bedrock_mem_rd) begin

        // handshaking
        lce_cmd_v_o = lce_cmd_ready_i & mem_resp_v_i;
        mem_resp_yumi_o = lce_cmd_ready_i & mem_resp_v_i;

        // inform ucode decode that this unit is using the LCE Command network
        lce_cmd_busy = lce_cmd_v_o;

        // Data is copied directly from the Mem Data Response
        lce_cmd_payload.dst_id = mem_resp_payload.lce_id;
        lce_cmd.header.msg_type.cmd = e_bedrock_cmd_data;
        lce_cmd_payload.way_id = mem_resp_payload.way_id;
        lce_cmd.data = mem_resp.data;
        lce_cmd.header.addr = mem_resp.header.addr;
        lce_cmd.header.size = mem_resp.header.size;
        lce_cmd_payload.state = mem_resp_payload.state;
        lce_cmd.header.payload = lce_cmd_payload;

        // decrement pending bit on mem response dequeue (same as lce cmd send)
        pending_busy = mem_resp_yumi_o;
        pending_w_v = mem_resp_yumi_o;
        pending_w_addr = mem_resp.header.addr;
        pending_li = 1'b0;

      end // rd, wr

      // Uncached load response - forward data to LCE
      // This transaction does not modify the pending bits
      else if (mem_resp.header.msg_type.mem == e_bedrock_mem_uc_rd) begin

        // handshaking
        lce_cmd_v_o = lce_cmd_ready_i & mem_resp_v_i;
        mem_resp_yumi_o = lce_cmd_ready_i & mem_resp_v_i;

        // block FSM from using LCE Command network
        lce_cmd_busy = lce_cmd_v_o;

        lce_cmd_payload.dst_id = mem_resp_payload.lce_id;
        lce_cmd.header.msg_type.cmd = e_bedrock_cmd_uc_data;
        lce_cmd_payload.way_id = '0;
        lce_cmd.header.payload = lce_cmd_payload;
        lce_cmd.data = mem_resp.data;
        lce_cmd.header.addr = mem_resp.header.addr;
        lce_cmd.header.size = mem_resp.header.size;

        // decrement pending bits if operating in normal mode and request was made
        // to coherent memory space
        pending_busy = mem_resp_yumi_o & cce_normal_mode_r & resp_pma_coherent_addr_lo;
        pending_w_v = mem_resp_yumi_o & cce_normal_mode_r & resp_pma_coherent_addr_lo;
        pending_w_addr = mem_resp.header.addr;
        pending_li = 1'b0;

      end // uc_rd

      // Uncached store response, send UC Store Done to requesting LCE,
      // don't modify pending bits
      else if (mem_resp.header.msg_type.mem == e_bedrock_mem_uc_wr) begin

        // handshaking
        lce_cmd_v_o = lce_cmd_ready_i & mem_resp_v_i;
        mem_resp_yumi_o = lce_cmd_ready_i & mem_resp_v_i;

        // block FSM from using LCE Command network
        lce_cmd_busy = lce_cmd_v_o;

        lce_cmd_payload.dst_id = mem_resp_payload.lce_id;
        lce_cmd.header.msg_type.cmd = e_bedrock_cmd_uc_st_done;
        lce_cmd_payload.way_id = '0;
        lce_cmd.header.payload = lce_cmd_payload;
        lce_cmd.header.addr = mem_resp.header.addr;
        // leave size as '0 equivalent, no data in this message

        // decrement pending bits if operating in normal mode and request was made
        // to coherent memory space
        pending_busy = mem_resp_yumi_o & cce_normal_mode_r & resp_pma_coherent_addr_lo;
        pending_w_v = mem_resp_yumi_o & cce_normal_mode_r & resp_pma_coherent_addr_lo;
        pending_w_addr = mem_resp.header.addr;
        pending_li = 1'b0;

      end // uc_wr

      // Dequeue memory writeback response, don't do anything with it
      // decrement pending bit
      // also set pending_busy to block FSM if needed
      else if (mem_resp.header.msg_type.mem == e_bedrock_mem_wr) begin

        mem_resp_yumi_o = mem_resp_v_i;
        pending_busy = mem_resp_yumi_o;
        pending_w_v = mem_resp_yumi_o;
        pending_w_addr = mem_resp.header.addr;
        pending_li = 1'b0;

      end // wb

      // TODO: amo requests

    end // mem_resp handling

    // Dequeue coherence ack when it arrives
    // Does not conflict with other dequeues of LCE Response
    // Decrements pending bit on arrival, so arbitrate with memory ports for access
    if (lce_resp_v_i & (lce_resp.header.msg_type.resp == e_bedrock_resp_coh_ack) & ~pending_busy) begin
        lce_resp_yumi_o = lce_resp_v_i;
        // inform FSM that pending bit is being used
        pending_busy = lce_resp_yumi_o;
        pending_w_v = lce_resp_yumi_o;
        pending_w_addr = lce_resp.header.addr;
        pending_li = 1'b0;
    end


    // FSM
    case (state_r)
      e_reset: begin
        state_n = e_clear_dir;
        cce_normal_mode_n = 1'b0;
        cnt_0_clr = 1'b1;
        cnt_1_clr = 1'b1;
        ack_cnt_clr = 1'b1;
      end // e_reset

      // After reset, clear the directory, then operate based on the current operating mode
      // If normal mode is set, perform the sync sequence with the LCEs
      e_clear_dir: begin
        dir_w_v = 1'b1;
        dir_cmd = e_clr_op;

        // increment through maximal number of tag sets (outer loop) and all LCE's (inner loop)
        // tag set number is cnt_0
        // LCE is cnt_1

        // bypass the address hashing in bp_cce_dir_segment, using dir_addr_li directly as the
        // tag set number for the operation
        dir_addr_bypass_li = 1'b1;
        dir_addr_li = '0;
        dir_addr_li[0+:lg_max_tag_sets_lp] = cnt_0[0+:lg_max_tag_sets_lp];
        dir_lce_li = cnt_1[0+:lce_id_width_p];

        // inner loop - LCE
        // clear the LCE counter back to 0 after reaching max LCE ID to reset for next tag set
        cnt_1_clr = (cnt_1 == (num_lce_p-1));
        // increment the LCE counter if not clearing
        cnt_1_inc = ~cnt_1_clr;

        // outer loop - tag set
        // cnt_0 clears after all LCEs in the last tag set have been cleared
        cnt_0_clr = (cnt_0 == (max_tag_sets_lp-1)) & cnt_1_clr;
        // move to next tag set when cnt_1 clears back to LCE 0
        cnt_0_inc = cnt_1_clr;

        // Stay in e_clear_dir until cnt_0_clr goes high
        // Next state depends on the CCE mode, as set by config bus
        state_n = cnt_0_clr
                  ? cce_normal_mode_li
                    ? e_send_sync
                    : e_uncached_only
                  : e_clear_dir;

      end // e_clear_dir

      // Uncached only mode
      // This mode supports uncached rd/wr operations
      // All of memory is treated as globally uncacheable in this mode
      e_uncached_only: begin

        // clear the MSHR
        mshr_n = '0;
        // clear the ack counter
        cnt_0_clr = 1'b1;
        cnt_1_clr = 1'b1;
        ack_cnt_clr = 1'b1;
        cnt_rst = 1'b1;

        state_n = e_uncached_only;

        // transition to normal/coherent operation as soon as config bus indicates
        if (cce_normal_mode_li) begin
          state_n = e_send_sync;

        // only issue memory command if memory credit is available
        // only process uncached requests
        // cached requests will stall on the input port
        end else if (lce_req_v_i) begin
          // cached requests not allowed, go to error state and stall
          if ((lce_req.header.msg_type.req == e_bedrock_req_rd_miss)
              | (lce_req.header.msg_type.req == e_bedrock_req_wr_miss)) begin
              state_n = e_error;

          // uncached load/store
          end else if ((lce_req.header.msg_type.req == e_bedrock_req_uc_wr)
                       | (lce_req.header.msg_type.req == e_bedrock_req_uc_rd)) begin

            // handshaking
            mem_cmd_v_o = mem_cmd_ready_i & lce_req_v_i & ~mem_credits_empty;
            lce_req_yumi_o = mem_cmd_v_o;

            // Uncached Store
            if (lce_req.header.msg_type.req == e_bedrock_req_uc_wr) begin
              mem_cmd.header.msg_type.mem = e_bedrock_mem_uc_wr;
              mem_cmd.data = lce_req.data;
            // Uncached Load
            end else begin
              mem_cmd.header.msg_type.mem = e_bedrock_mem_uc_rd;
            end

            mem_cmd.header.addr = lce_req.header.addr;
            mem_cmd_payload.lce_id = lce_req_payload.src_id;
            mem_cmd_payload.uncached = 1'b1;
            mem_cmd.header.payload = mem_cmd_payload;
            mem_cmd.header.size = lce_req.header.size;
          end // uncached request

          // TODO: add amo support here

        end // lce_req_v_i & ~cce_normal_mode_li
      end // e_uncached_only

      e_send_sync: begin
        // register that normal mode is active (can still be doing sync) and all outstanding
        // uncached accesses are complete
        cce_normal_mode_n = (~cce_normal_mode_r & mem_credits_full)
                            ? 1'b1
                            : cce_normal_mode_r;

        // after first entering e_send_sync from e_uncached_only, wait for all oustanding uncached
        // accesses to complete before sending first sync commnad
        if (mem_credits_full & ~lce_cmd_busy) begin
          lce_cmd_v_o = lce_cmd_ready_i;

          lce_cmd_payload.dst_id[0+:lg_num_lce_lp] = cnt_1[0+:lg_num_lce_lp];
          lce_cmd.header.payload = lce_cmd_payload;
          lce_cmd.header.msg_type.cmd = e_bedrock_cmd_sync;

          state_n = (lce_cmd_ready_i) ? e_sync_ack : e_send_sync;
          cnt_1_inc = lce_cmd_ready_i;
        end
      end // e_send_sync

      e_sync_ack: begin
        if (~lce_resp_coh_ack_yumi) begin
          lce_resp_yumi_o = lce_resp_v_i;
          state_n = (lce_resp_v_i)
                    ? (ack_cnt == (num_lce_p-1))
                      ? e_ready
                      : e_send_sync
                    : e_sync_ack;
          state_n = (lce_resp_v_i & (lce_resp.header.msg_type.resp != e_bedrock_resp_sync_ack))
                    ? e_error
                    : state_n;
          ack_cnt_clr = (state_n == e_ready);
          ack_cnt_inc = lce_resp_v_i & ~ack_cnt_clr;
          cnt_1_clr = (state_n == e_ready);
        end
      end // e_sync_ack

      e_ready: begin
        // clear the MSHR
        mshr_n = '0;
        // clear the ack counter
        cnt_0_clr = 1'b1;
        cnt_1_clr = 1'b1;
        ack_cnt_clr = 1'b1;
        cnt_rst = 1'b1;

        if (lce_req_v_i) begin
          mshr_n.lce_id = lce_req_payload.src_id;
          state_n = e_error;
          // cached request
          if (lce_req.header.msg_type.req == e_bedrock_req_rd_miss
              | lce_req.header.msg_type.req == e_bedrock_req_wr_miss) begin

            mshr_n.paddr = lce_req.header.addr;
            mshr_n.msg_size = lce_req.header.size;
            mshr_n.lru_way_id = lce_req_payload.lru_way_id;
            mshr_n.flags[e_opd_rqf] = (lce_req.header.msg_type.req == e_bedrock_req_wr_miss);
            mshr_n.flags[e_opd_nerf] = lce_req_payload.non_exclusive;

            // query PMA for coherence property - it is a violation for a cached request
            // to be incoherent.
            mshr_n.flags[e_opd_rcf] = req_pma_coherent_addr_lo;

            state_n = ~req_pma_coherent_addr_lo
                      ? e_error
                      : e_read_pending;

          // uncached request
          end else if (lce_req.header.msg_type.req == e_bedrock_req_uc_rd
                       | lce_req.header.msg_type.req == e_bedrock_req_uc_wr) begin

            mshr_n.paddr = lce_req.header.addr;
            mshr_n.msg_size = lce_req.header.size;
            mshr_n.flags[e_opd_ucf] = 1'b1;
            mshr_n.flags[e_opd_rqf] = (lce_req.header.msg_type.req == e_bedrock_req_uc_wr);

            // query PMA for coherence property
            // uncached requests can be made to coherent or incoherent memory regions
            mshr_n.flags[e_opd_rcf] = req_pma_coherent_addr_lo;

            // a coherent, but uncached request must serialize with other coherent operations
            // using the pending bits
            state_n = req_pma_coherent_addr_lo
                      ? e_read_pending
                      : e_uncached_req;

          // TODO: handle amo requests here with else if block on msg_type

          end else begin
            state_n = e_error;
          end
        end // lce_req_v
      end // e_ready

      // process uncached request
      e_uncached_req: begin
        // try to send uncached request to memory
        mem_cmd_v_o = mem_cmd_ready_i & lce_req_v_i & ~mem_credits_empty;
        lce_req_yumi_o = mem_cmd_v_o;

        // Uncached Store
        if (mshr_r.flags[e_opd_rqf]) begin
          mem_cmd.header.msg_type.mem = e_bedrock_mem_uc_wr;
          mem_cmd.data = lce_req.data;
        // Uncached Load
        end else begin
          mem_cmd.header.msg_type.mem = e_bedrock_mem_uc_rd;
        end

        mem_cmd.header.addr = mshr_r.paddr;
        mem_cmd_payload.lce_id = mshr_r.lce_id;
        mem_cmd.header.payload = mem_cmd_payload;
        mem_cmd.header.size = lce_req.header.size;

        // go back to ready state after sending memory command
        // since this state is only entered when CCE is in normal mode
        state_n = mem_cmd_v_o
                  ? e_ready
                  : e_uncached_req;

      end // e_uncached_req

      // process requests that need coherence/serialization of the pending bits
      // the request can be uncached or uncached
      e_read_pending: begin
        pending_r_v = 1'b1;
        state_n = (pending_lo)
                  ? e_read_pending
                  : e_coherent_req;
      end // e_read_pending

      // Coherent/cacheable memory space has three request types:
      // 1. normal, cached request
      // 2. uncached request
      // 3. amo request
      // only normal, cached requests will issue a speculative memory read
      e_coherent_req: begin
        if (lce_req_v_i & ~pending_busy) begin
          // write the pending bit if not amo or uncached to coherent memory
          // because those ops do not send coh_ack back to CCE after request completes
          pending_w_v =  ~(mshr_r.flags[e_opd_arf] | mshr_r.flags[e_opd_ucf]);
          pending_w_addr = lce_req.header.addr;
          pending_li = 1'b1;

          // skip speculative memory access if amo/uncached
          state_n = (mshr_r.flags[e_opd_arf] | mshr_r.flags[e_opd_ucf])
                    ? e_read_dir
                    : e_read_mem_spec;

          // only dequeue the request now if it is a normal cached request
          lce_req_yumi_o = ~(mshr_r.flags[e_opd_arf] | mshr_r.flags[e_opd_ucf]);

        end else begin
          // pending bit write port is busy, stay in e_ready state and try to consume request
          // next cycle
          state_n = e_coherent_req;
        end
      end // e_coherent_req

      e_read_mem_spec: begin
        // Mem Cmd needs to write pending bit, so only send if Mem Resp / LCE Cmd is not
        // writing the pending bit
        if (~pending_busy) begin
          mem_cmd_v_o = mem_cmd_ready_i & ~mem_credits_empty;
          mem_cmd.header.msg_type.mem = e_bedrock_mem_rd;
          mem_cmd.header.addr = (mshr_r.paddr >> lg_block_size_in_bytes_lp) << lg_block_size_in_bytes_lp;
          mem_cmd.header.size = mshr_r.msg_size;
          mem_cmd_payload.lce_id = mshr_r.lce_id;
          mem_cmd_payload.way_id = mshr_r.lru_way_id;
          // speculatively issue request for E state
          mem_cmd_payload.state = e_COH_E;
          mem_cmd_payload.speculative = 1'b1;
          mem_cmd.header.payload = mem_cmd_payload;

          // set the spec bit and clear all other bits for this entry
          spec_w_v = mem_cmd_v_o;
          spec_v_li = 1'b1;
          squash_v_li = 1'b1;
          fwd_mod_v_li = 1'b1;
          state_v_li = 1'b1;
          spec_bits_li.spec = 1'b1;
          spec_bits_li.squash = 1'b0;
          spec_bits_li.fwd_mod = 1'b0;
          spec_bits_li.state = e_COH_I;

          state_n = (mem_cmd_v_o) ? e_read_dir : e_read_mem_spec;

          pending_w_v = mem_cmd_v_o;
          pending_li = 1'b1;
          pending_w_addr = mshr_r.paddr;
        end

      end // e_read_mem_spec

      e_read_dir: begin
        // initiate the directory read
        // At the earliest, data will be valid in the next cycle
        dir_r_v = 1'b1;
        dir_addr_li = mshr_r.paddr;
        dir_cmd = e_rdw_op;
        dir_lce_li = mshr_r.lce_id;
        dir_lru_way_li = mshr_r.lru_way_id;
        state_n = e_wait_dir_gad;
      end // e_read_dir

      e_wait_dir_gad: begin

        // capture LRU outputs when they appear
        if (dir_lru_v_lo) begin
          mshr_n.lru_paddr = dir_lru_addr_lo;
          mshr_n.lru_coh_state = dir_lru_coh_state_lo;
        end

        if (sharers_v_lo) begin
          sharers_ways_n = sharers_ways_lo;
          sharers_hits_n = sharers_hits_lo;
        end

        if (sharers_v_lo & ~dir_busy_lo) begin

          mshr_n.way_id = gad_req_addr_way_lo;

          mshr_n.flags[e_opd_rf] = gad_replacement_flag_lo;
          mshr_n.flags[e_opd_uf] = gad_upgrade_flag_lo;
          mshr_n.flags[e_opd_csf] = gad_cached_shared_flag_lo;
          mshr_n.flags[e_opd_cef] = gad_cached_exclusive_flag_lo;
          mshr_n.flags[e_opd_cmf] = gad_cached_modified_flag_lo;
          mshr_n.flags[e_opd_cof] = gad_cached_owned_flag_lo;
          mshr_n.flags[e_opd_cff] = gad_cached_forward_flag_lo;

          mshr_n.owner_lce_id = gad_owner_lce_lo;
          mshr_n.owner_way_id = gad_owner_lce_way_lo;
          mshr_n.owner_coh_state = gad_owner_coh_state_lo;

          // TODO: MOESIF
          // determine next state for MESI protocol
          // atomic or uncached requests to coherent memory will set block to Invalid if it is
          // present in the requesting LCE
          mshr_n.next_coh_state =
            (mshr_r.flags[e_opd_arf] | mshr_r.flags[e_opd_ucf])
            ? e_COH_I
            : (mshr_r.flags[e_opd_rqf])
              ? e_COH_M
              : (mshr_r.flags[e_opd_nerf])
                ? e_COH_S
                : (gad_cached_shared_flag_lo | gad_cached_exclusive_flag_lo | gad_cached_modified_flag_lo
                   | gad_cached_owned_flag_lo | gad_cached_forward_flag_lo)
                  ? e_COH_S
                  : e_COH_E;

          state_n = e_write_next_state;
        end

      end // e_wait_dir_gad

      e_write_next_state: begin
        // writing to the directory will make the sharers_v_lo signal go low, but in this FSM
        // CCE we know that the sharers vectors are still valid in the state we need from the
        // previous read, so we perform the coherence state update for the requesting LCE anyway

        dir_lce_li = mshr_r.lce_id;
        dir_addr_li = mshr_r.paddr;
        dir_coh_state_li = mshr_r.next_coh_state;

        // upgrade detected, only change state
        if (mshr_r.flags[e_opd_uf]) begin
          dir_w_v = 1'b1;
          dir_cmd = e_wds_op;
          dir_way_li = mshr_r.way_id;

        // amo or uncached to coherent memory
        // only write directory if replacement flag is set indicating the requsting LCE has
        // the block cached already
        end else if (mshr_r.flags[e_opd_arf] | mshr_r.flags[e_opd_ucf]) begin
          dir_w_v = mshr_r.flags[e_opd_rf];
          dir_cmd = e_wds_op;
          // the block, if cached at the LCE, is in the way indicated by the way_id field of
          // the MSHR as produced by the GAD module
          dir_way_li = mshr_r.way_id;

        // normal requests, write tag and state
        end else begin
          dir_w_v = 1'b1;
          dir_cmd = e_wde_op;
          dir_way_li = mshr_r.lru_way_id;
        end

        // Ordering of coherence actions:
        // Replacement, if needed
        // - also set if amo or uncached to coherent memory and requesting LCE needs block
        // - invalidated and (possibly) written back
        // Invalidations, if needed
        // Upgrade, Transfer, or Memory access (resolve speculative access)
        state_n =
          (mshr_r.flags[e_opd_rf])
          ? e_replacement
          : (invalidate_flag)
            ? e_inv_cmd
            : (mshr_r.flags[e_opd_arf] | mshr_r.flags[e_opd_ucf])
              ? e_uc_coherent_cmd
              : (mshr_r.flags[e_opd_uf])
                ? e_upgrade_stw_cmd
                : (transfer_flag)
                  ? e_transfer
                  : e_resolve_speculation;

        // setup required state for sending invalidations
        // only if next state is invalidations (i.e., not doing a replacement)
        if (~mshr_r.flags[e_opd_rf] & invalidate_flag) begin
          // don't invalidate the requesting LCE
          pe_sharers_n = sharers_hits_r & ~req_lce_id_one_hot;
          // if doing a transfer, also remove owner LCE since transfer
          // routine will take care of setting owner into correct new state
          pe_sharers_n = transfer_flag
                         ? pe_sharers_n & ~owner_lce_id_one_hot
                         : pe_sharers_n;
          cnt_rst = 1'b1;
        end

      end // e_write_next_state

      e_replacement: begin
        // Send replacement writeback command if LCE Cmd port is free, else try again next cycle
        if (~lce_cmd_busy & lce_cmd_ready_i) begin
          lce_cmd_v_o = lce_cmd_ready_i;

          lce_cmd_payload.dst_id = mshr_r.lce_id;
          // set state to invalid and writeback
          lce_cmd.header.msg_type.cmd = e_bedrock_cmd_st_wb;
          // for an uc/amo request, the mshr way_id field indicates the way in which the requesting
          // LCE's copy of the cache block is stored at the LCE
          if (mshr_r.flags[e_opd_arf] | mshr_r.flags[e_opd_ucf]) begin
            lce_cmd_payload.way_id = mshr_r.way_id;
            lce_cmd.header.addr = mshr_r.paddr;
          end else begin
            lce_cmd_payload.way_id = mshr_r.lru_way_id;
            lce_cmd.header.addr = mshr_r.lru_paddr;
          end
          // Note: this state must be e_COH_I to properly handle amo or uncached access to
          // coherent memory that requires invalidating the requesting LCE if it has the block
          lce_cmd_payload.state = e_COH_I;
          lce_cmd.header.payload = lce_cmd_payload;

          state_n = (lce_cmd_ready_i) ? e_replacement_wb_resp : e_replacement;
        end
      end // e_replacement

      // TODO: replacement response could maybe move out of FSM and into auto-logic
      // need a DFF that tracks if wb response is pending, and must block certain following operations
      // if still waiting for response (i.e., finishing the transaction).
      // However, could overlap invalidations with waiting for wb response.
      e_replacement_wb_resp: begin
        if (lce_resp_v_i) begin
          if (lce_resp.header.msg_type.resp == e_bedrock_resp_null_wb) begin
            lce_resp_yumi_o = lce_resp_v_i;
            // replacement done, not an upgrade, so either do invalidations, transfer, or resolve
            // the speculative memory access
            state_n = (invalidate_flag)
                      ? e_inv_cmd
                      : (mshr_r.flags[e_opd_arf] | mshr_r.flags[e_opd_ucf])
                        ? e_uc_coherent_cmd
                        : (transfer_flag)
                          ? e_transfer
                          : e_resolve_speculation;

            // clear the replacement flag
            mshr_n.flags[e_opd_rf] = 1'b0;
            // set null writeback flag
            mshr_n.flags[e_opd_nwbf] = 1'b1;

            // setup required state for sending invalidations
            if (invalidate_flag) begin
              // don't invalidate the requesting LCE
              pe_sharers_n = sharers_hits_r & ~req_lce_id_one_hot;
              // if doing a transfer, also remove owner LCE since transfer
              // routine will take care of setting owner into correct new state
              pe_sharers_n = transfer_flag
                             ? pe_sharers_n & ~owner_lce_id_one_hot
                             : pe_sharers_n;
              cnt_rst = 1'b1;
            end

          end
          else if ((lce_resp.header.msg_type.resp == e_bedrock_resp_wb) & ~pending_busy) begin
            // Mem Data Cmd needs to write pending bit, so only send if Mem Data Resp / LCE Data Cmd is
            // not writing the pending bit
            mem_cmd_v_o = lce_resp_v_i & mem_cmd_ready_i & ~mem_credits_empty;
            lce_resp_yumi_o = mem_cmd_v_o;

            mem_cmd.header.msg_type.mem = e_bedrock_mem_wr;
            mem_cmd.header.addr = (lce_resp.header.addr >> lg_block_size_in_bytes_lp) << lg_block_size_in_bytes_lp;
            mem_cmd_payload.lce_id = mshr_r.lce_id;
            mem_cmd_payload.way_id = '0;
            mem_cmd.header.payload = mem_cmd_payload;
            mem_cmd.data = lce_resp.data;
            mem_cmd.header.size = lce_resp.header.size;

            // replacement done, not an upgrade, so either do invalidations, transfer, or resolve
            // the speculative memory access
            state_n = (lce_resp_yumi_o)
                      ? (invalidate_flag)
                        ? e_inv_cmd
                        : (mshr_r.flags[e_opd_arf] | mshr_r.flags[e_opd_ucf])
                          ? e_uc_coherent_cmd
                          : (transfer_flag)
                            ? e_transfer
                            : e_resolve_speculation
                      : e_replacement_wb_resp;

            // set the pending bit
            pending_w_v = lce_resp_yumi_o;
            pending_li = 1'b1;
            pending_w_addr = lce_resp.header.addr;

            // clear the replacement flag
            mshr_n.flags[e_opd_rf] = 1'b0;
            // clear null writeback flag
            mshr_n.flags[e_opd_nwbf] = 1'b0;

            // setup required state for sending invalidations
            if (lce_resp_yumi_o & invalidate_flag) begin
              // don't invalidate the requesting LCE
              pe_sharers_n = sharers_hits_r & ~req_lce_id_one_hot;
              // if doing a transfer, also remove owner LCE since transfer
              // routine will take care of setting owner into correct new state
              pe_sharers_n = transfer_flag
                             ? pe_sharers_n & ~owner_lce_id_one_hot
                             : pe_sharers_n;
              cnt_rst = 1'b1;
            end
          end // wb & pending bit available
        end // lce_resp_v_i
      end // e_replacement_wb_resp

      e_inv_cmd: begin

        // only send invalidation if priority encode has valid output
        // this indicates the sharers vector has a valid bit set
        if (pe_v) begin

          // try to send additional commands, but give priority to mem_resp auto-forward
          if (~lce_cmd_busy & lce_cmd_ready_i) begin

            lce_cmd_v_o = lce_cmd_ready_i;
            lce_cmd.header.msg_type.cmd = e_bedrock_cmd_inv;

            // destination and way come from sharers information
            lce_cmd_payload.dst_id[0+:lg_num_lce_lp] = pe_lce_id;
            lce_cmd_payload.way_id = sharers_ways_r[pe_lce_id];
            lce_cmd.header.payload = lce_cmd_payload;

            lce_cmd.header.addr = mshr_r.paddr;

            // message sent, increment count, write directory, clear bit for the destination LCE
            cnt_inc = lce_cmd_v_o;
            dir_w_v = lce_cmd_v_o;
            dir_cmd = e_wds_op;
            dir_addr_li = mshr_r.paddr;
            dir_lce_li = '0;
            dir_lce_li[0+:lg_num_lce_lp] = pe_lce_id;
            dir_way_li = sharers_ways_r[pe_lce_id];
            dir_coh_state_li = e_COH_I;

            // update sharers hit vector to feed back to priority encode module
            pe_sharers_n = pe_sharers_r & ~pe_lce_id_one_hot;

            // move to response state if none of the sharer bits are set, indicating
            // that the last command is sending this cycle
            if (pe_sharers_n == '0) begin
              state_n = e_inv_ack;
            end

          end else begin
            // could not send message, don't clear bit for first sharer
            pe_sharers_n = pe_sharers_r;
          end

        end // pe_v

        // dequeue responses as they arrive
        if (lce_resp_v_i & (lce_resp.header.msg_type.resp == e_bedrock_resp_inv_ack)) begin
          lce_resp_yumi_o = lce_resp_v_i;
          cnt_dec = lce_resp_yumi_o;
        end
      end // e_inv_cmd

      e_inv_ack: begin
        if (cnt == '0) begin
          state_n = (mshr_r.flags[e_opd_arf] | mshr_r.flags[e_opd_ucf])
                    ? e_uc_coherent_cmd
                    : (mshr_r.flags[e_opd_uf])
                      ? e_upgrade_stw_cmd
                      : (transfer_flag)
                        ? e_transfer
                        : e_resolve_speculation;

        end else begin
          // dequeue responses as they arrive
          if (lce_resp_v_i & (lce_resp.header.msg_type.resp == e_bedrock_resp_inv_ack)) begin
            lce_resp_yumi_o = lce_resp_v_i;
            cnt_dec = lce_resp_yumi_o;
            if (cnt == 'd1) begin
              state_n = (mshr_r.flags[e_opd_arf] | mshr_r.flags[e_opd_ucf])
                        ? e_uc_coherent_cmd
                        : (mshr_r.flags[e_opd_uf])
                          ? e_upgrade_stw_cmd
                          : (transfer_flag)
                            ? e_transfer
                            : e_resolve_speculation;
            end // cnt == 'd1
          end // inv ack
        end // else
      end // e_inv_ack

      // Process uncached request to coherent memory space
      e_uc_coherent_cmd: begin
        // at this point for amo/uncached request to coherent memory, the requesting LCE
        // has had block invalidated and written back if needed. All sharers (COH_S) blocks were
        // also invalidated.

        // now, if an owner has block it needs to be invalidated and written back (if required)
        if (transfer_flag) begin
          if (~lce_cmd_busy & lce_cmd_ready_i) begin
            lce_cmd_v_o = lce_cmd_ready_i;

            lce_cmd.header.addr = mshr_r.paddr;
            lce_cmd_payload.dst_id = mshr_r.owner_lce_id;
            lce_cmd_payload.way_id = mshr_r.owner_way_id;
            lce_cmd_payload.state = e_COH_I;
            lce_cmd.header.payload = lce_cmd_payload;

            // either invalidate or set tag and writeback
            // if owner is in F state, block is clean, so only need to invalidate
            // else, block in E, M, or O, need to invalidate and writeback
            lce_cmd.header.msg_type.cmd = mshr_r.flags[e_opd_cff]
                                          ? e_bedrock_cmd_inv
                                          : e_bedrock_cmd_st_wb;

            // update state of owner in directory
            dir_w_v = lce_cmd_v_o;
            dir_cmd = e_wds_op;
            dir_addr_li = mshr_r.paddr;
            dir_lce_li = mshr_r.owner_lce_id;
            dir_way_li = mshr_r.owner_way_id;
            dir_coh_state_li = e_COH_I;

            state_n = (lce_cmd_v_o)
                      ? e_uc_coherent_resp
                      : e_uc_coherent_cmd;

          end
        // no other LCE is owner, transfer flag not set
        end else begin
          state_n = e_uc_coherent_mem_cmd;
        end
      end // e_uc_coherent_cmd

      // amo/uc wait for replacement writeback or invalidation ack if sent
      e_uc_coherent_resp: begin
        if (lce_resp_v_i) begin
          if (lce_resp.header.msg_type.resp == e_bedrock_resp_wb) begin
            if (~pending_busy) begin
              // Mem Data Cmd needs to write pending bit, so only send if Mem Data Resp / LCE Data Cmd is
              // not writing the pending bit
              mem_cmd_v_o = lce_resp_v_i & mem_cmd_ready_i & ~mem_credits_empty;
              lce_resp_yumi_o = mem_cmd_v_o;

              mem_cmd.header.msg_type.mem = e_bedrock_mem_wr;
              mem_cmd.header.addr = (lce_resp.header.addr >> lg_block_size_in_bytes_lp) << lg_block_size_in_bytes_lp;
              mem_cmd.header.size = lce_resp.header.size;
              mem_cmd_payload.lce_id = mshr_r.lce_id;
              mem_cmd.header.payload = mem_cmd_payload;
              mem_cmd.data = lce_resp.data;

              state_n = (lce_resp_yumi_o)
                        ? e_uc_coherent_mem_cmd
                        : e_uc_coherent_resp;

              // set the pending bit
              pending_w_v = lce_resp_yumi_o;
              pending_li = 1'b1;
              pending_w_addr = lce_resp.header.addr;

            end
          end else if (lce_resp.header.msg_type.resp == e_bedrock_resp_null_wb) begin
            lce_resp_yumi_o = lce_resp_v_i;
            state_n = e_uc_coherent_mem_cmd;
          end else if (lce_resp.header.msg_type.resp == e_bedrock_resp_inv_ack) begin
            lce_resp_yumi_o = lce_resp_v_i;
            state_n = e_uc_coherent_mem_cmd;
          end
        end

      end // e_uc_coherent_resp

      // amo/uc after inv_ack/wb_response, issue op to memory
      // writes pending bit
      e_uc_coherent_mem_cmd: begin
        if (~pending_busy) begin
          mem_cmd_v_o = lce_req_v_i & mem_cmd_ready_i & ~mem_credits_empty;
          // set message type based on request message type
          unique case (lce_req.header.msg_type.req)
            e_bedrock_req_uc_rd: mem_cmd.header.msg_type = e_bedrock_mem_uc_rd;
            e_bedrock_req_uc_wr: mem_cmd.header.msg_type = e_bedrock_mem_uc_wr;
            /* TODO: for atomics
            e_bedrock_req_amoswap: mem_cmd.header.msg_type = e_bedrock_mem_amo_swap;
            e_bedrock_req_amoadd: mem_cmd.header.msg_type = e_bedrock_mem_amo_add;
            e_bedrock_req_amoxor: mem_cmd.header.msg_type = e_bedrock_mem_amo_xor;
            e_bedrock_req_amoand: mem_cmd.header.msg_type = e_bedrock_mem_amo_and;
            e_bedrock_req_amoor: mem_cmd.header.msg_type = e_bedrock_mem_amo_or;
            e_bedrock_req_amomin: mem_cmd.header.msg_type = e_bedrock_mem_amo_min;
            e_bedrock_req_amomax: mem_cmd.header.msg_type = e_bedrock_mem_amo_max;
            e_bedrock_req_amominu: mem_cmd.header.msg_type = e_bedrock_mem_amo_minu;
            e_bedrock_req_amomaxu: mem_cmd.header.msg_type = e_bedrock_mem_amo_maxu;
            */
            default: mem_cmd.header.msg_type = e_bedrock_mem_uc_rd;
          endcase
          // uncached/amo address must be aligned appropriate to the request size
          // in the LCE request (which is stored in the MSHR)
          mem_cmd.header.addr = mshr_r.paddr;
          mem_cmd.header.size = mshr_r.msg_size;
          // TODO: uncomment/modify when implementing atomics
          //mem_cmd.header.amo_no_return = mshr_r.flags[e_opd_anrf];
          mem_cmd_payload.lce_id = mshr_r.lce_id;
          mem_cmd_payload.way_id = '0;
          // this op is uncached in LCE for both amo or uncached requests
          mem_cmd_payload.uncached = 1'b1;
          mem_cmd.header.payload = mem_cmd_payload;
          // amo request data
          mem_cmd.data = lce_req.data;

          // finally dequeue the LCE request
          lce_req_yumi_o = mem_cmd_v_o;

          // set the pending bit
          pending_w_v = mem_cmd_v_o;
          pending_li = 1'b1;
          pending_w_addr = mshr_r.paddr;

          state_n = (mem_cmd_v_o)
                    ? e_ready
                    : e_uc_coherent_mem_cmd;

        end

      end // e_uc_coherent_mem_cmd

      e_transfer: begin
        // TODO: modify for MOESIF
        // Transfer required, three options:
        // 1. transfer: not used in MESI
        // 2. set state and transfer: write request and block in E, M
        // 3. set state, transfer, writeback: read request, block in E, M
        if (~lce_cmd_busy & lce_cmd_ready_i) begin
          lce_cmd_v_o = lce_cmd_ready_i;

          lce_cmd_payload.dst_id = mshr_r.owner_lce_id;
          lce_cmd_payload.way_id = mshr_r.owner_way_id;

          lce_cmd.header.msg_type.cmd = mshr_r.flags[e_opd_rqf]
                                        ? e_bedrock_cmd_st_tr
                                        : e_bedrock_cmd_st_tr_wb;

          lce_cmd.header.addr = mshr_r.paddr;

          // either Invalidate or Downgrade Owner, depending on request type
          lce_cmd_payload.state = mshr_r.flags[e_opd_rqf] ? e_COH_I : e_COH_S;

          // transfer information
          lce_cmd_payload.target = mshr_r.lce_id;
          lce_cmd_payload.target_way_id = mshr_r.lru_way_id;
          lce_cmd_payload.target_state = mshr_r.next_coh_state;
          lce_cmd.header.payload = lce_cmd_payload;

          // update state of owner in directory
          dir_w_v = lce_cmd_v_o;
          dir_cmd = e_wds_op;
          dir_addr_li = mshr_r.paddr;
          dir_lce_li = mshr_r.owner_lce_id;
          dir_way_li = mshr_r.owner_way_id;
          dir_coh_state_li = mshr_r.flags[e_opd_rqf] ? e_COH_I : e_COH_S;

          state_n = (lce_cmd_ready_i)
                    ? mshr_r.flags[e_opd_rqf]
                      ? e_resolve_speculation
                      : e_transfer_wb_resp
                    : e_transfer;
        end

      end // e_transfer

      e_transfer_wb_resp: begin
        if (lce_resp_v_i) begin
          if (lce_resp.header.msg_type.resp == e_bedrock_resp_null_wb) begin
            lce_resp_yumi_o = lce_resp_v_i;
            state_n = e_resolve_speculation;

          end
          else if ((lce_resp.header.msg_type.resp == e_bedrock_resp_wb) & ~pending_busy) begin
            // Mem Data Cmd needs to write pending bit, so only send if Mem Data Resp / LCE Data Cmd is
            // not writing the pending bit
            mem_cmd_v_o = lce_resp_v_i & mem_cmd_ready_i & ~mem_credits_empty;
            lce_resp_yumi_o = mem_cmd_v_o;

            mem_cmd.header.msg_type.mem = e_bedrock_mem_wr;
            mem_cmd.header.addr = (lce_resp.header.addr >> lg_block_size_in_bytes_lp) << lg_block_size_in_bytes_lp;
            mem_cmd_payload.lce_id = mshr_r.lce_id;
            mem_cmd_payload.way_id = '0;
            mem_cmd.header.payload = mem_cmd_payload;
            mem_cmd.data = lce_resp.data;
            mem_cmd.header.size = lce_resp.header.size;

            state_n = (lce_resp_yumi_o) ? e_resolve_speculation : e_transfer_wb_resp;

            // set the pending bit
            pending_w_v = lce_resp_yumi_o;
            pending_li = 1'b1;
            pending_w_addr = lce_resp.header.addr;

          end
        end
      end // e_transfer_wb_resp

      e_upgrade_stw_cmd: begin
        if (~lce_cmd_busy & lce_cmd_ready_i) begin
          lce_cmd_v_o = lce_cmd_ready_i;

          lce_cmd_payload.dst_id = mshr_r.lce_id;
          lce_cmd.header.msg_type.cmd = e_bedrock_cmd_st_wakeup;
          lce_cmd_payload.way_id = mshr_r.way_id;
          lce_cmd.header.addr = mshr_r.paddr;
          lce_cmd_payload.state = mshr_r.next_coh_state;
          lce_cmd.header.payload = lce_cmd_payload;

          state_n = (lce_cmd_ready_i) ? e_resolve_speculation : e_upgrade_stw_cmd;
        end
      end // e_upgrade_stw_cmd

      e_resolve_speculation: begin
        // Resolve speculation
        if (transfer_flag | mshr_r.flags[e_opd_uf]) begin
          // squash speculative memory request if transfer or upgrade
          spec_w_v = 1'b1;
          // no longer speculative
          spec_v_li = 1'b1;
          spec_bits_li.spec = 1'b0;
          // squash the response
          squash_v_li = 1'b1;
          spec_bits_li.squash = 1'b1;
        end else if (mshr_r.flags[e_opd_rqf]) begin
          // forward with M state
          spec_w_v = 1'b1;
          spec_v_li = 1'b1;
          fwd_mod_v_li = 1'b1;
          state_v_li = 1'b1;
          spec_bits_li.spec = 1'b0;
          spec_bits_li.state = e_COH_M;
          spec_bits_li.fwd_mod = 1'b1;
        end else if (mshr_r.flags[e_opd_csf] | mshr_r.flags[e_opd_nerf]) begin
          // forward with S state
          spec_w_v = 1'b1;
          spec_v_li = 1'b1;
          fwd_mod_v_li = 1'b1;
          state_v_li = 1'b1;
          spec_bits_li.spec = 1'b0;
          spec_bits_li.state = e_COH_S;
          spec_bits_li.fwd_mod = 1'b1;
        end else begin
          // forward with E state (as requested)
          spec_w_v = 1'b1;
          spec_v_li = 1'b1;
          spec_bits_li.spec = 1'b0;
        end
        state_n = e_ready;
      end // e_resolve_speculation

      e_error: begin
        state_n = e_error;
      end // e_error

      default: begin
        // use defaults above
      end

    endcase
  end // always_comb

  // Sequential Logic
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      state_r <= e_reset;
      mshr_r <= '0;
      sharers_ways_r <= '0;
      sharers_hits_r <= '0;
      pe_sharers_r <= '0;
      cce_normal_mode_r <= '0;
    end else begin
      state_r <= state_n;
      mshr_r <= mshr_n;
      sharers_ways_r <= sharers_ways_n;
      sharers_hits_r <= sharers_hits_n;
      pe_sharers_r <= pe_sharers_n;
      cce_normal_mode_r <= cce_normal_mode_n;
    end
  end

endmodule
