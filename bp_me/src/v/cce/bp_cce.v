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
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)

    // Derived parameters
    , localparam block_size_in_bytes_lp    = (cce_block_width_p/8)
    , localparam lg_num_lce_lp             = `BSG_SAFE_CLOG2(num_lce_p)
    , localparam lg_num_cce_lp             = `BSG_SAFE_CLOG2(num_cce_p)
    , localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp)
    , localparam lg_lce_assoc_lp           = `BSG_SAFE_CLOG2(lce_assoc_p)
    , localparam lg_lce_sets_lp            = `BSG_SAFE_CLOG2(lce_sets_p)
    , localparam tag_width_lp              = (paddr_width_p-lg_lce_sets_lp
                                              -lg_block_size_in_bytes_lp)
    , localparam num_way_groups_lp         = ((lce_sets_p % num_cce_p) == 0) ? (lce_sets_p/num_cce_p) : ((lce_sets_p/num_cce_p) + 1)
    , localparam lg_num_way_groups_lp      = `BSG_SAFE_CLOG2(num_way_groups_lp)
    , localparam inst_ram_addr_width_lp    = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)
    , localparam cfg_bus_width_lp          = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)

    // interface widths
    `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
    `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
  )
  (input                                               clk_i
   , input                                             reset_i

   , input [cfg_bus_width_lp-1:0]                      cfg_bus_i
   , output [cce_instr_width_p-1:0]                    cfg_cce_ucode_data_o

   // LCE-CCE Interface
   // inbound: valid->ready (a.k.a., valid->yumi), demanding consumer (connects to FIFO)
   // outbound: ready&valid (connects directly to ME network)
   , input [lce_cce_req_width_lp-1:0]                  lce_req_i
   , input                                             lce_req_v_i
   , output logic                                      lce_req_yumi_o

   , input [lce_cce_resp_width_lp-1:0]                 lce_resp_i
   , input                                             lce_resp_v_i
   , output logic                                      lce_resp_yumi_o

   , output logic [lce_cmd_width_lp-1:0]               lce_cmd_o
   , output logic                                      lce_cmd_v_o
   , input                                             lce_cmd_ready_i

   // CCE-MEM Interface
   // inbound: valid->ready (a.k.a., valid->yumi), demanding consumer (connects to FIFO)
   // outbound: ready&valid (connects to FIFO)
   , input [cce_mem_msg_width_lp-1:0]                  mem_resp_i
   , input                                             mem_resp_v_i
   , output logic                                      mem_resp_yumi_o

   , output logic [cce_mem_msg_width_lp-1:0]           mem_cmd_o
   , output logic                                      mem_cmd_v_o
   , input                                             mem_cmd_ready_i
  );

  // Define structure variables for output queues

  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p);

  bp_lce_cce_req_s  lce_req_li;
  bp_lce_cce_resp_s lce_resp_li;
  bp_lce_cmd_s      lce_cmd_lo;

  bp_cce_mem_msg_s  mem_cmd_lo, mem_resp_li;

  // assign output queue ports to structure variables
  assign lce_cmd_o = lce_cmd_lo;
  assign mem_cmd_o = mem_cmd_lo;

  // cast input messages with data
  assign mem_resp_li = mem_resp_i;
  assign lce_resp_li = lce_resp_i;
  assign lce_req_li = lce_req_i;

  // Config bus
  `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
  bp_cfg_bus_s cfg_bus_cast_i;
  assign cfg_bus_cast_i = cfg_bus_i;

  // PC to Decode signals
  logic [`bp_cce_inst_width-1:0] pc_inst_lo;
  logic pc_inst_v_lo;

  // Decode to PC signals
  logic pc_stall_lo;
  logic [inst_ram_addr_width_lp-1:0] pc_branch_target_lo;

  // ALU signals
  logic alu_branch_res_lo;
  logic [`bp_cce_inst_gpr_width-1:0] src_a, src_b, alu_res_lo;

  // Instruction Decode signals
  bp_cce_inst_decoded_s decoded_inst_lo;
  logic decoded_inst_v_lo;

  // Directory signals
  logic sharers_v_lo;
  logic [num_lce_p-1:0] sharers_hits_lo;
  logic [num_lce_p-1:0][lg_lce_assoc_lp-1:0] sharers_ways_lo;
  logic [num_lce_p-1:0][`bp_coh_bits-1:0] sharers_coh_states_lo;
  logic dir_lru_v_lo;
  logic dir_lru_cached_excl_lo;
  logic [tag_width_lp-1:0] dir_lru_tag_lo, dir_tag_lo;
  logic dir_busy_lo;

  logic [lg_lce_sets_lp-1:0] dir_set_li;
  logic [lg_num_lce_lp-1:0] dir_lce_li;
  logic [lg_lce_assoc_lp-1:0] dir_way_li;
  logic [tag_width_lp-1:0] dir_tag_li;
  logic [`bp_coh_bits-1:0] dir_coh_state_li;

  // Pending Bit Signals
  logic pending_lo;
  logic pending_v_lo;
  logic pending_li, pending_from_msg;
  logic pending_w_v_li, pending_w_v_from_msg;
  logic [lg_num_way_groups_lp-1:0] pending_w_way_group_li, pending_r_way_group_li, pending_w_way_group_from_msg;
  assign pending_r_way_group_li = dir_set_li;

  // WDP write is valid if instruction pending_w_v is set (WDP op) and decoder is not stalling
  // the instruction (due to mem data resp writing pending bit)
  logic wdp_pending_w_v;
  assign wdp_pending_w_v = decoded_inst_lo.pending_w_v & ~pc_stall_lo;
  assign pending_li = (wdp_pending_w_v) ? decoded_inst_lo.imm[0] : pending_from_msg;
  assign pending_w_v_li = (wdp_pending_w_v) ? decoded_inst_lo.pending_w_v : pending_w_v_from_msg;
  assign pending_w_way_group_li = (wdp_pending_w_v) ? dir_set_li : pending_w_way_group_from_msg;

  // GAD signals
  logic gad_v_li;

  logic [lg_lce_assoc_lp-1:0] gad_req_addr_way_lo;
  logic [lg_num_lce_lp-1:0] gad_transfer_lce_lo;
  logic [lg_lce_assoc_lp-1:0] gad_transfer_lce_way_lo;
  logic gad_transfer_flag_lo;
  logic gad_replacement_flag_lo;
  logic gad_upgrade_flag_lo;
  logic gad_invalidate_flag_lo;
  logic gad_cached_flag_lo;
  logic gad_cached_exclusive_flag_lo;
  logic gad_cached_owned_flag_lo;
  logic gad_cached_dirty_flag_lo;

  // Register signals
  `declare_bp_cce_mshr_s(lce_id_width_p, lce_assoc_p, paddr_width_p);
  bp_cce_mshr_s mshr;

  logic null_wb_flag_li;
  assign null_wb_flag_li = (lce_resp_v_i & (lce_resp_li.msg_type == e_lce_cce_resp_null_wb));

  logic [`bp_cce_inst_num_gpr-1:0][`bp_cce_inst_gpr_width-1:0] gpr_r_lo;
  logic [dword_width_p-1:0] nc_data_r_lo;
  logic [`bp_coh_bits-1:0] coh_state_r_lo;

  // Message Unit Signals
  logic                                          fence_zero_lo;
  logic                                          pending_w_busy_from_msg;
  logic                                          lce_cmd_busy_from_msg;
  logic                                          msg_inv_busy_lo;
  logic                                          msg_dir_w_v_lo;
  logic [lg_num_lce_lp-1:0]                      inv_dir_lce_lo;
  logic [lg_lce_assoc_lp-1:0]                    inv_dir_way_lo;

  // PC Logic, Instruction RAM
  bp_cce_pc
    #(.bp_params_p(bp_params_p))
    inst_ram
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.cfg_bus_i(cfg_bus_i)
      ,.cfg_cce_ucode_data_o(cfg_cce_ucode_data_o)

      ,.alu_branch_res_i(alu_branch_res_lo)

      ,.dir_busy_i(dir_busy_lo)

      ,.inv_busy_i(msg_inv_busy_lo)

      ,.pc_stall_i(pc_stall_lo)
      ,.pc_branch_target_i(pc_branch_target_lo)

      ,.inst_o(pc_inst_lo)
      ,.inst_v_o(pc_inst_v_lo)
      );

  // Instruction Decode
  bp_cce_inst_decode
    #(.inst_width_p(`bp_cce_inst_width)
      ,.inst_addr_width_p(inst_ram_addr_width_lp)
      )
    inst_decode
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.inst_i(pc_inst_lo)
      ,.inst_v_i(pc_inst_v_lo)

      ,.pending_w_busy_i(pending_w_busy_from_msg)
      ,.lce_cmd_busy_i(lce_cmd_busy_from_msg)

      ,.lce_req_v_i(lce_req_v_i)
      ,.lce_resp_v_i(lce_resp_v_i)
      ,.lce_resp_type_i(lce_resp_li.msg_type)
      ,.mem_resp_v_i(mem_resp_v_i)
      ,.pending_v_i('0)

      ,.lce_cmd_ready_i(lce_cmd_ready_i)
      ,.mem_cmd_ready_i(mem_cmd_ready_i)

      ,.fence_zero_i(fence_zero_lo)

      ,.decoded_inst_o(decoded_inst_lo)
      ,.decoded_inst_v_o(decoded_inst_v_lo)

      ,.pc_stall_o(pc_stall_lo)
      ,.pc_branch_target_o(pc_branch_target_lo)
      );

  // ALU
  bp_cce_alu
    #(.width_p(`bp_cce_inst_gpr_width)
      )
    alu
     (.v_i(decoded_inst_lo.alu_v)
      ,.br_v_i(decoded_inst_lo.branch_v)
      ,.opd_a_i(src_a)
      ,.opd_b_i(src_b)
      ,.alu_op_i(decoded_inst_lo.minor_op_u.alu_minor_op)
      ,.br_op_i(decoded_inst_lo.minor_op_u.branch_minor_op)
      ,.res_o(alu_res_lo)
      ,.branch_res_o(alu_branch_res_lo)
      );

  // Pending Bits
  bp_cce_pending
    #(.num_way_groups_p(num_way_groups_lp)
     )
    pending_bits
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.w_v_i(pending_w_v_li)
      ,.w_way_group_i(pending_w_way_group_li)
      ,.pending_i(pending_li)
      ,.r_v_i(decoded_inst_lo.pending_r_v)
      ,.r_way_group_i(pending_r_way_group_li)
      ,.pending_o(pending_lo)
      ,.pending_v_o(pending_v_lo)
      );

  // convert address (excluding block offset bits) into CCE local set index
  // TODO: for now, there is a 1:1 ratio of sets stored in directory and way groups
  // - when this changes, or when adding support for multiple LCE organizations, one bsg_hash_bank
  //   will be needed to map address to way group, and one per directory to map address to LCE set
  logic [lg_num_cce_lp-1:0] cce_dst_id_lo;
  localparam hash_index_width_lp=$clog2((2**lg_lce_sets_lp+num_cce_p-1)/num_cce_p);
  logic [hash_index_width_lp-1:0] cce_set_id_lo;
  logic [paddr_width_p-1:0] hash_addr_li;
  assign hash_addr_li =
    (decoded_inst_lo.dir_way_group_sel == e_dir_wg_sel_req_addr) ? mshr.paddr : mshr.lru_paddr;
  wire [lg_lce_sets_lp-1:0] hash_addr_rev =
    {<< {hash_addr_li[lg_block_size_in_bytes_lp+:lg_lce_sets_lp]}};

  bsg_hash_bank
    #(.banks_p(num_cce_p) // number of CCE's to spread way groups over
      ,.width_p(lg_lce_sets_lp) // width of address input
      )
    addr_to_cce_id
     (.i(hash_addr_rev)
      ,.bank_o(cce_dst_id_lo)
      ,.index_o(cce_set_id_lo)
      );

  // Directory
  bp_cce_dir
    #(.sets_p(num_way_groups_lp)
      ,.num_lce_p(num_lce_p)
      ,.lce_assoc_p(lce_assoc_p)
      ,.tag_width_p(tag_width_lp)
      )
    directory
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.set_i(dir_set_li[0+:lg_num_way_groups_lp])
      ,.lce_i(dir_lce_li)
      ,.way_i(dir_way_li)
      ,.lru_way_i(mshr.lru_way_id)

      ,.r_cmd_i(decoded_inst_lo.dir_op)
      ,.r_v_i(decoded_inst_lo.dir_r_v)

      ,.tag_i(dir_tag_li)
      ,.coh_state_i(dir_coh_state_li)

      ,.w_cmd_i(decoded_inst_lo.dir_op)
      ,.w_v_i(decoded_inst_lo.dir_w_v | msg_dir_w_v_lo)
      ,.w_clr_row_i('0)

      ,.sharers_v_o(sharers_v_lo)
      ,.sharers_hits_o(sharers_hits_lo)
      ,.sharers_ways_o(sharers_ways_lo)
      ,.sharers_coh_states_o(sharers_coh_states_lo)

      ,.lru_v_o(dir_lru_v_lo)
      ,.lru_cached_excl_o(dir_lru_cached_excl_lo)
      ,.lru_tag_o(dir_lru_tag_lo)

      ,.busy_o(dir_busy_lo)

      ,.tag_o(dir_tag_lo)

      );

  // GAD logic - auxiliary directory information logic
  bp_cce_gad
    #(.num_lce_p(num_lce_p)
      ,.lce_assoc_p(lce_assoc_p)
      )
    gad
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.gad_v_i(decoded_inst_lo.gad_v)

      ,.sharers_v_i(sharers_v_lo)
      ,.sharers_hits_i(sharers_hits_lo)
      ,.sharers_ways_i(sharers_ways_lo)
      ,.sharers_coh_states_i(sharers_coh_states_lo)

      ,.req_lce_i(lg_num_lce_lp'(mshr.lce_id))
      ,.req_type_flag_i(mshr.flags[e_flag_sel_rqf])
      ,.lru_dirty_flag_i(mshr.flags[e_flag_sel_ldf])
      ,.lru_cached_excl_flag_i(mshr.flags[e_flag_sel_lef])

      ,.req_addr_way_o(gad_req_addr_way_lo)

      ,.transfer_flag_o(gad_transfer_flag_lo)
      ,.transfer_lce_o(gad_transfer_lce_lo)
      ,.transfer_way_o(gad_transfer_lce_way_lo)
      ,.replacement_flag_o(gad_replacement_flag_lo)
      ,.upgrade_flag_o(gad_upgrade_flag_lo)
      ,.invalidate_flag_o(gad_invalidate_flag_lo)
      ,.cached_flag_o(gad_cached_flag_lo)
      ,.cached_exclusive_flag_o(gad_cached_exclusive_flag_lo)
      ,.cached_owned_flag_o(gad_cached_owned_flag_lo)
      ,.cached_dirty_flag_o(gad_cached_dirty_flag_lo)
      );

  // Registers
  bp_cce_reg
    #(.bp_params_p(bp_params_p))
    registers
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.decoded_inst_i(decoded_inst_lo)
      ,.lce_req_i(lce_req_li)
      ,.null_wb_flag_i(null_wb_flag_li)
      ,.lce_resp_type_i(lce_resp_li.msg_type)
      ,.mem_resp_type_i(mem_resp_li.msg_type)
      ,.alu_res_i(alu_res_lo)
      ,.mov_src_i(src_a)

      ,.pending_o_i(pending_lo)
      ,.pending_v_o_i(pending_v_lo)
      ,.dir_lru_v_i(dir_lru_v_lo)
      ,.dir_lru_cached_excl_i(dir_lru_cached_excl_lo)
      ,.dir_lru_tag_i(dir_lru_tag_lo)
      ,.dir_tag_i(dir_tag_lo)

      ,.gad_req_addr_way_i(gad_req_addr_way_lo)
      ,.gad_transfer_lce_i(gad_transfer_lce_lo)
      ,.gad_transfer_lce_way_i(gad_transfer_lce_way_lo)
      ,.gad_transfer_flag_i(gad_transfer_flag_lo)
      ,.gad_replacement_flag_i(gad_replacement_flag_lo)
      ,.gad_upgrade_flag_i(gad_upgrade_flag_lo)
      ,.gad_invalidate_flag_i(gad_invalidate_flag_lo)
      ,.gad_cached_flag_i(gad_cached_flag_lo)
      ,.gad_cached_exclusive_flag_i(gad_cached_exclusive_flag_lo)
      ,.gad_cached_owned_flag_i(gad_cached_owned_flag_lo)
      ,.gad_cached_dirty_flag_i(gad_cached_dirty_flag_lo)

      // register state outputs
      ,.mshr_o(mshr)
      ,.gpr_o(gpr_r_lo)
      ,.nc_data_o(nc_data_r_lo)
      ,.coh_state_o(coh_state_r_lo)
      );

  // Message unit
  bp_cce_msg
    #(.bp_params_p(bp_params_p)
      )
    bp_cce_msg
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.cfg_bus_i(cfg_bus_i)

      // To CCE
      ,.lce_req_i(lce_req_li)
      ,.lce_req_v_i(lce_req_v_i)
      ,.lce_req_yumi_o(lce_req_yumi_o)

      ,.lce_resp_i(lce_resp_li)
      ,.lce_resp_v_i(lce_resp_v_i)
      ,.lce_resp_yumi_o(lce_resp_yumi_o)

      // From CCE
      ,.lce_cmd_o(lce_cmd_lo)
      ,.lce_cmd_v_o(lce_cmd_v_o)
      ,.lce_cmd_ready_i(lce_cmd_ready_i)

      // To CCE
      ,.mem_resp_i(mem_resp_i)
      ,.mem_resp_v_i(mem_resp_v_i)
      ,.mem_resp_yumi_o(mem_resp_yumi_o)

      // From CCE
      ,.mem_cmd_o(mem_cmd_lo)
      ,.mem_cmd_v_o(mem_cmd_v_o)
      ,.mem_cmd_ready_i(mem_cmd_ready_i)

      ,.mshr_i(mshr)
      ,.decoded_inst_i(decoded_inst_lo)

      ,.pending_w_v_o(pending_w_v_from_msg)
      ,.pending_w_way_group_o(pending_w_way_group_from_msg)
      ,.pending_o(pending_from_msg)

      ,.pending_w_busy_o(pending_w_busy_from_msg)
      ,.lce_cmd_busy_o(lce_cmd_busy_from_msg)
      ,.msg_inv_busy_o(msg_inv_busy_lo)

      ,.gpr_i(gpr_r_lo)
      ,.sharers_hits_i(sharers_hits_lo)
      ,.sharers_ways_i(sharers_ways_lo)
      ,.nc_data_i(nc_data_r_lo)

      ,.fence_zero_o(fence_zero_lo)

      ,.lce_id_o(inv_dir_lce_lo)
      ,.lce_way_o(inv_dir_way_lo)

      ,.dir_w_v_o(msg_dir_w_v_lo)
      );


  // Combinational logic to select input source for various blocks

  // Directory source selects
  always_comb
  begin
    case (decoded_inst_lo.dir_way_group_sel)
      e_dir_wg_sel_r0: begin
        dir_set_li = gpr_r_lo[e_gpr_r0][lg_lce_sets_lp-1:0];
      end
      e_dir_wg_sel_r1: begin
        dir_set_li = gpr_r_lo[e_gpr_r1][lg_lce_sets_lp-1:0];
      end
      e_dir_wg_sel_r2: begin
        dir_set_li = gpr_r_lo[e_gpr_r2][lg_lce_sets_lp-1:0];
      end
      e_dir_wg_sel_r3: begin
        dir_set_li = gpr_r_lo[e_gpr_r3][lg_lce_sets_lp-1:0];
      end
      e_dir_wg_sel_r4: begin
        dir_set_li = gpr_r_lo[e_gpr_r4][lg_lce_sets_lp-1:0];
      end
      e_dir_wg_sel_r5: begin
        dir_set_li = gpr_r_lo[e_gpr_r5][lg_lce_sets_lp-1:0];
      end
      e_dir_wg_sel_r6: begin
        dir_set_li = gpr_r_lo[e_gpr_r6][lg_lce_sets_lp-1:0];
      end
      e_dir_wg_sel_r7: begin
        dir_set_li = gpr_r_lo[e_gpr_r7][lg_lce_sets_lp-1:0];
      end
      e_dir_wg_sel_req_addr: begin
        dir_set_li[0+:hash_index_width_lp] = cce_set_id_lo;
      end
      e_dir_wg_sel_lru_way_addr: begin
        dir_set_li[0+:hash_index_width_lp] = cce_set_id_lo;
      end
      default: begin
        dir_set_li = '0;
      end
    endcase
    case (decoded_inst_lo.dir_lce_sel)
      e_dir_lce_sel_r0: dir_lce_li = gpr_r_lo[e_gpr_r0][lg_num_lce_lp-1:0];
      e_dir_lce_sel_r1: dir_lce_li = gpr_r_lo[e_gpr_r1][lg_num_lce_lp-1:0];
      e_dir_lce_sel_r2: dir_lce_li = gpr_r_lo[e_gpr_r2][lg_num_lce_lp-1:0];
      e_dir_lce_sel_r3: dir_lce_li = gpr_r_lo[e_gpr_r3][lg_num_lce_lp-1:0];
      e_dir_lce_sel_r4: dir_lce_li = gpr_r_lo[e_gpr_r4][lg_num_lce_lp-1:0];
      e_dir_lce_sel_r5: dir_lce_li = gpr_r_lo[e_gpr_r5][lg_num_lce_lp-1:0];
      e_dir_lce_sel_r6: dir_lce_li = gpr_r_lo[e_gpr_r6][lg_num_lce_lp-1:0];
      e_dir_lce_sel_r7: dir_lce_li = gpr_r_lo[e_gpr_r7][lg_num_lce_lp-1:0];
      e_dir_lce_sel_req_lce: dir_lce_li = mshr.lce_id;
      e_dir_lce_sel_transfer_lce: dir_lce_li = mshr.tr_lce_id;
      e_dir_lce_sel_inv: dir_lce_li = inv_dir_lce_lo;
      default: dir_lce_li = '0;
    endcase
    case (decoded_inst_lo.dir_way_sel)
      e_dir_way_sel_r0: dir_way_li = gpr_r_lo[e_gpr_r0][lg_lce_assoc_lp-1:0];
      e_dir_way_sel_r1: dir_way_li = gpr_r_lo[e_gpr_r1][lg_lce_assoc_lp-1:0];
      e_dir_way_sel_r2: dir_way_li = gpr_r_lo[e_gpr_r2][lg_lce_assoc_lp-1:0];
      e_dir_way_sel_r3: dir_way_li = gpr_r_lo[e_gpr_r3][lg_lce_assoc_lp-1:0];
      e_dir_way_sel_r4: dir_way_li = gpr_r_lo[e_gpr_r4][lg_lce_assoc_lp-1:0];
      e_dir_way_sel_r5: dir_way_li = gpr_r_lo[e_gpr_r5][lg_lce_assoc_lp-1:0];
      e_dir_way_sel_r6: dir_way_li = gpr_r_lo[e_gpr_r6][lg_lce_assoc_lp-1:0];
      e_dir_way_sel_r7: dir_way_li = gpr_r_lo[e_gpr_r7][lg_lce_assoc_lp-1:0];
      e_dir_way_sel_req_addr_way: dir_way_li = mshr.way_id;
      e_dir_way_sel_lru_way_addr_way: dir_way_li = mshr.lru_way_id;
      e_dir_way_sel_sh_way_r0: dir_way_li = sharers_ways_lo[gpr_r_lo[e_gpr_r0][lg_num_lce_lp-1:0]];
      e_dir_way_sel_inv: dir_way_li = inv_dir_way_lo;
      default: dir_way_li = '0;
    endcase
    case (decoded_inst_lo.dir_coh_state_sel)
      e_dir_coh_sel_r0: dir_coh_state_li = gpr_r_lo[e_gpr_r0][`bp_coh_bits-1:0];
      e_dir_coh_sel_r1: dir_coh_state_li = gpr_r_lo[e_gpr_r1][`bp_coh_bits-1:0];
      e_dir_coh_sel_r2: dir_coh_state_li = gpr_r_lo[e_gpr_r2][`bp_coh_bits-1:0];
      e_dir_coh_sel_r3: dir_coh_state_li = gpr_r_lo[e_gpr_r3][`bp_coh_bits-1:0];
      e_dir_coh_sel_r4: dir_coh_state_li = gpr_r_lo[e_gpr_r4][`bp_coh_bits-1:0];
      e_dir_coh_sel_r5: dir_coh_state_li = gpr_r_lo[e_gpr_r5][`bp_coh_bits-1:0];
      e_dir_coh_sel_r6: dir_coh_state_li = gpr_r_lo[e_gpr_r6][`bp_coh_bits-1:0];
      e_dir_coh_sel_r7: dir_coh_state_li = gpr_r_lo[e_gpr_r7][`bp_coh_bits-1:0];
      e_dir_coh_sel_next_coh_st: dir_coh_state_li = mshr.next_coh_state;
      e_dir_coh_sel_inst_imm: dir_coh_state_li = decoded_inst_lo.imm[`bp_coh_bits-1:0];
      default: dir_coh_state_li = '0;
    endcase
    case (decoded_inst_lo.dir_tag_sel)
      e_dir_tag_sel_r0: dir_tag_li = gpr_r_lo[e_gpr_r0][paddr_width_p-1 -: tag_width_lp];
      e_dir_tag_sel_r1: dir_tag_li = gpr_r_lo[e_gpr_r1][paddr_width_p-1 -: tag_width_lp];
      e_dir_tag_sel_r2: dir_tag_li = gpr_r_lo[e_gpr_r2][paddr_width_p-1 -: tag_width_lp];
      e_dir_tag_sel_r3: dir_tag_li = gpr_r_lo[e_gpr_r3][paddr_width_p-1 -: tag_width_lp];
      e_dir_tag_sel_r4: dir_tag_li = gpr_r_lo[e_gpr_r4][paddr_width_p-1 -: tag_width_lp];
      e_dir_tag_sel_r5: dir_tag_li = gpr_r_lo[e_gpr_r5][paddr_width_p-1 -: tag_width_lp];
      e_dir_tag_sel_r6: dir_tag_li = gpr_r_lo[e_gpr_r6][paddr_width_p-1 -: tag_width_lp];
      e_dir_tag_sel_r7: dir_tag_li = gpr_r_lo[e_gpr_r7][paddr_width_p-1 -: tag_width_lp];
      e_dir_tag_sel_req_addr: dir_tag_li = mshr.paddr[paddr_width_p-1 -: tag_width_lp];
      e_dir_tag_sel_lru_way_addr: dir_tag_li = mshr.lru_paddr[paddr_width_p-1 -: tag_width_lp];
      e_dir_tag_sel_const_0: dir_tag_li = '0;
      default: dir_tag_li = '0;
    endcase
  end

  // ALU
  logic sharers_hits_r0;
  assign sharers_hits_r0 = sharers_hits_lo[gpr_r_lo[e_gpr_r0][lg_num_lce_lp-1:0]];
  logic [lg_lce_assoc_lp-1:0] sharers_ways_r0;
  assign sharers_ways_r0 = sharers_ways_lo[gpr_r_lo[e_gpr_r0][lg_num_lce_lp-1:0]];
  logic [`bp_coh_bits-1:0] sharers_coh_states_r0;
  assign sharers_coh_states_r0 = sharers_coh_states_lo[gpr_r_lo[e_gpr_r0][lg_num_lce_lp-1:0]];

  // Branch multiple-flag operands
  // Apply bit-mask from instruction to MSHR flags register
  logic [`bp_cce_inst_num_flags-1:0] bf_opd;
  assign bf_opd = (mshr.flags & decoded_inst_lo.imm[0+:`bp_cce_inst_num_flags]);
  logic bf_and, bf_or;
  // All flags are set (AND) if the flags with mask applied is the same as the mask itself
  assign bf_and = (bf_opd == decoded_inst_lo.imm[0+:`bp_cce_inst_num_flags]);
  // Any flag is set (OR) if at least one bit is set in the masked flags
  assign bf_or = |bf_opd;

  always_comb
  begin

    // ALU operand a select
    src_a = '0;
    case (decoded_inst_lo.src_a_sel)
      e_src_sel_gpr: begin
        case (decoded_inst_lo.src_a.gpr)
          e_src_r0: src_a = gpr_r_lo[e_gpr_r0];
          e_src_r1: src_a = gpr_r_lo[e_gpr_r1];
          e_src_r2: src_a = gpr_r_lo[e_gpr_r2];
          e_src_r3: src_a = gpr_r_lo[e_gpr_r3];
          e_src_r4: src_a = gpr_r_lo[e_gpr_r4];
          e_src_r5: src_a = gpr_r_lo[e_gpr_r5];
          e_src_r6: src_a = gpr_r_lo[e_gpr_r6];
          e_src_r7: src_a = gpr_r_lo[e_gpr_r7];
          e_src_gpr_imm: src_a = decoded_inst_lo.imm;
          default: src_a = '0;
        endcase
      end
      e_src_sel_flag: begin
        case (decoded_inst_lo.src_a.flag)
          e_src_rqf: src_a[0] = mshr.flags[e_flag_sel_rqf];
          e_src_ucf: src_a[0] = mshr.flags[e_flag_sel_ucf];
          e_src_nerf: src_a[0] = mshr.flags[e_flag_sel_nerf];
          e_src_ldf: src_a[0] = mshr.flags[e_flag_sel_ldf];
          e_src_pf: src_a[0] = mshr.flags[e_flag_sel_pf];
          e_src_lef: src_a[0] = mshr.flags[e_flag_sel_lef];
          e_src_cf: src_a[0] = mshr.flags[e_flag_sel_cf];
          e_src_cef: src_a[0] = mshr.flags[e_flag_sel_cef];
          e_src_cof: src_a[0] = mshr.flags[e_flag_sel_cof];
          e_src_cdf: src_a[0] = mshr.flags[e_flag_sel_cdf];
          e_src_tf: src_a[0] = mshr.flags[e_flag_sel_tf];
          e_src_rf: src_a[0] = mshr.flags[e_flag_sel_rf];
          e_src_uf: src_a[0] = mshr.flags[e_flag_sel_uf];
          e_src_if: src_a[0] = mshr.flags[e_flag_sel_if];
          e_src_nwbf: src_a[0] = mshr.flags[e_flag_sel_nwbf];
          e_src_sf: src_a[0] = mshr.flags[e_flag_sel_sf];
          e_src_flag_and: src_a[0] = bf_and;
          e_src_flag_nand: src_a[0] = ~bf_and;
          e_src_flag_or: src_a[0] = bf_or;
          e_src_flag_nor: src_a[0] = ~bf_or;
          e_src_flag_imm: src_a = decoded_inst_lo.imm;
          default: src_a = '0;
        endcase
      end
      e_src_sel_special: begin
        case (decoded_inst_lo.src_a.special)
          e_src_sharers_hit_r0: src_a[0] = sharers_hits_r0;
          e_src_sharers_way_r0: src_a[0+:lg_lce_assoc_lp] = sharers_ways_r0;
          e_src_sharers_state_r0: src_a[0+:`bp_coh_bits] = sharers_coh_states_r0;
          e_src_req_lce: src_a[0+:lg_num_lce_lp] = mshr.lce_id;
          e_src_next_coh_state: src_a[0+:`bp_coh_bits] = mshr.next_coh_state;
          e_src_coh_state: src_a[0+:`bp_coh_bits] = coh_state_r_lo;
          e_src_num_lce: src_a[0+:lg_num_lce_lp+1] = num_lce_p[0+:lg_num_lce_lp+1];
          e_src_req_addr: src_a[0+:paddr_width_p] = mshr.paddr;
          e_src_num_cce: src_a[0+:lg_num_cce_lp+1] = num_cce_p[0+:lg_num_cce_lp+1];
          e_src_lce_assoc: src_a[0+:lg_lce_assoc_lp+1] = lce_assoc_p[0+:lg_lce_assoc_lp+1];
          e_src_num_wg: src_a[0+:lg_num_way_groups_lp+1] = num_way_groups_lp[0+:lg_num_way_groups_lp+1];
          e_src_lce_req_v: src_a[0] = lce_req_v_i;
          e_src_mem_resp_v: src_a[0] = mem_resp_v_i;
          e_src_pending_v: src_a = '0; // TODO: v2
          e_src_lce_resp_v: src_a[0] = lce_resp_v_i;
          e_src_lce_resp_type: src_a[0+:$bits(bp_lce_cce_resp_type_e)] = lce_resp_li.msg_type;
          e_src_special_0: src_a[0] = 1'b0;
          e_src_special_1: src_a[0] = 1'b1;
          e_src_cce_id: src_a[0+:lg_num_cce_lp] = cfg_bus_cast_i.cce_id;
          e_src_special_imm: src_a = decoded_inst_lo.imm;
          default: src_a = '0;
        endcase
      end
      default: src_a = '0;
    endcase // src_a


    // ALU operand b select
    src_b = '0;
    case (decoded_inst_lo.src_b_sel)
      e_src_sel_gpr: begin
        case (decoded_inst_lo.src_b.gpr)
          e_src_r0: src_b = gpr_r_lo[e_gpr_r0];
          e_src_r1: src_b = gpr_r_lo[e_gpr_r1];
          e_src_r2: src_b = gpr_r_lo[e_gpr_r2];
          e_src_r3: src_b = gpr_r_lo[e_gpr_r3];
          e_src_r4: src_b = gpr_r_lo[e_gpr_r4];
          e_src_r5: src_b = gpr_r_lo[e_gpr_r5];
          e_src_r6: src_b = gpr_r_lo[e_gpr_r6];
          e_src_r7: src_b = gpr_r_lo[e_gpr_r7];
          e_src_gpr_imm: src_b = decoded_inst_lo.imm;
          default: src_b = '0;
        endcase
      end
      e_src_sel_flag: begin
        case (decoded_inst_lo.src_b.flag)
          e_src_rqf: src_b[0] = mshr.flags[e_flag_sel_rqf];
          e_src_ucf: src_b[0] = mshr.flags[e_flag_sel_ucf];
          e_src_nerf: src_b[0] = mshr.flags[e_flag_sel_nerf];
          e_src_ldf: src_b[0] = mshr.flags[e_flag_sel_ldf];
          e_src_pf: src_b[0] = mshr.flags[e_flag_sel_pf];
          e_src_lef: src_b[0] = mshr.flags[e_flag_sel_lef];
          e_src_cf: src_b[0] = mshr.flags[e_flag_sel_cf];
          e_src_cef: src_b[0] = mshr.flags[e_flag_sel_cef];
          e_src_cof: src_b[0] = mshr.flags[e_flag_sel_cof];
          e_src_cdf: src_b[0] = mshr.flags[e_flag_sel_cdf];
          e_src_tf: src_b[0] = mshr.flags[e_flag_sel_tf];
          e_src_rf: src_b[0] = mshr.flags[e_flag_sel_rf];
          e_src_uf: src_b[0] = mshr.flags[e_flag_sel_uf];
          e_src_if: src_b[0] = mshr.flags[e_flag_sel_if];
          e_src_nwbf: src_b[0] = mshr.flags[e_flag_sel_nwbf];
          e_src_sf: src_b[0] = mshr.flags[e_flag_sel_sf];
          e_src_flag_and: src_b[0] = bf_and;
          e_src_flag_nand: src_b[0] = ~bf_and;
          e_src_flag_or: src_b[0] = bf_or;
          e_src_flag_nor: src_b[0] = ~bf_or;
          e_src_flag_imm: src_b = decoded_inst_lo.imm;
          default: src_b = '0;
        endcase
      end
      e_src_sel_special: begin
        case (decoded_inst_lo.src_b.special)
          e_src_sharers_hit_r0: src_b[0] = sharers_hits_r0;
          e_src_sharers_way_r0: src_b[0+:lg_lce_assoc_lp] = sharers_ways_r0;
          e_src_sharers_state_r0: src_b[0+:`bp_coh_bits] = sharers_coh_states_r0;
          e_src_req_lce: src_b[0+:lg_num_lce_lp] = mshr.lce_id;
          e_src_next_coh_state: src_b[0+:`bp_coh_bits] = mshr.next_coh_state;
          e_src_coh_state: src_b[0+:`bp_coh_bits] = coh_state_r_lo;
          e_src_num_lce: src_b[0+:lg_num_lce_lp+1] = num_lce_p[0+:lg_num_lce_lp+1];
          e_src_req_addr: src_b[0+:paddr_width_p] = mshr.paddr;
          e_src_num_cce: src_b[0+:lg_num_cce_lp+1] = num_cce_p[0+:lg_num_cce_lp+1];
          e_src_lce_assoc: src_b[0+:lg_lce_assoc_lp+1] = lce_assoc_p[0+:lg_lce_assoc_lp+1];
          e_src_num_wg: src_b[0+:lg_num_way_groups_lp+1] = num_way_groups_lp[0+:lg_num_way_groups_lp+1];
          e_src_lce_req_v: src_b[0] = lce_req_v_i;
          e_src_mem_resp_v: src_b[0] = mem_resp_v_i;
          e_src_pending_v: src_b = '0; // TODO: v2
          e_src_lce_resp_v: src_b[0] = lce_resp_v_i;
          e_src_lce_resp_type: src_b[0+:$bits(bp_lce_cce_resp_type_e)] = lce_resp_li.msg_type;
          e_src_special_0: src_b[0] = 1'b0;
          e_src_special_1: src_b[0] = 1'b1;
          e_src_cce_id: src_b[0+:lg_num_cce_lp] = cfg_bus_cast_i.cce_id;
          e_src_special_imm: src_b = decoded_inst_lo.imm;
          default: src_b = '0;
        endcase
      end
      default: src_b = '0;
    endcase // src_b

  end

endmodule
