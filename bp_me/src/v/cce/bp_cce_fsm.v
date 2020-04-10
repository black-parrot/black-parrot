/**
 *
 * Name:
 *   bp_cce_fsm.v
 *
 * Description:
 *   This is an FSM based CCE - not necessarily synthesizable, and meant to compare with ucode CCE
 *
 */

module bp_cce_fsm
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_common_cfg_link_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)

    // Derived parameters
    , localparam block_size_in_bytes_lp    = (cce_block_width_p/8)
    , localparam lg_num_lce_lp             = `BSG_SAFE_CLOG2(num_lce_p)
    , localparam lg_num_cce_lp             = `BSG_SAFE_CLOG2(num_cce_p)
    , localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp)
    , localparam lg_lce_assoc_lp           = `BSG_SAFE_CLOG2(lce_assoc_p)
    , localparam lg_lce_sets_lp            = `BSG_SAFE_CLOG2(lce_sets_p)
    , localparam ptag_width_lp              = (paddr_width_p-lg_lce_sets_lp
                                              -lg_block_size_in_bytes_lp)
    , localparam num_way_groups_lp         = `BSG_CDIV(cce_way_groups_p, num_cce_p)
    , localparam lg_num_way_groups_lp      = `BSG_SAFE_CLOG2(num_way_groups_lp)
    , localparam inst_ram_addr_width_lp    = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)
    , localparam cfg_bus_width_lp          = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)

    // maximal number of tag sets stored in the directory for all LCE types
    , localparam max_tag_sets_lp           = `BSG_CDIV(lce_sets_p, num_cce_p)
    , localparam lg_max_tag_sets_lp        = `BSG_SAFE_CLOG2(max_tag_sets_lp)

    // interface widths
    `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
    `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

    , localparam counter_max = 256
    , localparam max_uc_req_lp = (counter_max-1)
    , localparam hash_index_width_lp=$clog2((2**lg_lce_sets_lp+num_cce_p-1)/num_cce_p)
  )
  (input                                               clk_i
   , input                                             reset_i

   // Config channel
   , input [cfg_bus_width_lp-1:0]                      cfg_bus_i
   , output [cce_instr_width_p-1:0]                    cfg_cce_ucode_data_o

   // LCE-CCE Interface
   , input [lce_cce_req_width_lp-1:0]                  lce_req_i
   , input                                             lce_req_v_i
   , output logic                                      lce_req_yumi_o

   , input [lce_cce_resp_width_lp-1:0]                 lce_resp_i
   , input                                             lce_resp_v_i
   , output logic                                      lce_resp_yumi_o

   // ready->valid
   , output logic [lce_cmd_width_lp-1:0]               lce_cmd_o
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

  // stub cfg ucode output, since FSM CCE has no ucode
  assign cfg_cce_ucode_data_o = '0;

  //synopsys translate_off
  initial begin
    assert (lce_sets_p > 1) else $error("Number of LCE sets must be greater than 1");
    assert (counter_max > num_way_groups_lp) else $error("Counter max value not large enough");
    assert (counter_max > max_tag_sets_lp) else $error("Counter max value not large enough");
  end
  //synopsys translate_on

  // Define structure variables for output queues

  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p);

  bp_lce_cce_req_s lce_req;
  bp_lce_cce_resp_s lce_resp;
  bp_lce_cmd_s lce_cmd;

  bp_cce_mem_msg_s mem_cmd, mem_resp;

  // assign output queue ports to structure variables
  assign lce_cmd_o = lce_cmd;
  assign mem_cmd_o = mem_cmd;

  // cast input messages with data
  assign mem_resp = mem_resp_i;
  assign lce_resp = lce_resp_i;
  assign lce_req = lce_req_i;

  // Config bus
  `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
  bp_cfg_bus_s cfg_bus_cast_i;
  assign cfg_bus_cast_i = cfg_bus_i;
  wire cce_normal_mode = (cfg_bus_cast_i.cce_mode == e_cce_mode_normal);

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
  logic dir_lru_cached_excl_lo;
  logic [paddr_width_p-1:0] dir_lru_addr_lo, dir_addr_lo;
  bp_coh_states_e dir_lru_coh_state_lo;
  logic dir_busy_lo;

  logic [paddr_width_p-1:0] dir_addr_li;
  logic dir_addr_bypass_li;
  logic [lce_id_width_p-1:0] dir_lce_li;
  logic [lg_lce_assoc_lp-1:0] dir_way_li, dir_lru_way_li;
  bp_coh_states_e dir_coh_state_li;

  // GAD signals
  logic gad_v;

  logic [lg_lce_assoc_lp-1:0] gad_req_addr_way_lo;
  logic [lce_id_width_p-1:0] gad_owner_lce_lo;
  logic [lg_lce_assoc_lp-1:0] gad_owner_lce_way_lo;
  logic gad_replacement_flag_lo;
  logic gad_upgrade_flag_lo;
  logic gad_invalidate_flag_lo;
  logic gad_cached_flag_lo;
  logic gad_cached_exclusive_flag_lo;
  logic gad_cached_owned_flag_lo;
  logic gad_cached_dirty_flag_lo;
  logic gad_cached_shared_flag_lo;

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
      ,.lru_cached_excl_o(dir_lru_cached_excl_lo)
      ,.lru_coh_state_o(dir_lru_coh_state_lo)
      ,.lru_addr_o(dir_lru_addr_lo)
      ,.addr_v_o() // only for RDE, can be left unconnected in FSM CCE
      ,.addr_o()
      ,.addr_dst_gpr_o()
      );

  // GAD logic - auxiliary directory information logic
  bp_cce_gad
    #(.bp_params_p(bp_params_p)
      )
    gad
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.gad_v_i(gad_v)

      ,.sharers_v_i(sharers_v_lo)
      ,.sharers_hits_i(sharers_hits_lo)
      ,.sharers_ways_i(sharers_ways_lo)
      ,.sharers_coh_states_i(sharers_coh_states_lo)

      ,.req_lce_i(mshr_r.lce_id)
      ,.req_type_flag_i(mshr_r.flags[e_opd_rqf])
      ,.lru_coh_state_i(mshr_r.lru_coh_state)

      ,.req_addr_way_o(gad_req_addr_way_lo)
      ,.owner_lce_o(gad_owner_lce_lo)
      ,.owner_way_o(gad_owner_lce_way_lo)
      ,.replacement_flag_o(gad_replacement_flag_lo)
      ,.upgrade_flag_o(gad_upgrade_flag_lo)
      ,.invalidate_flag_o(gad_invalidate_flag_lo)
      ,.cached_flag_o(gad_cached_flag_lo)
      ,.cached_exclusive_flag_o(gad_cached_exclusive_flag_lo)
      ,.cached_owned_flag_o(gad_cached_owned_flag_lo)
      ,.cached_dirty_flag_o(gad_cached_dirty_flag_lo)
      ,.cached_shared_flag_o(gad_cached_shared_flag_lo)
      );


  typedef enum logic [5:0] {
    RESET
    , CLEAR_DIR
    , UNCACHED_ONLY
    , SEND_SYNC
    , SYNC_ACK
    , READY

    , UC_REQ
    , READ_PENDING
    , DEQ_LCE_REQ
    , READ_MEM_SPEC
    , READ_DIR
    , WAIT_DIR_GAD
    , GAD

    , WRITE_NEXT_STATE

    , INV_CMD
    , INV_ACK

    , REPLACEMENT
    , REPLACEMENT_WB_RESP

    , UPGRADE_STW_CMD

    , TRANSFER_CMD
    , TRANSFER_ST_CMD
    , TRANSFER_WB_CMD
    , TRANSFER_WB_RESP

    , RESOLVE_SPECULATION

    , ERROR

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

  // Counter for uncached mode send/receive
  // This counter tracks the number of uncached mode memory commands
  // sent and responses received. If the config bus changes the CCE mode to
  // normal, but there are still outstanding accesses, the message module will
  // wait to transition modes until
  logic uc_cnt_inc, uc_cnt_dec, uc_cnt_rst;
  logic [`BSG_WIDTH(counter_max)-1:0] uc_cnt;
  bsg_counter_up_down
    #(.max_val_p(counter_max)
      ,.init_val_p(0)
      ,.max_step_p(1)
      )
    uc_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i | uc_cnt_rst)
     ,.up_i(uc_cnt_inc)
     ,.down_i(uc_cnt_dec)
     ,.count_o(uc_cnt)
     );

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
       ,.r_v_i(mem_resp_v_i & mem_resp.header.payload.speculative)
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

  wire lce_resp_coh_ack_yumi = lce_resp_v_i & (lce_resp.header.msg_type == e_lce_cce_coh_ack) & ~pending_busy;

  always_comb begin
    state_n = state_r;
    mshr_n = mshr_r;
    sharers_ways_n = sharers_ways_r;
    sharers_hits_n = sharers_hits_r;
    pe_sharers_n = pe_sharers_r;

    lce_req_yumi_o = '0;
    lce_resp_yumi_o = '0;
    lce_cmd = '0;
    lce_cmd_v_o = '0;

    mem_cmd = '0;
    mem_cmd_v_o = '0;
    mem_resp_yumi_o = '0;

    lce_cmd.header.src_id = cfg_bus_cast_i.cce_id;

    // up down counter
    cnt_inc = '0;
    cnt_dec = '0;
    cnt_rst = '0;

    uc_cnt_inc = '0;
    uc_cnt_dec = '0;
    uc_cnt_rst = '0;

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

    gad_v = '0;

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
      if (mem_resp.header.payload.speculative) begin

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
          lce_cmd.header.dst_id = mem_resp.header.payload.lce_id;

          // Data is copied directly from the Mem Data Response
          lce_cmd.header.msg_type = e_lce_cmd_data;
          lce_cmd.header.way_id = mem_resp.header.payload.way_id;
          lce_cmd.data = mem_resp.data;
          lce_cmd.header.addr = mem_resp.header.addr;
          // modify the coherence state
          lce_cmd.header.state = bp_coh_states_e'(spec_bits_lo.state);

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
          lce_cmd.header.dst_id = mem_resp.header.payload.lce_id;

          // Data is copied directly from the Mem Data Response
          lce_cmd.header.msg_type = e_lce_cmd_data;
          lce_cmd.header.way_id = mem_resp.header.payload.way_id;
          lce_cmd.data = mem_resp.data;
          lce_cmd.header.addr = mem_resp.header.addr;
          lce_cmd.header.state = mem_resp.header.payload.state;

          // decrement pending bit on mem response dequeue (same as lce cmd send)
          pending_busy = mem_resp_yumi_o;
          pending_w_v = mem_resp_yumi_o;
          pending_w_addr = mem_resp.header.addr;
          pending_li = 1'b0;

        end // forward unmodified

      end // speculative response

      // non-speculative memory access, forward directly to LCE
      else if ((mem_resp.header.msg_type == e_cce_mem_rd)
               | (mem_resp.header.msg_type == e_cce_mem_wr)) begin

        // handshaking
        lce_cmd_v_o = lce_cmd_ready_i & mem_resp_v_i;
        mem_resp_yumi_o = lce_cmd_ready_i & mem_resp_v_i;

        // inform ucode decode that this unit is using the LCE Command network
        lce_cmd_busy = lce_cmd_v_o;

        // Data is copied directly from the Mem Data Response
        lce_cmd.header.dst_id = mem_resp.header.payload.lce_id;
        lce_cmd.header.msg_type = e_lce_cmd_data;
        lce_cmd.header.way_id = mem_resp.header.payload.way_id;
        lce_cmd.data = mem_resp.data;
        lce_cmd.header.addr = mem_resp.header.addr;
        lce_cmd.header.state = mem_resp.header.payload.state;

        // decrement pending bit on mem response dequeue (same as lce cmd send)
        pending_busy = mem_resp_yumi_o;
        pending_w_v = mem_resp_yumi_o;
        pending_w_addr = mem_resp.header.addr;
        pending_li = 1'b0;

      end // rd, wr

      // Uncached load response - forward data to LCE
      // This transaction does not modify the pending bits
      else if (mem_resp.header.msg_type == e_cce_mem_uc_rd) begin

        // handshaking
        lce_cmd_v_o = lce_cmd_ready_i & mem_resp_v_i;
        mem_resp_yumi_o = lce_cmd_ready_i & mem_resp_v_i;

        // decrement count of outstanding uncached mode accesses if in uncached mode
        // or if waiting for responses during transition
        uc_cnt_dec = (~cce_normal_mode & mem_resp_yumi_o)
                     | ((uc_cnt > 0) & mem_resp_yumi_o);

        // block FSM from using LCE Command network
        lce_cmd_busy = lce_cmd_v_o;

        lce_cmd.header.dst_id = mem_resp.header.payload.lce_id;
        lce_cmd.header.msg_type = e_lce_cmd_uc_data;
        lce_cmd.header.way_id = '0;
        lce_cmd.data[0+:dword_width_p] = mem_resp.data[0+:dword_width_p];
        lce_cmd.header.addr = mem_resp.header.addr;

      end // uc_rd

      // Uncached store response, send UC Store Done to requesting LCE,
      // don't modify pending bits 
      else if (mem_resp.header.msg_type == e_cce_mem_uc_wr) begin

        // handshaking
        lce_cmd_v_o = lce_cmd_ready_i & mem_resp_v_i;
        mem_resp_yumi_o = lce_cmd_ready_i & mem_resp_v_i;

        // decrement count of outstanding uncached mode accesses if in uncached mode
        // or if waiting for responses during transition
        uc_cnt_dec = (~cce_normal_mode & mem_resp_yumi_o)
                     | ((uc_cnt > 0) & mem_resp_yumi_o);

        // block FSM from using LCE Command network
        lce_cmd_busy = lce_cmd_v_o;

        lce_cmd.header.dst_id = mem_resp.header.payload.lce_id;
        lce_cmd.header.msg_type = e_lce_cmd_uc_st_done;
        lce_cmd.header.way_id = '0;
        lce_cmd.header.addr = mem_resp.header.addr;

      end // uc_wr

      // Dequeue memory writeback response, don't do anything with it
      // decrement pending bit
      // also set pending_busy to block FSM if needed
      else if (mem_resp.header.msg_type == e_cce_mem_wb) begin

        mem_resp_yumi_o = mem_resp_v_i;
        pending_busy = mem_resp_yumi_o;
        pending_w_v = mem_resp_yumi_o;
        pending_w_addr = mem_resp.header.addr;
        pending_li = 1'b0;

      end // wb

    end // mem_resp handling

    // Dequeue coherence ack when it arrives
    // Does not conflict with other dequeues of LCE Response
    // Decrements pending bit on arrival, so arbitrate with memory ports for access
    if (lce_resp_v_i & (lce_resp.header.msg_type == e_lce_cce_coh_ack) & ~pending_busy) begin
        lce_resp_yumi_o = lce_resp_v_i;
        // inform FSM that pending bit is being used
        pending_busy = lce_resp_yumi_o;
        pending_w_v = lce_resp_yumi_o;
        pending_w_addr = lce_resp.header.addr;
        pending_li = 1'b0;
    end


    // FSM
    case (state_r)
      RESET: begin
        state_n = CLEAR_DIR;
        cnt_0_clr = 1'b1;
        cnt_1_clr = 1'b1;
        ack_cnt_clr = 1'b1;
      end
      CLEAR_DIR: begin
        dir_w_v = 1'b1;
        dir_cmd = e_clr_op;

        // increment through maximal number of tag sets (outer loop) and all LCE's (inner loop)
        // tag set number is cnt_0
        // LCE is cnt_1

        // bypass the address hashing in bp_cce_dir_segment, using dir_addr_li directly as the
        // tag set number for the operation
        dir_addr_bypass_li = 1'b1;
        dir_addr_li = {'0, cnt_0[0+:lg_max_tag_sets_lp]};
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

        // Stay in CLEAR_DIR until cnt_0_clr goes high
        // Next state depends on the CCE mode, as set by config bus
        state_n = cnt_0_clr
                  ? cce_normal_mode
                    ? SEND_SYNC
                    : UNCACHED_ONLY
                  : CLEAR_DIR;

      end // CLEAR_DIR
      UNCACHED_ONLY: begin

        // clear the MSHR
        mshr_n = '0;
        // clear the ack counter
        cnt_0_clr = 1'b1;
        cnt_1_clr = 1'b1;
        ack_cnt_clr = 1'b1;
        cnt_rst = 1'b1;

        state_n = UNCACHED_ONLY;

        if (cce_normal_mode) begin
          state_n = SEND_SYNC;
        // only issue uncached request if number of outstanding is less than max allowed
        // only process uncached requests
        // cached requests will stall on the input port
        end else if (lce_req_v_i
                     & ((lce_req.header.msg_type == e_lce_req_type_uc_wr)
                        | (lce_req.header.msg_type == e_lce_req_type_uc_rd))
                     & mem_cmd_ready_i & (uc_cnt < max_uc_req_lp)) begin

          // handshaking
          mem_cmd_v_o = lce_req_v_i & mem_cmd_ready_i;
          lce_req_yumi_o = lce_req_v_i & mem_cmd_ready_i;

          // increment count of uncached requests sent
          uc_cnt_inc = lce_req_v_i & mem_cmd_ready_i;

          // Uncached Store
          if (lce_req.header.msg_type == e_lce_req_type_uc_wr) begin
            mem_cmd.header.msg_type = e_cce_mem_uc_wr;
            mem_cmd.data = {{(cce_block_width_p-dword_width_p){1'b0}}, lce_req.data};
          // Uncached Load
          end else begin
            mem_cmd.header.msg_type = e_cce_mem_uc_rd;
          end

          mem_cmd.header.addr = lce_req.header.addr;
          mem_cmd.header.payload.lce_id = lce_req.header.src_id;
          mem_cmd.header.size =
            (bp_lce_cce_uc_req_size_e'(lce_req.header.uc_size) == e_lce_uc_req_1)
            ? e_mem_size_1
            : (bp_lce_cce_uc_req_size_e'(lce_req.header.uc_size) == e_lce_uc_req_2)
              ? e_mem_size_2
              : (bp_lce_cce_uc_req_size_e'(lce_req.header.uc_size) == e_lce_uc_req_4)
                ? e_mem_size_4
                : e_mem_size_8
            ;

        end // send uncached request
      end // UNCACHED_ONLY
      SEND_SYNC: begin
        // after first entering SEND_SYNC from UNCACHED_ONLY, wait for all oustanding uncached
        // accesses to complete before sending first sync commnad
        if ((uc_cnt == 0) & ~lce_cmd_busy) begin
          lce_cmd_v_o = lce_cmd_ready_i;

          // LCE Cmd Common Fields
          lce_cmd.header.dst_id = {'0, cnt_1[0+:lg_num_lce_lp]};
          lce_cmd.header.msg_type = e_lce_cmd_sync;

          state_n = (lce_cmd_ready_i) ? SYNC_ACK : SEND_SYNC;
          cnt_1_inc = lce_cmd_ready_i;
        end
      end
      SYNC_ACK: begin
        if (~lce_resp_coh_ack_yumi) begin
          lce_resp_yumi_o = lce_resp_v_i;
          state_n = (lce_resp_v_i)
                    ? (ack_cnt == num_lce_p-1)
                      ? READY
                      : SEND_SYNC
                    : SYNC_ACK;
          state_n = (lce_resp_v_i & (lce_resp.header.msg_type != e_lce_cce_sync_ack))
                    ? ERROR
                    : state_n;
          ack_cnt_clr = (state_n == READY);
          ack_cnt_inc = lce_resp_v_i & ~ack_cnt_clr;
          cnt_1_clr = (state_n == READY);
        end
      end
      READY: begin
        // clear the MSHR
        mshr_n = '0;
        // clear the ack counter
        cnt_0_clr = 1'b1;
        cnt_1_clr = 1'b1;
        ack_cnt_clr = 1'b1;
        cnt_rst = 1'b1;

        if (lce_req_v_i) begin
          mshr_n.lce_id = lce_req.header.src_id;
          state_n = ERROR;
          // cached request
          if (lce_req.header.msg_type == e_lce_req_type_rd
              | lce_req.header.msg_type == e_lce_req_type_wr) begin

            mshr_n.paddr = lce_req.header.addr;
            mshr_n.lru_way_id = lce_req.header.lru_way_id;
            mshr_n.flags[e_opd_ldf] = lce_req.header.lru_dirty;
            mshr_n.flags[e_opd_rqf] = (lce_req.header.msg_type == e_lce_req_type_wr);
            mshr_n.flags[e_opd_nerf] = lce_req.header.non_exclusive;

            state_n = READ_PENDING;

          // uncached request
          // request will be dequeued in the next state
          end else if (lce_req.header.msg_type == e_lce_req_type_uc_rd
                       | lce_req.header.msg_type == e_lce_req_type_uc_wr) begin

            mshr_n.paddr = lce_req.header.addr;
            mshr_n.uc_req_size = lce_req.header.uc_size;
            mshr_n.flags[e_opd_ucf] = 1'b1;
            mshr_n.flags[e_opd_rqf] = (lce_req.header.msg_type == e_lce_req_type_uc_wr);

            state_n = UC_REQ;
          end
        end
      end // READY
      UC_REQ: begin
        // send uncached request to memory
        if (lce_req_v_i & mem_cmd_ready_i) begin
          mem_cmd_v_o = mem_cmd_ready_i;

          // Uncached Store
          if (mshr_r.flags[e_opd_rqf]) begin
            mem_cmd.header.msg_type = e_cce_mem_uc_wr;
            mem_cmd.data = {{(cce_block_width_p-dword_width_p){1'b0}}, lce_req.data};
          // Uncached Load
          end else begin
            mem_cmd.header.msg_type = e_cce_mem_uc_rd;
          end

          mem_cmd.header.addr = mshr_r.paddr;
          mem_cmd.header.payload.lce_id = mshr_r.lce_id;
          mem_cmd.header.size =
            (bp_lce_cce_uc_req_size_e'(mshr_r.uc_req_size) == e_lce_uc_req_1)
            ? e_mem_size_1
            : (bp_lce_cce_uc_req_size_e'(mshr_r.uc_req_size) == e_lce_uc_req_2)
              ? e_mem_size_2
              : (bp_lce_cce_uc_req_size_e'(mshr_r.uc_req_size) == e_lce_uc_req_4)
                ? e_mem_size_4
                : e_mem_size_8
            ;

          lce_req_yumi_o = lce_req_v_i & mem_cmd_ready_i;

          // go back to ready state since this state is only entered when CCE is in normal mode
          state_n = READY;
        end // mem_cmd_ready

      end // UC_REQ
      READ_PENDING: begin
        pending_r_v = 1'b1;
        state_n = (pending_lo)
                  ? READ_PENDING
                  : DEQ_LCE_REQ;
      end
      DEQ_LCE_REQ: begin
        // dequeueing the request writes the pending bit and must arbitrate with logic above
        if (lce_req_v_i & ~pending_busy) begin
          state_n = READ_MEM_SPEC;
          lce_req_yumi_o = lce_req_v_i;

          pending_w_v = lce_req_yumi_o;
          pending_w_addr = lce_req.header.addr;
          pending_li = 1'b1;

        end else begin
          // pending bit write port is busy, stay in READY state and try to consume request
          // next cycle
          state_n = DEQ_LCE_REQ;
        end
      end
      READ_MEM_SPEC: begin
        // Mem Cmd needs to write pending bit, so only send if Mem Resp / LCE Cmd is not
        // writing the pending bit
        if (~pending_busy) begin
          mem_cmd_v_o = mem_cmd_ready_i;
          mem_cmd.header.msg_type = (mshr_r.flags[e_opd_rqf]) ? e_cce_mem_wr : e_cce_mem_rd;
          mem_cmd.header.addr = (mshr_r.paddr >> lg_block_size_in_bytes_lp) << lg_block_size_in_bytes_lp;
          mem_cmd.header.size = e_mem_size_64;
          mem_cmd.header.payload.lce_id = mshr_r.lce_id;
          mem_cmd.header.payload.way_id = mshr_r.lru_way_id;
          // speculatively issue request for E state
          mem_cmd.header.payload.state = e_COH_E;
          mem_cmd.header.payload.speculative = 1'b1;

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

          state_n = (mem_cmd_v_o) ? READ_DIR : READ_MEM_SPEC;

          pending_w_v = mem_cmd_v_o;
          pending_li = 1'b1;
          pending_w_addr = mshr_r.paddr;
        end

      end
      READ_DIR: begin
        // initiate the directory read
        // At the earliest, data will be valid in the next cycle
        dir_r_v = 1'b1;
        dir_addr_li = mshr_r.paddr;
        dir_cmd = e_rdw_op;
        dir_lce_li = mshr_r.lce_id;
        dir_lru_way_li = mshr_r.lru_way_id;
        state_n = WAIT_DIR_GAD;
      end
      WAIT_DIR_GAD: begin

        // capture LRU outputs when they appear
        if (dir_lru_v_lo) begin
          mshr_n.lru_paddr = dir_lru_addr_lo;
          mshr_n.lru_coh_state = dir_lru_coh_state_lo;
          mshr_n.flags[e_opd_lef] = dir_lru_cached_excl_lo;
        end

        if (sharers_v_lo) begin
          sharers_ways_n = sharers_ways_lo;
          sharers_hits_n = sharers_hits_lo;
        end

        gad_v = sharers_v_lo & ~dir_busy_lo;
        if (gad_v) begin

          mshr_n.way_id = gad_req_addr_way_lo;

          mshr_n.flags[e_opd_rf] = gad_replacement_flag_lo;
          mshr_n.flags[e_opd_uf] = gad_upgrade_flag_lo;
          mshr_n.flags[e_opd_if] = gad_invalidate_flag_lo;
          mshr_n.flags[e_opd_cf] = gad_cached_flag_lo;
          mshr_n.flags[e_opd_cef] = gad_cached_exclusive_flag_lo;
          mshr_n.flags[e_opd_cof] = gad_cached_owned_flag_lo;
          mshr_n.flags[e_opd_cdf] = gad_cached_dirty_flag_lo;
          mshr_n.flags[e_opd_csf] = gad_cached_shared_flag_lo;

          mshr_n.owner_lce_id = gad_owner_lce_lo;
          mshr_n.owner_way_id = gad_owner_lce_way_lo;

          mshr_n.next_coh_state =
            (mshr_r.flags[e_opd_rqf])
            ? e_COH_M
            : (mshr_r.flags[e_opd_nerf])
              ? e_COH_S
              : (gad_cached_flag_lo)
                ? e_COH_S
                : e_COH_E;

          state_n = WRITE_NEXT_STATE;
        end

      end
      WRITE_NEXT_STATE: begin
        // writing to the directory will make the sharers_v_lo signal go low, but in this FSM
        // CCE we know that the sharers vectors are still valid in the state we need from the
        // previous read, so we perform the coherence state update for the requesting LCE anyway

        dir_w_v = 1'b1;
        dir_lce_li = mshr_r.lce_id;
        dir_addr_li = mshr_r.paddr;
        dir_coh_state_li = mshr_r.next_coh_state;
        if (mshr_r.flags[e_opd_uf]) begin
          dir_cmd = e_wds_op;
          dir_way_li = mshr_r.way_id;
        end else begin
          dir_cmd = e_wde_op;
          dir_way_li = mshr_r.lru_way_id;
        end

        // TODO: for performance, move replacement before invalidation
        state_n =
          (mshr_r.flags[e_opd_if])
          ? INV_CMD
          : (mshr_r.flags[e_opd_uf])
            ? UPGRADE_STW_CMD
            : (mshr_r.flags[e_opd_rf])
              ? REPLACEMENT
              : (mshr_r.flags[e_opd_cof])
                ? TRANSFER_ST_CMD
                : RESOLVE_SPECULATION;

        // setup required state for sending invalidations
        if (mshr_r.flags[e_opd_if]) begin
          // don't invalidate the requesting LCE
          pe_sharers_n = sharers_hits_r & ~req_lce_id_one_hot;
          // if doing a transfer, also remove owner LCE since transfer
          // routine will take care of setting owner into correct new state
          pe_sharers_n = mshr_r.flags[e_opd_cof]
                         ? pe_sharers_n & ~owner_lce_id_one_hot
                         : pe_sharers_n;
          sharers_ways_n = sharers_ways_r;
          cnt_rst = 1'b1;
        end

      end
      INV_CMD: begin

        // only send invalidation if priority encode has valid output
        // this indicates the sharers vector has a valid bit set
        if (pe_v) begin

          // try to send additional commands, but give priority to mem_resp auto-forward
          if (~lce_cmd_busy & lce_cmd_ready_i) begin

            lce_cmd_v_o = lce_cmd_ready_i;
            lce_cmd.header.msg_type = e_lce_cmd_invalidate_tag;

            // destination and way come from sharers information
            lce_cmd.header.dst_id = pe_lce_id;
            lce_cmd.header.way_id = sharers_ways_r[pe_lce_id];

            lce_cmd.header.addr = mshr_r.paddr;

            // message sent, increment count, write directory, clear bit for the destination LCE
            cnt_inc = lce_cmd_v_o;
            dir_w_v = lce_cmd_v_o;
            dir_cmd = e_wds_op;
            dir_addr_li = mshr_r.paddr;
            dir_lce_li = {'0, pe_lce_id};
            dir_way_li = sharers_ways_r[pe_lce_id];
            dir_coh_state_li = e_COH_I;

            // update sharers hit vector to feed back to priority encode module
            pe_sharers_n = pe_sharers_r & ~pe_lce_id_one_hot;

            // move to response state if none of the sharer bits are set, indicating
            // that the last command is sending this cycle
            if (pe_sharers_n == '0) begin
              state_n = INV_ACK;
            end

          end else begin
            // could not send message, don't clear bit for first sharer
            pe_sharers_n = pe_sharers_r;
          end

        end // pe_v

        // dequeue responses as they arrive
        if (lce_resp_v_i & (lce_resp.header.msg_type == e_lce_cce_inv_ack)) begin
          lce_resp_yumi_o = lce_resp_v_i;
          cnt_dec = lce_resp_yumi_o;
        end
      end
      INV_ACK: begin
        if (cnt == '0) begin
          state_n = (mshr_r.flags[e_opd_uf])
                    ? UPGRADE_STW_CMD
                    : (mshr_r.flags[e_opd_rf])
                      ? REPLACEMENT
                      : (mshr_r.flags[e_opd_cof])
                        ? TRANSFER_ST_CMD
                        : RESOLVE_SPECULATION;
        end else begin
          // dequeue responses as they arrive
          if (lce_resp_v_i & (lce_resp.header.msg_type == e_lce_cce_inv_ack)) begin
            lce_resp_yumi_o = lce_resp_v_i;
            cnt_dec = lce_resp_yumi_o;
            if (cnt == 'd1) begin
              state_n = (mshr_r.flags[e_opd_uf])
                        ? UPGRADE_STW_CMD
                        : (mshr_r.flags[e_opd_rf])
                          ? REPLACEMENT
                          : (mshr_r.flags[e_opd_cof])
                            ? TRANSFER_ST_CMD
                            : RESOLVE_SPECULATION;
            end // cnt == 'd1
          end // inv ack
        end // else
      end
      REPLACEMENT: begin
        // Send replacement writeback command if LCE Cmd port is free, else try again next cycle
        if (~lce_cmd_busy & lce_cmd_ready_i) begin
          lce_cmd_v_o = lce_cmd_ready_i;

          // LCE Cmd Common Fields
          lce_cmd.header.dst_id = mshr_r.lce_id;
          lce_cmd.header.msg_type = e_lce_cmd_writeback;
          lce_cmd.header.way_id = mshr_r.lru_way_id;

          // Sub message fields
          lce_cmd.header.addr = mshr_r.lru_paddr;

          state_n = (lce_cmd_ready_i) ? REPLACEMENT_WB_RESP : REPLACEMENT;
        end
      end
      REPLACEMENT_WB_RESP: begin
        if (lce_resp_v_i) begin
          if (lce_resp.header.msg_type == e_lce_cce_resp_null_wb) begin
            lce_resp_yumi_o = lce_resp_v_i;
            state_n = (mshr_r.flags[e_opd_cof])
                      ? TRANSFER_ST_CMD
                      : RESOLVE_SPECULATION;
            // clear the replacement flag
            mshr_n.flags[e_opd_rf] = 1'b0;
            // set null writeback flag
            mshr_n.flags[e_opd_nwbf] = 1'b1;

          end
          else if ((lce_resp.header.msg_type == e_lce_cce_resp_wb) & ~pending_busy) begin
            // Mem Data Cmd needs to write pending bit, so only send if Mem Data Resp / LCE Data Cmd is
            // not writing the pending bit
            mem_cmd_v_o = lce_resp_v_i & mem_cmd_ready_i;
            lce_resp_yumi_o = lce_resp_v_i & mem_cmd_ready_i;

            mem_cmd.header.msg_type = e_cce_mem_wb;
            mem_cmd.header.addr = (lce_resp.header.addr >> lg_block_size_in_bytes_lp) << lg_block_size_in_bytes_lp;
            mem_cmd.header.payload.lce_id = mshr_r.lce_id;
            mem_cmd.header.payload.way_id = '0;
            mem_cmd.data = lce_resp.data;
            mem_cmd.header.size = e_mem_size_64;

            state_n = (lce_resp_yumi_o)
                      ? (mshr_r.flags[e_opd_cof])
                        ? TRANSFER_ST_CMD
                        : RESOLVE_SPECULATION
                      : REPLACEMENT_WB_RESP;

            // set the pending bit
            pending_w_v = lce_resp_yumi_o;
            pending_li = 1'b1;
            pending_w_addr = lce_resp.header.addr;

            // clear the replacement flag
            mshr_n.flags[e_opd_rf] = 1'b0;
            // clear null writeback flag
            mshr_n.flags[e_opd_nwbf] = 1'b0;

          end // wb & pending bit available
        end // lce_resp_v_i
      end
      TRANSFER_ST_CMD: begin
        if (~lce_cmd_busy & lce_cmd_ready_i) begin
          lce_cmd_v_o = lce_cmd_ready_i;

          // LCE Cmd Common Fields
          lce_cmd.header.dst_id = mshr_r.owner_lce_id;
          lce_cmd.header.msg_type = e_lce_cmd_set_tag;
          lce_cmd.header.way_id = mshr_r.owner_way_id;

          // Sub message fields
          lce_cmd.header.addr = mshr_r.paddr;
          // either Invalidate or Downgrade Owner
          lce_cmd.header.state = mshr_r.flags[e_opd_rqf] ? e_COH_I : e_COH_S;

          // update state of owner in directory
          dir_w_v = lce_cmd_v_o;
          dir_cmd = e_wds_op;
          dir_addr_li = mshr_r.paddr;
          dir_lce_li = mshr_r.owner_lce_id;
          dir_way_li = mshr_r.owner_way_id;
          dir_coh_state_li = mshr_r.flags[e_opd_rqf] ? e_COH_I : e_COH_S;

          state_n = (lce_cmd_ready_i) ? TRANSFER_CMD : TRANSFER_ST_CMD;
        end
      end
      TRANSFER_CMD: begin
        if (~lce_cmd_busy & lce_cmd_ready_i) begin
          lce_cmd_v_o = lce_cmd_ready_i;

          // LCE Cmd Common Fields
          lce_cmd.header.dst_id = mshr_r.owner_lce_id;
          lce_cmd.header.msg_type = e_lce_cmd_transfer;
          lce_cmd.header.way_id = mshr_r.owner_way_id;

          // Sub message fields
          lce_cmd.header.addr = mshr_r.paddr;
          lce_cmd.header.target = mshr_r.lce_id;
          lce_cmd.header.target_way_id = mshr_r.lru_way_id;
          lce_cmd.header.state = mshr_r.next_coh_state;

          state_n = (lce_cmd_ready_i) ? TRANSFER_WB_CMD : TRANSFER_CMD;
        end
      end
      TRANSFER_WB_CMD: begin
        if (~lce_cmd_busy & lce_cmd_ready_i) begin
          lce_cmd_v_o = lce_cmd_ready_i;

          // LCE Cmd Common Fields
          lce_cmd.header.dst_id = mshr_r.owner_lce_id;
          lce_cmd.header.msg_type = e_lce_cmd_writeback;
          lce_cmd.header.way_id = mshr_r.owner_way_id;

          // Sub message fields
          lce_cmd.header.addr = mshr_r.paddr;

          state_n = (lce_cmd_ready_i) ? TRANSFER_WB_RESP : TRANSFER_WB_CMD;
        end
      end
      TRANSFER_WB_RESP: begin
        if (lce_resp_v_i) begin
          if (lce_resp.header.msg_type == e_lce_cce_resp_null_wb) begin
            lce_resp_yumi_o = lce_resp_v_i;
            state_n = RESOLVE_SPECULATION;

          end
          else if ((lce_resp.header.msg_type == e_lce_cce_resp_wb) & ~pending_busy) begin
            // Mem Data Cmd needs to write pending bit, so only send if Mem Data Resp / LCE Data Cmd is
            // not writing the pending bit
            mem_cmd_v_o = lce_resp_v_i & mem_cmd_ready_i;
            lce_resp_yumi_o = lce_resp_v_i & mem_cmd_ready_i;

            mem_cmd.header.msg_type = e_cce_mem_wb;
            mem_cmd.header.addr = (lce_resp.header.addr >> lg_block_size_in_bytes_lp) << lg_block_size_in_bytes_lp;
            mem_cmd.header.payload.lce_id = mshr_r.lce_id;
            mem_cmd.header.payload.way_id = '0;
            mem_cmd.data = lce_resp.data;
            mem_cmd.header.size = e_mem_size_64;

            state_n = (lce_resp_yumi_o) ? RESOLVE_SPECULATION : TRANSFER_WB_RESP;

            // set the pending bit
            pending_w_v = lce_resp_yumi_o;
            pending_li = 1'b1;
            pending_w_addr = lce_resp.header.addr;

          end
        end
      end
      UPGRADE_STW_CMD: begin
        if (~lce_cmd_busy & lce_cmd_ready_i) begin
          lce_cmd_v_o = lce_cmd_ready_i;

          // LCE Cmd Common Fields
          lce_cmd.header.dst_id = mshr_r.lce_id;
          lce_cmd.header.msg_type = e_lce_cmd_set_tag_wakeup;
          lce_cmd.header.way_id = mshr_r.way_id;

          // Sub message fields
          lce_cmd.header.addr = mshr_r.paddr;
          lce_cmd.header.state = mshr_r.next_coh_state;

          state_n = (lce_cmd_ready_i) ? RESOLVE_SPECULATION : UPGRADE_STW_CMD;
        end
      end
      RESOLVE_SPECULATION: begin
        // Resolve speculation
        if (mshr_r.flags[e_opd_cof] | mshr_r.flags[e_opd_uf]) begin
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
        end else if (mshr_r.flags[e_opd_cf] | mshr_r.flags[e_opd_nerf]) begin
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
        state_n = READY;
      end
      ERROR: begin
        $display("oh no - error!");
        $finish(0);
      end
      default: begin
        // use defaults above
      end
    endcase
  end // always_comb

  // Sequential Logic
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      state_r <= RESET;
      mshr_r <= '0;
      sharers_ways_r <= '0;
      sharers_hits_r <= '0;
      pe_sharers_r <= '0;
    end else begin
      state_r <= state_n;
      mshr_r <= mshr_n;
      sharers_ways_r <= sharers_ways_n;
      sharers_hits_r <= sharers_hits_n;
      pe_sharers_r <= pe_sharers_n;
    end
  end

endmodule
