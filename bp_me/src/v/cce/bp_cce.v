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
  import bp_cce_pkg::*;
  #(parameter num_lce_p                    = "inv"
    , parameter num_cce_p                  = "inv"
    , parameter paddr_width_p              = "inv"
    , parameter lce_assoc_p                = "inv"
    , parameter lce_sets_p                 = "inv"
    , parameter block_size_in_bytes_p      = "inv"
    , parameter num_cce_inst_ram_els_p     = "inv"
    , parameter lce_req_data_width_p       = "inv"

    // Config channel
    , parameter cfg_link_addr_width_p = "inv"
    , parameter cfg_link_data_width_p = "inv"

    // Derived parameters
    , localparam lg_num_lce_lp             = `BSG_SAFE_CLOG2(num_lce_p)
    , localparam lg_num_cce_lp             = `BSG_SAFE_CLOG2(num_cce_p)
    , localparam block_size_in_bits_lp     = (block_size_in_bytes_p*8)
    , localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_p)
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
    , localparam inst_ram_addr_width_lp    = `BSG_SAFE_CLOG2(num_cce_inst_ram_els_p)

    , localparam bp_lce_cce_req_width_lp=
      `bp_lce_cce_req_width(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, lce_req_data_width_p)
    , localparam bp_lce_cce_resp_width_lp=
      `bp_lce_cce_resp_width(num_cce_p, num_lce_p, paddr_width_p)
    , localparam bp_lce_cce_data_resp_width_lp=
      `bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, paddr_width_p, block_size_in_bits_lp)
    , localparam bp_cce_lce_cmd_width_lp=
      `bp_cce_lce_cmd_width(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p)
    , localparam bp_lce_data_cmd_width_lp=
      `bp_lce_data_cmd_width(num_lce_p, block_size_in_bits_lp, lce_assoc_p)

    , localparam bp_mem_cce_resp_width_lp=
      `bp_mem_cce_resp_width(paddr_width_p, num_lce_p, lce_assoc_p)
    , localparam bp_mem_cce_data_resp_width_lp=
      `bp_mem_cce_data_resp_width(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p)
    , localparam bp_cce_mem_cmd_width_lp=
      `bp_cce_mem_cmd_width(paddr_width_p, num_lce_p, lce_assoc_p)
    , localparam bp_cce_mem_data_cmd_width_lp=
      `bp_cce_mem_data_cmd_width(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p)
  )
  (input                                               clk_i
   , input                                             reset_i
   , input                                             freeze_i

   // Config channel
   , input [cfg_link_addr_width_p-2:0]                 config_addr_i
   , input [cfg_link_data_width_p-1:0]                 config_data_i
   , input                                             config_v_i
   , input                                             config_w_i
   , output logic                                      config_ready_o

   , output logic [cfg_link_data_width_p-1:0]          config_data_o
   , output logic                                      config_v_o
   , input                                             config_ready_i

   // LCE-CCE Interface
   // inbound: valid->ready (a.k.a., valid->yumi), demanding consumer (connects to FIFO)
   // outbound: ready&valid (connects directly to ME network)
   , input [bp_lce_cce_req_width_lp-1:0]               lce_req_i
   , input                                             lce_req_v_i
   , output logic                                      lce_req_yumi_o

   , input [bp_lce_cce_resp_width_lp-1:0]              lce_resp_i
   , input                                             lce_resp_v_i
   , output logic                                      lce_resp_yumi_o

   , input [bp_lce_cce_data_resp_width_lp-1:0]         lce_data_resp_i
   , input                                             lce_data_resp_v_i
   , output logic                                      lce_data_resp_yumi_o

   , output logic [bp_cce_lce_cmd_width_lp-1:0]        lce_cmd_o
   , output logic                                      lce_cmd_v_o
   , input                                             lce_cmd_ready_i

   , output logic [bp_lce_data_cmd_width_lp-1:0]       lce_data_cmd_o
   , output logic                                      lce_data_cmd_v_o
   , input                                             lce_data_cmd_ready_i

   // CCE-MEM Interface
   // inbound: valid->ready (a.k.a., valid->yumi), demanding consumer (connects to FIFO)
   // outbound: ready&valid (connects to FIFO)
   , input [bp_mem_cce_resp_width_lp-1:0]              mem_resp_i
   , input                                             mem_resp_v_i
   , output logic                                      mem_resp_yumi_o

   , input [bp_mem_cce_data_resp_width_lp-1:0]         mem_data_resp_i
   , input                                             mem_data_resp_v_i
   , output logic                                      mem_data_resp_yumi_o

   , output logic [bp_cce_mem_cmd_width_lp-1:0]        mem_cmd_o
   , output logic                                      mem_cmd_v_o
   , input                                             mem_cmd_ready_i

   , output logic [bp_cce_mem_data_cmd_width_lp-1:0]   mem_data_cmd_o
   , output logic                                      mem_data_cmd_v_o
   , input                                             mem_data_cmd_ready_i

   , input [lg_num_cce_lp-1:0]                         cce_id_i

   , output logic [inst_ram_addr_width_lp-1:0]         boot_rom_addr_o
   , input [`bp_cce_inst_width-1:0]                    boot_rom_data_i
  );

  initial begin
    assert (lce_sets_p > 1) else $error("Number of LCE sets must be greater than 1");
  end

  // Define structure variables for output queues

  `declare_bp_me_if(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p);

  `declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p);
  `declare_bp_lce_data_cmd_s(num_lce_p
                             ,block_size_in_bits_lp
                             ,lce_assoc_p);

  bp_cce_lce_cmd_s lce_cmd_s_o;
  bp_lce_data_cmd_s lce_data_cmd_s_o;
  bp_cce_mem_cmd_s mem_cmd_s_o;
  bp_cce_mem_data_cmd_s mem_data_cmd_s_o;

  // assign output queue ports to structure variables
  always_comb
  begin
    lce_cmd_o = lce_cmd_s_o;
    lce_data_cmd_o = lce_data_cmd_s_o;
    mem_cmd_o = mem_cmd_s_o;
    mem_data_cmd_o = mem_data_cmd_s_o;
  end

  // PC to Decode signals
  logic [`bp_cce_inst_width-1:0] pc_inst_lo;
  logic pc_inst_v_lo;

  // Decode to PC signals
  logic pc_stall_lo;
  logic [inst_ram_addr_width_lp-1:0] pc_branch_target_lo;

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
  logic dir_entry_v_lo;
  logic dir_way_group_v_lo;
  logic [tag_width_lp-1:0] dir_tag_lo;
  logic [`bp_cce_coh_bits-1:0] dir_coh_state_lo;
  logic [way_group_width_lp-1:0] dir_way_group_lo;

  logic [lg_num_way_groups_lp-1:0] dir_way_group_li;
  logic [lg_num_lce_lp-1:0] dir_lce_li;
  logic [lg_lce_assoc_lp-1:0] dir_way_li;
  logic [tag_width_lp-1:0] dir_tag_li;
  logic [`bp_cce_coh_bits-1:0] dir_coh_state_li;

  // GAD signals
  logic [lg_lce_assoc_lp-1:0] gad_req_addr_way_lo;
  logic [lg_num_lce_lp-1:0] gad_transfer_lce_lo;
  logic [lg_lce_assoc_lp-1:0] gad_transfer_lce_way_lo;
  logic gad_transfer_flag_lo;
  logic gad_replacement_flag_lo;
  logic gad_upgrade_flag_lo;
  logic gad_invalidate_flag_lo;
  logic gad_exclusive_flag_lo;
  logic gad_cached_flag_lo;
  logic [tag_width_lp-1:0] gad_lru_tag_lo;
  logic [`bp_cce_coh_bits-1:0] gad_coh_state_lo;
  logic [num_lce_p-1:0] gad_sharers_hits_lo;
  logic [num_lce_p-1:0][lg_lce_assoc_lp-1:0] gad_sharers_ways_lo;
  logic [num_lce_p-1:0][`bp_cce_coh_bits-1:0] gad_sharers_coh_states_lo;
  logic gad_v_li;

  // Register signals
  logic [lg_num_lce_lp-1:0] req_lce_r_lo;
  logic [paddr_width_p-1:0] req_addr_r_lo;
  logic [tag_width_lp-1:0] req_tag_r_lo;
  logic [lg_lce_assoc_lp-1:0] req_addr_way_r_lo;
  logic [`bp_cce_coh_bits-1:0] req_coh_state_r_lo;
  logic [lg_lce_assoc_lp-1:0] lru_way_r_lo;
  logic [paddr_width_p-1:0] lru_addr_r_lo;
  logic [lg_num_lce_lp-1:0] transfer_lce_r_lo;
  logic [lg_lce_assoc_lp-1:0] transfer_lce_way_r_lo;
  logic [`bp_cce_coh_bits-1:0] next_coh_state_r_lo;
  logic [block_size_in_bits_lp-1:0] cache_block_data_r_lo;
  logic [`bp_cce_inst_num_flags-1:0] flags_r_lo;
  logic [`bp_cce_inst_num_gpr-1:0][`bp_cce_inst_gpr_width-1:0] gpr_r_lo;
  logic [`bp_lce_cce_ack_type_width-1:0] ack_type_r_lo;
  logic [way_group_width_lp-1:0] way_group_r_lo;
  logic [num_lce_p-1:0] sharers_hits_r_lo;
  logic [num_lce_p-1:0][lg_lce_assoc_lp-1:0] sharers_ways_r_lo;
  logic [num_lce_p-1:0][`bp_cce_coh_bits-1:0] sharers_coh_states_r_lo;
  logic [`bp_lce_cce_nc_req_size_width-1:0] nc_req_size_r_lo;
  logic [lce_req_data_width_p-1:0] nc_data_r_lo;

  // LCE Command Queue
  logic [lg_num_lce_lp-1:0] lce_cmd_lce;
  logic [paddr_width_p-1:0] lce_cmd_addr;
  logic [lg_lce_assoc_lp-1:0] lce_cmd_way;

  // PC Logic, Instruction RAM
  bp_cce_pc
    #(.inst_ram_els_p(num_cce_inst_ram_els_p)
      ,.cfg_link_addr_width_p(cfg_link_addr_width_p)
      ,.cfg_link_data_width_p(cfg_link_data_width_p)
      )
    pc_inst_ram
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.freeze_i(freeze_i)

      ,.config_addr_i(config_addr_i)
      ,.config_data_i(config_data_i)
      ,.config_v_i(config_v_i)
      ,.config_w_i(config_w_i)
      ,.config_ready_o(config_ready_o)

      ,.config_data_o(config_data_o)
      ,.config_v_o(config_v_o)
      ,.config_ready_i(config_ready_i)

      ,.alu_branch_res_i(alu_branch_res_lo)

      ,.pc_stall_i(pc_stall_lo)
      ,.pc_branch_target_i(pc_branch_target_lo)

      ,.inst_o(pc_inst_lo)
      ,.inst_v_o(pc_inst_v_lo)

      ,.boot_rom_addr_o(boot_rom_addr_o)
      ,.boot_rom_data_i(boot_rom_data_i)
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

  // Input messages to the CCE are buffered by two element FIFOs in bp_cce_top.v, thus
  // the outbound valid signal is a yumi.
  //
  // Outbound queues all use ready&valid handshaking. Outbound messages going to LCEs are not
  // buffered by bp_cce_top.v, but messages to memory are.
  always_comb
  begin
    lce_req_yumi_o = decoded_inst_lo.lce_req_yumi;
    lce_resp_yumi_o = decoded_inst_lo.lce_resp_yumi;
    lce_data_resp_yumi_o = decoded_inst_lo.lce_data_resp_yumi;
    mem_resp_yumi_o = decoded_inst_lo.mem_resp_yumi;
    mem_data_resp_yumi_o = decoded_inst_lo.mem_data_resp_yumi;

    lce_cmd_v_o = decoded_inst_lo.lce_cmd_v;
    lce_data_cmd_v_o = decoded_inst_lo.lce_data_cmd_v;
    mem_cmd_v_o = decoded_inst_lo.mem_cmd_v;
    mem_data_cmd_v_o = decoded_inst_lo.mem_data_cmd_v;
  end

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
      ,.lce_assoc_p(lce_assoc_p)
      ,.tag_width_p(tag_width_lp)
      )
    directory
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.way_group_i(dir_way_group_li)
      ,.lce_i(dir_lce_li)
      ,.way_i(dir_way_li)

      ,.r_cmd_i(decoded_inst_lo.dir_r_cmd)
      ,.r_v_i(decoded_inst_lo.dir_r_v)

      ,.tag_i(dir_tag_li)
      ,.coh_state_i(dir_coh_state_li)
      ,.pending_i(decoded_inst_lo.imm[0])

      ,.w_cmd_i(decoded_inst_lo.dir_w_cmd)
      ,.w_v_i(decoded_inst_lo.dir_w_v)

      ,.pending_o(dir_pending_lo)
      ,.pending_v_o(dir_pending_v_lo)
      ,.tag_o(dir_tag_lo)
      ,.coh_state_o(dir_coh_state_lo)
      ,.entry_v_o(dir_entry_v_lo)
      ,.way_group_o(dir_way_group_lo)
      ,.way_group_v_o(dir_way_group_v_lo)
      );

  // GAD logic - auxiliary directory information logic
  assign gad_v_li = decoded_inst_v_lo & decoded_inst_lo.gad_op_w_v;

  bp_cce_gad
    #(.num_way_groups_p(num_way_groups_lp)
      ,.num_lce_p(num_lce_p)
      ,.lce_assoc_p(lce_assoc_p)
      ,.tag_width_p(tag_width_lp)
      )
    gad
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.way_group_i(way_group_r_lo)
      ,.req_lce_i(req_lce_r_lo)
      ,.req_tag_i(req_tag_r_lo)
      ,.lru_way_i(lru_way_r_lo)
      ,.req_type_flag_i(flags_r_lo[e_flag_sel_rqf])
      ,.lru_dirty_flag_i(flags_r_lo[e_flag_sel_ldf])
      ,.gad_v_i(gad_v_li)
      ,.req_addr_way_o(gad_req_addr_way_lo)
      ,.coh_state_o(gad_coh_state_lo)
      ,.lru_tag_o(gad_lru_tag_lo)
      ,.transfer_flag_o(gad_transfer_flag_lo)
      ,.transfer_lce_o(gad_transfer_lce_lo)
      ,.transfer_way_o(gad_transfer_lce_way_lo)
      ,.replacement_flag_o(gad_replacement_flag_lo)
      ,.upgrade_flag_o(gad_upgrade_flag_lo)
      ,.invalidate_flag_o(gad_invalidate_flag_lo)
      ,.exclusive_flag_o(gad_exclusive_flag_lo)
      ,.cached_flag_o(gad_cached_flag_lo)
      ,.sharers_hits_o(gad_sharers_hits_lo)
      ,.sharers_ways_o(gad_sharers_ways_lo)
      ,.sharers_coh_states_o(gad_sharers_coh_states_lo)
      );

  // Registers
  bp_cce_reg
    #(.num_lce_p(num_lce_p)
      ,.num_cce_p(num_cce_p)
      ,.paddr_width_p(paddr_width_p)
      ,.lce_assoc_p(lce_assoc_p)
      ,.lce_sets_p(lce_sets_p)
      ,.block_size_in_bytes_p(block_size_in_bytes_p)
      ,.lce_req_data_width_p(lce_req_data_width_p)
      )
    cce_reg
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.decoded_inst_i(decoded_inst_lo)
      ,.lce_req_i(lce_req_i)
      ,.lce_data_resp_i(lce_data_resp_i)
      ,.lce_resp_i(lce_resp_i)
      ,.mem_resp_i(mem_resp_i)
      ,.mem_data_resp_i(mem_data_resp_i)
      ,.alu_res_i(alu_res_lo)
      ,.mov_src_i(mov_src)
      ,.dir_way_group_o_i(dir_way_group_lo)
      ,.dir_way_group_v_o_i(dir_way_group_v_lo)
      ,.dir_coh_state_o_i(dir_coh_state_lo)
      ,.dir_entry_v_o_i(dir_entry_v_lo)
      ,.dir_pending_o_i(dir_pending_lo)
      ,.dir_pending_v_o_i(dir_pending_v_lo)
      ,.gad_sharers_hits_i(gad_sharers_hits_lo)
      ,.gad_sharers_ways_i(gad_sharers_ways_lo)
      ,.gad_sharers_coh_states_i(gad_sharers_coh_states_lo)
      ,.gad_req_addr_way_i(gad_req_addr_way_lo)
      ,.gad_coh_state_i(gad_coh_state_lo)
      ,.gad_lru_tag_i(gad_lru_tag_lo)
      ,.gad_transfer_lce_i(gad_transfer_lce_lo)
      ,.gad_transfer_lce_way_i(gad_transfer_lce_way_lo)
      ,.gad_transfer_flag_i(gad_transfer_flag_lo)
      ,.gad_replacement_flag_i(gad_replacement_flag_lo)
      ,.gad_upgrade_flag_i(gad_upgrade_flag_lo)
      ,.gad_invalidate_flag_i(gad_invalidate_flag_lo)
      ,.gad_exclusive_flag_i(gad_exclusive_flag_lo)
      ,.gad_cached_flag_i(gad_cached_flag_lo)
      // register state outputs
      ,.req_lce_o(req_lce_r_lo)
      ,.req_addr_o(req_addr_r_lo)
      ,.req_tag_o(req_tag_r_lo)
      ,.req_addr_way_o(req_addr_way_r_lo)
      ,.req_coh_state_o(req_coh_state_r_lo)
      ,.lru_way_o(lru_way_r_lo)
      ,.lru_addr_o(lru_addr_r_lo)
      ,.transfer_lce_o(transfer_lce_r_lo)
      ,.transfer_lce_way_o(transfer_lce_way_r_lo)
      ,.next_coh_state_o(next_coh_state_r_lo)
      ,.cache_block_data_o(cache_block_data_r_lo)
      ,.flags_o(flags_r_lo)
      ,.gpr_o(gpr_r_lo)
      ,.ack_type_o(ack_type_r_lo)
      ,.way_group_o(way_group_r_lo)
      ,.sharers_hits_o(sharers_hits_r_lo)
      ,.sharers_ways_o(sharers_ways_r_lo)
      ,.sharers_coh_states_o(sharers_coh_states_r_lo)
      ,.nc_req_size_o(nc_req_size_r_lo)
      ,.nc_data_o(nc_data_r_lo)
      );

  // A localparams and signals for output queue message formation
  // NOTE: num_cce_p must be a power of two
  // TODO: the special logic to compute set index based on gpr value below can probably be put
  // into microcode software
  localparam gpr_shift_lp = (num_cce_p == 1) ? 0 : lg_num_cce_lp;
  localparam [paddr_width_p-lg_lce_sets_lp-1:0] lce_cmd_addr_0 =
    (paddr_width_p-lg_lce_sets_lp)'('0);
  logic [lg_lce_sets_lp-1:0] gpr_set;

  // Output queue message field inputs
  always_comb
  begin
    gpr_set = '0;
    case (decoded_inst_lo.lce_cmd_lce_sel)
      e_lce_cmd_lce_r0: lce_cmd_lce = gpr_r_lo[e_gpr_r0][lg_num_lce_lp-1:0];
      e_lce_cmd_lce_r1: lce_cmd_lce = gpr_r_lo[e_gpr_r1][lg_num_lce_lp-1:0];
      e_lce_cmd_lce_r2: lce_cmd_lce = gpr_r_lo[e_gpr_r2][lg_num_lce_lp-1:0];
      e_lce_cmd_lce_r3: lce_cmd_lce = gpr_r_lo[e_gpr_r3][lg_num_lce_lp-1:0];
      e_lce_cmd_lce_req_lce: lce_cmd_lce = req_lce_r_lo;
      e_lce_cmd_lce_tr_lce: lce_cmd_lce = transfer_lce_r_lo;
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
        lce_cmd_addr = req_addr_r_lo;
      end
      e_lce_cmd_addr_lru_way_addr: begin
        lce_cmd_addr = lru_addr_r_lo;
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
        lce_cmd_way = req_addr_way_r_lo;
      end
      e_lce_cmd_way_tr_addr_way: begin
        lce_cmd_way = transfer_lce_way_r_lo;
      end
      e_lce_cmd_way_sh_list_r0: begin
        lce_cmd_way = sharers_ways_r_lo[gpr_r_lo[e_gpr_r0][lg_num_lce_lp-1:0]];
      end
      e_lce_cmd_way_lru_addr_way: begin
        lce_cmd_way = lru_way_r_lo;
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
      e_mem_data_cmd_addr_lru_way_addr: mem_data_cmd_addr = lru_addr_r_lo;
      e_mem_data_cmd_addr_req_addr: mem_data_cmd_addr = req_addr_r_lo;
      default mem_data_cmd_addr = '0;
    endcase
  end

  always_comb
  begin
    // LCE Command Queue Inputs
    lce_cmd_s_o.dst_id = lce_cmd_lce;
    lce_cmd_s_o.src_id = (lg_num_cce_lp)'(cce_id_i);
    lce_cmd_s_o.msg_type = decoded_inst_lo.lce_cmd_cmd;
    lce_cmd_s_o.addr = lce_cmd_addr;
    lce_cmd_s_o.way_id = lce_cmd_way;
    if ((decoded_inst_lo.lce_cmd_cmd == e_lce_cmd_set_tag)
        || (decoded_inst_lo.lce_cmd_cmd == e_lce_cmd_set_tag_wakeup)) begin
      lce_cmd_s_o.state = next_coh_state_r_lo;
    end else begin
      lce_cmd_s_o.state = '0;
    end
    if (decoded_inst_lo.lce_cmd_cmd == e_lce_cmd_transfer) begin
      lce_cmd_s_o.target = req_lce_r_lo;
      lce_cmd_s_o.target_way_id = lru_way_r_lo;
    end else begin
      lce_cmd_s_o.target = '0;
      lce_cmd_s_o.target_way_id = '0;
    end

    // LCE Data Command Queue Inputs
    lce_data_cmd_s_o.dst_id = req_lce_r_lo;
    if (flags_r_lo[e_flag_sel_ucf] == e_lce_req_non_cacheable) begin
      lce_data_cmd_s_o.msg_type = e_lce_data_cmd_non_cacheable;
      lce_data_cmd_s_o.way_id = '0;
      lce_data_cmd_s_o.data = {(block_size_in_bits_lp-lce_req_data_width_p)'('0),nc_data_r_lo};
    end else begin
      lce_data_cmd_s_o.msg_type = e_lce_data_cmd_cce;
      lce_data_cmd_s_o.way_id = lru_way_r_lo;
      lce_data_cmd_s_o.data = cache_block_data_r_lo;
    end

    // Mem Command Queue Inputs
    mem_cmd_s_o.msg_type = bp_lce_cce_req_type_e'(flags_r_lo[e_flag_sel_rqf]);
    mem_cmd_s_o.payload.lce_id = req_lce_r_lo;
    mem_cmd_s_o.payload.way_id = lru_way_r_lo;
    mem_cmd_s_o.addr = req_addr_r_lo;
    mem_cmd_s_o.non_cacheable = bp_lce_cce_req_non_cacheable_e'(flags_r_lo[e_flag_sel_ucf]);
    mem_cmd_s_o.nc_size = bp_lce_cce_nc_req_size_e'(nc_req_size_r_lo);

    // Mem Data Command Queue Inputs
    mem_data_cmd_s_o.msg_type = bp_lce_cce_req_type_e'(flags_r_lo[e_flag_sel_rqf]);
    mem_data_cmd_s_o.addr = mem_data_cmd_addr;
    if (flags_r_lo[e_flag_sel_ucf]) begin
      mem_data_cmd_s_o.data = {(block_size_in_bits_lp-lce_req_data_width_p)'('0),nc_data_r_lo};
    end else begin
      mem_data_cmd_s_o.data = cache_block_data_r_lo;
    end
    mem_data_cmd_s_o.non_cacheable = bp_lce_cce_req_non_cacheable_e'(flags_r_lo[e_flag_sel_ucf]);
    mem_data_cmd_s_o.nc_size = bp_lce_cce_nc_req_size_e'(nc_req_size_r_lo);
    // Request data for return
    mem_data_cmd_s_o.payload.lce_id = req_lce_r_lo;
    mem_data_cmd_s_o.payload.way_id = lru_way_r_lo;
    mem_data_cmd_s_o.payload.req_addr = req_addr_r_lo;
    mem_data_cmd_s_o.payload.tr_lce_id = transfer_lce_r_lo;
    mem_data_cmd_s_o.payload.tr_way_id = transfer_lce_way_r_lo;
    mem_data_cmd_s_o.payload.transfer = flags_r_lo[e_flag_sel_tf];
    mem_data_cmd_s_o.payload.replacement = flags_r_lo[e_flag_sel_rf];
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
        dir_way_group_li = req_addr_r_lo[way_group_offset_high_lp-1 -: lg_num_way_groups_lp];
      end
      e_dir_wg_sel_lru_way_addr: begin
        dir_way_group_li = lru_addr_r_lo[way_group_offset_high_lp-1 -: lg_num_way_groups_lp];
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
      e_dir_lce_sel_req_lce: dir_lce_li = req_lce_r_lo;
      e_dir_lce_sel_transfer_lce: dir_lce_li = transfer_lce_r_lo;
      default: dir_lce_li = '0;
    endcase
    case (decoded_inst_lo.dir_way_sel)
      e_dir_way_sel_r0: dir_way_li = gpr_r_lo[e_gpr_r0][lg_lce_assoc_lp-1:0];
      e_dir_way_sel_r1: dir_way_li = gpr_r_lo[e_gpr_r1][lg_lce_assoc_lp-1:0];
      e_dir_way_sel_r2: dir_way_li = gpr_r_lo[e_gpr_r2][lg_lce_assoc_lp-1:0];
      e_dir_way_sel_r3: dir_way_li = gpr_r_lo[e_gpr_r3][lg_lce_assoc_lp-1:0];
      e_dir_way_sel_req_addr_way: dir_way_li = req_addr_way_r_lo;
      e_dir_way_sel_lru_way_addr_way: dir_way_li = lru_way_r_lo;
      e_dir_way_sel_sh_way_r0: dir_way_li = sharers_ways_r_lo[gpr_r_lo[e_gpr_r0][lg_num_lce_lp-1:0]];
      default: dir_way_li = '0;
    endcase
    case (decoded_inst_lo.dir_coh_state_sel)
      e_dir_coh_sel_next_coh_st: dir_coh_state_li = next_coh_state_r_lo;
      e_dir_coh_sel_inst_imm: dir_coh_state_li = decoded_inst_lo.imm[`bp_cce_coh_bits-1:0];
      default: dir_coh_state_li = '0;
    endcase
    case (decoded_inst_lo.dir_tag_sel)
      e_dir_tag_sel_req_addr: dir_tag_li = req_addr_r_lo[paddr_width_p-1 -: tag_width_lp];
      e_dir_tag_sel_lru_way_addr: dir_tag_li = lru_addr_r_lo[paddr_width_p-1 -: tag_width_lp];
      e_dir_tag_sel_const_0: dir_tag_li = '0;
      default: dir_tag_li = '0;
    endcase
  end

  // ALU

  logic sharers_hits_r0;
  assign sharers_hits_r0 = sharers_hits_r_lo[gpr_r_lo[e_gpr_r0][lg_num_lce_lp-1:0]];
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
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_rqf]};
      end
      e_src_nerf: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_nerf]};
      end
      e_src_ldf: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_ldf]};
      end
      e_src_nwbf: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_nwbf]};
      end
      e_src_tf: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_tf]};
      end
      e_src_rf: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_rf]};
      end
      e_src_rwbf: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_rwbf]};
      end
      e_src_pf: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_pf]};
      end
      e_src_uf: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_uf]};
      end
      e_src_if: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_if]};
      end
      e_src_ef: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_ef]};
      end
      e_src_pcf: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_pcf]};
      end
      e_src_ucf: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_ucf]};
      end
      e_src_cf: begin
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_cf]};
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
        alu_opd_a_li = {{(`bp_cce_inst_gpr_width-lg_num_lce_lp){1'b0}}, req_lce_r_lo};
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
      e_src_rqf: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_rqf]};
      e_src_nerf: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_nerf]};
      e_src_ldf: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_ldf]};
      e_src_nwbf: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_nwbf]};
      e_src_tf: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_tf]};
      e_src_rf: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_rf]};
      e_src_rwbf: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_rwbf]};
      e_src_pf: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_pf]};
      e_src_uf: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_uf]};
      e_src_if: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_if]};
      e_src_ef: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_ef]};
      e_src_pcf: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_pcf]};
      e_src_ucf: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_ucf]};
      e_src_cf: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, flags_r_lo[e_flag_sel_cf]};
      e_src_const_0: alu_opd_b_li = '0;
      e_src_const_1: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-1){1'b0}}, 1'b1};
      e_src_imm: alu_opd_b_li = decoded_inst_lo.imm;
      e_src_req_lce: alu_opd_b_li = {{(`bp_cce_inst_gpr_width-lg_num_lce_lp){1'b0}}, req_lce_r_lo};
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
