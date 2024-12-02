/**
 *
 * Name:
 *   bp_cce_hybrid_coh_pipe.sv
 *
 * Description:
 *   This module processes cached or uncached requests to cacheable memory.
 *   It contains the coherence directory and pending queue and bits.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_hybrid_coh_pipe
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter pending_buffer_els_p       = 2

    // Derived parameters
    , localparam lg_num_lce_lp             = `BSG_SAFE_CLOG2(num_lce_p)
    , localparam lg_lce_assoc_lp           = `BSG_SAFE_CLOG2(lce_assoc_p)

    , localparam num_way_groups_lp         = `BSG_CDIV(cce_way_groups_p, num_cce_p)

    , localparam block_size_in_bytes_lp    = bedrock_block_width_p/8
    , localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp)

    // maximal number of tag sets stored in the directory for all LCE types
    , localparam max_tag_sets_lp           = `BSG_CDIV(lce_sets_p, num_cce_p)
    , localparam lg_max_tag_sets_lp        = `BSG_SAFE_CLOG2(max_tag_sets_lp)

    , localparam counter_max_lp            = 256
    , localparam counter_width_lp          = `BSG_SAFE_CLOG2(counter_max_lp+1)

    // interface width
    `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
  )
  (input                                            clk_i
   , input                                          reset_i

   // control
   , input bp_cce_mode_e                            cce_mode_i
   , input [cce_id_width_p-1:0]                     cce_id_i
   , output logic                                   empty_o

   // LCE-CCE Interface
   // BedRock Burst protocol: ready&valid
   , input [lce_req_header_width_lp-1:0]            lce_req_header_i
   , input [bedrock_fill_width_p-1:0]               lce_req_data_i
   , input                                          lce_req_v_i
   , output logic                                   lce_req_ready_and_o

   , output logic [lce_cmd_header_width_lp-1:0]     lce_cmd_header_o
   , output logic [bedrock_fill_width_p-1:0]        lce_cmd_data_o
   , output logic                                   lce_cmd_v_o
   , input                                          lce_cmd_ready_and_i

   , input                                          inv_yumi_i
   , input                                          wb_yumi_i

   // to programmable pipeline
   , output logic [lce_req_header_width_lp-1:0]     lce_req_header_o
   , output logic                                   lce_req_v_o
   , input                                          lce_req_ready_and_i
   // from programmable pipeline
   , input                                          prog_v_i
   , output logic                                   prog_yumi_o
   , input                                          prog_status_i // 1 = okay, 0 = squash

   // CCE-MEM Interface
   // BedRock Stream protocol: ready&valid
   , output logic [mem_fwd_header_width_lp-1:0]     mem_fwd_header_o
   , output logic [bedrock_fill_width_p-1:0]        mem_fwd_data_o
   , output logic                                   mem_fwd_v_o
   , input                                          mem_fwd_ready_and_i

   // Spec bits write port - to memory response pipe
   , output logic                                   spec_w_v_o
   , output logic [paddr_width_p-1:0]               spec_w_addr_o
   , output logic                                   spec_w_addr_bypass_hash_o
   , output logic                                   spec_v_o
   , output logic                                   spec_squash_v_o
   , output logic                                   spec_fwd_mod_v_o
   , output logic                                   spec_state_v_o
   , output bp_cce_spec_s                           spec_bits_o

   // Pending bits write port - from memory response pipe
   , input                                          mem_rev_pending_w_v_i
   , output logic                                   mem_rev_pending_w_yumi_o
   , input [paddr_width_p-1:0]                      mem_rev_pending_w_addr_i
   , input                                          mem_rev_pending_w_addr_bypass_hash_i
   , input                                          mem_rev_pending_up_i
   , input                                          mem_rev_pending_down_i
   , input                                          mem_rev_pending_clear_i

   // Pending bits write port - from LCE response pipe (coherence ack)
   , input                                          lce_resp_pending_w_v_i
   , output logic                                   lce_resp_pending_w_yumi_o
   , input [paddr_width_p-1:0]                      lce_resp_pending_w_addr_i
   , input                                          lce_resp_pending_w_addr_bypass_hash_i
   , input                                          lce_resp_pending_up_i
   , input                                          lce_resp_pending_down_i
   , input                                          lce_resp_pending_clear_i
   );

  // parameter checks
  if (counter_max_lp < num_way_groups_lp) $fatal(0,"Counter max value not large enough");
  if (counter_max_lp < max_tag_sets_lp) $fatal(0,"Counter max value not large enough");

  // Define structure variables for output queues
  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);

  // LCE and Memory input/output messages
  `bp_cast_i(bp_bedrock_lce_req_header_s, lce_req_header);
  `bp_cast_o(bp_bedrock_lce_cmd_header_s, lce_cmd_header);
  `bp_cast_o(bp_bedrock_mem_fwd_header_s, mem_fwd_header);

  // request to programmable pipe
  `bp_cast_o(bp_bedrock_lce_req_header_s, lce_req_header);

  // MSHR
  `declare_bp_cce_mshr_s(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);
  bp_cce_mshr_s mshr_r, mshr_n;

  // Pending Bits and Queue
  logic pending_empty;
  bp_bedrock_lce_req_header_s  pending_lce_req_header_lo;
  logic pending_lce_req_v_lo, pending_lce_req_ready_and_li;
  logic [bedrock_fill_width_p-1:0]  pending_lce_req_data_lo;

  // pending bits write input
  // these must be arbitrated between the three write ports: FSM, LCE Response, Mem Response
  logic pending_w_v, pending_w_yumi, pending_w_addr_bypass_hash;
  logic pending_up, pending_down, pending_clear;
  logic [paddr_width_p-1:0] pending_w_addr;

  bp_cce_hybrid_pending
    #(.bp_params_p(bp_params_p)
      ,.buffer_els_p(pending_buffer_els_p)
      )
    pending_bits_and_queue
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.cce_id_i(cce_id_i)
      // request from input port
      // guaranteed to target cacheable memory space (cached or uncached)
      ,.lce_req_header_i(lce_req_header_cast_i)
      ,.lce_req_data_i(lce_req_data_i)
      ,.lce_req_v_i(lce_req_v_i)
      ,.lce_req_ready_and_o(lce_req_ready_and_o)
      // request to pipeline
      // guaranteed to be ready for execution
      ,.lce_req_header_o(pending_lce_req_header_lo)
      ,.lce_req_data_o(pending_lce_req_data_lo)
      ,.lce_req_v_o(pending_lce_req_v_lo)
      ,.lce_req_ready_and_i(pending_lce_req_ready_and_li)
      // Pending bits write port - from memory response pipe wbuf or FSM
      ,.pending_w_v_i(pending_w_v)
      ,.pending_w_yumi_o(pending_w_yumi)
      ,.pending_w_addr_i(pending_w_addr)
      ,.pending_w_addr_bypass_hash_i(pending_w_addr_bypass_hash)
      ,.pending_up_i(pending_up)
      ,.pending_down_i(pending_down)
      ,.pending_clear_i(pending_clear)
      // control
      ,.empty_o(pending_empty)
      );

  // LCE Request Stream Pump
  bp_bedrock_lce_req_header_s fsm_req_header_li;
  logic [bedrock_fill_width_p-1:0] fsm_req_data_li;
  logic fsm_req_v_li, fsm_req_yumi_lo;
  logic [paddr_width_p-1:0] fsm_req_addr_li;
  logic fsm_req_new_li, fsm_req_critical_li, fsm_req_last_li;
  bp_me_stream_pump_in
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(bedrock_fill_width_p)
     ,.payload_width_p(lce_req_payload_width_lp)
     ,.msg_stream_mask_p(lce_req_stream_mask_gp)
     ,.fsm_stream_mask_p(lce_req_stream_mask_gp)
     )
   lce_req_pump_in
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(pending_lce_req_header_lo)
     ,.msg_data_i(pending_lce_req_data_lo)
     ,.msg_v_i(pending_lce_req_v_lo)
     ,.msg_ready_and_o(pending_lce_req_ready_and_li)

     ,.fsm_header_o(fsm_req_header_li)
     ,.fsm_data_o(fsm_req_data_li)
     ,.fsm_v_o(fsm_req_v_li)
     ,.fsm_yumi_i(fsm_req_yumi_lo)
     ,.fsm_addr_o(fsm_req_addr_li)
     ,.fsm_new_o(fsm_req_new_li)
     ,.fsm_critical_o(fsm_req_critical_li)
     ,.fsm_last_o(fsm_req_last_li)
     );

  // LCE Command Stream Pump
  bp_bedrock_lce_cmd_header_s fsm_cmd_header_lo;
  logic [bedrock_fill_width_p-1:0] fsm_cmd_data_lo;
  logic fsm_cmd_v_lo, fsm_cmd_ready_then_li;
  logic [paddr_width_p-1:0] fsm_cmd_addr_li;
  logic fsm_cmd_new_li, fsm_cmd_critical_li, fsm_cmd_last_li;
  bp_me_stream_pump_out
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(bedrock_fill_width_p)
     ,.payload_width_p(lce_cmd_payload_width_lp)
     ,.msg_stream_mask_p(lce_cmd_stream_mask_gp)
     ,.fsm_stream_mask_p(lce_cmd_stream_mask_gp)
     )
   lce_cmd_pump_out
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_o(lce_cmd_header_cast_o)
     ,.msg_data_o(lce_cmd_data_o)
     ,.msg_v_o(lce_cmd_v_o)
     ,.msg_ready_and_i(lce_cmd_ready_and_i)

     ,.fsm_header_i(fsm_cmd_header_lo)
     ,.fsm_addr_o(fsm_cmd_addr_li)
     ,.fsm_data_i(fsm_cmd_data_lo)
     ,.fsm_v_i(fsm_cmd_v_lo)
     ,.fsm_ready_then_o(fsm_cmd_ready_then_li)
     ,.fsm_new_o(fsm_cmd_new_li)
     ,.fsm_critical_o(fsm_cmd_critical_li)
     ,.fsm_last_o(fsm_cmd_last_li)
     );

  // Memory Fwd Stream Pump
  bp_bedrock_mem_fwd_header_s fsm_fwd_header_lo;
  logic [bedrock_fill_width_p-1:0] fsm_fwd_data_lo;
  logic fsm_fwd_v_lo, fsm_fwd_ready_then_li;
  logic [paddr_width_p-1:0] fsm_fwd_addr_lo;
  logic fsm_fwd_new_li, fsm_fwd_critical_li, fsm_fwd_last_li;
  bp_me_stream_pump_out
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(bedrock_fill_width_p)
     ,.payload_width_p(mem_fwd_payload_width_lp)
     ,.msg_stream_mask_p(mem_fwd_stream_mask_gp)
     ,.fsm_stream_mask_p(mem_fwd_stream_mask_gp)
     )
   fwd_stream_pump
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     // to memory command output
     ,.msg_header_o(mem_fwd_header_cast_o)
     ,.msg_data_o(mem_fwd_data_o)
     ,.msg_v_o(mem_fwd_v_o)
     ,.msg_ready_and_i(mem_fwd_ready_and_i)
     // from FSM CCE
     ,.fsm_header_i(fsm_fwd_header_lo)
     ,.fsm_data_i(fsm_fwd_data_lo)
     ,.fsm_v_i(fsm_fwd_v_lo)
     ,.fsm_ready_then_o(fsm_fwd_ready_then_li)
     ,.fsm_addr_o(fsm_fwd_addr_lo)
     ,.fsm_new_o(fsm_fwd_new_li)
     ,.fsm_critical_o(fsm_fwd_critical_li)
     ,.fsm_last_o(fsm_fwd_last_li)
     );

  // Directory signals
  logic dir_r_v, dir_w_v;
  bp_cce_inst_minor_dir_op_e dir_cmd;
  logic sharers_v_lo;
  logic [num_lce_p-1:0] sharers_hits_lo;
  logic [num_lce_p-1:0][lce_assoc_width_p-1:0] sharers_ways_lo;
  bp_coh_states_e [num_lce_p-1:0] sharers_coh_states_lo;
  logic dir_lru_v_lo;
  logic [paddr_width_p-1:0] dir_lru_addr_lo;
  bp_coh_states_e dir_lru_coh_state_lo;
  logic dir_busy_lo;

  logic [paddr_width_p-1:0] dir_addr_li;
  logic dir_addr_bypass_li;
  logic [lce_id_width_p-1:0] dir_lce_li;
  logic [lce_assoc_width_p-1:0] dir_way_li;
  bp_coh_states_e dir_coh_state_li;

  // GAD signals
  logic [lce_assoc_width_p-1:0] gad_req_addr_way_lo;
  logic [lce_id_width_p-1:0] gad_owner_lce_lo;
  logic [lce_assoc_width_p-1:0] gad_owner_lce_way_lo;
  bp_coh_states_e gad_owner_coh_state_lo;
  logic gad_rf_lo;
  logic gad_uf_lo;
  logic gad_csf_lo;
  logic gad_cef_lo;
  logic gad_cmf_lo;
  logic gad_cof_lo;
  logic gad_cff_lo;

  // Directory
  bp_cce_dir
    #(.bp_params_p(bp_params_p))
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
      ,.cce_id_i(cce_id_i)
      );

  // GAD logic - auxiliary directory information logic
  bp_cce_gad
    #(.bp_params_p(bp_params_p))
    gad
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.gad_v_i(sharers_v_lo & ~dir_busy_lo)

      ,.sharers_v_i(sharers_v_lo)
      ,.sharers_hits_i(sharers_hits_lo)
      ,.sharers_ways_i(sharers_ways_lo)
      ,.sharers_coh_states_i(sharers_coh_states_lo)

      ,.req_lce_i(mshr_r.lce_id)
      ,.req_type_flag_i(mshr_r.flags.write_not_read)
      ,.lru_coh_state_i(mshr_r.lru_coh_state)
      ,.atomic_req_flag_i(mshr_r.flags.atomic)
      ,.uncached_req_flag_i(mshr_r.flags.uncached)

      ,.req_addr_way_o(gad_req_addr_way_lo)
      ,.owner_lce_o(gad_owner_lce_lo)
      ,.owner_way_o(gad_owner_lce_way_lo)
      ,.owner_coh_state_o(gad_owner_coh_state_lo)
      ,.replacement_flag_o(gad_rf_lo)
      ,.upgrade_flag_o(gad_uf_lo)
      ,.cached_shared_flag_o(gad_csf_lo)
      ,.cached_exclusive_flag_o(gad_cef_lo)
      ,.cached_modified_flag_o(gad_cmf_lo)
      ,.cached_owned_flag_o(gad_cof_lo)
      ,.cached_forward_flag_o(gad_cff_lo)
      );

  // Counter for invalidation send/receive
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
  logic [`BSG_SAFE_CLOG2(counter_max_lp+1)-1:0] cnt_0;
  bsg_counter_clear_up
    #(.max_val_p(counter_max_lp)
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
  logic [`BSG_SAFE_CLOG2(counter_max_lp+1)-1:0] cnt_1;
  bsg_counter_clear_up
    #(.max_val_p(counter_max_lp)
      ,.init_val_p(0)
     )
    counter_1
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.clear_i(cnt_1_clr)
      ,.up_i(cnt_1_inc)
      ,.count_o(cnt_1)
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

  // flags for cacheable requests
  // transfer occurs if any cache has block in E, M, O, or F (ownerhsip states)
  // and not doing an upgrade and not uncached access.
  wire transfer_flag = (mshr_r.flags.cached_exclusive | mshr_r.flags.cached_modified
                        | mshr_r.flags.cached_owned | mshr_r.flags.cached_forward)
                       & ~mshr_r.flags.upgrade & ~mshr_r.flags.uncached;
  // Upgrade with block in O or F in other LCE should invalidate owner.
  // No need to writeback because requestor will get read/write permissions and has up-to-date block
  // Upgrade flag only set if cacheable request
  wire upgrade_inv_owner = mshr_r.flags.upgrade
                           & (mshr_r.flags.cached_owned | mshr_r.flags.cached_forward);
  // invalidations occur if write request and any block in S state (shared, not owner)
  // also need to invalidate owner in O or F when doing upgrade
  wire inv_sharers = (~mshr_r.flags.uncached & mshr_r.flags.write_not_read & mshr_r.flags.cached_shared);

  // flags for uncached requests
  // all sharers need to be invalidated, regardless of read or write request
  wire uc_inv_sharers = mshr_r.flags.uncached & mshr_r.flags.cached_shared;
  wire uc_inv_owner = mshr_r.flags.uncached
                      & (mshr_r.flags.cached_forward | mshr_r.flags.cached_exclusive
                         | mshr_r.flags.cached_modified | mshr_r.flags.cached_owned);

  // invalidation flag - for either cacheable or uncacheable requests
  wire invalidate_flag = inv_sharers | uc_inv_sharers | upgrade_inv_owner;

  typedef enum logic [4:0] {
    e_reset
    ,e_clear_dir
    // setup for all requests
    ,e_ready
    ,e_read_mem_spec
    ,e_read_dir
    ,e_wait_dir_gad
    // select next action: replacement, invalidation, prog_sync
    ,e_ris_select
    ,e_replacement
    ,e_replacement_wb_resp
    ,e_inv_cmd
    ,e_inv_ack
    // sync with programmable pipe
    ,e_prog_sync
    // cached completion
    ,e_write_next_state
    ,e_upgrade_stw_cmd
    ,e_transfer
    ,e_transfer_wb_resp
    ,e_resolve_speculation
    // uncached completion
    ,e_uc_coherent_cmd
    ,e_uc_coherent_resp
    ,e_uc_coherent_mem_fwd
    ,e_error
  } state_e;

  state_e state_r, state_n;

  // Combinational Logic
  always_comb begin
    empty_o = pending_empty & (state_r == e_ready) & ~fsm_req_v_li;

    state_n = state_r;
    mshr_n = mshr_r;
    sharers_ways_n = sharers_ways_r;
    sharers_hits_n = sharers_hits_r;
    pe_sharers_n = pe_sharers_r;

    // LCE request
    fsm_req_yumi_lo = '0;

    // memory command defaults
    fsm_fwd_header_lo = '0;
    fsm_fwd_data_lo = '0;
    fsm_fwd_v_lo = 1'b0;

    // TODO
    // programmable pipe interface
    lce_req_v_o = 1'b1;
    lce_req_header_cast_o = fsm_req_header_li;
    prog_yumi_o = 1'b0;

    // lce command defaults
    fsm_cmd_header_lo = '0;
    fsm_cmd_header_lo.payload.src_id = cce_id_i;

    fsm_cmd_header_lo.msg_type.cmd = e_bedrock_cmd_data;
    fsm_cmd_header_lo.addr = mshr_r.paddr;
    fsm_fwd_header_lo.size = mshr_r.msg_size;
    fsm_cmd_header_lo.payload.dst_id = mshr_r.lce_id;
    fsm_cmd_header_lo.payload.way_id = mshr_r.way_id;
    fsm_cmd_header_lo.payload.src_did = mshr_r.src_did;
    fsm_cmd_header_lo.payload.src_id = cce_id_i;
    fsm_cmd_header_lo.payload.state = e_COH_I;


    fsm_cmd_v_lo = 1'b0;
    // never send data with commands
    fsm_cmd_data_lo = '0;

    // spec bits write
    spec_w_v_o = '0;
    spec_w_addr_o = mshr_r.paddr;
    spec_w_addr_bypass_hash_o = '0;
    spec_v_o = '0;
    spec_squash_v_o = '0;
    spec_fwd_mod_v_o = '0;
    spec_state_v_o = '0;
    spec_bits_o = '0;

    pending_w_v = 1'b0;
    pending_w_addr_bypass_hash = 1'b0;
    pending_up = 1'b0;
    pending_down = 1'b0;
    pending_clear = 1'b0;
    pending_w_addr = '0;

    dir_r_v = '0;
    dir_w_v = '0;
    dir_cmd = e_rdw_op;
    dir_lce_li = mshr_r.lce_id;
    dir_way_li = mshr_r.way_id;
    dir_addr_li = mshr_r.paddr;
    dir_addr_bypass_li = '0;
    dir_coh_state_li = mshr_r.next_coh_state;

    cnt_inc = '0;
    cnt_dec = '0;
    cnt_rst = '0;

    cnt_1_clr = '0;
    cnt_1_inc = '0;
    cnt_0_clr = '0;
    cnt_0_inc = '0;

    case (state_r)
      e_reset: begin
        state_n = e_clear_dir;
        cnt_rst = 1'b1;
        cnt_0_clr = 1'b1;
        cnt_1_clr = 1'b1;
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
        // don't increment when exiting this state (and clearing the counter)
        cnt_0_inc = cnt_1_clr & ~cnt_0_clr;

        // Stay in e_clear_dir until cnt_0_clr goes high
        state_n = cnt_0_clr ? e_ready : state_r;
      end // e_clear_dir

      // Process requests that have cleared pending bit check
      // Coherent/cacheable memory space has three request types:
      // 1. normal, cached request
      // 2. uncached request
      // 3. amo request
      // only normal, cached requests will issue a speculative memory read

      // Ordering of coherence actions:
      // Replacement, if needed
      // - requesting LCE has a valid block in LRU way
      // - uncached or amo request and requesting LCE has target address cached
      // Invalidations, if needed
      // - cacheable write request and cached shared by other LCEs
      // - uncached request (rd or wr) and cached shared by other LCEs
      // - upgrade (cacheable req) and cached O or F by other
      // Sync with programmable pipeline
      // Update directory state for this request
      // Uncacheable access
      // or Cacheable access: Upgrade, Transfer, or Memory access (resolve speculative access)

      e_ready: begin
        // clear counters
        cnt_0_clr = 1'b1;
        cnt_1_clr = 1'b1;
        cnt_rst = 1'b1;

        // populate MSHR fields from LCE request
        mshr_n = '0;
        mshr_n.msg_type.req = fsm_req_header_li.msg_type.req;
        mshr_n.msg_subop = fsm_req_header_li.subop;
        mshr_n.paddr = fsm_req_header_li.addr;
        mshr_n.msg_size = fsm_req_header_li.size;
        mshr_n.lce_id = fsm_req_header_li.payload.src_id;
        mshr_n.lru_way_id = fsm_req_header_li.payload.lru_way_id;
        mshr_n.flags.non_exclusive = fsm_req_header_li.payload.non_exclusive;
        mshr_n.flags.cacheable_address = 1'b1;
        mshr_n.src_did = fsm_req_header_li.payload.src_did;

        unique case (fsm_req_header_li.msg_type.req)
          e_bedrock_req_rd_miss: begin
            // write pending bit for speculative memory read
            // do write this cycle to make spec memory read logic simpler
            pending_w_v = fsm_req_v_li;
            pending_up = 1'b1;
            pending_w_addr = fsm_req_header_li.addr;
            fsm_req_yumi_lo = fsm_req_v_li & pending_w_yumi;
            state_n = fsm_req_yumi_lo ? e_read_mem_spec : state_r;
          end
          e_bedrock_req_wr_miss: begin
            mshr_n.flags.write_not_read = 1'b1;
            // write pending bit for speculative memory read
            // do write this cycle to make spec memory read logic simpler
            pending_w_v = fsm_req_v_li;
            pending_up = 1'b1;
            pending_w_addr = fsm_req_header_li.addr;
            fsm_req_yumi_lo = fsm_req_v_li & pending_w_yumi;
            state_n = fsm_req_yumi_lo ? e_read_mem_spec : state_r;
          end
          e_bedrock_req_uc_rd: begin
            mshr_n.flags.uncached = 1'b1;
            fsm_req_yumi_lo = fsm_req_v_li;
            state_n = fsm_req_yumi_lo ? e_read_dir : state_r;
          end
          e_bedrock_req_uc_wr: begin
            mshr_n.flags.uncached = 1'b1;
            mshr_n.flags.write_not_read = 1'b1;
            // do not dequeue fsm_req yet, because data is needed when sending fsm_fwd
            state_n = fsm_req_v_li ? e_read_dir : state_r;
          end
          e_bedrock_req_uc_amo: begin
            // TODO: implement amo requests
            mshr_n.flags.uncached = 1'b1;
            mshr_n.flags.atomic = 1'b1;
            mshr_n.flags.atomic_no_return = 1'b0; // TODO: amo no return property
            // do not dequeue fsm_req yet, because data is needed when sending fsm_fwd
            state_n = fsm_req_v_li ? e_error : state_r;
          end
          default: begin
          end
        endcase
      end // e_ready

      // issue speculative memory read command
      // associated pending bit write occurred last cycle
      e_read_mem_spec: begin
        // r&v on mem_fwd
        fsm_fwd_v_lo = fsm_fwd_ready_then_li;
        fsm_fwd_header_lo.msg_type.fwd = e_bedrock_mem_rd;
        fsm_fwd_header_lo.addr = mshr_r.paddr;
        fsm_fwd_header_lo.size = mshr_r.msg_size;
        fsm_fwd_header_lo.payload.lce_id = mshr_r.lce_id;
        fsm_fwd_header_lo.payload.way_id = mshr_r.lru_way_id;
        fsm_fwd_header_lo.payload.src_did = mshr_r.src_did;
        // speculatively issue request for E state
        fsm_fwd_header_lo.payload.state = e_COH_E;
        fsm_fwd_header_lo.payload.speculative = 1'b1;

        // set the spec bit and clear all other bits for this entry
        // this write is idempotent - write each cycle until memory command sends
        spec_w_v_o = 1'b1;
        spec_v_o = 1'b1;
        spec_squash_v_o = 1'b1;
        spec_fwd_mod_v_o = 1'b1;
        spec_state_v_o = 1'b1;
        spec_bits_o.spec = 1'b1;
        spec_bits_o.squash = 1'b0;
        spec_bits_o.fwd_mod = 1'b0;
        spec_bits_o.state = e_COH_I;

        state_n = fsm_fwd_v_lo ? e_read_dir : state_r;

      end // e_read_mem_spec

      e_read_dir: begin
        // initiate the directory read
        // At the earliest, data will be valid in the next cycle
        dir_r_v = 1'b1;
        dir_addr_li = mshr_r.paddr;
        dir_cmd = e_rdw_op;
        dir_lce_li = mshr_r.lce_id;
        state_n = e_wait_dir_gad;
      end // e_read_dir

      e_wait_dir_gad: begin

        // capture LRU outputs when they appear
        if (dir_lru_v_lo) begin
          mshr_n.lru_paddr = dir_lru_addr_lo;
          mshr_n.lru_coh_state = dir_lru_coh_state_lo;
        end

        // capture sharer information when it appears
        if (sharers_v_lo) begin
          sharers_ways_n = sharers_ways_lo;
          sharers_hits_n = sharers_hits_lo;
        end

        // process directory output when read completes
        if (sharers_v_lo & ~dir_busy_lo) begin

          mshr_n.way_id = gad_req_addr_way_lo;

          mshr_n.flags.replacement = gad_rf_lo;
          mshr_n.flags.upgrade = gad_uf_lo;
          mshr_n.flags.cached_shared = gad_csf_lo;
          mshr_n.flags.cached_exclusive = gad_cef_lo;
          mshr_n.flags.cached_modified = gad_cmf_lo;
          mshr_n.flags.cached_owned = gad_cof_lo;
          mshr_n.flags.cached_forward = gad_cff_lo;

          mshr_n.owner_lce_id = gad_owner_lce_lo;
          mshr_n.owner_way_id = gad_owner_lce_way_lo;
          mshr_n.owner_coh_state = gad_owner_coh_state_lo;

          // determine next state for MOESIF protocol
          // atomic or uncached requests to coherent memory will set block to Invalid if it is
          // present in the requesting LCE
          // write requests get block in M
          // read request gets block in S if non-exclusive request or block cached anywhere
          // else send block in E
          mshr_n.next_coh_state =
            (mshr_r.flags.atomic | mshr_r.flags.uncached)
            ? e_COH_I
            : (mshr_r.flags.write_not_read)
              ? e_COH_M
              : (mshr_r.flags.non_exclusive | gad_csf_lo | gad_cef_lo
                 | gad_cmf_lo | gad_cof_lo | gad_cff_lo)
                ? e_COH_S
                : e_COH_E;

          state_n = e_ris_select;

        end // process GAD output
      end // e_wait_dir_gad

      // after processing directory, choose next coherence action
      e_ris_select: begin
        // unconditionally perform setup for sending invalidations
        // if invalidations are not needed then the FSM simply won't use this

        // don't invalidate the requesting LCE
        pe_sharers_n = sharers_hits_r & ~req_lce_id_one_hot;
        // if doing a transfer or uncached req and owner exists, also remove owner LCE since
        // transfer routine will take care of setting owner into correct new state
        // and uncached sequence will writeback owner
        pe_sharers_n = (transfer_flag | uc_inv_owner)
                       ? pe_sharers_n & ~owner_lce_id_one_hot
                       : pe_sharers_n;
        // reset counter for invalidation command/ack tracking
        cnt_rst = 1'b1;

        // choose next state - replacement, invalidations, or sync with programmable pipe
        // replace (invalidate existing block) in LCE if:
        // 1. cacheable req, not an upgrade, and LRU block may be dirty (E, M, or O)
        // 2. uncacheable req and target block in any state in requesting LCE
        // invalidate if:
        // 1. cacheable write request and any block in S
        // 2. cacheable write that is upgrade and owner in O or F
        // 3. uncacheable request and any block in S
        state_n = (mshr_r.flags.replacement)
                  ? e_replacement
                  : (invalidate_flag)
                    ? e_inv_cmd
                    : e_prog_sync;
      end // e_ris_select

      e_replacement: begin
        fsm_cmd_v_lo = fsm_cmd_ready_then_li;

        // set message to invalid and writeback
        fsm_cmd_header_lo.msg_type.cmd = e_bedrock_cmd_st_wb;

        // for an uc/amo request, the mshr way_id field indicates the way in which the requesting
        // LCE's copy of the cache block is stored at the LCE
        if (mshr_r.flags.atomic | mshr_r.flags.uncached) begin
          fsm_cmd_header_lo.payload.way_id = mshr_r.way_id;
          fsm_cmd_header_lo.addr = mshr_r.paddr;
        end else begin
          fsm_cmd_header_lo.payload.way_id = mshr_r.lru_way_id;
          fsm_cmd_header_lo.addr = mshr_r.lru_paddr;
        end
        fsm_cmd_header_lo.payload.dst_id = mshr_r.lce_id;
        // Note: this state must be e_COH_I to properly handle amo or uncached access to
        // coherent memory that requires invalidating the requesting LCE if it has the block
        fsm_cmd_header_lo.payload.state = e_COH_I;

        state_n = fsm_cmd_ready_then_li
                  ? e_replacement_wb_resp
                  : state_r;
      end // e_replacement

      e_replacement_wb_resp: begin
        // wait for signal from LCE response module
        // note: no transition for upgrade because replacement occuring implies not an upgrade

        // clear the replacement flag
        mshr_n.flags.replacement = 1'b0;

        state_n = wb_yumi_i
                  ? (invalidate_flag)
                    ? e_inv_cmd
                    : e_prog_sync
                  : state_r;
      end // e_replacement_wb_resp

      e_inv_cmd: begin

        // only send invalidation if priority encode has valid output
        // this indicates the sharers vector has a valid bit set
        fsm_cmd_v_lo = pe_v & fsm_cmd_ready_then_li;
        fsm_cmd_header_lo.msg_type.cmd = e_bedrock_cmd_inv;
        fsm_cmd_header_lo.addr = mshr_r.paddr;

        // destination and way come from sharers information
        fsm_cmd_header_lo.payload.dst_id[0+:lg_num_lce_lp] = pe_lce_id;
        fsm_cmd_header_lo.payload.way_id = sharers_ways_r[pe_lce_id];

        // message sent, increment count
        cnt_inc = fsm_cmd_v_lo & fsm_cmd_new_li;
        // write directory - idempotent
        dir_w_v = cnt_inc;
        dir_cmd = e_wds_op;
        dir_addr_li = mshr_r.paddr;
        dir_lce_li = '0;
        dir_lce_li[0+:lg_num_lce_lp] = pe_lce_id;
        dir_way_li = sharers_ways_r[pe_lce_id];
        dir_coh_state_li = e_COH_I;

        // update sharers hit vector to feed back to priority encode module
        // only update if invalidation actually sends
        pe_sharers_n = dir_w_v
                       ? pe_sharers_r & ~pe_lce_id_one_hot
                       : pe_sharers_r;

        // move to inv_ack state if sharer vector will be empty next cycle, indicating
        // that the last command is sending this cycle, otherwise send more invalidations.
        // if pe_v is not set, go to e_error because sharers list is empty
        state_n = (pe_v)
                  ? (pe_sharers_n == '0)
                    ? e_inv_ack
                    : state_r
                  : e_error;

        // decrement counter if invalidate ack arrives
        cnt_dec = inv_yumi_i;
      end // e_inv_cmd

      e_inv_ack: begin
        // decrement counter as acks arrive
        cnt_dec = inv_yumi_i;

        // move to next state if all acks already arrived or last ack arriving in current cycle
        if ((cnt == '0) || ((cnt == 'd1) && inv_yumi_i)) begin
          state_n = e_prog_sync;
        end
      end // e_inv_ack

      e_prog_sync: begin

        if (prog_v_i) begin
          // squash speculative memory request (write unconditionally - idempotent)
          spec_w_v_o = ~prog_status_i;
          // no longer speculative
          spec_v_o = 1'b1;
          spec_bits_o.spec = 1'b0;
          // squash the response
          spec_squash_v_o = 1'b1;
          spec_bits_o.squash = 1'b1;

          // decrement pending bit - must only happen once
          pending_w_v = ~prog_status_i;
          pending_w_addr_bypass_hash = 1'b0;
          pending_up = 1'b0;
          pending_down = 1'b1;
          pending_clear = 1'b0;
          pending_w_addr = mshr_r.paddr;

          // ack programmable pipe when pending write happens or on good status
          prog_yumi_o = (~prog_status_i & pending_w_yumi) | prog_status_i;

          // if status is good, proceed
          // else, speculative memory response (if exists) will get squashed and pending bit
          // will get decremented to close out the request, then back to ready for next request
          state_n = (prog_yumi_o)
                    ? (prog_status_i)
                      ? e_write_next_state
                      : e_ready
                    : state_r;
        end // prog_v_i

      end // e_prog_sync

      e_write_next_state: begin
        // writing to the directory will make the sharers_v_lo signal go low, but in this FSM
        // CCE we know that the sharers vectors are still valid in the state we need from the
        // previous read, so we perform the coherence state update for the requesting LCE anyway

        dir_lce_li = mshr_r.lce_id;
        dir_addr_li = mshr_r.paddr;
        dir_coh_state_li = mshr_r.next_coh_state;

        // upgrade detected, only change state
        if (mshr_r.flags.upgrade) begin
          dir_w_v = 1'b1;
          dir_cmd = e_wds_op;
          dir_way_li = mshr_r.way_id;

        // amo or uncached to coherent memory
        // only write directory if replacement flag is set indicating the requsting LCE has
        // the block cached already
        end else if (mshr_r.flags.atomic | mshr_r.flags.uncached) begin
          dir_w_v = mshr_r.flags.replacement;
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
        // Uncached, or
        // Upgrade, Transfer, or Memory access (resolve speculative access)
        state_n = (mshr_r.flags.atomic | mshr_r.flags.uncached)
                  ? (uc_inv_owner)
                    ? e_uc_coherent_cmd
                    : e_uc_coherent_mem_fwd
                  : (mshr_r.flags.upgrade)
                    ? e_upgrade_stw_cmd
                    : (transfer_flag)
                      ? e_transfer
                      : e_resolve_speculation;
      end // e_write_next_state

      e_transfer: begin
        // Transfer required:
        // 1. write request: set state and transfer, invalidate owner, requestor to M
        // 2. read req w/ owner in O or F: transfer only
        // 3. read req w/ owner in M: set state, transfer, make owner O (dirty-shared)
        // 4. read req w/ owner in E: set state, transfer, writeback, make owner F (clean-shared)
        //    - WB required to ensure silent E->M is recorded
        fsm_cmd_v_lo = fsm_cmd_ready_then_li;

        fsm_cmd_header_lo.payload.dst_id = mshr_r.owner_lce_id;
        fsm_cmd_header_lo.payload.way_id = mshr_r.owner_way_id;

        fsm_cmd_header_lo.msg_type.cmd = mshr_r.flags.write_not_read | mshr_r.flags.cached_modified
                                         ? e_bedrock_cmd_st_tr
                                         : mshr_r.flags.cached_owned | mshr_r.flags.cached_forward
                                           ? e_bedrock_cmd_tr
                                           // transfer, not cached in M, O, or F -> cached in E
                                           : e_bedrock_cmd_st_tr_wb;

        fsm_cmd_header_lo.addr = mshr_r.paddr;

        // either Invalidate or Downgrade Owner, depending on request type
        // write request invalidates owner (can only have 1 writer!)
        // read request downgrades owner: M->O, E->F
        // else set state field to I in message, but it will not be used by LCE sending transfer
        fsm_cmd_header_lo.payload.state = mshr_r.flags.write_not_read
                                          ? e_COH_I
                                          : mshr_r.flags.cached_modified
                                            ? e_COH_O
                                            : mshr_r.flags.cached_exclusive
                                              ? e_COH_F
                                              : e_COH_I;

        // transfer information
        fsm_cmd_header_lo.payload.target = mshr_r.lce_id;
        fsm_cmd_header_lo.payload.target_way_id = mshr_r.lru_way_id;
        fsm_cmd_header_lo.payload.target_state = mshr_r.next_coh_state;

        // update state of owner in directory if required
        // transfer from owner in O or F does not require update to owner state
        dir_w_v = fsm_cmd_v_lo & fsm_cmd_ready_then_li
                  & (mshr_r.flags.write_not_read | mshr_r.flags.cached_modified | mshr_r.flags.cached_exclusive);
        dir_cmd = e_wds_op;
        dir_addr_li = mshr_r.paddr;
        dir_lce_li = mshr_r.owner_lce_id;
        dir_way_li = mshr_r.owner_way_id;
        dir_coh_state_li = mshr_r.flags.write_not_read
                           ? e_COH_I
                           : mshr_r.flags.cached_modified
                             ? e_COH_O
                             : mshr_r.flags.cached_exclusive
                               ? e_COH_F
                               : e_COH_I;

        // only transfer from owner in E for read miss requires a writeback
        state_n = fsm_cmd_v_lo
                  ? mshr_r.flags.cached_exclusive & ~mshr_r.flags.write_not_read
                    ? e_transfer_wb_resp
                    : e_resolve_speculation
                  : state_r;

      end // e_transfer

      e_transfer_wb_resp: begin
        state_n = wb_yumi_i ? e_resolve_speculation : state_r;
      end // e_transfer_wb_resp

      e_upgrade_stw_cmd: begin
        // r&v handshake
        fsm_cmd_v_lo = fsm_cmd_ready_then_li;

        fsm_cmd_header_lo.msg_type.cmd = e_bedrock_cmd_st_wakeup;
        fsm_cmd_header_lo.addr = mshr_r.paddr;
        fsm_cmd_header_lo.payload.dst_id = mshr_r.lce_id;
        fsm_cmd_header_lo.payload.way_id = mshr_r.way_id;
        fsm_cmd_header_lo.payload.state = mshr_r.next_coh_state;

        state_n = fsm_cmd_v_lo
                  ? e_resolve_speculation
                  : e_upgrade_stw_cmd;
      end // e_upgrade_stw_cmd

      e_resolve_speculation: begin
        // Resolve speculation
        if (transfer_flag | mshr_r.flags.upgrade) begin
          // squash speculative memory request if transfer or upgrade
          spec_w_v_o = 1'b1;
          // no longer speculative
          spec_v_o = 1'b1;
          spec_bits_o.spec = 1'b0;
          // squash the response
          spec_squash_v_o = 1'b1;
          spec_bits_o.squash = 1'b1;
        end else if (mshr_r.flags.write_not_read) begin
          // forward with M state
          spec_w_v_o = 1'b1;
          spec_v_o = 1'b1;
          spec_fwd_mod_v_o = 1'b1;
          spec_state_v_o = 1'b1;
          spec_bits_o.spec = 1'b0;
          spec_bits_o.state = e_COH_M;
          spec_bits_o.fwd_mod = 1'b1;
        end else if (mshr_r.flags.cached_shared | mshr_r.flags.non_exclusive) begin
          // forward with S state
          spec_w_v_o = 1'b1;
          spec_v_o = 1'b1;
          spec_fwd_mod_v_o = 1'b1;
          spec_state_v_o = 1'b1;
          spec_bits_o.spec = 1'b0;
          spec_bits_o.state = e_COH_S;
          spec_bits_o.fwd_mod = 1'b1;
        end else begin
          // forward with E state (as requested)
          spec_w_v_o = 1'b1;
          spec_v_o = 1'b1;
          spec_bits_o.spec = 1'b0;
        end
        state_n = e_ready;
      end // e_resolve_speculation

      // Process uncached request to coherent memory space
      e_uc_coherent_cmd: begin
        // at this point for amo/uncached request to coherent memory, the requesting LCE
        // has had block invalidated and written back if needed. All sharers (COH_S) blocks were
        // also invalidated. The owner now needs to be invalidated and written back (if required).

        fsm_cmd_v_lo = fsm_cmd_ready_then_li;

        fsm_cmd_header_lo.addr = mshr_r.paddr;
        fsm_cmd_header_lo.payload.dst_id = mshr_r.owner_lce_id;
        fsm_cmd_header_lo.payload.way_id = mshr_r.owner_way_id;
        fsm_cmd_header_lo.payload.state = e_COH_I;

        // either invalidate or set tag and writeback
        // if owner is in F state, block is clean, so only need to invalidate
        // else, block in E, M, or O, need to invalidate and writeback
        fsm_cmd_header_lo.msg_type.cmd = mshr_r.flags.cached_forward
                                         ? e_bedrock_cmd_inv
                                         : e_bedrock_cmd_st_wb;

        // update state of owner in directory
        dir_w_v = fsm_cmd_v_lo;
        dir_cmd = e_wds_op;
        dir_addr_li = mshr_r.paddr;
        dir_lce_li = mshr_r.owner_lce_id;
        dir_way_li = mshr_r.owner_way_id;
        dir_coh_state_li = e_COH_I;

        state_n = fsm_cmd_v_lo
                  ? e_uc_coherent_resp
                  : state_r;
      end // e_uc_coherent_cmd

      // amo/uc wait for replacement writeback or invalidation ack if sent
      // writeback is forwarded to memory by LCE response module
      e_uc_coherent_resp: begin
        state_n = (wb_yumi_i | inv_yumi_i)
                  ? e_uc_coherent_mem_fwd
                  : state_r;
      end // e_uc_coherent_resp

      // amo/uc after inv_ack/wb_response, issue op to memory
      // writes pending bit
      e_uc_coherent_mem_fwd: begin
        fsm_fwd_v_lo = fsm_fwd_ready_then_li & fsm_req_v_li;
        fsm_req_yumi_lo = fsm_fwd_v_lo;

        // set message type based on request message type
        unique case (fsm_req_header_li.msg_type.req)
          e_bedrock_req_uc_wr: fsm_fwd_header_lo.msg_type = e_bedrock_mem_wr;
          e_bedrock_req_uc_amo: fsm_fwd_header_lo.msg_type = e_bedrock_mem_amo;
          // e_bedrock_req_uc_rd:
          default: fsm_fwd_header_lo.msg_type = e_bedrock_mem_rd;
        endcase

        // uncached/amo address must be aligned appropriate to the request size
        // in the LCE request (which is stored in the MSHR)
        fsm_fwd_header_lo.subop = mshr_r.msg_subop;
        fsm_fwd_header_lo.addr = mshr_r.paddr;
        fsm_fwd_header_lo.size = mshr_r.msg_size;
        // TODO: uncomment/modify when implementing atomics
        //fsm_fwd_header_lo.amo_no_return = mshr_r.flags.atomic_no_return;
        fsm_fwd_header_lo.payload.lce_id = mshr_r.lce_id;
        fsm_fwd_header_lo.payload.way_id = '0;
        fsm_fwd_header_lo.payload.src_did = mshr_r.src_did;
        // this op is uncached in LCE for both amo or uncached requests
        fsm_fwd_header_lo.payload.uncached = 1'b1;
        fsm_fwd_data_lo = fsm_req_data_li;

        // Do NOT write pending bit for this memory command.
        // Uncached requests to coherent memory write the pending bit when they are processed
        // by the pending module. This write is associated with the required memory command
        // that every uncached memory access performs. The memory response will decrement
        // the pending bit when it returns, thereby closing the request and allowing the next
        // request to proceed (uncached requests do not have an ack back to the CCE from the LCE
        // so the best we can do for ordering is ensure the data is on its way to the LCE before
        // moving on).

        // if last beat is acked, check if pending write happened
        state_n = (fsm_req_yumi_lo & fsm_req_last_li)
                  ? e_ready
                  : state_r;

      end // e_uc_coherent_mem_fwd

      e_error: begin
        state_n = state_r;
      end // e_error

      default: begin
        // use defaults above
      end

    endcase

    // Pending bit write arbitration
    // do this after the FSM code so that pending_w_v can be examined to determine if FSM is writing
    // the pending bits
    // arbitration order (high to low): FSM, mem_rev, mem_fwd, lce_resp
    mem_rev_pending_w_yumi_o = 1'b0;
    lce_resp_pending_w_yumi_o = 1'b0;
    if (~pending_w_v) begin
      if (mem_rev_pending_w_v_i) begin
        pending_w_v = mem_rev_pending_w_v_i;
        pending_w_addr_bypass_hash = mem_rev_pending_w_addr_bypass_hash_i;
        pending_up = mem_rev_pending_up_i;
        pending_down = mem_rev_pending_down_i;
        pending_clear = mem_rev_pending_clear_i;
        pending_w_addr = mem_rev_pending_w_addr_i;
        mem_rev_pending_w_yumi_o = pending_w_yumi;
      end
      else if (lce_resp_pending_w_v_i) begin
        pending_w_v = lce_resp_pending_w_v_i;
        pending_w_addr_bypass_hash = lce_resp_pending_w_addr_bypass_hash_i;
        pending_up = lce_resp_pending_up_i;
        pending_down = lce_resp_pending_down_i;
        pending_clear = lce_resp_pending_clear_i;
        pending_w_addr = lce_resp_pending_w_addr_i;
        lce_resp_pending_w_yumi_o = pending_w_yumi;
      end
    end

  end // always_comb

  // Sequential Logic
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      state_r <= e_reset;
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
  end // always_ff

  //synopsys translate_off
  always_ff @(negedge clk_i) begin
    if (~reset_i) begin
      assert(state_n != e_error) else
        $display("Error!: moving to e_error from %0s", state_r.name());
    end
  end
  //synopsys translate_on

endmodule
