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
  import bp_cfg_link_pkg::*;
  #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
    `declare_bp_proc_params(cfg_p)

    , parameter cce_trace_p             = 0

    // Derived parameters
    , localparam block_size_in_bytes_lp    = (cce_block_width_p/8)
    , localparam lg_num_lce_lp             = `BSG_SAFE_CLOG2(num_lce_p)
    , localparam lg_num_cce_lp             = `BSG_SAFE_CLOG2(num_cce_p)
    , localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp)
    , localparam lg_lce_assoc_lp           = `BSG_SAFE_CLOG2(lce_assoc_p)
    , localparam lg_lce_sets_lp            = `BSG_SAFE_CLOG2(lce_sets_p)
    , localparam ptag_width_lp              = (paddr_width_p-lg_lce_sets_lp
                                              -lg_block_size_in_bytes_lp)
    , localparam entry_width_lp            = (ptag_width_lp+`bp_cce_coh_bits)
    , localparam tag_set_width_lp          = (entry_width_lp*lce_assoc_p)
    , localparam way_group_width_lp        = (tag_set_width_lp*num_lce_p)
    , localparam way_group_offset_high_lp  = (lg_block_size_in_bytes_lp+lg_lce_sets_lp)
    , localparam num_way_groups_lp         = (lce_sets_p/num_cce_p)
    , localparam lg_num_way_groups_lp      = `BSG_SAFE_CLOG2(num_way_groups_lp)
    , localparam inst_ram_addr_width_lp    = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)
    , localparam mshr_width_lp = `bp_cce_mshr_width(num_lce_p, lce_assoc_p, paddr_width_p)

    // interface widths
    `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
    `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, mshr_width_lp)

    , localparam counter_max = 256
  )
  (input                                               clk_i
   , input                                             reset_i
   , input                                             freeze_i

   // Config channel
   , input                                             cfg_w_v_i
   , input [cfg_addr_width_p-1:0]                      cfg_addr_i
   , input [cfg_data_width_p-1:0]                      cfg_data_i

   // LCE-CCE Interface
   // inbound: valid->ready (a.k.a., valid->yumi), demanding consumer (connects to FIFO)
   // outbound: ready&valid (connects directly to ME network)
   , input [lce_cce_req_width_lp-1:0]                  lce_req_i
   , input                                             lce_req_v_i
   , output logic                                      lce_req_yumi_o

   , input [lce_cce_resp_width_lp-1:0]                 lce_resp_i
   , input                                             lce_resp_v_i
   , output logic                                      lce_resp_yumi_o

   , input [lce_cce_data_resp_width_lp-1:0]            lce_data_resp_i
   , input                                             lce_data_resp_v_i
   , output logic                                      lce_data_resp_yumi_o

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

   , input [lg_num_cce_lp-1:0]                         cce_id_i
  );

  //synopsys translate_off
  initial begin
    assert (lce_sets_p > 1) else $error("Number of LCE sets must be greater than 1");
    assert (num_cce_p >= 1 && `BSG_IS_POW2(num_cce_p))
      else $error("Number of CCE must be power of two");
  end
  //synopsys translate_on

  // Define structure variables for output queues

  `declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, mshr_width_lp);
  `declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p);

  bp_lce_cce_req_s lce_req;
  bp_lce_cce_resp_s lce_resp;
  bp_lce_cce_data_resp_s lce_data_resp;
  bp_cce_lce_cmd_s lce_cmd;
  bp_lce_data_cmd_s lce_data_cmd;

  bp_mem_cce_resp_s mem_resp;
  bp_mem_cce_data_resp_s mem_data_resp;
  bp_cce_mem_cmd_s mem_cmd;
  bp_cce_mem_data_cmd_s mem_data_cmd;

  // assign output queue ports to structure variables
  assign lce_cmd_o = lce_cmd;
  assign lce_data_cmd_o = lce_data_cmd;
  assign mem_cmd_o = mem_cmd;
  assign mem_data_cmd_o = mem_data_cmd;

  // cast input messages with data
  assign lce_data_resp = lce_data_resp_i;
  assign mem_resp = mem_resp_i;
  assign mem_data_resp = mem_data_resp_i;
  assign lce_resp = lce_resp_i;
  assign lce_req = lce_req_i;

  // CCE Mode
  bp_cce_mode_e cce_mode_r, cce_mode_n;
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      cce_mode_r <= e_cce_mode_uncached;
    end else begin
      cce_mode_r <= cce_mode_n;
    end
  end

  wire cfg_cce_mode_addr_v = (cfg_addr_i == bp_cfg_reg_cce_mode_gp);
  always_comb begin
    cce_mode_n = cce_mode_r;
    if (cfg_w_v_i & cfg_cce_mode_addr_v) begin
      cce_mode_n = bp_cce_mode_e'(cfg_data_i[0+:`bp_cce_mode_bits]);
    end
  end


  // CCE FSM
  // The FSM handles LCE Requests, Responses, Data Responses, Mem Responses
  // Mem Data Responses are automatically forwarded as LCE Data Commands

  // MSHR
  `declare_bp_cce_mshr_s(num_lce_p, lce_assoc_p, paddr_width_p);
  bp_cce_mshr_s mshr_r, mshr_n, mem_resp_mshr;
  assign mem_resp_mshr = mem_resp.payload;

  // uncached data register
  // filled by LCE Request
  logic [dword_width_p-1:0] uc_data_r, uc_data_n;

  // Pending Bits
  logic pending_li, pending_lo;
  logic pending_v_lo, pending_w_v, pending_r_v;
  logic [lg_num_way_groups_lp-1:0] pending_w_way_group, pending_r_way_group;
  // The read way group always comes from the MSHR
  assign pending_r_way_group = mshr_r.paddr[(way_group_offset_high_lp-1) -: lg_num_way_groups_lp];

  bp_cce_pending
    #(.num_way_groups_p(num_way_groups_lp)
     )
    pending_bits
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.w_v_i(pending_w_v)
      ,.w_way_group_i(pending_w_way_group)
      ,.pending_i(pending_li)
      ,.r_v_i(pending_r_v)
      ,.r_way_group_i(pending_r_way_group)
      ,.pending_o(pending_lo)
      ,.pending_v_o(pending_v_lo)
      );

  // Directory signals
  logic dir_r_v, dir_w_v, dir_wg_clr;
  bp_cce_inst_minor_read_dir_op_e dir_r_cmd;
  bp_cce_inst_minor_write_dir_op_e dir_w_cmd;
  logic sharers_v_lo;
  logic [num_lce_p-1:0] sharers_hits_lo;
  logic [num_lce_p-1:0][lg_lce_assoc_lp-1:0] sharers_ways_lo;
  logic [num_lce_p-1:0][`bp_cce_coh_bits-1:0] sharers_coh_states_lo;
  logic dir_lru_v_lo;
  logic dir_lru_cached_excl_lo;
  logic [ptag_width_lp-1:0] dir_lru_tag_lo;
  logic dir_busy_lo;

  logic [lg_num_way_groups_lp-1:0] dir_way_group_li;
  logic [lg_num_lce_lp-1:0] dir_lce_li;
  logic [lg_lce_assoc_lp-1:0] dir_way_li;
  logic [ptag_width_lp-1:0] dir_tag_li;
  logic [`bp_cce_coh_bits-1:0] dir_coh_state_li;

  // GAD signals
  logic gad_v;

  logic [lg_lce_assoc_lp-1:0] gad_req_addr_way_lo;
  logic [lg_num_lce_lp-1:0] gad_transfer_lce_lo;
  logic [lg_lce_assoc_lp-1:0] gad_transfer_lce_way_lo;
  logic gad_transfer_flag_lo;
  logic gad_replacement_flag_lo;
  logic gad_upgrade_flag_lo;
  logic gad_invalidate_flag_lo;
  logic gad_exclusive_flag_lo;
  logic gad_cached_flag_lo;
  logic gad_error_lo;

  // Directory
  bp_cce_fsm_dir
    #(.num_way_groups_p(num_way_groups_lp)
      ,.num_lce_p(num_lce_p)
      ,.num_cce_p(num_cce_p)
      ,.lce_assoc_p(lce_assoc_p)
      ,.tag_width_p(ptag_width_lp)
      )
    directory
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.way_group_i(dir_way_group_li)
      ,.lce_i(dir_lce_li)
      ,.way_i(dir_way_li)
      ,.lru_way_i(mshr_r.lru_way_id)

      ,.r_cmd_i(dir_r_cmd)
      ,.r_v_i(dir_r_v)

      ,.tag_i(dir_tag_li)
      ,.coh_state_i(dir_coh_state_li)

      ,.w_cmd_i(dir_w_cmd)
      ,.w_v_i(dir_w_v)
      ,.w_clr_wg_i(dir_wg_clr)

      ,.sharers_v_o(sharers_v_lo)
      ,.sharers_hits_o(sharers_hits_lo)
      ,.sharers_ways_o(sharers_ways_lo)
      ,.sharers_coh_states_o(sharers_coh_states_lo)

      ,.lru_v_o(dir_lru_v_lo)
      ,.lru_cached_excl_o(dir_lru_cached_excl_lo)
      ,.lru_tag_o(dir_lru_tag_lo)

      ,.busy_o(dir_busy_lo)

      );

  // GAD logic - auxiliary directory information logic
  bp_cce_gad
    #(.num_lce_p(num_lce_p)
      ,.lce_assoc_p(lce_assoc_p)
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
      ,.req_type_flag_i(mshr_r.flags[e_flag_sel_rqf])
      ,.lru_dirty_flag_i(mshr_r.flags[e_flag_sel_ldf])
      ,.lru_cached_excl_flag_i(mshr_r.flags[e_flag_sel_lef])

      ,.req_addr_way_o(gad_req_addr_way_lo)

      ,.transfer_flag_o(gad_transfer_flag_lo)
      ,.transfer_lce_o(gad_transfer_lce_lo)
      ,.transfer_way_o(gad_transfer_lce_way_lo)
      ,.replacement_flag_o(gad_replacement_flag_lo)
      ,.upgrade_flag_o(gad_upgrade_flag_lo)
      ,.invalidate_flag_o(gad_invalidate_flag_lo)
      ,.exclusive_flag_o(gad_exclusive_flag_lo)
      ,.cached_flag_o(gad_cached_flag_lo)

      ,.error_o(gad_error_lo)
      );


  typedef enum logic [5:0] {
    RESET
    , CLEAR_DIR
    , SEND_SET_CLEAR
    , SEND_SYNC
    , SYNC_ACK
    , READY

    , LCE_REQ
    , READ_PENDING
    , CHECK_PENDING
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

    , READ_MEM
    , SEND_SET_TAG

    , UC_REQ

    , ERROR
  } state_e;

  state_e state_r, state_n;

  // Counter for set clear operation
  logic sc_cnt_clr, sc_cnt_inc;
  logic [`BSG_SAFE_CLOG2(num_way_groups_lp+1)-1:0] sc_cnt;
  bsg_counter_clear_up
    #(.max_val_p(num_way_groups_lp)
      ,.init_val_p(0)
     )
    sc_counter
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.clear_i(sc_cnt_clr)
      ,.up_i(sc_cnt_inc)
      ,.count_o(sc_cnt)
      );

  // General use counter
  logic cnt_clr, cnt_inc;
  logic [`BSG_SAFE_CLOG2(counter_max+1)-1:0] cnt;
  bsg_counter_clear_up
    #(.max_val_p(counter_max)
      ,.init_val_p(0)
     )
    counter
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.clear_i(cnt_clr)
      ,.up_i(cnt_inc)
      ,.count_o(cnt)
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

  logic [paddr_width_p-1:0] set_clear_addr;

  localparam set_shift_lp = (num_cce_p == 1) ? 0 : lg_num_cce_lp;

  logic sync_ack_yumi, inv_ack_yumi, coh_ack_yumi;
  assign lce_resp_yumi_o = sync_ack_yumi | inv_ack_yumi | coh_ack_yumi;

  // Transfer and Coherence Acks are dequeued automatically unless state machine is in INV_ACK
  assign coh_ack_yumi = lce_resp_v_i
    & ((lce_resp.msg_type == e_lce_cce_coh_ack) | (lce_resp.msg_type == e_lce_cce_tr_ack));

  always_comb begin
    state_n = state_r;
    mshr_n = mshr_r;
    uc_data_n = uc_data_r;

    lce_req_yumi_o = '0;
    lce_data_resp_yumi_o = '0;
    lce_cmd = '0;
    lce_cmd.src_id = cce_id_i;
    lce_cmd_v_o = '0;
    mem_cmd = '0;
    mem_cmd_v_o = '0;
    mem_data_cmd = '0;
    mem_data_cmd_v_o = '0;
    mem_resp_yumi_o = '0;

    cnt_clr = '0;
    cnt_inc = '0;
    sc_cnt_clr = '0;
    sc_cnt_inc = '0;
    ack_cnt_clr = '0;
    ack_cnt_inc = '0;

    sync_ack_yumi = '0;
    inv_ack_yumi = '0;

    pending_li = '0;
    pending_r_v = '0;
    pending_w_v = '0;
    //pending_r_way_group = '0; - set directly from MSHR
    pending_w_way_group = '0;

    gad_v = '0;

    dir_r_v = '0;
    dir_w_v = '0;
    dir_wg_clr = '0;
    dir_r_cmd = e_rdw_op;
    dir_w_cmd = e_wde_op;
    dir_way_group_li = mshr_r.paddr[(way_group_offset_high_lp-1) -: lg_num_way_groups_lp];
    dir_lce_li = mshr_r.lce_id;
    dir_way_li = mshr_r.way_id;
    dir_tag_li = mshr_r.paddr[(paddr_width_p-1) -: ptag_width_lp];
    dir_coh_state_li = mshr_r.next_coh_state;

    case (state_r)
      RESET: begin
        state_n = (reset_i | freeze_i) ? RESET : CLEAR_DIR;
        sc_cnt_clr = 1'b1;
        cnt_clr = 1'b1;
        ack_cnt_clr = 1'b1;
      end
      CLEAR_DIR: begin
        dir_w_v = 1'b1;
        dir_wg_clr = 1'b1;

        // increment through all way-groups (outer loop) and all LCE's (inner loop)
        dir_way_group_li = sc_cnt[0+:lg_num_way_groups_lp];
        dir_lce_li = cnt[0+:lg_num_lce_lp];

        // clear the LCE counter back to 0 after reaching max LCE ID
        cnt_clr = (cnt == (num_lce_p-1));
        // increment the LCE counter if not clearing
        cnt_inc = ~cnt_clr;

        state_n = ((sc_cnt == num_way_groups_lp-1) & (cnt == num_lce_p-1))
                  ? SEND_SET_CLEAR
                  : CLEAR_DIR;

        // clear way group counter when moving to the next state
        sc_cnt_clr = (state_n == SEND_SET_CLEAR);
        // increment the way group counter whenever the LCE counter resets to 0, except when it
        // is being cleared
        sc_cnt_inc = cnt_clr & ~sc_cnt_clr;

        // override next state if in uncached mode
        state_n = ((state_n == SEND_SET_CLEAR) & (cce_mode_r == e_cce_mode_uncached))
                  ? READY
                  : state_n;
      end
      SEND_SET_CLEAR: begin
        // output a valid set clear command
        lce_cmd_v_o = 1'b1;
        lce_cmd.dst_id = cnt[0+:lg_num_lce_lp];
        lce_cmd.msg_type = e_lce_cmd_set_clear;
        // sc_cnt holds the current way-group being targeted by the set clear command, which
        // needs to be translated into an LCE relative set index
        lce_cmd.addr = ((paddr_width_p'(sc_cnt) << set_shift_lp) + paddr_width_p'(cce_id_i))
                       << lg_block_size_in_bytes_lp;

        // reset set counter to 0 if command is accepted and current count is max
        sc_cnt_clr = lce_cmd_ready_i & (sc_cnt == (num_way_groups_lp-1));
        // increment set counter when not clearing it and command is accepted
        sc_cnt_inc = lce_cmd_ready_i & ~sc_cnt_clr;

        // send syncs once last command is accepted
        state_n = (lce_cmd_ready_i & (sc_cnt == num_way_groups_lp-1) & (cnt == num_lce_p-1))
                  ? SEND_SYNC
                  : SEND_SET_CLEAR;

        // clear the counters if moving to sending sync commands
        cnt_clr = (state_n == SEND_SYNC);

        // only increment the LCE counter if it isn't being cleared
        // this avoids a clear then increment in the same cycle
        cnt_inc = sc_cnt_clr & ~cnt_clr;

      end
      SEND_SYNC: begin
        lce_cmd_v_o = 1'b1;
        lce_cmd.dst_id = cnt[0+:lg_num_lce_lp];
        lce_cmd.msg_type = e_lce_cmd_sync;
        state_n = (lce_cmd_ready_i) ? SYNC_ACK : SEND_SYNC;
        cnt_inc = lce_cmd_ready_i;
      end
      SYNC_ACK: begin
        sync_ack_yumi = lce_resp_v_i;
        state_n = (lce_resp_v_i)
                  ? (ack_cnt == num_lce_p-1)
                    ? READY
                    : SEND_SYNC
                  : SYNC_ACK;
        state_n = (lce_resp_v_i & (lce_resp.msg_type != e_lce_cce_sync_ack))
                  ? ERROR
                  : state_n;
        ack_cnt_clr = (state_n == READY);
        ack_cnt_inc = lce_resp_v_i & ~ack_cnt_clr;
        cnt_clr = (state_n == READY);
      end
      READY: begin
        // clear the MSHR
        mshr_n = '0;
        // clear the ack counter
        cnt_clr = 1'b1;
        ack_cnt_clr = 1'b1;

        if (mem_resp_v_i) begin
          // Uncached store response
          if (mem_resp_mshr.flags[e_flag_sel_ucf]) begin
            lce_cmd_v_o = 1'b1;
            lce_cmd.dst_id = mem_resp_mshr.lce_id;
            lce_cmd.msg_type = e_lce_cmd_uc_st_done;
            lce_cmd.addr = mem_resp_mshr.paddr;
            mem_resp_yumi_o = lce_cmd_ready_i;
            state_n = READY;
          end

          // Only dequeue if lce data command isn't finishing sending.
          // This avoids a conflict on the pending bits write port.
          else if (~(mem_data_resp_v_i & lce_data_cmd_ready_i)) begin
            mem_resp_yumi_o = 1'b1;
            pending_w_v = 1'b1;
            pending_w_way_group =
              mem_resp.addr[(way_group_offset_high_lp-1) -: lg_num_way_groups_lp];
            pending_li = 1'b0;
            // Next state is determined by flags in the MSHR being restored
            // If the response is not for a replacement writeback, then the LCE request
            // transaction is now complete, so the MSHR is cleared and the CCE stays in the READY
            // state. Otherwise, the MSHR is restored and the next state is determined by the
            // flags in the MSHR returned from memory.
            state_n = (mem_resp_mshr.flags[e_flag_sel_rwbf])
                      ? (mem_resp_mshr.flags[e_flag_sel_tf])
                        ? TRANSFER_CMD
                        : READ_MEM
                      : READY;
            // restore the MSHR from the memory response
            mshr_n = (state_n == READY)
                     ? '0
                     : mem_resp_mshr;
            // clear the replacement writeback flag
            mshr_n.flags[e_flag_sel_rwbf] = 1'b0;
          end
        end else if (lce_req_v_i) begin
          mshr_n.lce_id = lce_req.src_id;
          mshr_n.paddr = lce_req.addr;
          mshr_n.lru_way_id = lce_req.lru_way_id;
          mshr_n.nc_req_size = lce_req.nc_size;
          mshr_n.flags[e_flag_sel_ucf] = lce_req.non_cacheable;
          mshr_n.flags[e_flag_sel_rqf] = lce_req.msg_type;
          mshr_n.flags[e_flag_sel_ldf] = lce_req.lru_dirty;
          mshr_n.flags[e_flag_sel_nerf] = lce_req.non_exclusive;
          uc_data_n = lce_req.data;
          state_n = (lce_req.non_cacheable) ? UC_REQ : READ_PENDING;
          cnt_clr = 1'b1;
        end
      end
      UC_REQ: begin
        // Uncached Store
        if (mshr_r.flags[e_flag_sel_rqf]) begin
          mem_data_cmd_v_o = 1'b1;
          mem_data_cmd.msg_type = bp_lce_cce_req_type_e'(mshr_r.flags[e_flag_sel_rqf]);
          mem_data_cmd.addr = mshr_r.paddr;
          mem_data_cmd.payload = mshr_r;
          mem_data_cmd.data = {{(cce_block_width_p-dword_width_p){1'b0}}, uc_data_r};
          mem_data_cmd.non_cacheable = bp_lce_cce_req_non_cacheable_e'(mshr_r.flags[e_flag_sel_ucf]);
          mem_data_cmd.nc_size = bp_lce_cce_nc_req_size_e'(mshr_r.nc_req_size);
          state_n = (mem_data_cmd_ready_i) ? READY : UC_REQ;
          lce_req_yumi_o = mem_data_cmd_ready_i;

        // Uncached Load
        end else begin
          mem_cmd_v_o = 1'b1;
          mem_cmd.msg_type = bp_lce_cce_req_type_e'(mshr_r.flags[e_flag_sel_rqf]);
          mem_cmd.addr = mshr_r.paddr;
          mem_cmd.payload.lce_id = mshr_r.lce_id;
          mem_cmd.payload.way_id = '0;
          mem_cmd.non_cacheable = bp_lce_cce_req_non_cacheable_e'(mshr_r.flags[e_flag_sel_ucf]);
          mem_cmd.nc_size = bp_lce_cce_nc_req_size_e'(mshr_r.nc_req_size);
          state_n = (mem_cmd_ready_i) ? READY : UC_REQ;
          lce_req_yumi_o = mem_cmd_ready_i;
        end
      end
      READ_PENDING: begin
        pending_r_v = 1'b1;
        state_n = (pending_v_lo)
                  ? (pending_lo)
                    ? READY
                    : READ_DIR
                  : ERROR;
      end
      READ_DIR: begin
        lce_req_yumi_o = 1'b1;
        // initiate the directory read
        // At the earliest, data will be valid in the next cycle
        dir_r_v = 1'b1;
        dir_way_group_li = mshr_r.paddr[way_group_offset_high_lp-1 -: lg_num_way_groups_lp];
        dir_r_cmd = e_rdw_op;
        dir_lce_li = mshr_r.lce_id;
        //dir_lru_way_li = mshr_r.lru_way_id; // this input is hardwired
        state_n = WAIT_DIR_GAD;
      end
      WAIT_DIR_GAD: begin

        // capture LRU outputs when they appear
        if (dir_lru_v_lo) begin
          mshr_n.lru_paddr = {dir_lru_tag_lo
                              , mshr_r.paddr[lg_block_size_in_bytes_lp +: lg_lce_sets_lp]
                              , {lg_block_size_in_bytes_lp{1'b0}}
                             };
          mshr_n.flags[e_flag_sel_lef] = dir_lru_cached_excl_lo;

        end

        gad_v = sharers_v_lo & ~dir_busy_lo;
        if (gad_v) begin

          mshr_n.way_id = gad_req_addr_way_lo;

          mshr_n.flags[e_flag_sel_rf] = gad_replacement_flag_lo;
          mshr_n.flags[e_flag_sel_rwbf] = gad_replacement_flag_lo;
          mshr_n.flags[e_flag_sel_uf] = gad_upgrade_flag_lo;
          mshr_n.flags[e_flag_sel_if] = gad_invalidate_flag_lo;
          mshr_n.flags[e_flag_sel_ef] = gad_exclusive_flag_lo;
          mshr_n.flags[e_flag_sel_cf] = gad_cached_flag_lo;
          mshr_n.flags[e_flag_sel_tf] = gad_transfer_flag_lo;

          mshr_n.tr_lce_id = gad_transfer_lce_lo;
          mshr_n.tr_way_id = gad_transfer_lce_way_lo;

          mshr_n.next_coh_state =
            (mshr_r.flags[e_flag_sel_rqf])
            ? e_MESI_M
            : (mshr_r.flags[e_flag_sel_nerf])
              ? e_MESI_S
              : (gad_cached_flag_lo)
                ? e_MESI_S
                : e_MESI_E;

          state_n = WRITE_NEXT_STATE;
        end

      end
      WRITE_NEXT_STATE: begin
        // writing to the directory will make the sharers_v_lo signal go low, but in this FSM
        // CCE we know that the sharers vectors are still valid in the state we need from the
        // previous read, so we perform the coherence state update for the requesting LCE anyway

        dir_w_v = 1'b1;
        dir_lce_li = mshr_r.lce_id;
        dir_way_group_li = mshr_r.paddr[way_group_offset_high_lp-1 -: lg_num_way_groups_lp];
        dir_coh_state_li = mshr_r.next_coh_state;
        if (mshr_r.flags[e_flag_sel_uf]) begin
          dir_w_cmd = e_wds_op;
          dir_way_li = mshr_r.way_id;
        end else begin
          dir_w_cmd = e_wde_op;
          dir_tag_li = mshr_r.paddr[(paddr_width_p-1) -: ptag_width_lp];
          dir_way_li = mshr_r.lru_way_id;
        end

        state_n =
          (mshr_r.flags[e_flag_sel_if])
          ? INV_CMD
          : (mshr_r.flags[e_flag_sel_uf])
            ? UPGRADE_STW_CMD
            : (mshr_r.flags[e_flag_sel_rf])
              ? REPLACEMENT
              : (mshr_r.flags[e_flag_sel_tf])
                ? TRANSFER_CMD
                : READ_MEM;

        ack_cnt_clr = 1'b1;
        cnt_clr = 1'b1;
      end
      INV_CMD: begin
        // Send invalidation commands only to LCEs that hit in the sharers vector and that are
        // not the requesting LCE
        if ((cnt[0+:lg_num_lce_lp] != mshr_r.lce_id) & (sharers_hits_lo[cnt])) begin
          // LCE given by cnt needs to be invalidated, try to send the LCE Cmd
          lce_cmd_v_o = 1'b1;
          lce_cmd.dst_id = cnt[0+:lg_num_lce_lp];
          lce_cmd.msg_type = e_lce_cmd_invalidate_tag;
          lce_cmd.addr = mshr_r.paddr;
          lce_cmd.way_id = sharers_ways_lo[cnt];

          cnt_clr = (cnt == (num_lce_p-1)) & lce_cmd_ready_i;
          cnt_inc = lce_cmd_ready_i & ~cnt_clr;

          state_n = (cnt_clr) ? INV_ACK : INV_CMD;

          // increment the Ack counting register if the command is sent
          ack_cnt_inc = (lce_cmd_ready_i);

        end else begin
          cnt_clr = (cnt == (num_lce_p-1));
          cnt_inc = ~cnt_clr;
          state_n = (cnt_clr) ? INV_ACK : INV_CMD;
        end

      end
      INV_ACK: begin
        inv_ack_yumi = (lce_resp_v_i & (lce_resp.msg_type == e_lce_cce_inv_ack));
        cnt_inc = inv_ack_yumi;
        // cnt counter holds the number of invalidation acks received so far
        // ack_cnt holds the number that the CCE needs to wait for
        // Transition to another state if there is a valid request and all but the last ack has
        // been received - since the last ack is being dequeued this cycle!
        state_n = (inv_ack_yumi & (cnt == (ack_cnt-1)))
                  ? (mshr_r.flags[e_flag_sel_uf])
                    ? UPGRADE_STW_CMD
                    : (mshr_r.flags[e_flag_sel_rf])
                      ? REPLACEMENT
                      : (mshr_r.flags[e_flag_sel_tf])
                        ? TRANSFER_CMD
                        : READ_MEM
                  : INV_ACK;

        // clear counter and ack count register if all acks received
        cnt_clr = (state_n != INV_ACK);
        ack_cnt_clr = (state_n != INV_ACK);
      end
      REPLACEMENT: begin
        lce_cmd_v_o = 1'b1;
        lce_cmd.dst_id = mshr_r.lce_id;
        lce_cmd.msg_type = e_lce_cmd_writeback;
        lce_cmd.addr = mshr_r.lru_paddr;
        lce_cmd.way_id = mshr_r.lru_way_id;
        state_n = (lce_cmd_ready_i) ? REPLACEMENT_WB_RESP : REPLACEMENT;
      end
      REPLACEMENT_WB_RESP: begin
        if (lce_data_resp_v_i & lce_data_resp.msg_type == e_lce_resp_null_wb) begin
          lce_data_resp_yumi_o = 1'b1;
          state_n = (mshr_r.flags[e_flag_sel_tf])
                    ? TRANSFER_CMD
                    : READ_MEM;

          // clear the replacement writeback flag
          mshr_n.flags[e_flag_sel_rwbf] = 1'b0;

        end else if (~(mem_data_resp_v_i & lce_data_cmd_ready_i)) begin
        // Mem Data Cmd needs to write pending bit, so only send if Mem Data Resp / LCE Data Cmd is
        // not writing the pending bit
          mem_data_cmd_v_o = lce_data_resp_v_i;
          lce_data_resp_yumi_o = lce_data_resp_v_i & mem_data_cmd_ready_i;
          mem_data_cmd.msg_type = bp_lce_cce_req_type_e'(mshr_r.flags[e_flag_sel_rqf]);
          mem_data_cmd.addr = lce_data_resp.addr;
          mem_data_cmd.payload = mshr_r;
          mem_data_cmd.data = lce_data_resp.data;
          state_n = (lce_data_resp_yumi_o) ? READY : REPLACEMENT_WB_RESP;

          pending_w_v = lce_data_resp_yumi_o;
          pending_li = 1'b1;
          pending_w_way_group =
            lce_data_resp.addr[(way_group_offset_high_lp-1) -: lg_num_way_groups_lp];
        end
      end
      TRANSFER_CMD: begin
        lce_cmd_v_o = 1'b1;
        lce_cmd.dst_id = mshr_r.tr_lce_id;
        lce_cmd.msg_type = e_lce_cmd_transfer;
        lce_cmd.addr = mshr_r.paddr;
        lce_cmd.way_id = mshr_r.tr_way_id;
        lce_cmd.target = mshr_r.lce_id;
        lce_cmd.target_way_id = mshr_r.lru_way_id;
        state_n = (lce_cmd_ready_i) ? TRANSFER_ST_CMD : TRANSFER_CMD;
      end
      TRANSFER_ST_CMD: begin
        lce_cmd_v_o = 1'b1;
        lce_cmd.dst_id = mshr_r.lce_id;
        lce_cmd.msg_type = e_lce_cmd_set_tag;
        lce_cmd.addr = mshr_r.paddr;
        lce_cmd.way_id = mshr_r.lru_way_id;
        lce_cmd.state = mshr_r.next_coh_state;
        state_n = (lce_cmd_ready_i) ? TRANSFER_WB_CMD : TRANSFER_ST_CMD;
      end
      TRANSFER_WB_CMD: begin
        lce_cmd_v_o = 1'b1;
        lce_cmd.dst_id = mshr_r.tr_lce_id;
        lce_cmd.msg_type = e_lce_cmd_writeback;
        lce_cmd.addr = mshr_r.paddr;
        lce_cmd.way_id = mshr_r.tr_way_id;
        state_n = (lce_cmd_ready_i) ? TRANSFER_WB_RESP : TRANSFER_WB_CMD;
      end
      TRANSFER_WB_RESP: begin
        if (lce_data_resp_v_i & lce_data_resp.msg_type == e_lce_resp_null_wb) begin
          lce_data_resp_yumi_o = 1'b1;
          state_n = READY;
          mshr_n = '0;
        end else if (~(mem_data_resp_v_i & lce_data_cmd_ready_i)) begin
        // Mem Data Cmd needs to write pending bit, so only send if Mem Data Resp / LCE Data Cmd is
        // not writing the pending bit
          mem_data_cmd_v_o = lce_data_resp_v_i;
          lce_data_resp_yumi_o = lce_data_resp_v_i & mem_data_cmd_ready_i;
          mem_data_cmd.msg_type = bp_lce_cce_req_type_e'(mshr_r.flags[e_flag_sel_rqf]);
          mem_data_cmd.addr = lce_data_resp.addr;
          mem_data_cmd.payload = mshr_r;
          mem_data_cmd.data = lce_data_resp.data;
          state_n = (lce_data_resp_yumi_o) ? READY : TRANSFER_WB_RESP;
          mshr_n = (lce_data_resp_yumi_o) ? '0 : mshr_r;

          pending_w_v = lce_data_resp_yumi_o;
          pending_li = 1'b1;
          pending_w_way_group =
            lce_data_resp.addr[(way_group_offset_high_lp-1) -: lg_num_way_groups_lp];
        end
      end
      UPGRADE_STW_CMD: begin
        lce_cmd_v_o = 1'b1;
        lce_cmd.dst_id = mshr_r.lce_id;
        lce_cmd.msg_type = e_lce_cmd_set_tag_wakeup;
        lce_cmd.addr = mshr_r.paddr;
        lce_cmd.way_id = mshr_r.way_id;
        lce_cmd.state = mshr_r.next_coh_state;
        state_n = (lce_cmd_ready_i) ? READY : UPGRADE_STW_CMD;
        mshr_n = (lce_cmd_ready_i) ? '0 : mshr_r;
      end
      READ_MEM: begin
        // Mem Cmd needs to write pending bit, so only send if Mem Data Resp / LCE Data Cmd is not
        // writing the pending bit
        if (~(mem_data_resp_v_i & lce_data_cmd_ready_i)) begin
          mem_cmd_v_o = 1'b1;
          mem_cmd.msg_type = bp_lce_cce_req_type_e'(mshr_r.flags[e_flag_sel_rqf]);
          mem_cmd.addr = mshr_r.paddr;
          mem_cmd.payload.lce_id = mshr_r.lce_id;
          mem_cmd.payload.way_id = mshr_r.lru_way_id;
          mem_cmd.non_cacheable = bp_lce_cce_req_non_cacheable_e'(mshr_r.flags[e_flag_sel_ucf]);
          mem_cmd.nc_size = bp_lce_cce_nc_req_size_e'(mshr_r.nc_req_size);
          state_n = (mem_cmd_ready_i) ? SEND_SET_TAG : READ_MEM;

          pending_w_v = mem_cmd_ready_i;
          pending_li = 1'b1;
          pending_w_way_group = mshr_r.paddr[(way_group_offset_high_lp-1) -: lg_num_way_groups_lp];
        end
      end
      SEND_SET_TAG: begin
        lce_cmd_v_o = 1'b1;
        lce_cmd.dst_id = mshr_r.lce_id;
        lce_cmd.msg_type = e_lce_cmd_set_tag;
        lce_cmd.addr = mshr_r.paddr;
        lce_cmd.way_id = mshr_r.lru_way_id;
        lce_cmd.state = mshr_r.next_coh_state;
        state_n = (lce_cmd_ready_i) ? READY : SEND_SET_TAG;
        mshr_n = (lce_cmd_ready_i) ? '0 : mshr_r;
      end
      ERROR: begin
        $display("oh no - error!");
        $finish(0);
      end
      default: begin
        // use defaults above
      end
    endcase

    // Mem Data Response to LCE Data Command

    // LCE Data Cmd feeds a wormhole router, so v_o must be held high until the wormhole router
    // asserts lce_data_cmd_ready_i. The pending bit is cleared on the cycle that
    // lce_data_cmd_ready_i goes high. The main CCE FSM will stall if it is trying to write
    // a pending bit in the same cycle.

    lce_data_cmd = '0;
    lce_data_cmd_v_o = '0;
    mem_data_resp_yumi_o = '0;

    if (mem_data_resp_v_i) begin
      lce_data_cmd_v_o = mem_data_resp_v_i;
      mem_data_resp_yumi_o = lce_data_cmd_ready_i;
      // Clear the pending bit in the cycle that the wormhole router asserts ready_i
      if (lce_data_cmd_ready_i) begin
        pending_w_v = lce_data_cmd_ready_i;
        pending_w_way_group =
          mem_data_resp.addr[(way_group_offset_high_lp-1) -: lg_num_way_groups_lp];
        pending_li = 1'b0;
      end
    end
    lce_data_cmd.dst_id = mem_data_resp.payload.lce_id;
    lce_data_cmd.data = mem_data_resp.data;
    // Data is copied directly from the Mem Data Response
    // For uncached responses, only the least significant 64-bits will be valid
    if (mem_data_resp.non_cacheable == e_lce_req_non_cacheable) begin
      lce_data_cmd.msg_type = e_lce_data_cmd_non_cacheable;
      lce_data_cmd.way_id = '0;
    end else begin
      lce_data_cmd.msg_type = e_lce_data_cmd_cce;
      lce_data_cmd.way_id = mem_data_resp.payload.way_id;
    end

  end

  // Sequential Logic
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      state_r <= RESET;
      mshr_r <= '0;
      uc_data_r <= '0;
    end else begin
      state_r <= state_n;
      mshr_r <= mshr_n;
      uc_data_r <= uc_data_n;
    end
  end

endmodule
