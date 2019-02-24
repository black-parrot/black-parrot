/*
 *
 * bp_be_bserial_top.v
 *
 */

module bp_be_bserial_top
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_be_bserial_pkg::*;
 import bp_be_rv64_pkg::*;
 #(parameter core_els_p                    = "inv"
   , parameter vaddr_width_p               = "inv"
   , parameter paddr_width_p               = "inv"
   , parameter asid_width_p                = "inv"
   , parameter branch_metadata_fwd_width_p = "inv"


   // MMU parameters
   , parameter num_cce_p                   = "inv"
   , parameter num_lce_p                   = "inv"
   , parameter lce_assoc_p                 = "inv"
   , parameter lce_sets_p                  = "inv"
   , parameter cce_block_size_in_bytes_p   = "inv"
   , localparam cce_block_size_in_bits_lp  = cce_block_size_in_bytes_p * rv64_byte_width_gp

   // Generated parameters
   , localparam fe_queue_width_lp          = `bp_fe_queue_width(vaddr_width_p
                                                                , branch_metadata_fwd_width_p)
   , localparam fe_cmd_width_lp            = `bp_fe_cmd_width(vaddr_width_p
                                                              , paddr_width_p
                                                              , asid_width_p
                                                              , branch_metadata_fwd_width_p
                                                              )
   , localparam lce_cce_req_width_lp       = `bp_lce_cce_req_width(num_cce_p
                                                            , num_lce_p
                                                            , paddr_width_p
                                                            , lce_assoc_p
                                                            )
   , localparam lce_cce_resp_width_lp      = `bp_lce_cce_resp_width(num_cce_p
                                                              , num_lce_p
                                                              , paddr_width_p
                                                              )
   , localparam lce_cce_data_resp_width_lp = `bp_lce_cce_data_resp_width(num_cce_p
                                                                        , num_lce_p
                                                                        , paddr_width_p
                                                                        , cce_block_size_in_bits_lp
                                                                        )
   , localparam cce_lce_cmd_width_lp       = `bp_cce_lce_cmd_width(num_cce_p
                                                                   , num_lce_p
                                                                   , paddr_width_p
                                                                   , lce_assoc_p
                                                                   )
   , localparam cce_lce_data_cmd_width_lp  = `bp_cce_lce_data_cmd_width(num_cce_p
                                                                       , num_lce_p
                                                                       , paddr_width_p
                                                                       , cce_block_size_in_bits_lp
                                                                       , lce_assoc_p
                                                                       )
   , localparam lce_lce_tr_resp_width_lp   = `bp_lce_lce_tr_resp_width(num_lce_p
                                                                       , paddr_width_p
                                                                       , cce_block_size_in_bits_lp
                                                                       , lce_assoc_p
                                                                       )
   , localparam proc_cfg_width_lp          = `bp_proc_cfg_width(core_els_p, num_lce_p)

   , localparam pipe_stage_reg_width_lp    = `bp_be_pipe_stage_reg_width(branch_metadata_fwd_width_p)
   , localparam calc_result_width_lp       = `bp_be_calc_result_width(branch_metadata_fwd_width_p)
   , localparam exception_width_lp         = `bp_be_exception_width

   , localparam bserial_opcode_width_lp    = `bp_be_bserial_opcode_width

   // From RISC-V specifications
   , localparam reg_data_width_lp          = rv64_reg_data_width_gp
   , localparam reg_addr_width_lp          = rv64_reg_addr_width_gp
   , localparam instr_width_lp             = rv64_instr_width_gp
   )
  (input                                     clk_i
   , input                                   reset_i

   // FE queue interface
   , input [fe_queue_width_lp-1:0]           fe_queue_i
   , input                                   fe_queue_v_i
   , output                                  fe_queue_rdy_o

   , output                                  fe_queue_clr_o
   , output                                  fe_queue_dequeue_o
   , output                                  fe_queue_rollback_o

   // FE cmd interface
   , output [fe_cmd_width_lp-1:0]            fe_cmd_o
   , output                                  fe_cmd_v_o
   , input                                   fe_cmd_rdy_i

   // LCE-CCE interface
   , output [lce_cce_req_width_lp-1:0]       lce_cce_req_o
   , output                                  lce_cce_req_v_o
   , input                                   lce_cce_req_rdy_i

   , output [lce_cce_resp_width_lp-1:0]      lce_cce_resp_o
   , output                                  lce_cce_resp_v_o
   , input                                   lce_cce_resp_rdy_i

   , output [lce_cce_data_resp_width_lp-1:0] lce_cce_data_resp_o
   , output                                  lce_cce_data_resp_v_o
   , input                                   lce_cce_data_resp_rdy_i

   , input [cce_lce_cmd_width_lp-1:0]        cce_lce_cmd_i
   , input                                   cce_lce_cmd_v_i
   , output                                  cce_lce_cmd_rdy_o

   , input [cce_lce_data_cmd_width_lp-1:0]   cce_lce_data_cmd_i
   , input                                   cce_lce_data_cmd_v_i
   , output                                  cce_lce_data_cmd_rdy_o

   , input [lce_lce_tr_resp_width_lp-1:0]    lce_lce_tr_resp_i
   , input                                   lce_lce_tr_resp_v_i
   , output                                  lce_lce_tr_resp_rdy_o

   , output [lce_lce_tr_resp_width_lp-1:0]   lce_lce_tr_resp_o
   , output                                  lce_lce_tr_resp_v_o
   , input                                   lce_lce_tr_resp_rdy_i

   // Processor configuration
   , input [proc_cfg_width_lp-1:0]           proc_cfg_i

   // Commit tracer
   , output                                  pc_o
   , output                                  pc_w_v_o
   , output                                  npc_o
   , output                                  npc_w_v_o
   , output [reg_addr_width_lp-1:0]          rd_addr_o
   , output                                  rd_data_o
   , output                                  rd_w_v_o
   , output                                  commit_v_o
   , output                                  recover_v_o
   , output                                  shex_dir_o
   , output                                  skip_commit_o
   );

// Declare parameterized structures
`declare_bp_common_proc_cfg_s(core_els_p, num_lce_p)
`declare_bp_common_fe_be_if_structs(vaddr_width_p
                                    , paddr_width_p
                                    , asid_width_p
                                    , branch_metadata_fwd_width_p
                                    );
`declare_bp_be_mmu_structs(vaddr_width_p, lce_sets_p, cce_block_size_in_bytes_p)
`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   );

// Casting
bp_fe_queue_s fe_queue;

assign fe_queue = fe_queue_i;

// Top level connections
bp_proc_cfg_s proc_cfg;

bp_be_mmu_cmd_s mmu_cmd;
logic mmu_cmd_v, mmu_cmd_rdy;

bp_be_mmu_resp_s mmu_resp;
logic mmu_resp_v, mmu_resp_rdy;

logic [reg_data_width_lp-1:0] imm_n;
bp_be_instr_s instr_r;
logic instr_v, instr_ready;

logic boot_pc_r;

// Datapath signals
//   control
logic mdr_w_v;
logic mar_w_v;

logic shex;
logic recover;
logic true_npc_sel;
logic start_boot, booting;
logic start_compute;
logic start_branch;
logic commit_v;
logic skip_commit;

logic [bserial_opcode_width_lp-1:0] alu_op;
logic shex_dir;

logic rf_en_lo;
logic npc_match_ex_n, npc_match_ex_r;
logic pc_not_rs1;
logic imm_not_rs2;
logic npc_br_not_four;

//   data
logic pc_ex_lo;
logic alu_ex_lo;
logic npc0_n, npc0_r;
logic npc1_n, npc1_r;
logic four_r;
logic calc_npc_ex;
logic true_npc_ex;
logic imm_r;

logic victim_r_lo;

logic rs1_r_v, rs2_r_v, rd_w_v;
logic rs1_lo, rs2_lo, rd_lo;

logic alu_a_li, alu_b_li;

// Casting
assign proc_cfg = proc_cfg_i;

assign mmu_cmd      = '0;
assign mmu_cmd_v    = '0;
assign mmu_resp_rdy = '0;


assign pc_o          = pc_ex_lo;
assign pc_w_v_o      = shex | booting;
assign npc_o         = calc_npc_ex;
assign npc_w_v_o     = shex | booting;
assign rd_data_o     = alu_ex_lo;
assign rd_addr_o     = instr_r.rd_addr;
assign rd_w_v_o      = rd_w_v;
assign commit_v_o    = commit_v;
assign recover_v_o   = recover;
assign shex_dir_o    = shex_dir;
assign skip_commit_o = skip_commit;

bp_be_bserial_ctl
 #(.vaddr_width_p(vaddr_width_p)
   ,.paddr_width_p(paddr_width_p)
   ,.asid_width_p(asid_width_p)
   ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
   )
 be_ctl
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.fe_cmd_o(fe_cmd_o)
   ,.fe_cmd_v_o(fe_cmd_v_o)
   ,.fe_cmd_ready_i(fe_cmd_rdy_i)

   ,.chk_roll_fe_o(fe_queue_rollback_o)
   ,.chk_flush_fe_o(fe_queue_clr_o)
   ,.chk_dequeue_fe_o(fe_queue_dequeue_o)
   
   ,.instr_i(instr_r)
   ,.instr_v_i(instr_v)
   ,.instr_ready_o(instr_ready)

   ,.shex_o(shex)
   ,.recover_o(recover)
   ,.mar_w_v_o(mar_w_v)
   ,.mdr_w_v_o(mdr_w_v)
   ,.npc_match_ex_i(npc_match_ex_r)
   ,.br_tgt_i(alu_ex_lo)
   ,.true_npc_sel_o(true_npc_sel)
   ,.alu_op_o(alu_op)
   ,.pc_not_rs1_o(pc_not_rs1)
   ,.imm_not_rs2_o(imm_not_rs2)
   ,.npc_br_not_four_o(npc_br_not_four)
   ,.rs1_r_v_o(rs1_r_v)
   ,.rs2_r_v_o(rs2_r_v)
   ,.rd_w_v_o(rd_w_v)
   ,.commit_v_o(commit_v)
   ,.shex_dir_o(shex_dir)
   ,.skip_commit_o(skip_commit)
   ,.rf_en_o(rf_en_lo)

   ,.start_boot_o(start_boot)
   ,.booting_o(booting)
   ,.start_branch_o(start_branch)
   ,.start_compute_o(start_compute)
   );

assign fe_queue_rdy_o = commit_v;
assign instr_v        = fe_queue_v_i & instr_ready;

bsg_parallel_in_serial_out
 #(.width_p(1)
   ,.els_p(reg_data_width_lp)
   )
 pc_piso
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.data_i(fe_queue.msg.fetch.pc)
   ,.valid_i(instr_v)
   ,.ready_o(/* We depend on the state machine to determine ready_o */)

   ,.data_o(pc_ex_lo)
   ,.valid_o(/* We depend on the state machine to determine valid_o */)
   ,.yumi_i(shex)
   );

always_ff @(posedge clk_i)
  begin
    if (instr_v) 
      $display("[FETCH] pc: %x instr: %x imm: %x"
               , fe_queue.msg.fetch.pc
               , fe_queue.msg.fetch.instr
               , imm_n
               ); 
    if (start_branch)
      $display("[BRANCH] pc: %x instr: %x imm: %x"
               , fe_queue.msg.fetch.pc
               , fe_queue.msg.fetch.instr
               , imm_n
               ); 
  end

always_comb
  begin
    // Immediate extraction
    // TODO: Should cast, but feeling lazy
    casez(fe_queue.msg.fetch.instr[6:0])
      `RV64_LUI_OP, `RV64_AUIPC_OP : imm_n = `rv64_signext_u_imm(fe_queue.msg.fetch.instr);
      `RV64_JAL_OP                 : imm_n = `rv64_signext_j_imm(fe_queue.msg.fetch.instr);
      `RV64_BRANCH_OP              : imm_n = `rv64_signext_b_imm(fe_queue.msg.fetch.instr);
      `RV64_STORE_OP               : imm_n = `rv64_signext_s_imm(fe_queue.msg.fetch.instr);
      `RV64_JALR_OP, `RV64_LOAD_OP, `RV64_OP_IMM_OP, `RV64_OP_IMM_32_OP 
                                   : imm_n = `rv64_signext_i_imm(fe_queue.msg.fetch.instr);
                                   
      // Should not reach
      default                      : imm_n = '0;
    endcase
  end

bsg_parallel_in_serial_out
 #(.width_p(1)
   ,.els_p(reg_data_width_lp)
   )
 imm_piso
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   
   ,.data_i(imm_n)
   ,.valid_i(instr_v | start_branch)
   ,.ready_o(/* We depend on the state machine to determine ready_o */)

   ,.data_o(imm_r)
   ,.valid_o(/* We depend on the state machine to determine valid_o */)
   ,.yumi_i(shex) /* The IMM is consumed before branch. This is bad */
   );

bsg_dff_en
 #(.width_p(instr_width_lp))
 instr_reg
  (.clk_i(clk_i)
   ,.en_i(instr_v) 

   ,.data_i(fe_queue.msg.fetch.instr)
   ,.data_o(instr_r)
   );

bsg_parallel_in_serial_out
 #(.width_p(1)
   ,.els_p(reg_data_width_lp)
   )
 boot_pc_piso
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.data_i(reg_data_width_lp'(bp_pc_entry_point_gp))
   ,.valid_i(start_boot)
   ,.ready_o(/* We depend on the state machine to determine ready_o */)

   ,.data_o(boot_pc_r)
   ,.valid_o(/* We depend on the state machine to determine valid_o */)
   ,.yumi_i(booting)
   );

bsg_parallel_in_serial_out
 #(.width_p(1)
   ,.els_p(reg_data_width_lp)
   )
 four_piso
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.valid_i(start_compute)
   ,.data_i(reg_data_width_lp'(4))
   ,.ready_o(/* We depend on the state machine to determine ready_o */)

   ,.valid_o(/* We depend on the state machine to determine valid_o */)
   ,.data_o(four_r)
   ,.yumi_i(shex)
   );

assign npc0_n = booting ? boot_pc_r
                        : ~true_npc_sel 
                          ? npc0_r 
                          : npc_br_not_four
                            ? alu_ex_lo 
                            : calc_npc_ex;
bsg_shift_reg
 #(.width_p(1)
   ,.stages_p(reg_data_width_lp)
   )
 npc0
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.data_i(npc0_n)
   ,.v_i(shex | booting)
   ,.dir_i(1'b0) // TODO: Need to add dir to NPC compare as well

   ,.data_o(npc0_r)
   );

assign npc1_n = booting ? boot_pc_r
                        : true_npc_sel 
                          ? npc1_r 
                          : npc_br_not_four
                            ? alu_ex_lo
                            : calc_npc_ex;
bsg_shift_reg
 #(.width_p(1)
   ,.stages_p(reg_data_width_lp)
   )
 npc1
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.data_i(npc1_n)
   ,.v_i(shex | booting)
   ,.dir_i(1'b0) // TODO: Need to add dir to NPC compare as well

   ,.data_o(npc1_r)
   );

bp_be_bserial_regfile
 regfile
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.en_i(rf_en_lo)
   ,.dir_i(shex_dir)

   ,.rs1_r_v_i(rs1_r_v)
   ,.rs1_addr_i(instr_r.rs1_addr)
   ,.rs1_data_o(rs1_lo)

   ,.rs2_r_v_i(rs2_r_v)
   ,.rs2_addr_i(instr_r.rs2_addr)
   ,.rs2_data_o(rs2_lo)

   ,.rd_w_v_i(rd_w_v)
   ,.rd_addr_i(instr_r.rd_addr)
   ,.rd_data_i(alu_ex_lo)
   ,.rd_data_o(rd_lo)
   );

bsg_shift_reg
 #(.width_p(1)
   ,.stages_p(reg_data_width_lp)
   )
 victim_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.data_i(rd_lo)
   ,.v_i(shex | recover)
   ,.dir_i(shex_dir) /* TODO: This shift dir should be the previous shift dir */

   ,.data_o(victim_r_lo)
   );

bsg_dff_reset
 #(.width_p(1))
 npc_match_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.data_i(npc_match_ex_n)
   ,.data_o(npc_match_ex_r)
   );

assign true_npc_ex    = true_npc_sel ? npc1_r : npc0_r;
assign npc_match_ex_n = start_compute | (npc_match_ex_r & (true_npc_ex == pc_ex_lo));

assign alu_a_li = pc_not_rs1  ? true_npc_ex : rs1_lo;
assign alu_b_li = imm_not_rs2 ? imm_r       : rs2_lo;

bp_be_bserial_alu
 alu
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.set_i(start_compute & (alu_op == e_bserial_op_sub))
   ,.clr_i(start_compute & (alu_op != e_bserial_op_sub) | start_branch)

   ,.a_i(alu_a_li)
   ,.b_i(alu_b_li)
   ,.op_i(alu_op)

   ,.s_o(alu_ex_lo)
   );

bp_be_bserial_adder
 npc_calculator
  (.clk_i(clk_i)
   ,.clr_i(start_compute)

   ,.a_i(true_npc_ex) // This could either be true_npc_ex or pc_ex
   ,.b_i(four_r)

   ,.s_o(calc_npc_ex)
   );

bsg_serial_in_parallel_out
 #(.width_p(1)
   ,.els_p(reg_data_width_lp)
   ,.consume_all_p(1)
   )
 mar
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.valid_i(mar_w_v)
   ,.data_i()
   ,.ready_o()

   ,.valid_o(/* Valid is tracked by FSM */)
   ,.data_o()
   ,.yumi_cnt_i(1'b0 /* TODO: consume on mem data */)
   );

bsg_serial_in_parallel_out
 #(.width_p(1)
   ,.els_p(reg_data_width_lp)
   ,.consume_all_p(1)
   )
 mdr
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.valid_i(mdr_w_v)
   ,.data_i()
   ,.ready_o()

   ,.valid_o(/* Valid is tracked by FSM */)
   ,.data_o()
   ,.yumi_cnt_i(1'b0 /* TODO: consume on mem data */)
   );

bp_be_mmu_top
 #(.vaddr_width_p(vaddr_width_p)
   ,.paddr_width_p(paddr_width_p)
   ,.asid_width_p(asid_width_p)
   ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)

   ,.num_cce_p(num_cce_p)
   ,.num_lce_p(num_lce_p)
   ,.cce_block_size_in_bytes_p(cce_block_size_in_bytes_p)
   ,.lce_assoc_p(lce_assoc_p)
   ,.lce_sets_p(lce_sets_p)
   )
 be_mmu
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.mmu_cmd_i(mmu_cmd)
   ,.mmu_cmd_v_i(mmu_cmd_v)
   ,.mmu_cmd_ready_o(mmu_cmd_rdy)

   ,.chk_psn_ex_i(1'b0) /* We definitely aren't expecting to support traps / exceptions for a while */

   ,.mmu_resp_o(mmu_resp)
   ,.mmu_resp_v_o(mmu_resp_v)
   ,.mmu_resp_ready_i(mmu_resp_rdy)

   ,.lce_req_o(lce_cce_req_o)
   ,.lce_req_v_o(lce_cce_req_v_o)
   ,.lce_req_ready_i(lce_cce_req_rdy_i)

   ,.lce_resp_o(lce_cce_resp_o)
   ,.lce_resp_v_o(lce_cce_resp_v_o)
   ,.lce_resp_ready_i(lce_cce_resp_rdy_i)

   ,.lce_data_resp_o(lce_cce_data_resp_o)
   ,.lce_data_resp_v_o(lce_cce_data_resp_v_o)
   ,.lce_data_resp_ready_i(lce_cce_data_resp_rdy_i)

   ,.lce_cmd_i(cce_lce_cmd_i)
   ,.lce_cmd_v_i(cce_lce_cmd_v_i)
   ,.lce_cmd_ready_o(cce_lce_cmd_rdy_o)

   ,.lce_data_cmd_i(cce_lce_data_cmd_i)
   ,.lce_data_cmd_v_i(cce_lce_data_cmd_v_i)
   ,.lce_data_cmd_ready_o(cce_lce_data_cmd_rdy_o)

   ,.lce_tr_resp_i(lce_lce_tr_resp_i)
   ,.lce_tr_resp_v_i(lce_lce_tr_resp_v_i)
   ,.lce_tr_resp_ready_o(lce_lce_tr_resp_rdy_o)

   ,.lce_tr_resp_o(lce_lce_tr_resp_o)
   ,.lce_tr_resp_v_o(lce_lce_tr_resp_v_o)
   ,.lce_tr_resp_ready_i(lce_lce_tr_resp_rdy_i)

   ,.dcache_id_i(proc_cfg.dcache_id)
   );

endmodule : bp_be_bserial_top

