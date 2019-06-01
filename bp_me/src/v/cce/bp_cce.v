/**
 *
 * Name:
 *   bp_cce.v
 *
 * Description:
 *
 */

module bp_cce
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_cfg_link_pkg::*;
  #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
    `declare_bp_proc_params(cfg_p)

    // Config channel
    , parameter cfg_link_addr_width_p = bp_cfg_link_addr_width_gp
    , parameter cfg_link_data_width_p = bp_cfg_link_data_width_gp

    , parameter cce_trace_p             = "inv"

    // Derived parameters
    , localparam block_size_in_bytes_lp    = (cce_block_width_p/8)
    , localparam lg_num_lce_lp             = `BSG_SAFE_CLOG2(num_lce_p)
    , localparam lg_num_cce_lp             = `BSG_SAFE_CLOG2(num_cce_p)
    , localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp)
    , localparam lg_lce_assoc_lp           = `BSG_SAFE_CLOG2(lce_assoc_p)
    , localparam lg_lce_sets_lp            = `BSG_SAFE_CLOG2(lce_sets_p)
    , localparam tag_width_lp              = (paddr_width_p-lg_lce_sets_lp
                                              -lg_block_size_in_bytes_lp)
    , localparam entry_width_lp            = (tag_width_lp+`bp_cce_coh_bits)
    , localparam tag_set_width_lp          = (entry_width_lp*lce_assoc_p)
    , localparam way_group_width_lp        = (tag_set_width_lp*num_lce_p)
    , localparam way_group_offset_high_lp  = (lg_block_size_in_bytes_lp+lg_lce_sets_lp)
    , localparam num_way_groups_lp         = (lce_sets_p/num_cce_p)
    , localparam lg_num_way_groups_lp      = `BSG_SAFE_CLOG2(num_way_groups_lp)
    , localparam inst_ram_addr_width_lp    = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)

    // interface widths
    `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
    `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
  )
  (input                                               clk_i
   , input                                             reset_i
   , input                                             freeze_i

   // Config channel
   , input                                             cfg_w_v_i
   , input [cfg_link_addr_width_p-1:0]                 cfg_addr_i
   , input [cfg_link_data_width_p-1:0]                 cfg_data_i

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

  `declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p);
  `declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p);

  bp_cce_lce_cmd_s lce_cmd;
  bp_lce_data_cmd_s lce_data_cmd;
  bp_cce_mem_cmd_s mem_cmd;
  bp_cce_mem_data_cmd_s mem_data_cmd;
  bp_lce_cce_data_resp_s lce_data_resp;
  bp_mem_cce_data_resp_s mem_data_resp;
  bp_lce_cce_resp_s lce_resp;

  // assign output queue ports to structure variables
  assign lce_cmd_o = lce_cmd;
  assign lce_data_cmd_o = lce_data_cmd;
  assign mem_cmd_o = mem_cmd;
  assign mem_data_cmd_o = mem_data_cmd;

  // cast input messages with data
  assign lce_data_resp = lce_data_resp_i;
  assign mem_data_resp = mem_data_resp_i;
  assign lce_resp = lce_resp_i;

  // PC to Decode signals
  logic [`bp_cce_inst_width-1:0] pc_inst_lo;
  logic pc_inst_v_lo;

  // Decode to PC signals
  logic pc_stall_lo;
  logic [inst_ram_addr_width_lp-1:0] pc_branch_target_lo;

  // PC output signals
  bp_cce_mode_e cce_mode_lo;

  // ALU signals
  logic alu_v_lo;
  logic alu_branch_res_lo;
  logic [`bp_cce_inst_gpr_width-1:0] alu_opd_a_li, alu_opd_b_li, alu_res_lo, mov_src;

  // Instruction Decode signals
  bp_cce_inst_decoded_s decoded_inst_lo;
  logic decoded_inst_v_lo;

  // Directory signals
  logic dir_pending_lo;
  logic dir_pending_v_lo;
  logic sharers_v_lo;
  logic [num_lce_p-1:0] sharers_hits_lo;
  logic [num_lce_p-1:0][lg_lce_assoc_lp-1:0] sharers_ways_lo;
  logic [num_lce_p-1:0][`bp_cce_coh_bits-1:0] sharers_coh_states_lo;
  logic dir_lru_v_lo;
  logic dir_lru_cached_excl_lo;
  logic [tag_width_lp-1:0] dir_lru_tag_lo;
  logic dir_busy_lo;

  logic [lg_num_way_groups_lp-1:0] dir_way_group_li;
  logic [lg_num_lce_lp-1:0] dir_lce_li;
  logic [lg_lce_assoc_lp-1:0] dir_way_li;
  logic [tag_width_lp-1:0] dir_tag_li;
  logic [`bp_cce_coh_bits-1:0] dir_coh_state_li;

  // GAD signals
  logic gad_v_li;

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

  // Register signals
  `declare_bp_cce_mshr_s(num_lce_p, lce_assoc_p, paddr_width_p);
  bp_cce_mshr_s mshr;

  bp_lce_cce_resp_msg_type_e null_wb_flag_li;
  assign null_wb_flag_li = lce_data_resp_v_i
                           ? (lce_data_resp.msg_type)
                           : bp_lce_cce_resp_msg_type_e'('0);
  bp_lce_cce_ack_type_e resp_ack_type_li;
  assign resp_ack_type_li = lce_resp_v_i
                            ? (lce_resp.msg_type)
                            : bp_lce_cce_ack_type_e'('0);
  logic [`bp_cce_inst_num_gpr-1:0][`bp_cce_inst_gpr_width-1:0] gpr_r_lo;
  logic [`bp_lce_cce_ack_type_width-1:0] ack_type_r_lo;
  logic [`bp_lce_cce_nc_req_size_width-1:0] nc_req_size_r_lo;
  logic [dword_width_p-1:0] nc_data_r_lo;
  logic lru_cached_excl_r_lo;

  // LCE Command Queue
  logic [lg_num_lce_lp-1:0] lce_cmd_lce;
  logic [paddr_width_p-1:0] lce_cmd_addr;
  logic [lg_lce_assoc_lp-1:0] lce_cmd_way;

  // PC Logic, Instruction RAM
  bp_cce_pc
    #(.inst_ram_els_p(num_cce_instr_ram_els_p)
      ,.cfg_link_addr_width_p(cfg_link_addr_width_p)
      ,.cfg_link_data_width_p(cfg_link_data_width_p)
      )
    inst_ram
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.freeze_i(freeze_i)

      ,.cfg_w_v_i(cfg_w_v_i)
      ,.cfg_addr_i(cfg_addr_i)
      ,.cfg_data_i(cfg_data_i)

      ,.alu_branch_res_i(alu_branch_res_lo)

      ,.dir_busy_i(dir_busy_lo)
      ,.gad_error_i(gad_error_lo)

      ,.pc_stall_i(pc_stall_lo)
      ,.pc_branch_target_i(pc_branch_target_lo)

      ,.inst_o(pc_inst_lo)
      ,.inst_v_o(pc_inst_v_lo)

      ,.cce_mode_o(cce_mode_lo)
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

      ,.lce_req_v_i(lce_req_v_i)
      ,.lce_resp_v_i(lce_resp_v_i)
      ,.lce_data_resp_v_i(lce_data_resp_v_i)
      ,.mem_resp_v_i(mem_resp_v_i)
      ,.mem_data_resp_v_i(mem_data_resp_v_i)
      ,.pending_v_i('0)

      ,.lce_cmd_ready_i(lce_cmd_ready_i)
      ,.lce_data_cmd_ready_i(lce_data_cmd_ready_i)
      ,.mem_cmd_ready_i(mem_cmd_ready_i)
      ,.mem_data_cmd_ready_i(mem_data_cmd_ready_i)

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
      ,.opd_a_i(alu_opd_a_li)
      ,.opd_b_i(alu_opd_b_li)
      ,.alu_op_i(decoded_inst_lo.minor_op_u.alu_minor_op)
      ,.v_o(alu_v_lo)
      ,.res_o(alu_res_lo)
      ,.branch_res_o(alu_branch_res_lo)
      );

  // Directory
  bp_cce_dir
    #(.num_way_groups_p(num_way_groups_lp)
      ,.num_lce_p(num_lce_p)
      ,.num_cce_p(num_cce_p)
      ,.lce_assoc_p(lce_assoc_p)
      ,.tag_width_p(tag_width_lp)
      )
    directory
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.way_group_i(dir_way_group_li)
      ,.lce_i(dir_lce_li)
      ,.way_i(dir_way_li)
      ,.lru_way_i(mshr.lru_way_id)

      ,.r_cmd_i(decoded_inst_lo.dir_r_cmd)
      ,.r_v_i(decoded_inst_lo.dir_r_v)

      ,.tag_i(dir_tag_li)
      ,.coh_state_i(dir_coh_state_li)
      ,.pending_i(decoded_inst_lo.imm[0])

      ,.w_cmd_i(decoded_inst_lo.dir_w_cmd)
      ,.w_v_i(decoded_inst_lo.dir_w_v)

      ,.pending_o(dir_pending_lo)
      ,.pending_v_o(dir_pending_v_lo)

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
  assign gad_v_li = decoded_inst_v_lo & decoded_inst_lo.gad_op_w_v;

  bp_cce_gad
    #(.num_lce_p(num_lce_p)
      ,.lce_assoc_p(lce_assoc_p)
      )
    gad
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.gad_v_i(gad_v_li)

      ,.sharers_v_i(sharers_v_lo)
      ,.sharers_hits_i(sharers_hits_lo)
      ,.sharers_ways_i(sharers_ways_lo)
      ,.sharers_coh_states_i(sharers_coh_states_lo)

      ,.req_lce_i(mshr.lce_id)
      ,.req_type_flag_i(mshr.flags[e_flag_sel_rqf])
      ,.lru_dirty_flag_i(mshr.flags[e_flag_sel_ldf])
      ,.lru_cached_excl_i(lru_cached_excl_r_lo)

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

  // Registers
  bp_cce_reg
    #(.num_lce_p(num_lce_p)
      ,.num_cce_p(num_cce_p)
      ,.paddr_width_p(paddr_width_p)
      ,.lce_assoc_p(lce_assoc_p)
      ,.lce_sets_p(lce_sets_p)
      ,.block_size_in_bytes_p(block_size_in_bytes_lp)
      ,.lce_req_data_width_p(dword_width_p)
      )
    registers
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.decoded_inst_i(decoded_inst_lo)
      ,.lce_req_i(lce_req_i)
      ,.null_wb_flag_i(null_wb_flag_li)
      ,.resp_ack_type_i(resp_ack_type_li)
      ,.mem_resp_i(mem_resp_i)
      ,.mem_data_resp_i(mem_data_resp_i)
      ,.alu_res_i(alu_res_lo)
      ,.mov_src_i(mov_src)

      ,.dir_pending_o_i(dir_pending_lo)
      ,.dir_pending_v_o_i(dir_pending_v_lo)
      ,.dir_lru_v_i(dir_lru_v_lo)
      ,.dir_lru_cached_excl_i(dir_lru_cached_excl_lo)
      ,.dir_lru_tag_i(dir_lru_tag_lo)

      ,.gad_req_addr_way_i(gad_req_addr_way_lo)
      ,.gad_transfer_lce_i(gad_transfer_lce_lo)
      ,.gad_transfer_lce_way_i(gad_transfer_lce_way_lo)
      ,.gad_transfer_flag_i(gad_transfer_flag_lo)
      ,.gad_replacement_flag_i(gad_replacement_flag_lo)
      ,.gad_upgrade_flag_i(gad_upgrade_flag_lo)
      ,.gad_invalidate_flag_i(gad_invalidate_flag_lo)
      ,.gad_exclusive_flag_i(gad_exclusive_flag_lo)
      ,.gad_cached_flag_i(gad_cached_flag_lo)

      // register state outputs
      ,.mshr_o(mshr)
      ,.gpr_o(gpr_r_lo)
      ,.ack_type_o(ack_type_r_lo)
      ,.nc_req_size_o(nc_req_size_r_lo)
      ,.nc_data_o(nc_data_r_lo)
      ,.lru_cached_excl_o(lru_cached_excl_r_lo)
      );

  // NOTE: num_cce_p must be a power of two
  localparam gpr_shift_lp = (num_cce_p == 1) ? 0 : lg_num_cce_lp;
  localparam [paddr_width_p-lg_lce_sets_lp-1:0] lce_cmd_addr_0 =
    (paddr_width_p-lg_lce_sets_lp)'('0);

  // Output queue message field inputs
  logic [lg_lce_sets_lp-1:0] gpr_set;
  always_comb
  begin
    gpr_set = '0;
    case (decoded_inst_lo.lce_cmd_lce_sel)
      e_lce_cmd_lce_r0: lce_cmd_lce = gpr_r_lo[e_gpr_r0][lg_num_lce_lp-1:0];
      e_lce_cmd_lce_r1: lce_cmd_lce = gpr_r_lo[e_gpr_r1][lg_num_lce_lp-1:0];
      e_lce_cmd_lce_r2: lce_cmd_lce = gpr_r_lo[e_gpr_r2][lg_num_lce_lp-1:0];
      e_lce_cmd_lce_r3: lce_cmd_lce = gpr_r_lo[e_gpr_r3][lg_num_lce_lp-1:0];
      e_lce_cmd_lce_req_lce: lce_cmd_lce = mshr.lce_id;
      e_lce_cmd_lce_tr_lce: lce_cmd_lce = mshr.tr_lce_id;
      e_lce_cmd_lce_0: lce_cmd_lce = '0;
      default: lce_cmd_lce = '0;
    endcase
    case (decoded_inst_lo.lce_cmd_addr_sel)
      // When using a GPR to source the LCE Command Address field, the GPR is setting only the
      // "set index" bits of the address. The GPR holds the way-group number relative to this CCE,
      // which is then translated into the proper set index in the LCE (sets in the LCEs are
      // striped across the CCEs in the system).
      // Thus, set index bits = (way_group * num_cce_p) + cce_id_i
      // NOTE: num_cce_p must be a power of two
      e_lce_cmd_addr_r0: begin
        gpr_set = gpr_r_lo[e_gpr_r0][lg_lce_sets_lp-1:0];
        lce_cmd_addr = (({lce_cmd_addr_0,gpr_set} << gpr_shift_lp) + paddr_width_p'(cce_id_i))
                       << lg_block_size_in_bytes_lp;
      end
      e_lce_cmd_addr_r1: begin
        gpr_set = gpr_r_lo[e_gpr_r1][lg_lce_sets_lp-1:0];
        lce_cmd_addr = (({lce_cmd_addr_0,gpr_set} << gpr_shift_lp) + paddr_width_p'(cce_id_i))
                       << lg_block_size_in_bytes_lp;
      end
      e_lce_cmd_addr_r2: begin
        gpr_set = gpr_r_lo[e_gpr_r2][lg_lce_sets_lp-1:0];
        lce_cmd_addr = (({lce_cmd_addr_0,gpr_set} << gpr_shift_lp) + paddr_width_p'(cce_id_i))
                       << lg_block_size_in_bytes_lp;
      end
      e_lce_cmd_addr_r3: begin
        gpr_set = gpr_r_lo[e_gpr_r3][lg_lce_sets_lp-1:0];
        lce_cmd_addr = (({lce_cmd_addr_0,gpr_set} << gpr_shift_lp) + paddr_width_p'(cce_id_i))
                       << lg_block_size_in_bytes_lp;
      end
      e_lce_cmd_addr_req_addr: begin
        lce_cmd_addr = mshr.paddr;
      end
      e_lce_cmd_addr_lru_way_addr: begin
        lce_cmd_addr = mshr.lru_paddr;
      end
      e_lce_cmd_addr_0: begin
        lce_cmd_addr = '0;
      end
      default: begin
        lce_cmd_addr = '0;
      end
    endcase
    case (decoded_inst_lo.lce_cmd_way_sel)
      e_lce_cmd_way_req_addr_way: begin
        lce_cmd_way = mshr.way_id;
      end
      e_lce_cmd_way_tr_addr_way: begin
        lce_cmd_way = mshr.tr_way_id;
      end
      e_lce_cmd_way_sh_list_r0: begin
        lce_cmd_way = sharers_ways_lo[gpr_r_lo[e_gpr_r0][lg_num_lce_lp-1:0]];
      end
      e_lce_cmd_way_lru_addr_way: begin
        lce_cmd_way = mshr.lru_way_id;
      end
      e_lce_cmd_way_0: begin
        lce_cmd_way = '0;
      end
      default: begin
        lce_cmd_way = '0;
      end
    endcase
  end
  // Mem Data Command Queue
  logic [paddr_width_p-1:0] mem_data_cmd_addr;
  always_comb
  begin
    case (decoded_inst_lo.mem_data_cmd_addr_sel)
      e_mem_data_cmd_addr_lru_way_addr: mem_data_cmd_addr = mshr.lru_paddr;
      e_mem_data_cmd_addr_req_addr: mem_data_cmd_addr = mshr.paddr;
      default mem_data_cmd_addr = '0;
    endcase
  end

  // Uncached access module
  logic                                          lce_req_yumi_from_uc;
  logic [lce_data_cmd_width_lp-1:0]              lce_data_cmd_from_uc;
  logic                                          lce_data_cmd_v_from_uc;
  logic [cce_lce_cmd_width_lp-1:0]               lce_cmd_from_uc;
  logic                                          lce_cmd_v_from_uc;
  logic                                          mem_resp_yumi_from_uc;
  logic                                          mem_data_resp_yumi_from_uc;
  logic [cce_mem_cmd_width_lp-1:0]               mem_cmd_from_uc;
  logic                                          mem_cmd_v_from_uc;
  logic [cce_mem_data_cmd_width_lp-1:0]          mem_data_cmd_from_uc;
  logic                                          mem_data_cmd_v_from_uc;

  bp_cce_uncached
    #(.num_lce_p(num_lce_p)
      ,.num_cce_p(num_cce_p)
      ,.paddr_width_p(paddr_width_p)
      ,.lce_assoc_p(lce_assoc_p)
      ,.lce_sets_p(lce_sets_p)
      ,.block_size_in_bytes_p(block_size_in_bytes_lp)
      ,.lce_req_data_width_p(dword_width_p)
      )
    bp_cce_uncached
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.cce_id_i(cce_id_i)
      ,.cce_mode_i(cce_mode_lo)

      // To CCE
      ,.lce_req_i(lce_req_i)
      ,.lce_req_v_i(lce_req_v_i)
      ,.lce_req_yumi_o(lce_req_yumi_from_uc)

      // From CCE
      ,.lce_cmd_o(lce_cmd_from_uc)
      ,.lce_cmd_v_o(lce_cmd_v_from_uc)
      ,.lce_cmd_ready_i(lce_cmd_ready_i)

      ,.lce_data_cmd_o(lce_data_cmd_from_uc)
      ,.lce_data_cmd_v_o(lce_data_cmd_v_from_uc)
      ,.lce_data_cmd_ready_i(lce_data_cmd_ready_i)

      // To CCE
      ,.mem_resp_i(mem_resp_i)
      ,.mem_resp_v_i(mem_resp_v_i)
      ,.mem_resp_yumi_o(mem_resp_yumi_from_uc)
      ,.mem_data_resp_i(mem_data_resp_i)
      ,.mem_data_resp_v_i(mem_data_resp_v_i)
      ,.mem_data_resp_yumi_o(mem_data_resp_yumi_from_uc)

      // From CCE
      ,.mem_cmd_o(mem_cmd_from_uc)
      ,.mem_cmd_v_o(mem_cmd_v_from_uc)
      ,.mem_cmd_ready_i(mem_cmd_ready_i)
      ,.mem_data_cmd_o(mem_data_cmd_from_uc)
      ,.mem_data_cmd_v_o(mem_data_cmd_v_from_uc)
      ,.mem_data_cmd_ready_i(mem_data_cmd_ready_i)
      );

  // Output Message Formation

  // Input messages to the CCE are buffered by two element FIFOs in bp_cce_top.v, thus
  // the outbound valid signal is a yumi.
  //
  // Outbound queues all use ready&valid handshaking. Outbound messages going to LCEs are not
  // buffered by bp_cce_top.v, but messages to memory are.
  always_comb
  begin
    if (cce_mode_lo == e_cce_mode_uncached) begin
      // In uncached mode, LCE resp, data resp, and cmd are never used
      lce_resp_yumi_o = '0;
      lce_data_resp_yumi_o = '0;

      // Remainder of interface signals come from the uncached access module
      lce_req_yumi_o = lce_req_yumi_from_uc;
      mem_resp_yumi_o = mem_resp_yumi_from_uc;
      mem_data_resp_yumi_o = mem_data_resp_yumi_from_uc;
      lce_cmd_v_o = lce_cmd_v_from_uc;
      lce_data_cmd_v_o = lce_data_cmd_v_from_uc;
      mem_cmd_v_o = mem_cmd_v_from_uc;
      mem_data_cmd_v_o = mem_data_cmd_v_from_uc;

      lce_cmd = lce_cmd_from_uc;
      lce_data_cmd = lce_data_cmd_from_uc;
      mem_data_cmd = mem_data_cmd_from_uc;
      mem_cmd = mem_cmd_from_uc;
    end else begin
      // Normal operation - control signals come from decoder
      lce_req_yumi_o = decoded_inst_lo.lce_req_yumi;
      lce_resp_yumi_o = decoded_inst_lo.lce_resp_yumi;
      lce_data_resp_yumi_o = decoded_inst_lo.lce_data_resp_yumi;
      mem_resp_yumi_o = decoded_inst_lo.mem_resp_yumi;
      mem_data_resp_yumi_o = decoded_inst_lo.mem_data_resp_yumi;

      lce_cmd_v_o = decoded_inst_lo.lce_cmd_v;
      lce_data_cmd_v_o = decoded_inst_lo.lce_data_cmd_v;
      mem_cmd_v_o = decoded_inst_lo.mem_cmd_v;
      mem_data_cmd_v_o = decoded_inst_lo.mem_data_cmd_v;

      // LCE Command Queue Inputs
      lce_cmd.dst_id = lce_cmd_lce;
      lce_cmd.src_id = (lg_num_cce_lp)'(cce_id_i);
      lce_cmd.msg_type = decoded_inst_lo.lce_cmd_cmd;
      lce_cmd.addr = lce_cmd_addr;
      lce_cmd.way_id = lce_cmd_way;
      if ((decoded_inst_lo.lce_cmd_cmd == e_lce_cmd_set_tag)
          | (decoded_inst_lo.lce_cmd_cmd == e_lce_cmd_set_tag_wakeup)) begin
        lce_cmd.state = mshr.next_coh_state;
      end else begin
        lce_cmd.state = '0;
      end
      if (decoded_inst_lo.lce_cmd_cmd == e_lce_cmd_transfer) begin
        lce_cmd.target = mshr.lce_id;
        lce_cmd.target_way_id = mshr.lru_way_id;
      end else begin
        lce_cmd.target = '0;
        lce_cmd.target_way_id = '0;
      end

      // LCE Data Command Queue Inputs
      lce_data_cmd.dst_id = mshr.lce_id;
      if (mshr.flags[e_flag_sel_ucf] == e_lce_req_non_cacheable) begin
        lce_data_cmd.msg_type = e_lce_data_cmd_non_cacheable;
        lce_data_cmd.way_id = '0;
        lce_data_cmd.data = {(cce_block_width_p-dword_width_p)'('0)
                             , mem_data_resp.data[0+:dword_width_p]};
      end else begin
        lce_data_cmd.msg_type = e_lce_data_cmd_cce;
        lce_data_cmd.way_id = mshr.lru_way_id;
        lce_data_cmd.data = mem_data_resp.data;
      end

      // Mem Command Queue Inputs
      mem_cmd.msg_type = bp_lce_cce_req_type_e'(mshr.flags[e_flag_sel_rqf]);
      mem_cmd.payload.lce_id = mshr.lce_id;
      mem_cmd.payload.way_id = mshr.lru_way_id;
      mem_cmd.addr = mshr.paddr;
      mem_cmd.non_cacheable = bp_lce_cce_req_non_cacheable_e'(mshr.flags[e_flag_sel_ucf]);
      mem_cmd.nc_size = bp_lce_cce_nc_req_size_e'(nc_req_size_r_lo);

      // Mem Data Command Queue Inputs
      mem_data_cmd.msg_type = bp_lce_cce_req_type_e'(mshr.flags[e_flag_sel_rqf]);
      mem_data_cmd.addr = mem_data_cmd_addr;
      if (mshr.flags[e_flag_sel_ucf]) begin
        mem_data_cmd.data = {(cce_block_width_p-dword_width_p)'('0),nc_data_r_lo};
      end else begin
        mem_data_cmd.data = lce_data_resp.data;
      end
      mem_data_cmd.non_cacheable = bp_lce_cce_req_non_cacheable_e'(mshr.flags[e_flag_sel_ucf]);
      mem_data_cmd.nc_size = bp_lce_cce_nc_req_size_e'(nc_req_size_r_lo);
      // Request data for return
      mem_data_cmd.payload.lce_id = mshr.lce_id;
      mem_data_cmd.payload.way_id = mshr.lru_way_id;
      mem_data_cmd.payload.req_addr = mshr.paddr;
      mem_data_cmd.payload.tr_lce_id = mshr.tr_lce_id;
      mem_data_cmd.payload.tr_way_id = mshr.tr_way_id;
      mem_data_cmd.payload.transfer = mshr.flags[e_flag_sel_tf];
      mem_data_cmd.payload.replacement = mshr.flags[e_flag_sel_rf];
    end
  end


  // Combinational logic to select input source for various blocks

  // Directory source selects
  always_comb
  begin
    case (decoded_inst_lo.dir_way_group_sel)
      e_dir_wg_sel_r0: begin
        dir_way_group_li = gpr_r_lo[e_gpr_r0][lg_num_way_groups_lp-1:0];
      end
      e_dir_wg_sel_r1: begin
        dir_way_group_li = gpr_r_lo[e_gpr_r1][lg_num_way_groups_lp-1:0];
      end
      e_dir_wg_sel_r2: begin
        dir_way_group_li = gpr_r_lo[e_gpr_r2][lg_num_way_groups_lp-1:0];
      end
      e_dir_wg_sel_r3: begin
        dir_way_group_li = gpr_r_lo[e_gpr_r3][lg_num_way_groups_lp-1:0];
      end
      e_dir_wg_sel_req_addr: begin
        dir_way_group_li = mshr.paddr[way_group_offset_high_lp-1 -: lg_num_way_groups_lp];
      end
      e_dir_wg_sel_lru_way_addr: begin
        dir_way_group_li = mshr.lru_paddr[way_group_offset_high_lp-1 -: lg_num_way_groups_lp];
      end
      default: begin
        dir_way_group_li = '0;
      end
    endcase
    case (decoded_inst_lo.dir_lce_sel)
      e_dir_lce_sel_r0: dir_lce_li = gpr_r_lo[e_gpr_r0][lg_num_lce_lp-1:0];
      e_dir_lce_sel_r1: dir_lce_li = gpr_r_lo[e_gpr_r1][lg_num_lce_lp-1:0];
      e_dir_lce_sel_r2: dir_lce_li = gpr_r_lo[e_gpr_r2][lg_num_lce_lp-1:0];
      e_dir_lce_sel_r3: dir_lce_li = gpr_r_lo[e_gpr_r3][lg_num_lce_lp-1:0];
      e_dir_lce_sel_req_lce: dir_lce_li = mshr.lce_id;
      e_dir_lce_sel_transfer_lce: dir_lce_li = mshr.tr_lce_id;
      default: dir_lce_li = '0;
    endcase
    case (decoded_inst_lo.dir_way_sel)
      e_dir_way_sel_r0: dir_way_li = gpr_r_lo[e_gpr_r0][lg_lce_assoc_lp-1:0];
      e_dir_way_sel_r1: dir_way_li = gpr_r_lo[e_gpr_r1][lg_lce_assoc_lp-1:0];
      e_dir_way_sel_r2: dir_way_li = gpr_r_lo[e_gpr_r2][lg_lce_assoc_lp-1:0];
      e_dir_way_sel_r3: dir_way_li = gpr_r_lo[e_gpr_r3][lg_lce_assoc_lp-1:0];
      e_dir_way_sel_req_addr_way: dir_way_li = mshr.way_id;
      e_dir_way_sel_lru_way_addr_way: dir_way_li = mshr.lru_way_id;
      e_dir_way_sel_sh_way_r0: dir_way_li = sharers_ways_lo[gpr_r_lo[e_gpr_r0][lg_num_lce_lp-1:0]];
      default: dir_way_li = '0;
    endcase
    case (decoded_inst_lo.dir_coh_state_sel)
      e_dir_coh_sel_next_coh_st: dir_coh_state_li = mshr.next_coh_state;
      e_dir_coh_sel_inst_imm: dir_coh_state_li = decoded_inst_lo.imm[`bp_cce_coh_bits-1:0];
      default: dir_coh_state_li = '0;
    endcase
    case (decoded_inst_lo.dir_tag_sel)
      e_dir_tag_sel_req_addr: dir_tag_li = mshr.paddr[paddr_width_p-1 -: tag_width_lp];
      e_dir_tag_sel_lru_way_addr: dir_tag_li = mshr.lru_paddr[paddr_width_p-1 -: tag_width_lp];
      e_dir_tag_sel_const_0: dir_tag_li = '0;
      default: dir_tag_li = '0;
    endcase
  end

  // ALU

  logic sharers_hits_r0;
  assign sharers_hits_r0 = sharers_hits_lo[gpr_r_lo[e_gpr_r0][lg_num_lce_lp-1:0]];
  localparam [`bp_cce_inst_gpr_width-`bp_lce_cce_ack_type_width-1:0] gpr_ack_0 =
    (`bp_cce_inst_gpr_width-`bp_lce_cce_ack_type_width)'('0);
  localparam [`bp_cce_inst_gpr_width-2:0] gpr_width_minus1_0 = (`bp_cce_inst_gpr_width-1)'('0);
  always_comb
  begin

    // ALU operand a select
    // TODO: set to 0 if not ALU operation
    // source from "src_a" wire (change alu_opd_a_li in this case to src_a), then add logic
    // similar to mov_src to generate alu_opd_a_li
    case (decoded_inst_lo.src_a)
      e_src_r0: begin
        alu_opd_a_li = gpr_r_lo[e_gpr_r0];
      end
      e_src_r1: begin
        alu_opd_a_li = gpr_r_lo[e_gpr_r1];
      end
      e_src_r2: begin
        alu_opd_a_li = gpr_r_lo[e_gpr_r2];
      end
      e_src_r3: begin
        alu_opd_a_li = gpr_r_lo[e_gpr_r3];
      end
      e_src_rqf: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_rqf]};
      end
      e_src_nerf: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_nerf]};
      end
      e_src_ldf: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_ldf]};
      end
      e_src_nwbf: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_nwbf]};
      end
      e_src_tf: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_tf]};
      end
      e_src_rf: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_rf]};
      end
      e_src_rwbf: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_rwbf]};
      end
      e_src_pf: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_pf]};
      end
      e_src_uf: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_uf]};
      end
      e_src_if: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_if]};
      end
      e_src_ef: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_ef]};
      end
      e_src_pcf: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_pcf]};
      end
      e_src_ucf: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_ucf]};
      end
      e_src_cf: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_cf]};
      end
      e_src_const_0: begin
        alu_opd_a_li = '0;
      end
      e_src_const_1: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, 1'b1};
      end
      e_src_imm: begin
        alu_opd_a_li = decoded_inst_lo.imm;
      end
      e_src_req_lce: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-lg_num_lce_lp){1'b0}}, mshr.lce_id};
      end
      e_src_ack_type: begin
        alu_opd_a_li = {gpr_ack_0, ack_type_r_lo};
      end
      e_src_sharers_hit_r0: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, sharers_hits_r0};
      end
      e_src_cce_id: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-lg_num_cce_lp){1'b0}}, cce_id_i};
      end
      e_src_lce_req_ready: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, lce_req_v_i};
      end
      e_src_mem_resp_ready: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mem_resp_v_i};
      end
      e_src_mem_data_resp_ready: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mem_data_resp_v_i};
      end
      e_src_pending_ready: begin
        alu_opd_a_li = '0; // TODO: v2
      end
      e_src_lce_resp_ready: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, lce_resp_v_i};
      end
      e_src_lce_data_resp_ready: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, lce_data_resp_v_i};
      end
      default: begin
        alu_opd_a_li = '0;
      end
    endcase

    // TODO: source from "src_a" wire that will source both mov_src_a and alu_src_a
    if (decoded_inst_lo.mov_dst_w_v) begin
      mov_src = alu_opd_a_li;
    end else begin
      mov_src = '0;
    end

  

    // ALU operand b select
    // TODO: set to 0 unless required by current operation
    alu_opd_b_li = '0;
    case (decoded_inst_lo.src_b)
      e_src_r0: alu_opd_b_li = gpr_r_lo[e_gpr_r0];
      e_src_r1: alu_opd_b_li = gpr_r_lo[e_gpr_r1];
      e_src_r2: alu_opd_b_li = gpr_r_lo[e_gpr_r2];
      e_src_r3: alu_opd_b_li = gpr_r_lo[e_gpr_r3];
      e_src_rqf: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_rqf]};
      e_src_nerf: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_nerf]};
      e_src_ldf: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_ldf]};
      e_src_nwbf: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_nwbf]};
      e_src_tf: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_tf]};
      e_src_rf: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_rf]};
      e_src_rwbf: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_rwbf]};
      e_src_pf: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_pf]};
      e_src_uf: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_uf]};
      e_src_if: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_if]};
      e_src_ef: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_ef]};
      e_src_pcf: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_pcf]};
      e_src_ucf: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_ucf]};
      e_src_cf: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mshr.flags[e_flag_sel_cf]};
      e_src_const_0: alu_opd_b_li = '0;
      e_src_const_1: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, 1'b1};
      e_src_imm: alu_opd_b_li = decoded_inst_lo.imm;
      e_src_req_lce: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-lg_num_lce_lp){1'b0}}, mshr.lce_id};
      e_src_ack_type: alu_opd_b_li = {gpr_ack_0, ack_type_r_lo};
      e_src_sharers_hit_r0: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, sharers_hits_r0};
      e_src_cce_id: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-lg_num_cce_lp){1'b0}}, cce_id_i};
      e_src_lce_req_ready: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, lce_req_v_i};
      e_src_mem_resp_ready: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, mem_resp_v_i};
      e_src_mem_data_resp_ready: alu_opd_b_li = {gpr_width_minus1_0, mem_data_resp_v_i};
      e_src_pending_ready: alu_opd_b_li = '0; // TODO: v2
      e_src_lce_resp_ready: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, lce_resp_v_i};
      e_src_lce_data_resp_ready: alu_opd_b_li = {gpr_width_minus1_0, lce_data_resp_v_i};
      default: alu_opd_b_li = '0;
    endcase
  end

endmodule
