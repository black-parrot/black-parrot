/**
 *
 * Name:
 *   bp_cce.v
 *
 * Description:
 *   This is the top level module for the CCE.
 *
 */

module bp_cce
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_common_cfg_link_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p      = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    // Derived parameters
    , localparam block_size_in_bytes_lp    = (cce_block_width_p/8)
    , localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp)

    // number of way groups managed by this CCE
    , localparam num_way_groups_lp         = `BSG_CDIV(cce_way_groups_p, num_cce_p)
    , localparam lg_num_way_groups_lp      = `BSG_SAFE_CLOG2(num_way_groups_lp)
    , localparam lg_cce_way_groups_lp      = `BSG_SAFE_CLOG2(cce_way_groups_p)

    // counter max (used for e.g., stall and performance counters)
    , localparam max_counter_val_lp        = ((2**16)-1)
    , localparam counter_width_lp          = `BSG_SAFE_CLOG2(max_counter_val_lp)

    // Interface Widths
    , localparam cfg_bus_width_lp          = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
    `declare_bp_lce_cce_if_header_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p)
    `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, cce_block_width_p)
    `declare_bp_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce_mem)
  )
  (input                                               clk_i
   , input                                             reset_i

   // Configuration Interface
   , input [cfg_bus_width_lp-1:0]                      cfg_bus_i

   // ucode programming interface, synchronous read, direct connection to RAM
   , input                                             ucode_v_i
   , input                                             ucode_w_i
   , input [cce_pc_width_p-1:0]                        ucode_addr_i
   , input [cce_instr_width_p-1:0]                     ucode_data_i
   , output [cce_instr_width_p-1:0]                    ucode_data_o

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

  // CCE Parameter Assertions
  //synopsys translate_off
  initial begin
    assert(`BSG_IS_POW2(cce_way_groups_p))
      else $error("Number of way groups must be a power of two");
    assert(`BSG_IS_POW2(dcache_assoc_p) && `BSG_IS_POW2(dcache_sets_p))
      else $error("D$ sets and assoc must be power of two");
    assert(`BSG_IS_POW2(icache_assoc_p) && `BSG_IS_POW2(icache_sets_p))
      else $error("I$ sets and assoc must be power of two");
    assert(`BSG_IS_POW2(acache_assoc_p) || acache_assoc_p == 0)
      else $error("A$ assoc must be power of two or 0");
    assert(`BSG_IS_POW2(acache_sets_p) || acache_sets_p == 0)
      else $error("A$ sets must be power of two or 0");
    assert (icache_block_width_p == cce_block_width_p) else $error("icache block width must match cce block width");
    assert (dcache_block_width_p == cce_block_width_p) else $error("dcache block width must match cce block width");
    assert (acache_block_width_p == cce_block_width_p) else $error("acache block width must match cce block width");
    assert (block_size_in_bytes_lp inside {8, 16, 32, 64, 128}) else $error("invalid CCE block width");
  end
  //synopsys translate_on

  // LCE-CCE and Mem-CCE Interface
  `declare_bp_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce_mem);
  `declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, cce_block_width_p);

  // Config Interface
  `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);

  // MSHR
  `declare_bp_cce_mshr_s(lce_id_width_p, lce_assoc_p, paddr_width_p);

  // Config bus casting
  bp_cfg_bus_s cfg_bus_cast_i;
  assign cfg_bus_cast_i = cfg_bus_i;

  // Message casting
  bp_lce_cce_req_s  lce_req;
  bp_lce_cce_resp_s lce_resp;
  bp_lce_cmd_s      lce_cmd;
  bp_cce_mem_msg_s  mem_cmd, mem_resp;
  assign lce_req   = lce_req_i;
  assign lce_resp  = lce_resp_i;
  assign lce_cmd_o = lce_cmd;
  assign mem_cmd_o = mem_cmd;
  assign mem_resp  = mem_resp_i;


  // Inter-module signals

  // From Fetch to Execute/Pre-Decode
  logic [cce_pc_width_p-1:0]           fetch_pc_lo;
  bp_cce_inst_s                        fetch_inst_lo;
  logic                                fetch_inst_v_lo;

  // From Predecode to Fetch
  logic [cce_pc_width_p-1:0]           predicted_fetch_pc_lo;

  // From Decoder to rest of Execute
  bp_cce_inst_decoded_s                decoded_inst_lo;
  logic [cce_pc_width_p-1:0]           ex_pc_lo;

  // From Execute to Fetch/Decode
  logic [cce_pc_width_p-1:0]           branch_resolution_pc_lo;
  logic                                stall_lo, mispredict_lo;

  // From ALU
  logic [`bp_cce_inst_gpr_width-1:0]   alu_res_lo;

  // From Source Selector to Execute
  logic [`bp_cce_inst_gpr_width-1:0]   src_a, src_b;
  logic [paddr_width_p-1:0]            addr_lo;
  logic                                addr_bypass_lo;
  logic [lce_id_width_p-1:0]           lce_lo;
  logic [lce_assoc_width_p-1:0]        way_lo, lru_way_lo;
  bp_coh_states_e                      state_lo;

  // From Arbitration to Directory
  logic [paddr_width_p-1:0]            dir_addr_li;
  logic                                dir_addr_bypass_li;
  logic [lce_id_width_p-1:0]           dir_lce_li;
  logic [lce_assoc_width_p-1:0]        dir_way_li;
  bp_coh_states_e                      dir_coh_state_li;
  bp_cce_inst_minor_dir_op_e           dir_cmd_li;
  logic                                dir_w_v_li;
  // From Arbitration to Pending Bits
  logic                                pending_li;
  logic                                pending_w_v_li;
  logic [paddr_width_p-1:0]            pending_w_addr_li;
  logic                                pending_w_addr_bypass_li;
  // From Arbitration to Spec Bits
  logic                                spec_r_v_li;
  logic [paddr_width_p-1:0]            spec_r_addr_li;
  logic                                spec_r_addr_bypass_li;

  // From Directory
  logic                                dir_busy_lo;
  logic                                sharers_v_lo;
  logic [num_lce_p-1:0]                sharers_hits_lo;
  logic [num_lce_p-1:0][lce_assoc_width_p-1:0] sharers_ways_lo;
  bp_coh_states_e [num_lce_p-1:0]      sharers_coh_states_lo;
  logic                                dir_addr_v_lo, dir_lru_v_lo;
  bp_coh_states_e                      dir_lru_coh_state_lo;
  logic [paddr_width_p-1:0]            dir_addr_lo, dir_lru_addr_lo;
  bp_cce_inst_opd_gpr_e                dir_addr_dst_gpr_lo;

  // From Pending Bits
  logic                                pending_lo;

  // From Spec Bits
  bp_cce_spec_s                        spec_bits_lo;

  // From GAD
  logic [lce_assoc_width_p-1:0]        gad_req_addr_way_lo;
  logic [lce_id_width_p-1:0]           gad_owner_lce_lo;
  logic [lce_assoc_width_p-1:0]        gad_owner_way_lo;
  bp_coh_states_e                      gad_owner_coh_state_lo;
  logic                                gad_replacement_flag_lo;
  logic                                gad_upgrade_flag_lo;
  logic                                gad_cached_shared_flag_lo;
  logic                                gad_cached_exclusive_flag_lo;
  logic                                gad_cached_modified_flag_lo;
  logic                                gad_cached_owned_flag_lo;
  logic                                gad_cached_forward_flag_lo;

  // From Register File
  bp_cce_mshr_s mshr_lo;
  logic [`bp_cce_inst_num_gpr-1:0][`bp_cce_inst_gpr_width-1:0] gpr_lo;
  bp_coh_states_e coh_state_default_lo;
  logic auto_fwd_msg_lo;

  // From Message Unit
  logic [paddr_width_p-1:0]                  msg_dir_addr_lo;
  logic                                      msg_dir_addr_bypass_lo;
  logic [lce_id_width_p-1:0]                 msg_dir_lce_lo;
  logic [lce_assoc_width_p-1:0]              msg_dir_way_lo;
  bp_coh_states_e                            msg_dir_coh_state_lo;
  bp_cce_inst_minor_dir_op_e                 msg_dir_w_cmd_lo;
  logic                                      msg_dir_w_v_lo;

  logic                                      msg_pending_w_v_lo;
  logic [paddr_width_p-1:0]                  msg_pending_w_addr_lo;
  logic                                      msg_pending_w_addr_bypass_lo;
  logic                                      msg_pending_lo;

  logic                                      msg_spec_r_v_lo;
  logic [paddr_width_p-1:0]                  msg_spec_r_addr_lo;
  logic                                      msg_spec_r_addr_bypass_lo;

  // From Message Unit to Stall
  logic                                      msg_lce_cmd_busy_lo;
  logic                                      msg_lce_resp_busy_lo;
  logic                                      msg_mem_resp_busy_lo;
  logic                                      msg_busy_lo;
  logic                                      msg_mem_credits_empty_lo;

  // From Stall Unit
  //logic [counter_width_lp-1:0]               stall_count_lo;

  /*
   * Fetch Stage
   */

  // Inst Fetch and microcode RAM
  bp_cce_inst_ram
    #(.bp_params_p(bp_params_p)
      )
    inst_ram
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.cfg_bus_i(cfg_bus_i)

      ,.ucode_v_i(ucode_v_i)
      ,.ucode_w_i(ucode_w_i)
      ,.ucode_addr_i(ucode_addr_i)
      ,.ucode_data_i(ucode_data_i)
      ,.ucode_data_o(ucode_data_o)

      ,.predicted_fetch_pc_i(predicted_fetch_pc_lo)
      ,.branch_resolution_pc_i(branch_resolution_pc_lo)
      ,.stall_i(stall_lo)
      ,.mispredict_i(mispredict_lo)
      ,.fetch_pc_o(fetch_pc_lo)
      ,.inst_o(fetch_inst_lo)
      ,.inst_v_o(fetch_inst_v_lo)
      );

  // Inst Pre-decode
  bp_cce_inst_predecode
    #(.width_p(cce_pc_width_p)
      )
    inst_predecode
     (.inst_i(fetch_inst_lo)
      ,.pc_i(fetch_pc_lo)
      ,.predicted_next_pc_o(predicted_fetch_pc_lo)
      );

  /*
   * Decode/Execute Stage
   */

  // Instruction Decode
  bp_cce_inst_decode
    #(.cce_pc_width_p(cce_pc_width_p)
      )
    inst_decode
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.inst_i(fetch_inst_lo)
      ,.pc_i(fetch_pc_lo)
      ,.inst_v_i(fetch_inst_v_lo)
      ,.stall_i(stall_lo)
      ,.mispredict_i(mispredict_lo)
      ,.decoded_inst_o(decoded_inst_lo)
      ,.pc_o(ex_pc_lo)
      );

  // ALU
  bp_cce_alu
    #(.width_p(`bp_cce_inst_gpr_width)
      )
    alu
     (.opd_a_i(src_a)
      ,.opd_b_i(src_b)
      ,.alu_op_i(decoded_inst_lo.alu_op)
      ,.res_o(alu_res_lo)
      );

  // Branch Unit
  bp_cce_branch
    #(.width_p(`bp_cce_inst_gpr_width)
      ,.cce_pc_width_p(cce_pc_width_p)
      )
    branch
     (.opd_a_i(src_a)
      ,.opd_b_i(src_b)
      ,.branch_i(decoded_inst_lo.branch)
      ,.predicted_taken_i(decoded_inst_lo.predict_taken)
      ,.branch_op_i(decoded_inst_lo.branch_op)
      ,.execute_pc_i(ex_pc_lo)
      ,.branch_target_i(decoded_inst_lo.branch_target[0+:cce_pc_width_p])
      ,.mispredict_o(mispredict_lo)
      ,.pc_o(branch_resolution_pc_lo)
      );

  // Source Select
  bp_cce_src_sel
    #(.bp_params_p(bp_params_p)
     )
    source_selector
     (.src_a_sel_i(decoded_inst_lo.src_a_sel)
      ,.src_a_i(decoded_inst_lo.src_a)
      ,.src_b_sel_i(decoded_inst_lo.src_b_sel)
      ,.src_b_i(decoded_inst_lo.src_b)
      ,.addr_sel_i(decoded_inst_lo.addr_sel)
      ,.lce_sel_i(decoded_inst_lo.lce_sel)
      ,.way_sel_i(decoded_inst_lo.way_sel)
      ,.lru_way_sel_i(decoded_inst_lo.lru_way_sel)
      ,.coh_state_sel_i(decoded_inst_lo.coh_state_sel)
      ,.cfg_bus_i(cfg_bus_i)
      ,.mshr_i(mshr_lo)
      ,.gpr_i(gpr_lo)
      ,.imm_i(decoded_inst_lo.imm)
      ,.auto_fwd_msg_i(auto_fwd_msg_lo)
      ,.coh_state_default_i(coh_state_default_lo)
      ,.sharers_hits_i(sharers_hits_lo)
      ,.sharers_ways_i(sharers_ways_lo)
      ,.sharers_coh_states_i(sharers_coh_states_lo)
      ,.mem_resp_v_i(mem_resp_v_i)
      ,.lce_resp_v_i(lce_resp_v_i)
      ,.lce_req_v_i(lce_req_v_i)
      ,.lce_req_i(lce_req)
      ,.lce_resp_i(lce_resp)
      ,.mem_resp_i(mem_resp)
      ,.src_a_o(src_a)
      ,.src_b_o(src_b)
      ,.addr_o(addr_lo)
      ,.addr_bypass_o(addr_bypass_lo)
      ,.lce_o(lce_lo)
      ,.way_o(way_lo)
      ,.lru_way_o(lru_way_lo)
      ,.state_o(state_lo)
      );

  // Arbitration Unit for Directory, Spec Bits, Pending Bits
  bp_cce_arbitrate
    #(.bp_params_p(bp_params_p)
      )
    arbitration
     (.stall_i(stall_lo)
      ,.dir_addr_i(addr_lo)
      ,.dir_addr_bypass_i(addr_bypass_lo)
      ,.dir_lce_i(lce_lo)
      ,.dir_way_i(way_lo)
      ,.dir_coh_state_i(state_lo)
      ,.dir_cmd_i(decoded_inst_lo.minor_op_u.dir_minor_op)
      ,.dir_w_v_i(decoded_inst_lo.dir_w_v)
      ,.msg_dir_addr_i(msg_dir_addr_lo)
      ,.msg_dir_addr_bypass_i(msg_dir_addr_bypass_lo)
      ,.msg_dir_lce_i(msg_dir_lce_lo)
      ,.msg_dir_way_i(msg_dir_way_lo)
      ,.msg_dir_coh_state_i(msg_dir_coh_state_lo)
      ,.msg_dir_w_cmd_i(msg_dir_w_cmd_lo)
      ,.msg_dir_w_v_i(msg_dir_w_v_lo)
      ,.dir_addr_o(dir_addr_li)
      ,.dir_addr_bypass_o(dir_addr_bypass_li)
      ,.dir_lce_o(dir_lce_li)
      ,.dir_way_o(dir_way_li)
      ,.dir_coh_state_o(dir_coh_state_li)
      ,.dir_cmd_o(dir_cmd_li)
      ,.dir_w_v_o(dir_w_v_li)
      ,.pending_w_v_i(decoded_inst_lo.pending_w_v)
      ,.pending_w_addr_i(addr_lo)
      ,.pending_w_addr_bypass_i(addr_bypass_lo)
      ,.pending_i(decoded_inst_lo.pending_bit)
      ,.msg_pending_w_v_i(msg_pending_w_v_lo)
      ,.msg_pending_w_addr_i(msg_pending_w_addr_lo)
      ,.msg_pending_w_addr_bypass_i(msg_pending_w_addr_bypass_lo)
      ,.msg_pending_i(msg_pending_lo)
      ,.pending_w_v_o(pending_w_v_li)
      ,.pending_w_addr_o(pending_w_addr_li)
      ,.pending_w_addr_bypass_o(pending_w_addr_bypass_li)
      ,.pending_o(pending_li)
      ,.spec_r_v_i(decoded_inst_lo.spec_r_v)
      ,.spec_r_addr_i(addr_lo)
      ,.spec_r_addr_bypass_i(addr_bypass_lo)
      ,.msg_spec_r_v_i(msg_spec_r_v_lo)
      ,.msg_spec_r_addr_i(msg_spec_r_addr_lo)
      ,.msg_spec_r_addr_bypass_i(msg_spec_r_addr_bypass_lo)
      ,.spec_r_v_o(spec_r_v_li)
      ,.spec_r_addr_o(spec_r_addr_li)
      ,.spec_r_addr_bypass_o(spec_r_addr_bypass_li)
      );

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
      ,.lru_way_i(lru_way_lo) // only used for reads, therefore not arbitrated with message unit
      ,.coh_state_i(dir_coh_state_li)
      ,.addr_dst_gpr_i(decoded_inst_lo.dst.gpr) // only used for reads, not arbitrated
      ,.cmd_i(dir_cmd_li)
      ,.r_v_i(decoded_inst_lo.dir_r_v) // only ucode reads directory
      ,.w_v_i(dir_w_v_li)
      // Outputs
      ,.busy_o(dir_busy_lo)
      ,.sharers_v_o(sharers_v_lo)
      ,.sharers_hits_o(sharers_hits_lo)
      ,.sharers_ways_o(sharers_ways_lo)
      ,.sharers_coh_states_o(sharers_coh_states_lo)
      ,.lru_v_o(dir_lru_v_lo)
      ,.lru_coh_state_o(dir_lru_coh_state_lo)
      ,.lru_addr_o(dir_lru_addr_lo)
      ,.addr_v_o(dir_addr_v_lo)
      ,.addr_o(dir_addr_lo)
      ,.addr_dst_gpr_o(dir_addr_dst_gpr_lo)
      );

  // Pending Bits
  bp_cce_pending_bits
    #(.num_way_groups_p(num_way_groups_lp)
      ,.cce_way_groups_p(cce_way_groups_p)
      ,.num_cce_p(num_cce_p)
      ,.paddr_width_p(paddr_width_p)
      ,.addr_offset_p(lg_block_size_in_bytes_lp)
     )
    pending_bits
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // from arbitration - message or ucode
      ,.w_v_i(pending_w_v_li)
      ,.w_addr_i(pending_w_addr_li)
      ,.w_addr_bypass_hash_i(pending_w_addr_bypass_li)
      ,.pending_i(pending_li)
      ,.clear_i(decoded_inst_lo.pending_clear) // only ucode can clear pending bit
      // reads - only ucode
      ,.r_v_i(decoded_inst_lo.pending_r_v)
      ,.r_addr_i(addr_lo)
      ,.r_addr_bypass_hash_i(addr_bypass_lo)
      // output of read
      ,.pending_o(pending_lo)
      );

  // GAD logic - auxiliary directory information logic
  bp_cce_gad
    #(.bp_params_p(bp_params_p)
      )
    gad
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.gad_v_i(decoded_inst_lo.gad_v)

      ,.sharers_v_i(sharers_v_lo)
      ,.sharers_hits_i(sharers_hits_lo)
      ,.sharers_ways_i(sharers_ways_lo)
      ,.sharers_coh_states_i(sharers_coh_states_lo)

      ,.req_lce_i(mshr_lo.lce_id)
      ,.req_type_flag_i(mshr_lo.flags[e_opd_rqf])
      ,.lru_coh_state_i(mshr_lo.lru_coh_state)

      ,.req_addr_way_o(gad_req_addr_way_lo)
      ,.owner_lce_o(gad_owner_lce_lo)
      ,.owner_way_o(gad_owner_way_lo)
      ,.owner_coh_state_o(gad_owner_coh_state_lo)
      ,.replacement_flag_o(gad_replacement_flag_lo)
      ,.upgrade_flag_o(gad_upgrade_flag_lo)
      ,.cached_shared_flag_o(gad_cached_shared_flag_lo)
      ,.cached_exclusive_flag_o(gad_cached_exclusive_flag_lo)
      ,.cached_modified_flag_o(gad_cached_modified_flag_lo)
      ,.cached_owned_flag_o(gad_cached_owned_flag_lo)
      ,.cached_forward_flag_o(gad_cached_forward_flag_lo)
      );

  // Register File
  bp_cce_reg
    #(.bp_params_p(bp_params_p)
      )
    registers
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.decoded_inst_i(decoded_inst_lo)
      ,.dir_lru_v_i(dir_lru_v_lo)
      ,.dir_addr_v_i(dir_addr_v_lo)

      ,.stall_i(stall_lo)

      ,.src_a_i(src_a)
      ,.alu_res_i(alu_res_lo)

      ,.lce_req_header_i(lce_req.header)
      ,.lce_resp_header_i(lce_resp.header)
      ,.mem_resp_header_i(mem_resp.header)

      ,.pending_i(pending_lo)

      ,.dir_lru_coh_state_i(dir_lru_coh_state_lo)
      ,.dir_lru_addr_i(dir_lru_addr_lo)

      ,.dir_addr_i(dir_addr_lo)
      ,.dir_addr_dst_gpr_i(dir_addr_dst_gpr_lo)

      ,.gad_req_addr_way_i(gad_req_addr_way_lo)
      ,.gad_owner_lce_i(gad_owner_lce_lo)
      ,.gad_owner_way_i(gad_owner_way_lo)
      ,.gad_owner_coh_state_i(gad_owner_coh_state_lo)
      ,.gad_replacement_flag_i(gad_replacement_flag_lo)
      ,.gad_upgrade_flag_i(gad_upgrade_flag_lo)
      ,.gad_cached_shared_flag_i(gad_cached_shared_flag_lo)
      ,.gad_cached_exclusive_flag_i(gad_cached_exclusive_flag_lo)
      ,.gad_cached_modified_flag_i(gad_cached_modified_flag_lo)
      ,.gad_cached_owned_flag_i(gad_cached_owned_flag_lo)
      ,.gad_cached_forward_flag_i(gad_cached_forward_flag_lo)

      ,.spec_sf_i(spec_bits_lo.spec)

      // register state outputs
      ,.mshr_o(mshr_lo)
      ,.gpr_o(gpr_lo)
      ,.coh_state_o(coh_state_default_lo)
      ,.auto_fwd_msg_o(auto_fwd_msg_lo)
      );

  // Message unit
  bp_cce_msg
    #(.bp_params_p(bp_params_p)
      )
    message
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.cfg_bus_i(cfg_bus_i)

      // To CCE
      ,.lce_req_i(lce_req)
      ,.lce_req_v_i(lce_req_v_i)
      ,.lce_req_yumi_o(lce_req_yumi_o)

      ,.lce_resp_i(lce_resp)
      ,.lce_resp_v_i(lce_resp_v_i)
      ,.lce_resp_yumi_o(lce_resp_yumi_o)

      // From CCE
      ,.lce_cmd_o(lce_cmd)
      ,.lce_cmd_v_o(lce_cmd_v_o)
      ,.lce_cmd_ready_i(lce_cmd_ready_i)

      // To CCE
      ,.mem_resp_i(mem_resp)
      ,.mem_resp_v_i(mem_resp_v_i)
      ,.mem_resp_yumi_o(mem_resp_yumi_o)

      // From CCE
      ,.mem_cmd_o(mem_cmd)
      ,.mem_cmd_v_o(mem_cmd_v_o)
      ,.mem_cmd_ready_i(mem_cmd_ready_i)

      // Inputs
      ,.lce_i(lce_lo)
      ,.addr_i(addr_lo)
      ,.way_i(way_lo)
      ,.coh_state_i(state_lo)
      ,.sharers_v_i(sharers_v_lo)
      ,.sharers_hits_i(sharers_hits_lo)
      ,.sharers_ways_i(sharers_ways_lo)

      ,.decoded_inst_i(decoded_inst_lo)
      ,.mshr_i(mshr_lo)
      ,.src_a_i(src_a)
      ,.auto_fwd_msg_i(auto_fwd_msg_lo)

      // Outputs to Pending Bits
      ,.pending_w_v_o(msg_pending_w_v_lo)
      ,.pending_w_addr_o(msg_pending_w_addr_lo)
      ,.pending_w_addr_bypass_o(msg_pending_w_addr_bypass_lo)
      ,.pending_o(msg_pending_lo)

      // Outputs to Spec Bits
      ,.spec_r_v_o(msg_spec_r_v_lo)
      ,.spec_r_addr_o(msg_spec_r_addr_lo)
      ,.spec_r_addr_bypass_o(msg_spec_r_addr_bypass_lo)
      ,.spec_bits_i(spec_bits_lo)

      // Outputs to Directory
      ,.dir_addr_o(msg_dir_addr_lo)
      ,.dir_addr_bypass_o(msg_dir_addr_bypass_lo)
      ,.dir_lce_o(msg_dir_lce_lo)
      ,.dir_way_o(msg_dir_way_lo)
      ,.dir_coh_state_o(msg_dir_coh_state_lo)
      ,.dir_w_cmd_o(msg_dir_w_cmd_lo)
      ,.dir_w_v_o(msg_dir_w_v_lo)

      // Outputs to Stall
      // LCE Command used by auto-forward
      ,.lce_cmd_busy_o(msg_lce_cmd_busy_lo)
      // LCE Response used by auto-forward
      ,.lce_resp_busy_o(msg_lce_resp_busy_lo)
      // Mem Response used by auto-forward
      ,.mem_resp_busy_o(msg_mem_resp_busy_lo)
      // Stall ucode (as in inv command being processed)
      ,.busy_o(msg_busy_lo)
      // memory credits empty
      ,.mem_credits_empty_o(msg_mem_credits_empty_lo)

      );

  // Speculative Access Bits
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

      ,.w_v_i(decoded_inst_lo.spec_w_v)
      ,.w_addr_i(addr_lo)
      ,.w_addr_bypass_hash_i(addr_bypass_lo)

      ,.spec_v_i(decoded_inst_lo.spec_v)
      ,.squash_v_i(decoded_inst_lo.spec_squash_v)
      ,.fwd_mod_v_i(decoded_inst_lo.spec_fwd_mod_v)
      ,.state_v_i(decoded_inst_lo.spec_state_v)
      ,.spec_i(decoded_inst_lo.spec_bits)

      ,.r_v_i(spec_r_v_li)
      ,.r_addr_i(spec_r_addr_li)
      ,.r_addr_bypass_hash_i(spec_r_addr_bypass_li)

      ,.spec_o(spec_bits_lo)
      );

  // Instruction Stall Detection
  bp_cce_inst_stall
    #()
    inst_stall
     (.decoded_inst_i(decoded_inst_lo)

      ,.lce_req_v_i(lce_req_v_i)
      ,.lce_resp_v_i(lce_resp_v_i)
      ,.mem_resp_v_i(mem_resp_v_i)
      ,.pending_v_i('0)

      ,.lce_cmd_ready_i(lce_cmd_ready_i)
      ,.mem_cmd_ready_i(mem_cmd_ready_i)
      ,.mem_credits_empty_i(msg_mem_credits_empty_lo)

      // From Messague Unit
      ,.msg_busy_i(msg_busy_lo)
      ,.msg_pending_w_busy_i(msg_pending_w_v_lo)
      ,.msg_lce_cmd_busy_i(msg_lce_cmd_busy_lo)
      ,.msg_lce_resp_busy_i(msg_lce_resp_busy_lo)
      ,.msg_mem_resp_busy_i(msg_mem_resp_busy_lo)
      ,.msg_spec_r_busy_i(msg_spec_r_v_lo)
      ,.msg_dir_w_busy_i(msg_dir_w_v_lo)

      // From Directory
      ,.dir_busy_i(dir_busy_lo)

      ,.stall_o(stall_lo)
      );

endmodule
