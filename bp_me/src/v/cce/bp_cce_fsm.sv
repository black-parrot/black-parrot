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
 *   Atomics in L2/Mem will be supported in a future change.
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
    , localparam cfg_bus_width_lp          = `bp_cfg_bus_width(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)

    // maximal number of tag sets stored in the directory for all LCE types
    , localparam max_tag_sets_lp           = `BSG_CDIV(lce_sets_p, num_cce_p)
    , localparam lg_max_tag_sets_lp        = `BSG_SAFE_CLOG2(max_tag_sets_lp)

    // interface widths
    `declare_bp_bedrock_lce_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)

    , localparam counter_max = 256
    , localparam hash_index_width_lp=$clog2((2**lg_lce_sets_lp+num_cce_p-1)/num_cce_p)

    , localparam counter_width_lp = `BSG_SAFE_CLOG2(counter_max+1)

    // log2 of dword width bytes
    , localparam lg_dword_width_bytes_lp = `BSG_SAFE_CLOG2(dword_width_gp/8)

    // stream pump
    , localparam stream_words_lp = cce_block_width_p / dword_width_gp
    , localparam data_len_width_lp = `BSG_SAFE_CLOG2(stream_words_lp)
  )
  (input                                            clk_i
   , input                                          reset_i

   // Config channel
   , input [cfg_bus_width_lp-1:0]                   cfg_bus_i

   // LCE-CCE Interface
   // BedRock Burst protocol: ready&valid
   , input [lce_req_msg_header_width_lp-1:0]        lce_req_header_i
   , input                                          lce_req_header_v_i
   , output logic                                   lce_req_header_ready_and_o
   , input                                          lce_req_has_data_i
   , input [dword_width_gp-1:0]                     lce_req_data_i
   , input                                          lce_req_data_v_i
   , output logic                                   lce_req_data_ready_and_o
   , input                                          lce_req_last_i

   , input [lce_resp_msg_header_width_lp-1:0]       lce_resp_header_i
   , input                                          lce_resp_header_v_i
   , output logic                                   lce_resp_header_ready_and_o
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
   // BedRock Stream protocol: ready&valid
   , input [cce_mem_msg_header_width_lp-1:0]        mem_resp_header_i
   , input [dword_width_gp-1:0]                     mem_resp_data_i
   , input                                          mem_resp_v_i
   , output logic                                   mem_resp_ready_and_o
   , input                                          mem_resp_last_i

   , output logic [cce_mem_msg_header_width_lp-1:0] mem_cmd_header_o
   , output logic [dword_width_gp-1:0]              mem_cmd_data_o
   , output logic                                   mem_cmd_v_o
   , input                                          mem_cmd_ready_and_i
   , output logic                                   mem_cmd_last_o
   );

  // Define structure variables for output queues
  `declare_bp_bedrock_lce_if(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce);
  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce);

  // LCE-CCE Interface structs
  bp_bedrock_lce_req_msg_header_s  lce_req;
  bp_bedrock_lce_resp_msg_header_s lce_resp;
  bp_bedrock_lce_cmd_msg_header_s  lce_cmd;
  assign lce_cmd_header_o = lce_cmd;

  // lce request header buffer
  logic lce_req_v, lce_req_yumi;
  bsg_two_fifo
    #(.width_p(lce_req_msg_header_width_lp))
    lce_req_buffer
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.ready_o(lce_req_header_ready_and_o)
      ,.data_i(lce_req_header_i)
      ,.v_i(lce_req_header_v_i)
      ,.v_o(lce_req_v)
      ,.data_o(lce_req)
      ,.yumi_i(lce_req_yumi)
      );

  // lce response header buffer
  logic lce_resp_v, lce_resp_yumi;
  bsg_two_fifo
    #(.width_p(lce_resp_msg_header_width_lp))
    lce_resp_buffer
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.ready_o(lce_resp_header_ready_and_o)
      ,.data_i(lce_resp_header_i)
      ,.v_i(lce_resp_header_v_i)
      ,.v_o(lce_resp_v)
      ,.data_o(lce_resp)
      ,.yumi_i(lce_resp_yumi)
      );

  // Memory Response Stream Pump
  bp_bedrock_cce_mem_msg_header_s mem_resp_base_header_li;
  bp_bedrock_cce_mem_payload_s mem_resp_payload_li;
  assign mem_resp_payload_li = mem_resp_base_header_li.payload;
  logic mem_resp_v_li, mem_resp_yumi_lo;
  logic mem_resp_stream_new_li, mem_resp_stream_last_li, mem_resp_stream_done_li;
  logic [paddr_width_p-1:0] mem_resp_addr_li;
  logic [dword_width_gp-1:0] mem_resp_data_li;
  bp_me_stream_pump_in
    #(.bp_params_p(bp_params_p)
      ,.stream_data_width_p(dword_width_gp)
      ,.block_width_p(cce_block_width_p)
      ,.payload_width_p(cce_mem_payload_width_lp)
      ,.msg_stream_mask_p(mem_resp_payload_mask_gp)
      ,.fsm_stream_mask_p(mem_resp_payload_mask_gp)
      // provide buffer space for two 8-beat long data carrying messages
      ,.buffer_els_p(16)
      )
    mem_resp_stream_pump
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // from memory response input
      ,.msg_header_i(mem_resp_header_i)
      ,.msg_data_i(mem_resp_data_i)
      ,.msg_v_i(mem_resp_v_i)
      ,.msg_last_i(mem_resp_last_i)
      ,.msg_ready_and_o(mem_resp_ready_and_o)
      // to FSM CCE
      ,.fsm_base_header_o(mem_resp_base_header_li)
      ,.fsm_addr_o(mem_resp_addr_li)
      ,.fsm_data_o(mem_resp_data_li)
      ,.fsm_v_o(mem_resp_v_li)
      ,.fsm_yumi_i(mem_resp_yumi_lo)
      ,.fsm_new_o(mem_resp_stream_new_li)
      ,.fsm_last_o(mem_resp_stream_last_li)
      ,.fsm_done_o(mem_resp_stream_done_li)
      );

  // Memory Command Stream Pump
  bp_bedrock_cce_mem_msg_header_s mem_cmd_base_header_lo;
  bp_bedrock_cce_mem_payload_s mem_cmd_payload_lo;
  logic mem_cmd_v_lo, mem_cmd_ready_and_li;
  logic mem_cmd_stream_new_li, mem_cmd_stream_done_li;
  logic [dword_width_gp-1:0] mem_cmd_data_lo;
  logic [data_len_width_lp-1:0] mem_cmd_stream_cnt_li;
  bp_me_stream_pump_out
    #(.bp_params_p(bp_params_p)
      ,.stream_data_width_p(dword_width_gp)
      ,.block_width_p(cce_block_width_p)
      ,.payload_width_p(cce_mem_payload_width_lp)
      ,.msg_stream_mask_p(mem_cmd_payload_mask_gp)
      ,.fsm_stream_mask_p(mem_cmd_payload_mask_gp)
      )
    mem_cmd_stream_pump
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // to memory command output
      ,.msg_header_o(mem_cmd_header_o)
      ,.msg_data_o(mem_cmd_data_o)
      ,.msg_v_o(mem_cmd_v_o)
      ,.msg_last_o(mem_cmd_last_o)
      ,.msg_ready_and_i(mem_cmd_ready_and_i)
      // from FSM CCE
      ,.fsm_base_header_i(mem_cmd_base_header_lo)
      ,.fsm_data_i(mem_cmd_data_lo)
      ,.fsm_v_i(mem_cmd_v_lo)
      ,.fsm_ready_and_o(mem_cmd_ready_and_li)
      ,.fsm_cnt_o(mem_cmd_stream_cnt_li)
      ,.fsm_new_o(mem_cmd_stream_new_li)
      ,.fsm_done_o(mem_cmd_stream_done_li)
      );

  // Config bus
  `declare_bp_cfg_bus_s(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  bp_cfg_bus_s cfg_bus_cast_i;
  assign cfg_bus_cast_i = cfg_bus_i;
  wire cce_normal_mode_li = (cfg_bus_cast_i.cce_mode == e_cce_mode_normal);
  logic cce_normal_mode_r, cce_normal_mode_n;

  // MSHR
  `declare_bp_cce_mshr_s(lce_id_width_p, lce_assoc_p, paddr_width_p);
  bp_cce_mshr_s mshr_r, mshr_n;
  wire [paddr_width_p-1:0] mshr_r_paddr_aligned = (mshr_r.paddr >> lg_block_size_in_bytes_lp) << lg_block_size_in_bytes_lp;

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

  // CCE PMA - LCE requests
  logic req_pma_cacheable_addr_lo;
  bp_cce_pma
    #(.bp_params_p(bp_params_p)
      )
    req_pma
      (.paddr_i(lce_req.addr)
       ,.paddr_v_i(lce_req_v)
       ,.cacheable_addr_o(req_pma_cacheable_addr_lo)
       );

  //synopsys translate_off
  always @(negedge clk_i) begin
    if (~reset_i) begin
      // Cacheable requests must target cacheable memory
      assert(!(lce_req_v && ~req_pma_cacheable_addr_lo
               && ((lce_req.msg_type.req == e_bedrock_req_rd_miss)
                   || (lce_req.msg_type.req == e_bedrock_req_wr_miss))
              )
            ) else
      $error("CCE PMA violation - cacheable requests must target cacheable memory");
    end
  end
  //synopsys translate_on

  // CCE PMA - Mem responses
  logic resp_pma_cacheable_addr_lo;
  bp_cce_pma
    #(.bp_params_p(bp_params_p)
      )
    resp_pma
      (.paddr_i(mem_resp_base_header_li.addr)
       ,.paddr_v_i(mem_resp_v_li)
       ,.cacheable_addr_o(resp_pma_cacheable_addr_lo)
       );

  typedef enum logic [5:0] {
    e_reset
    , e_clear_dir
    , e_uncached_only
    , e_uncached_only_data
    , e_send_sync
    , e_sync_ack
    , e_ready

    , e_uncached_req
    , e_uncached_data
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

  typedef enum logic [2:0] {
    e_mem_resp_reset
    , e_mem_resp_ready
    , e_mem_resp_send_data
    , e_mem_resp_drain_data
  } mem_resp_state_e;

  mem_resp_state_e mem_resp_state_r, mem_resp_state_n;

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

  // memory command/response counter
  logic [`BSG_WIDTH(mem_noc_max_credits_p)-1:0] mem_credit_count_lo;
  bsg_flow_counter
    #(.els_p(mem_noc_max_credits_p)
      // memory command increments on done singal from stream pump
      ,.ready_THEN_valid_p(1)
      )
    mem_credit_counter
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // memory commands consume credits
      ,.v_i(mem_cmd_stream_done_li)
      ,.ready_i(1'b0) // unused due to ready_then_valid param
      // memory responses return credits
      ,.yumi_i(mem_resp_stream_done_li)
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
       ,.r_v_i(mem_resp_v_li & mem_resp_payload_li.speculative)
       ,.r_addr_i(mem_resp_base_header_li.addr)
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

  wire lce_resp_coh_ack_yumi = lce_resp_v & (lce_resp.msg_type.resp == e_bedrock_resp_coh_ack) & ~pending_busy;

  // transfer occurs if any cache has block in E, M, O, or F (ownerhsip states)
  wire transfer_flag = (mshr_r.flags[e_opd_cef] | mshr_r.flags[e_opd_cmf]
                        | mshr_r.flags[e_opd_cof] | mshr_r.flags[e_opd_cff]);
  // invalidations occur if write request and any blcok in S state (shared, not owner)
  // owner does not need to be invalidated; owner state is changed by the st_tr or st_tr_wb command
  wire invalidate_flag = (mshr_r.flags[e_opd_rqf] & mshr_r.flags[e_opd_csf]);

  always_comb begin
    state_n = state_r;
    mem_resp_state_n = mem_resp_state_r;
    mshr_n = mshr_r;
    sharers_ways_n = sharers_ways_r;
    sharers_hits_n = sharers_hits_r;
    pe_sharers_n = pe_sharers_r;
    cce_normal_mode_n = cce_normal_mode_r;

    // memory response stream pump
    mem_resp_yumi_lo = '0;

    // memory command stream pump
    mem_cmd_base_header_lo = '0;
    mem_cmd_v_lo = '0;
    mem_cmd_data_lo = '0;
    mem_cmd_payload_lo = '0;

    // LCE request and response input control
    lce_req_yumi = '0;
    lce_req_data_ready_and_o = '0;
    lce_resp_yumi = '0;
    lce_resp_data_ready_and_o = '0;

    // LCE command output control
    lce_cmd = '0;
    lce_cmd_header_v_o = '0;
    lce_cmd_data_o = '0;
    lce_cmd_data_v_o = '0;
    lce_cmd.payload.src_id = cfg_bus_cast_i.cce_id;
    lce_cmd_last_o = '0;
    lce_cmd_has_data_o = '0;

    // up down counter
    cnt_inc = '0;
    cnt_dec = '0;
    cnt_rst = '0;

    cnt_1_clr = '0;
    cnt_1_inc = '0;
    cnt_0_clr = '0;
    cnt_0_inc = '0;

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

    // Mem Response auto-processing and forwarding to LCE Command logic
    // The pending bit is written when the LCE Command header sends.
    // The main FSM will stall if it wants to write to the pending bits in the same cycle.
    case (mem_resp_state_r)
      e_mem_resp_reset: begin
        mem_resp_state_n = e_mem_resp_ready;
      end
      e_mem_resp_ready: begin
        if (mem_resp_v_li) begin

          // Speculative access response
          // Note: speculative access is only supported for cached requests
          if (mem_resp_payload_li.speculative) begin

            if (spec_bits_lo.spec) begin // speculation not resolved yet
              // do nothing, wait for speculation to be resolved
              // Note: this blocks memory responses behind the speculative response from being
              // forwarded. However, the CCE will not move on to a new LCE request until it
              // resolves the speculation for the current request.
            end // speculative bit sill set

            else if (spec_bits_lo.squash) begin // speculation resolved, squash
              // ack the first beat of the memory response since it doesn't need to be split
              // into header and data, and do nothing with it
              mem_resp_yumi_lo = mem_resp_v_li;

              // decrement pending bit on mem response dequeue
              pending_busy = mem_resp_yumi_lo;
              pending_w_v = mem_resp_yumi_lo;
              pending_w_addr = mem_resp_base_header_li.addr;
              pending_li = 1'b0;
              // if first beat is not last, drain remaining beats
              mem_resp_state_n = (mem_resp_yumi_lo & ~mem_resp_stream_last_li)
                                 ? e_mem_resp_drain_data
                                 : e_mem_resp_ready;

            end // squash

            else if (spec_bits_lo.fwd_mod) begin // speculation resolved, forward with modified state
              // forward the header this cycle
              // forward data next cycle(s)

              // inform ucode decode that this unit is using the LCE Command network
              lce_cmd_busy = 1'b1;

              // send LCE command header, but don't ack the mem response beat since its data
              // will send after the header sends.
              lce_cmd_header_v_o = mem_resp_v_li;
              lce_cmd_has_data_o = 1'b1;

              // command header
              lce_cmd.msg_type = e_bedrock_cmd_data;
              lce_cmd.addr = mem_resp_base_header_li.addr;
              lce_cmd.size = mem_resp_base_header_li.size;

              // command payload
              // modify the coherence state
              lce_cmd.payload.dst_id = mem_resp_payload_li.lce_id;
              lce_cmd.payload.way_id = mem_resp_payload_li.way_id;
              lce_cmd.payload.state = bp_coh_states_e'(spec_bits_lo.state);

              // decrement pending bit on lce cmd header send
              pending_busy = lce_cmd_header_v_o & lce_cmd_header_ready_and_i;
              pending_w_v = lce_cmd_header_v_o & lce_cmd_header_ready_and_i;
              pending_w_addr = mem_resp_base_header_li.addr;
              pending_li = 1'b0;

              // send data next cycle, after header sends
              mem_resp_state_n = (lce_cmd_header_v_o & lce_cmd_header_ready_and_i)
                                 ? e_mem_resp_send_data
                                 : e_mem_resp_ready;

            end // fwd_mod

            else begin // speculation resolved, forward unmodified
              // forward the header this cycle
              // forward data next cycle(s)

              // inform ucode decode that this unit is using the LCE Command network
              lce_cmd_busy = 1'b1;

              // send LCE command header, but don't ack the mem response beat since its data
              // will send after the header sends.
              lce_cmd_header_v_o = mem_resp_v_li;
              lce_cmd_has_data_o = 1'b1;

              // command header
              lce_cmd.msg_type = e_bedrock_cmd_data;
              lce_cmd.addr = mem_resp_base_header_li.addr;
              lce_cmd.size = mem_resp_base_header_li.size;

              // command payload
              lce_cmd.payload.dst_id = mem_resp_payload_li.lce_id;
              lce_cmd.payload.way_id = mem_resp_payload_li.way_id;
              lce_cmd.payload.state = mem_resp_payload_li.state;

              // decrement pending bit on lce cmd header send
              pending_busy = lce_cmd_header_v_o & lce_cmd_header_ready_and_i;
              pending_w_v = lce_cmd_header_v_o & lce_cmd_header_ready_and_i;
              pending_w_addr = mem_resp_base_header_li.addr;
              pending_li = 1'b0;

              // send data next cycle, after header sends
              mem_resp_state_n = (lce_cmd_header_v_o & lce_cmd_header_ready_and_i)
                                 ? e_mem_resp_send_data
                                 : e_mem_resp_ready;

            end // forward unmodified

          end // speculative response

          // non-speculative memory access, forward directly to LCE
          else if (mem_resp_base_header_li.msg_type == e_bedrock_mem_rd) begin
            // forward the header this cycle
            // forward data next cycle(s)

            // inform ucode decode that this unit is using the LCE Command network
            lce_cmd_busy = 1'b1;

            // send LCE command header, but don't ack the mem response beat since its data
            // will send after the header sends.
            lce_cmd_header_v_o = mem_resp_v_li;
            lce_cmd_has_data_o = 1'b1;

            // command header
            lce_cmd.msg_type = e_bedrock_cmd_data;
            lce_cmd.addr = mem_resp_base_header_li.addr;
            lce_cmd.size = mem_resp_base_header_li.size;

            // command payload
            lce_cmd.payload.dst_id = mem_resp_payload_li.lce_id;
            lce_cmd.payload.way_id = mem_resp_payload_li.way_id;
            lce_cmd.payload.state = mem_resp_payload_li.state;

            // decrement pending bit on mem response dequeue (same as lce cmd send)
            pending_busy = lce_cmd_header_v_o & lce_cmd_header_ready_and_i;
            pending_w_v = lce_cmd_header_v_o & lce_cmd_header_ready_and_i;
            pending_w_addr = mem_resp_base_header_li.addr;
            pending_li = 1'b0;

            // send data next cycle, after header sends
            mem_resp_state_n = (lce_cmd_header_v_o & lce_cmd_header_ready_and_i)
                               ? e_mem_resp_send_data
                               : e_mem_resp_ready;

          end // rd, wr miss from LCE

          // Uncached load response - forward data to LCE
          else if (mem_resp_base_header_li.msg_type == e_bedrock_mem_uc_rd) begin
            // forward the header this cycle
            // forward data next cycle(s)

            // inform ucode decode that this unit is using the LCE Command network
            lce_cmd_busy = 1'b1;

            // send LCE command header, but don't ack the mem response beat since its data
            // will send after the header sends.
            lce_cmd_header_v_o = mem_resp_v_li;
            lce_cmd_has_data_o = 1'b1;

            // command header
            lce_cmd.msg_type = e_bedrock_cmd_uc_data;
            lce_cmd.addr = mem_resp_base_header_li.addr;
            lce_cmd.size = mem_resp_base_header_li.size;

            // command payload
            lce_cmd.payload.dst_id = mem_resp_payload_li.lce_id;

            // send data next cycle, after header sends
            mem_resp_state_n = (lce_cmd_header_v_o & lce_cmd_header_ready_and_i)
                               ? e_mem_resp_send_data
                               : e_mem_resp_ready;

            // decrement pending bits if operating in normal mode and request was made
            // to coherent memory space
            pending_busy = (lce_cmd_header_v_o & lce_cmd_header_ready_and_i) & cce_normal_mode_r & resp_pma_cacheable_addr_lo;
            pending_w_v = (lce_cmd_header_v_o & lce_cmd_header_ready_and_i) & cce_normal_mode_r & resp_pma_cacheable_addr_lo;
            pending_w_addr = mem_resp_base_header_li.addr;
            pending_li = 1'b0;

          end // uc_rd

          // Uncached store response, send UC Store Done to requesting LCE
          else if (mem_resp_base_header_li.msg_type == e_bedrock_mem_uc_wr) begin
            // UC Store Done is header only, dequeue memory response when LCE command header sends

            // inform ucode decode that this unit is using the LCE Command network
            lce_cmd_busy = 1'b1;

            // handshaking
            // r&v for LCE command header
            // valid->yumi for mem response header
            lce_cmd_header_v_o = mem_resp_v_li;
            lce_cmd_has_data_o = 1'b0;
            mem_resp_yumi_lo = mem_resp_v_li & lce_cmd_header_ready_and_i;

            // command header
            lce_cmd.msg_type = e_bedrock_cmd_uc_st_done;
            lce_cmd.addr = mem_resp_base_header_li.addr;
            // leave size as '0 equivalent, no data in this message

            // command payload
            lce_cmd.payload.dst_id = mem_resp_payload_li.lce_id;

            // decrement pending bits if operating in normal mode and request was made
            // to coherent memory space
            pending_busy = mem_resp_yumi_lo & cce_normal_mode_r & resp_pma_cacheable_addr_lo;
            pending_w_v = mem_resp_yumi_lo & cce_normal_mode_r & resp_pma_cacheable_addr_lo;
            pending_w_addr = mem_resp_base_header_li.addr;
            pending_li = 1'b0;

          end // uc_wr

          // Dequeue memory writeback response, don't do anything with it
          // decrement pending bit
          // also set pending_busy to block FSM if needed
          else if (mem_resp_base_header_li.msg_type == e_bedrock_mem_wr) begin

            mem_resp_yumi_lo = mem_resp_v_li;
            pending_busy = mem_resp_yumi_lo;
            pending_w_v = mem_resp_yumi_lo;
            pending_w_addr = mem_resp_base_header_li.addr;
            pending_li = 1'b0;

          end // wb

        end // mem_resp handling
      end
      e_mem_resp_send_data: begin
        // send data
        // last send occurs when cnt is one
        lce_cmd_busy = 1'b1;
        lce_cmd_data_o = mem_resp_data_li;
        lce_cmd_data_v_o = mem_resp_v_li;
        lce_cmd_last_o = mem_resp_stream_last_li;
        // consume beat when data sends on LCE command
        mem_resp_yumi_lo = mem_resp_v_li & lce_cmd_data_ready_and_i;
        mem_resp_state_n = (mem_resp_stream_done_li)
                           ? e_mem_resp_ready
                           : e_mem_resp_send_data;

      end
      e_mem_resp_drain_data: begin
        // when a speculative read is squashed, its data must be drained
        mem_resp_yumi_lo = mem_resp_v_li;
        mem_resp_state_n = (mem_resp_stream_done_li)
                           ? e_mem_resp_ready
                           : e_mem_resp_drain_data;

      end
      default: begin
        // do nothing
      end
    endcase // memory response auto forwarding

    // Dequeue coherence ack when it arrives
    // Does not conflict with other dequeues of LCE Response
    // Decrements pending bit on arrival, so arbitrate with memory ports for access
    if (lce_resp_v & (lce_resp.msg_type.resp == e_bedrock_resp_coh_ack) & ~pending_busy) begin
        lce_resp_yumi = lce_resp_v;
        // inform FSM that pending bit is being used
        pending_busy = lce_resp_yumi;
        pending_w_v = lce_resp_yumi;
        pending_w_addr = lce_resp.addr;
        pending_li = 1'b0;
    end

    // FSM
    case (state_r)
      e_reset: begin
        state_n = e_clear_dir;
        cce_normal_mode_n = 1'b0;
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
        // clear the counters
        cnt_0_clr = 1'b1;
        cnt_1_clr = 1'b1;
        cnt_rst = 1'b1;

        state_n = e_uncached_only;

        // transition to normal/coherent operation as soon as config bus indicates
        if (cce_normal_mode_li) begin
          state_n = e_send_sync;

        // only issue memory command if memory credit is available
        // only process uncached requests
        // cached requests will stall on the input port
        // cached requests not allowed, go to error state and stall
        end else if (lce_req_v
            & ((lce_req.msg_type.req == e_bedrock_req_rd_miss)
               | (lce_req.msg_type.req == e_bedrock_req_wr_miss))) begin
          state_n = e_error;

        // uncached store
        end else if (lce_req_v & (lce_req.msg_type.req == e_bedrock_req_uc_wr)) begin
          // first beat of memory command must include data
          // handshake is r&v on both LCE request header and memory command stream, and
          // valid->yumi on LCE request data
          mem_cmd_v_lo = lce_req_v & lce_req_data_v_i & ~mem_credits_empty;
          lce_req_data_ready_and_o = mem_cmd_ready_and_li;
          // LCE request header is only dequeued if stream pump indicates stream is done
          lce_req_yumi = mem_cmd_v_lo & mem_cmd_ready_and_li & mem_cmd_stream_done_li;

          // form message
          mem_cmd_base_header_lo.addr = lce_req.addr;
          mem_cmd_base_header_lo.size = lce_req.size;
          mem_cmd_base_header_lo.msg_type.mem = e_bedrock_mem_uc_wr;
          mem_cmd_payload_lo.lce_id = lce_req.payload.src_id;
          mem_cmd_payload_lo.uncached = 1'b1;
          mem_cmd_base_header_lo.payload = mem_cmd_payload_lo;
          mem_cmd_data_lo = lce_req_data_i;

          state_n = (mem_cmd_v_lo & mem_cmd_ready_and_li) & ~mem_cmd_stream_done_li
                    ? e_uncached_only_data : e_uncached_only;

        end // uncached store

        // uncached load
        else if (lce_req_v & (lce_req.msg_type.req == e_bedrock_req_uc_rd)) begin
          // uncached load has no data
          mem_cmd_v_lo = lce_req_v & ~mem_credits_empty;
          lce_req_yumi = mem_cmd_v_lo & mem_cmd_ready_and_li & mem_cmd_stream_done_li;

          mem_cmd_base_header_lo.addr = lce_req.addr;
          mem_cmd_base_header_lo.size = lce_req.size;
          mem_cmd_payload_lo.lce_id = lce_req.payload.src_id;
          mem_cmd_payload_lo.uncached = 1'b1;
          mem_cmd_base_header_lo.payload = mem_cmd_payload_lo;
          mem_cmd_base_header_lo.msg_type.mem = e_bedrock_mem_uc_rd;

        end // uncached load

        // TODO: add amo support here

      end // e_uncached_only

      e_uncached_only_data: begin
        if (lce_req_v) begin
          // send data
          mem_cmd_v_lo = lce_req_v & lce_req_data_v_i & ~mem_credits_empty;
          lce_req_data_ready_and_o = mem_cmd_ready_and_li;
          // LCE request header is only dequeued if stream pump indicates stream is done
          lce_req_yumi = mem_cmd_v_lo & mem_cmd_ready_and_li & mem_cmd_stream_done_li;

          // form message
          mem_cmd_base_header_lo.addr = lce_req.addr;
          mem_cmd_base_header_lo.size = lce_req.size;
          mem_cmd_base_header_lo.msg_type.mem = e_bedrock_mem_uc_wr;
          mem_cmd_payload_lo.lce_id = lce_req.payload.src_id;
          mem_cmd_payload_lo.uncached = 1'b1;
          mem_cmd_base_header_lo.payload = mem_cmd_payload_lo;
          mem_cmd_data_lo = lce_req_data_i;

          state_n = mem_cmd_stream_done_li
                    ? e_uncached_only
                    : e_uncached_only_data;
        end

      end // e_uncached_only_data

      e_send_sync: begin
        // register that normal mode is active (can still be doing sync) and all outstanding
        // uncached accesses are complete
        cce_normal_mode_n = (~cce_normal_mode_r & mem_credits_full)
                            ? 1'b1
                            : cce_normal_mode_r;

        // after first entering e_send_sync from e_uncached_only, wait for all oustanding uncached
        // accesses to complete before sending first sync commnad
        if (mem_credits_full & ~lce_cmd_busy) begin
          lce_cmd_header_v_o = 1'b1;
          lce_cmd_has_data_o = 1'b0;

          lce_cmd.msg_type.cmd = e_bedrock_cmd_sync;
          lce_cmd.payload.dst_id[0+:lg_num_lce_lp] = cnt_1[0+:lg_num_lce_lp];

          state_n = (lce_cmd_header_v_o & lce_cmd_header_ready_and_i) ? e_sync_ack : e_send_sync;
          cnt_1_inc = lce_cmd_header_v_o & lce_cmd_header_ready_and_i;

        end
      end // e_send_sync

      e_sync_ack: begin
        if (~lce_resp_coh_ack_yumi) begin
          lce_resp_yumi = lce_resp_v;
          state_n = (lce_resp_v)
                    ? (cnt_0 == (num_lce_p-1))
                      ? e_ready
                      : e_send_sync
                    : e_sync_ack;
          state_n = (lce_resp_v & (lce_resp.msg_type.resp != e_bedrock_resp_sync_ack))
                    ? e_error
                    : state_n;
          cnt_0_clr = (state_n == e_ready);
          cnt_0_inc = lce_resp_v & ~cnt_0_clr;
          cnt_1_clr = (state_n == e_ready);
        end
      end // e_sync_ack

      e_ready: begin
        // clear the MSHR
        mshr_n = '0;
        // clear the ack counter
        cnt_0_clr = 1'b1;
        cnt_1_clr = 1'b1;
        cnt_rst = 1'b1;

        if (lce_req_v) begin
          mshr_n.lce_id = lce_req.payload.src_id;
          state_n = e_error;
          // cached request
          if (lce_req.msg_type.req == e_bedrock_req_rd_miss
              | lce_req.msg_type.req == e_bedrock_req_wr_miss) begin

            mshr_n.paddr = lce_req.addr;
            mshr_n.msg_size = lce_req.size;
            mshr_n.lru_way_id = lce_req.payload.lru_way_id;
            mshr_n.flags[e_opd_rqf] = (lce_req.msg_type.req == e_bedrock_req_wr_miss);
            mshr_n.flags[e_opd_nerf] = lce_req.payload.non_exclusive;

            // query PMA for coherence property - it is a violation for a cached request
            // to be incoherent.
            mshr_n.flags[e_opd_rcf] = req_pma_cacheable_addr_lo;

            state_n = ~req_pma_cacheable_addr_lo
                      ? e_error
                      : e_read_pending;

          // uncached request
          end else if (lce_req.msg_type.req == e_bedrock_req_uc_rd
                       | lce_req.msg_type.req == e_bedrock_req_uc_wr) begin

            mshr_n.paddr = lce_req.addr;
            mshr_n.msg_size = lce_req.size;
            mshr_n.flags[e_opd_ucf] = 1'b1;
            mshr_n.flags[e_opd_rqf] = (lce_req.msg_type.req == e_bedrock_req_uc_wr);

            // query PMA for coherence property
            // uncached requests can be made to coherent or incoherent memory regions
            mshr_n.flags[e_opd_rcf] = req_pma_cacheable_addr_lo;

            // a coherent, but uncached request must serialize with other coherent operations
            // using the pending bits
            state_n = req_pma_cacheable_addr_lo
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

        // uncached store
        if (mshr_r.flags[e_opd_rqf]) begin
          // first beat of memory command must include data
          // handshake is r&v on both LCE request header and memory command stream, and
          // valid->yumi on LCE request data
          mem_cmd_v_lo = lce_req_v & lce_req_data_v_i & ~mem_credits_empty;
          lce_req_data_ready_and_o = mem_cmd_ready_and_li;
          // LCE request header is only dequeued if stream pump indicates stream is done
          lce_req_yumi = mem_cmd_v_lo & mem_cmd_ready_and_li & mem_cmd_stream_done_li;

          // form message
          mem_cmd_base_header_lo.addr = mshr_r.paddr;
          mem_cmd_base_header_lo.size = mshr_r.msg_size;
          mem_cmd_base_header_lo.msg_type.mem = e_bedrock_mem_uc_wr;
          mem_cmd_payload_lo.lce_id = mshr_r.lce_id;
          mem_cmd_payload_lo.uncached = 1'b1;
          mem_cmd_base_header_lo.payload = mem_cmd_payload_lo;
          mem_cmd_data_lo = lce_req_data_i;

          // if mem command is acked, check if stream is done or not to determine if need to
          // send additional data. If command is not acked, try again next cycle.
          state_n = (mem_cmd_v_lo & mem_cmd_ready_and_li)
                    ? mem_cmd_stream_done_li
                      ? e_ready
                      : e_uncached_data
                    : e_uncached_req;

        end // uncached store

        // uncached load
        else begin
          // uncached load has no data
          mem_cmd_v_lo = lce_req_v & ~mem_credits_empty;
          lce_req_yumi = mem_cmd_v_lo & mem_cmd_ready_and_li & mem_cmd_stream_done_li;

          mem_cmd_base_header_lo.addr = mshr_r.paddr;
          mem_cmd_base_header_lo.size = mshr_r.msg_size;
          mem_cmd_base_header_lo.msg_type.mem = e_bedrock_mem_uc_rd;
          mem_cmd_payload_lo.lce_id = mshr_r.lce_id;
          mem_cmd_payload_lo.uncached = 1'b1;
          mem_cmd_base_header_lo.payload = mem_cmd_payload_lo;

          state_n = lce_req_yumi ? e_ready : e_uncached_req;

        end // uncached load

      end // e_uncached_req

      e_uncached_data: begin
        // send data

         mem_cmd_v_lo = lce_req_v & lce_req_data_v_i & ~mem_credits_empty;
         lce_req_data_ready_and_o = mem_cmd_ready_and_li;
         // LCE request header is only dequeued if stream pump indicates stream is done
         lce_req_yumi = mem_cmd_v_lo & mem_cmd_ready_and_li & mem_cmd_stream_done_li;

         // form message
         mem_cmd_base_header_lo.addr = mshr_r.paddr;
         mem_cmd_base_header_lo.size = mshr_r.msg_size;
         mem_cmd_base_header_lo.msg_type.mem = e_bedrock_mem_uc_wr;
         mem_cmd_payload_lo.lce_id = mshr_r.lce_id;
         mem_cmd_payload_lo.uncached = 1'b1;
         mem_cmd_base_header_lo.payload = mem_cmd_payload_lo;
         mem_cmd_data_lo = lce_req_data_i;

         // stream pump done signal indicates if all data has sent
         state_n = mem_cmd_stream_done_li
                   ? e_ready
                   : e_uncached_data;

      end

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
        if (lce_req_v & ~pending_busy) begin
          // write the pending bit if not amo or uncached to coherent memory
          // because those ops do not send coh_ack back to CCE after request completes
          pending_w_v =  ~(mshr_r.flags[e_opd_arf] | mshr_r.flags[e_opd_ucf]);
          pending_w_addr = lce_req.addr;
          pending_li = 1'b1;

          // skip speculative memory access if amo/uncached
          state_n = (mshr_r.flags[e_opd_arf] | mshr_r.flags[e_opd_ucf])
                    ? e_read_dir
                    : e_read_mem_spec;

          // only dequeue the request now if it is a normal cached request
          lce_req_yumi = ~(mshr_r.flags[e_opd_arf] | mshr_r.flags[e_opd_ucf]);

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
          // handshake is r&v
          mem_cmd_v_lo = ~mem_credits_empty;
          mem_cmd_base_header_lo.msg_type.mem = e_bedrock_mem_rd;
          mem_cmd_base_header_lo.addr = mshr_r_paddr_aligned;
          mem_cmd_base_header_lo.size = mshr_r.msg_size;
          mem_cmd_payload_lo.lce_id = mshr_r.lce_id;
          mem_cmd_payload_lo.way_id = mshr_r.lru_way_id;
          // speculatively issue request for E state
          mem_cmd_payload_lo.state = e_COH_E;
          mem_cmd_payload_lo.speculative = 1'b1;
          mem_cmd_base_header_lo.payload = mem_cmd_payload_lo;

          // set the spec bit and clear all other bits for this entry
          spec_w_v = mem_cmd_v_lo & mem_cmd_ready_and_li;
          spec_v_li = 1'b1;
          squash_v_li = 1'b1;
          fwd_mod_v_li = 1'b1;
          state_v_li = 1'b1;
          spec_bits_li.spec = 1'b1;
          spec_bits_li.squash = 1'b0;
          spec_bits_li.fwd_mod = 1'b0;
          spec_bits_li.state = e_COH_I;

          state_n = (mem_cmd_v_lo & mem_cmd_ready_and_li) ? e_read_dir : e_read_mem_spec;

          pending_w_v = mem_cmd_v_lo & mem_cmd_ready_and_li;
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
        if (~lce_cmd_busy) begin
          lce_cmd_header_v_o = 1'b1;
          lce_cmd_has_data_o = 1'b0;

          // set state to invalid and writeback
          lce_cmd.msg_type.cmd = e_bedrock_cmd_st_wb;
          // for an uc/amo request, the mshr way_id field indicates the way in which the requesting
          // LCE's copy of the cache block is stored at the LCE
          if (mshr_r.flags[e_opd_arf] | mshr_r.flags[e_opd_ucf]) begin
            lce_cmd.payload.way_id = mshr_r.way_id;
            lce_cmd.addr = mshr_r.paddr;
          end else begin
            lce_cmd.payload.way_id = mshr_r.lru_way_id;
            lce_cmd.addr = mshr_r.lru_paddr;
          end
          lce_cmd.payload.dst_id = mshr_r.lce_id;
          // Note: this state must be e_COH_I to properly handle amo or uncached access to
          // coherent memory that requires invalidating the requesting LCE if it has the block
          lce_cmd.payload.state = e_COH_I;

          state_n = (lce_cmd_header_v_o & lce_cmd_header_ready_and_i)
                    ? e_replacement_wb_resp
                    : e_replacement;
        end
      end // e_replacement

      e_replacement_wb_resp: begin
        if (lce_resp_v) begin
          if (lce_resp.msg_type.resp == e_bedrock_resp_null_wb) begin
            lce_resp_yumi = lce_resp_v;
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
          else if ((lce_resp.msg_type.resp == e_bedrock_resp_wb) & ~pending_busy & ~mem_credits_empty) begin
            // Mem Data Cmd needs to write pending bit, so only send if Mem Data Resp / LCE Data Cmd is
            // not writing the pending bit. Mem command also requires a credit, so only proceed if
            // there is at least one credit availabe.

            // r&v on mem cmd header
            // v->y on lce resp header, but wait to dequeue until last data beat sends
            // r&v on lce resp data

            // send memory command if data is valid (header already guaranteed valid)
            mem_cmd_v_lo = lce_resp_data_v_i;
            lce_resp_data_ready_and_o = mem_cmd_ready_and_li;
            // only dequeue LCE response header when stream pump finishes
            lce_resp_yumi = mem_cmd_stream_done_li;

            mem_cmd_base_header_lo.msg_type = e_bedrock_mem_wr;
            mem_cmd_base_header_lo.addr = (lce_resp.addr >> lg_block_size_in_bytes_lp) << lg_block_size_in_bytes_lp;
            mem_cmd_base_header_lo.size = lce_resp.size;
            mem_cmd_payload_lo.lce_id = mshr_r.lce_id;
            mem_cmd_payload_lo.way_id = '0;
            mem_cmd_base_header_lo.payload = mem_cmd_payload_lo;
            mem_cmd_data_lo = lce_resp_data_i;

            // send remaining beats
            state_n = (mem_cmd_stream_done_li)
                      ? (invalidate_flag)
                        ? e_inv_cmd
                        : (transfer_flag)
                          ? e_transfer
                          : e_resolve_speculation
                      : e_replacement_wb_resp;

            // set the pending bit on last beat
            pending_w_v = mem_cmd_stream_done_li;
            pending_li = 1'b1;
            pending_w_addr = lce_resp.addr;

            // clear the replacement flag
            mshr_n.flags[e_opd_rf] = 1'b0;
            // clear null writeback flag
            mshr_n.flags[e_opd_nwbf] = 1'b0;

            // setup required state for sending invalidations
            if (mem_cmd_stream_done_li & invalidate_flag) begin
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
        end // lce_resp_v
      end // e_replacement_wb_resp

      e_inv_cmd: begin

        // only send invalidation if priority encode has valid output
        // this indicates the sharers vector has a valid bit set
        if (pe_v) begin

          // try to send additional commands, but give priority to mem_resp auto-forward
          if (~lce_cmd_busy) begin

            lce_cmd_header_v_o = 1'b1;
            lce_cmd_has_data_o = 1'b0;
            lce_cmd.msg_type.cmd = e_bedrock_cmd_inv;
            lce_cmd.addr = mshr_r.paddr;

            // destination and way come from sharers information
            lce_cmd.payload.dst_id[0+:lg_num_lce_lp] = pe_lce_id;
            lce_cmd.payload.way_id = sharers_ways_r[pe_lce_id];

            // message sent, increment count, write directory, clear bit for the destination LCE
            cnt_inc = lce_cmd_header_v_o & lce_cmd_header_ready_and_i;
            dir_w_v = lce_cmd_header_v_o & lce_cmd_header_ready_and_i;
            dir_cmd = e_wds_op;
            dir_addr_li = mshr_r.paddr;
            dir_lce_li = '0;
            dir_lce_li[0+:lg_num_lce_lp] = pe_lce_id;
            dir_way_li = sharers_ways_r[pe_lce_id];
            dir_coh_state_li = e_COH_I;

            // update sharers hit vector to feed back to priority encode module
            pe_sharers_n = (lce_cmd_header_v_o & lce_cmd_header_ready_and_i)
                           ? pe_sharers_r & ~pe_lce_id_one_hot
                           : pe_sharers_r;

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
        if (lce_resp_v & (lce_resp.msg_type.resp == e_bedrock_resp_inv_ack)) begin
          lce_resp_yumi = lce_resp_v;
          cnt_dec = lce_resp_yumi;
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
          if (lce_resp_v & (lce_resp.msg_type.resp == e_bedrock_resp_inv_ack)) begin
            lce_resp_yumi = lce_resp_v;
            cnt_dec = lce_resp_yumi;
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
          if (~lce_cmd_busy) begin
            lce_cmd_header_v_o = 1'b1;
            lce_cmd_has_data_o = 1'b0;

            lce_cmd.addr = mshr_r.paddr;
            lce_cmd.payload.dst_id = mshr_r.owner_lce_id;
            lce_cmd.payload.way_id = mshr_r.owner_way_id;
            lce_cmd.payload.state = e_COH_I;

            // either invalidate or set tag and writeback
            // if owner is in F state, block is clean, so only need to invalidate
            // else, block in E, M, or O, need to invalidate and writeback
            lce_cmd.msg_type.cmd = mshr_r.flags[e_opd_cff]
                                   ? e_bedrock_cmd_inv
                                   : e_bedrock_cmd_st_wb;

            // update state of owner in directory
            dir_w_v = lce_cmd_header_v_o & lce_cmd_header_ready_and_i;
            dir_cmd = e_wds_op;
            dir_addr_li = mshr_r.paddr;
            dir_lce_li = mshr_r.owner_lce_id;
            dir_way_li = mshr_r.owner_way_id;
            dir_coh_state_li = e_COH_I;

            state_n = (lce_cmd_header_v_o & lce_cmd_header_ready_and_i)
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
        if (lce_resp_v) begin
          if (lce_resp.msg_type.resp == e_bedrock_resp_wb & ~pending_busy & ~mem_credits_empty) begin
            if (~pending_busy) begin
              // Mem Data Cmd needs to write pending bit, so only send if Mem Data Resp / LCE Data Cmd is
              // not writing the pending bit
              // r&v on mem cmd header
              // v->y on lce resp header
              // r&v on lce resp data
              mem_cmd_v_lo = lce_resp_v & lce_resp_data_v_i;
              lce_resp_data_ready_and_o = mem_cmd_ready_and_li;
              lce_resp_yumi = mem_cmd_stream_done_li;

              mem_cmd_base_header_lo.msg_type.mem = e_bedrock_mem_wr;
              // TODO: should this address be aligned by the CCE?
              mem_cmd_base_header_lo.addr = (lce_resp.addr >> lg_block_size_in_bytes_lp) << lg_block_size_in_bytes_lp;
              mem_cmd_base_header_lo.size = lce_resp.size;
              mem_cmd_payload_lo.lce_id = mshr_r.lce_id;
              mem_cmd_base_header_lo.payload = mem_cmd_payload_lo;
              mem_cmd_data_lo = lce_resp_data_i;

              // set the pending bit
              pending_w_v = mem_cmd_stream_done_li;
              pending_li = 1'b1;
              pending_w_addr = lce_resp.addr;

              state_n = (mem_cmd_stream_done_li)
                        ? e_uc_coherent_mem_cmd
                        : e_uc_coherent_resp;

            end
          end else if (lce_resp.msg_type.resp == e_bedrock_resp_null_wb) begin
            lce_resp_yumi = lce_resp_v;
            state_n = e_uc_coherent_mem_cmd;
          end else if (lce_resp.msg_type.resp == e_bedrock_resp_inv_ack) begin
            lce_resp_yumi = lce_resp_v;
            state_n = e_uc_coherent_mem_cmd;
          end
        end

      end // e_uc_coherent_resp

      // amo/uc after inv_ack/wb_response, issue op to memory
      // writes pending bit
      e_uc_coherent_mem_cmd: begin
        if (~pending_busy & ~mem_credits_empty) begin
          // r&v on mem cmd header
          // v->y on lce req header
          // r&v on lce req data
          mem_cmd_v_lo = lce_req_v;
          lce_req_yumi = mem_cmd_stream_done_li;
          lce_req_data_ready_and_o = mem_cmd_ready_and_li;

          // set message type based on request message type
          unique case (lce_req.msg_type.req)
            e_bedrock_req_uc_rd: mem_cmd_base_header_lo.msg_type = e_bedrock_mem_uc_rd;
            e_bedrock_req_uc_wr: mem_cmd_base_header_lo.msg_type = e_bedrock_mem_uc_wr;
            e_bedrock_req_uc_amo: mem_cmd_base_header_lo.msg_type = e_bedrock_mem_amo;
            default: mem_cmd_base_header_lo.msg_type = e_bedrock_mem_uc_rd;
          endcase
          // uncached/amo address must be aligned appropriate to the request size
          // in the LCE request (which is stored in the MSHR)
          mem_cmd_base_header_lo.addr = mshr_r.paddr;
          mem_cmd_base_header_lo.size = mshr_r.msg_size;
          // TODO: uncomment/modify when implementing atomics
          //mem_cmd_base_header_lo.amo_no_return = mshr_r.flags[e_opd_anrf];
          mem_cmd_payload_lo.lce_id = mshr_r.lce_id;
          mem_cmd_payload_lo.way_id = '0;
          // this op is uncached in LCE for both amo or uncached requests
          mem_cmd_payload_lo.uncached = 1'b1;
          mem_cmd_base_header_lo.payload = mem_cmd_payload_lo;
          mem_cmd_data_lo = lce_req_data_i;

          // set the pending bit
          pending_w_v = mem_cmd_stream_done_li;
          pending_li = 1'b1;
          pending_w_addr = mshr_r.paddr;

          state_n = mem_cmd_stream_done_li
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
        if (~lce_cmd_busy) begin
          lce_cmd_header_v_o = 1'b1;
          lce_cmd_has_data_o = 1'b0;

          lce_cmd.payload.dst_id = mshr_r.owner_lce_id;
          lce_cmd.payload.way_id = mshr_r.owner_way_id;

          lce_cmd.msg_type.cmd = mshr_r.flags[e_opd_rqf]
                                        ? e_bedrock_cmd_st_tr
                                        : e_bedrock_cmd_st_tr_wb;

          lce_cmd.addr = mshr_r.paddr;

          // either Invalidate or Downgrade Owner, depending on request type
          lce_cmd.payload.state = mshr_r.flags[e_opd_rqf] ? e_COH_I : e_COH_S;

          // transfer information
          lce_cmd.payload.target = mshr_r.lce_id;
          lce_cmd.payload.target_way_id = mshr_r.lru_way_id;
          lce_cmd.payload.target_state = mshr_r.next_coh_state;

          // update state of owner in directory
          dir_w_v = lce_cmd_header_v_o & lce_cmd_header_ready_and_i;
          dir_cmd = e_wds_op;
          dir_addr_li = mshr_r.paddr;
          dir_lce_li = mshr_r.owner_lce_id;
          dir_way_li = mshr_r.owner_way_id;
          dir_coh_state_li = mshr_r.flags[e_opd_rqf] ? e_COH_I : e_COH_S;

          state_n = (lce_cmd_header_v_o & lce_cmd_header_ready_and_i)
                    ? mshr_r.flags[e_opd_rqf]
                      ? e_resolve_speculation
                      : e_transfer_wb_resp
                    : e_transfer;
        end

      end // e_transfer

      e_transfer_wb_resp: begin
        if (lce_resp_v) begin
          if (lce_resp.msg_type.resp == e_bedrock_resp_null_wb) begin
            lce_resp_yumi = lce_resp_v;
            state_n = e_resolve_speculation;

          end
          else if ((lce_resp.msg_type.resp == e_bedrock_resp_wb) & ~pending_busy & ~mem_credits_empty) begin
            // Mem Data Cmd needs to write pending bit, so only send if Mem Data Resp / LCE Data Cmd is
            // not writing the pending bit. Mem command also needs a credit, only process if one is
            // available.

            // handshake
            // lce resp is v->yumi
            // mem cmd is r&v
            // lce resp data is r&v
            mem_cmd_v_lo = lce_resp_v & lce_resp_data_v_i;
            lce_resp_data_ready_and_o = mem_cmd_ready_and_li;
            lce_resp_yumi = mem_cmd_stream_done_li;

            mem_cmd_base_header_lo.msg_type.mem = e_bedrock_mem_wr;
            // TODO: should CCE align this address?
            mem_cmd_base_header_lo.addr = (lce_resp.addr >> lg_block_size_in_bytes_lp) << lg_block_size_in_bytes_lp;
            mem_cmd_payload_lo.lce_id = mshr_r.lce_id;
            mem_cmd_payload_lo.way_id = '0;
            mem_cmd_base_header_lo.payload = mem_cmd_payload_lo;
            mem_cmd_base_header_lo.size = lce_resp.size;
            mem_cmd_data_lo = lce_resp_data_i;

            state_n = (mem_cmd_stream_done_li) ? e_resolve_speculation : e_transfer_wb_resp;

            // set the pending bit
            pending_w_v = mem_cmd_stream_done_li;
            pending_li = 1'b1;
            pending_w_addr = lce_resp.addr;

          end
        end
      end // e_transfer_wb_resp

      e_upgrade_stw_cmd: begin
        // r&v handshake
        if (~lce_cmd_busy) begin
          lce_cmd_header_v_o = 1'b1;
          lce_cmd_has_data_o = 1'b0;

          lce_cmd.msg_type.cmd = e_bedrock_cmd_st_wakeup;
          lce_cmd.addr = mshr_r.paddr;
          lce_cmd.payload.dst_id = mshr_r.lce_id;
          lce_cmd.payload.way_id = mshr_r.way_id;
          lce_cmd.payload.state = mshr_r.next_coh_state;

          state_n = (lce_cmd_header_v_o & lce_cmd_header_ready_and_i)
                    ? e_resolve_speculation
                    : e_upgrade_stw_cmd;
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
      mem_resp_state_r <= e_mem_resp_reset;
      mshr_r <= '0;
      sharers_ways_r <= '0;
      sharers_hits_r <= '0;
      pe_sharers_r <= '0;
      cce_normal_mode_r <= '0;
    end else begin
      state_r <= state_n;
      mem_resp_state_r <= mem_resp_state_n;
      mshr_r <= mshr_n;
      sharers_ways_r <= sharers_ways_n;
      sharers_hits_r <= sharers_hits_n;
      pe_sharers_r <= pe_sharers_n;
      cce_normal_mode_r <= cce_normal_mode_n;
    end
  end

  //synopsys translate_off
  initial begin
    assert (lce_sets_p > 1) else $error("Number of LCE sets must be greater than 1");
    assert (counter_max > num_way_groups_lp) else $error("Counter max value not large enough");
    assert (counter_max > max_tag_sets_lp) else $error("Counter max value not large enough");
    assert (icache_block_width_p == cce_block_width_p) else $error("icache block width must match cce block width");
    assert (dcache_block_width_p == cce_block_width_p) else $error("dcache block width must match cce block width");
    assert (acache_block_width_p == cce_block_width_p) else $error("acache block width must match cce block width");
    assert (block_size_in_bytes_lp inside {8, 16, 32, 64, 128}) else $error("invalid CCE block width");
    assert (dword_width_gp == 64) else $error("FSM CCE requires dword width of 64-bits");
  end
  //synopsys translate_on

endmodule
