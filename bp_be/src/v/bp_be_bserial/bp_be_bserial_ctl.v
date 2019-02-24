/*
 *
 * bp_be_bserial_ctl.v
 *
 */
module bp_be_bserial_ctl
 import bp_be_bserial_pkg::*;
 import bp_be_rv64_pkg::*;
 #(parameter vaddr_width_p                 = "inv"
   , parameter paddr_width_p               = "inv"
   , parameter asid_width_p                = "inv"
   , parameter branch_metadata_fwd_width_p = "inv"

   // Generated parameters
   , localparam fe_cmd_width_lp   = `bp_fe_cmd_width(vaddr_width_p
                                                     , paddr_width_p
                                                     , asid_width_p
                                                     , branch_metadata_fwd_width_p
                                                     )

   , localparam bserial_opcode_width_lp = `bp_be_bserial_opcode_width
   // Calculated parameters
   , localparam compute_cnt_width_lp = `BSG_SAFE_CLOG2(rv64_reg_data_width_gp)
                                                     
   // From RISC-V specification
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   , localparam instr_width_lp    = rv64_instr_width_gp
   )
  (input                                        clk_i
   , input                                      reset_i

   // FE cmd interface
   , output [fe_cmd_width_lp-1:0]               fe_cmd_o
   , output                                     fe_cmd_v_o
   , input                                      fe_cmd_ready_i

   // FE queue interface
   , output                                     chk_roll_fe_o
   , output                                     chk_flush_fe_o
   , output                                     chk_dequeue_fe_o

   , input [instr_width_lp-1:0]                 instr_i
   , input                                      instr_v_i
   , output                                     instr_ready_o

   // Datapath control signals
   , input  logic                               npc_match_ex_i
   , input  logic                               br_tgt_i 

   , output logic                               start_compute_o
   , output logic                               shex_o

   , output logic                               recover_o
   , output logic                               mar_w_v_o
   , output logic                               mdr_w_v_o
   , output logic                               true_npc_sel_o
   , output logic [bserial_opcode_width_lp-1:0] alu_op_o
   , output logic                               pc_not_rs1_o
   , output logic                               imm_not_rs2_o
   , output logic                               npc_br_not_four_o
   , output logic                               rs1_r_v_o
   , output logic                               rs2_r_v_o
   , output logic                               rd_w_v_o
   , output logic                               commit_v_o
   , output logic                               shex_dir_o
   , output logic                               skip_commit_o
   , output logic                               rf_en_o
 
   , output logic                               start_boot_o
   , output logic                               booting_o

   , output logic                               start_branch_o
   );

// Declare parameterizable structs
`declare_bp_common_fe_be_if_structs(vaddr_width_p
                                    , paddr_width_p
                                    , asid_width_p
                                    , branch_metadata_fwd_width_p
                                    );

// Casting
bp_fe_cmd_s                      fe_cmd;
bp_fe_cmd_pc_redirect_operands_s fe_cmd_pc_redirect_operands;
bp_be_instr_s                    instr;

assign fe_cmd_o = fe_cmd;
assign instr    = instr_i;

// State machine
typedef enum bit [2:0]
{ 
  e_reset
  , e_boot
  , e_idle
  , e_compute
  , e_recover
  , e_branch
} bp_be_bserial_state_e;

logic is_reset, is_boot, is_idle, is_compute, is_recover, is_branch;
logic reset_to_boot, boot_to_idle, idle_to_compute;
logic compute_to_idle, compute_to_branch, branch_to_idle, compute_to_recover, recover_to_idle;
bp_be_bserial_state_e state_r, state_n;

logic [reg_data_width_lp-1:0] br_tgt_r;

// Default assignments 
assign chk_roll_fe_o    = 1'b0;
assign chk_dequeue_fe_o = compute_to_idle | branch_to_idle;;

assign mdr_w_v_o = '0;
assign mar_w_v_o = '0;

// Suppress warnings
wire                      unused0;
wire                      unused1;
wire                      unused2;
wire                      unused3;
wire [instr_width_lp-1:0] unused4;
wire                      unused5;

assign unused2 = fe_cmd_ready_i;

logic [`BSG_SAFE_CLOG2(reg_data_width_lp):0] compute_cnt;
  bsg_counter_clear_up
   #(.max_val_p(reg_data_width_lp)
     ,.init_val_p(0)
     )
   compute_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
  
     ,.clear_i(reset_to_boot | idle_to_compute | compute_to_recover | compute_to_branch)
     ,.up_i(~compute_to_branch & (is_boot | is_compute | is_recover | is_branch))
  
     ,.count_o(compute_cnt)
     );

  bsg_dff_reset_en
   #(.width_p(1))
   true_npc_idx
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(compute_to_idle | branch_to_idle)

     ,.data_i(~true_npc_sel_o)
     ,.data_o( true_npc_sel_o)
     );

  bsg_serial_in_parallel_out
   #(.width_p(1)
     ,.els_p(reg_data_width_lp)
     ,.consume_all_p(1)
     )
   br_tgt_sipo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(br_tgt_i)
     ,.valid_i(is_branch)
     ,.ready_o(/* We rely on state machine for ready_o */)

     ,.data_o(br_tgt_r)
     ,.valid_o(/* We rely on state machine for valid_o */)
     ,.yumi_cnt_i(1'b0)
     );

always_ff @(posedge clk_i)
  begin
    if (branch_to_idle) 
      begin
        $display("[TGT]: %x ", br_tgt_r);
      end
  end

assign start_boot_o     = reset_to_boot;
assign start_branch_o   = compute_to_branch;
assign booting_o        = is_boot;
assign instr_ready_o    = is_idle;
assign start_compute_o  = idle_to_compute;
assign shex_o           = is_compute | is_branch;
assign recover_o        = is_recover;

assign fe_cmd_v_o = compute_to_recover;
assign chk_flush_fe_o = fe_cmd_v_o;
always_comb
  begin
    fe_cmd.opcode                                   = e_op_pc_redirection;
    fe_cmd_pc_redirect_operands.pc                  = br_tgt_r;
    fe_cmd_pc_redirect_operands.subopcode           = e_subop_branch_mispredict;
    /* TODO: branch metadata, although we really shouldn't be predicting at all... */
    fe_cmd_pc_redirect_operands.branch_metadata_fwd = '0; 

    fe_cmd_pc_redirect_operands.misprediction_reason = e_incorrect_prediction;

    fe_cmd.operands.pc_redirect_operands = fe_cmd_pc_redirect_operands;
  end

always_comb
  begin
    skip_commit_o = 1'b0;
    rf_en_o       = 1'b1;
    case (state_r)
      e_compute:
        begin
          unique casez (instr)
            `RV64_ADDI, `RV64_ADDIW:
              begin
                alu_op_o          = (instr.opcode == `RV64_OP_IMM_32_OP)
                                    ? (compute_cnt < reg_data_width_lp'(32))
                                      ? e_bserial_op_add
                                      : e_bserial_op_sext
                                    : e_bserial_op_add;
                pc_not_rs1_o      = 1'b0;
                imm_not_rs2_o     = 1'b1;
                npc_br_not_four_o = 1'b0;
                rs1_r_v_o         = 1'b1;
                rs2_r_v_o         = 1'b0;
                rd_w_v_o          = 1'b1;
                shex_dir_o        = 1'b0;
              end
            `RV64_BNE:
              begin
                alu_op_o          = e_bserial_op_ne;
                pc_not_rs1_o      = 1'b0;
                imm_not_rs2_o     = 1'b0;
                npc_br_not_four_o = 1'b0;
                rs1_r_v_o         = 1'b1;
                rs2_r_v_o         = 1'b1;
                rd_w_v_o          = 1'b0;
                shex_dir_o        = 1'b0;
              end
            `RV64_LUI:
              begin
                alu_op_o          = e_bserial_op_passb;
                pc_not_rs1_o      = 1'b0;
                imm_not_rs2_o     = 1'b1;
                npc_br_not_four_o = 1'b0;
                rs1_r_v_o         = 1'b0;
                rs2_r_v_o         = 1'b0;
                rd_w_v_o          = 1'b1;
                shex_dir_o        = 1'b0;
              end
            `RV64_SLLI:
              begin
                alu_op_o          = e_bserial_op_sll;
                pc_not_rs1_o      = 1'b0;
                imm_not_rs2_o     = 1'b0; // IMM is read by state machine
                npc_br_not_four_o = 1'b0;
                rs1_r_v_o         = 1'b1;
                rs2_r_v_o         = 1'b0;
                rd_w_v_o          = 1'b1;
                rf_en_o           = (compute_cnt < instr[24:20]);
                shex_dir_o        = 1'b1;
                skip_commit_o     = 1'b1;
              end
            default:
              begin
                alu_op_o          = e_bserial_op_add;
                pc_not_rs1_o      = 1'b0;
                imm_not_rs2_o     = 1'b0;
                npc_br_not_four_o = 1'b0;
                rs1_r_v_o         = 1'b0;
                rs2_r_v_o         = 1'b0;
                rd_w_v_o          = 1'b0;
                shex_dir_o        = 1'b0;
              end
          endcase
        end
      e_recover:
        begin
          // RD recover muxing dealt with by state
          /* TODO: Mispredicted shifts will have a different recovery count... */
          /*         Maybe an up/down counter could be elegant */
          alu_op_o          = e_bserial_op_add;
          pc_not_rs1_o      = 1'b0;
          imm_not_rs2_o     = 1'b0;
          npc_br_not_four_o = 1'b0;
          rs1_r_v_o         = 1'b0;
          rs2_r_v_o         = 1'b0;
          rd_w_v_o          = 1'b1;
          shex_dir_o        = 1'b0;
        end
      e_branch:
        begin
          alu_op_o          = e_bserial_op_add;
          pc_not_rs1_o      = 1'b1;
          imm_not_rs2_o     = 1'b1;
          npc_br_not_four_o = 1'b1;
          rs1_r_v_o         = 1'b0;
          rs2_r_v_o         = 1'b0;
          rd_w_v_o          = 1'b0; // TODO: Think about JALR / JAL
          shex_dir_o        = 1'b0;
        end
      default:
        begin  
          alu_op_o          = e_bserial_op_add;
          pc_not_rs1_o      = 1'b0;
          imm_not_rs2_o     = 1'b0;
          npc_br_not_four_o = 1'b0;
          rs1_r_v_o         = 1'b0;
          rs2_r_v_o         = 1'b0;
          rd_w_v_o          = 1'b0;
          shex_dir_o        = 1'b0; 
        end
    endcase
  end

assign is_reset        = (state_r == e_reset);
assign is_boot         = (state_r == e_boot);
assign is_idle         = (state_r == e_idle);
assign is_compute      = (state_r == e_compute); 
assign is_recover      = (state_r == e_recover);
assign is_branch       = (state_r == e_branch);

assign reset_to_boot      = is_reset   & (state_n == e_boot);
assign boot_to_idle       = is_boot    & (state_n == e_idle);
assign idle_to_compute    = is_idle    & (state_n == e_compute);
assign compute_to_idle    = is_compute & (state_n == e_idle);
assign compute_to_branch  = is_compute & (state_n == e_branch);
assign compute_to_recover = is_compute & (state_n == e_recover);
assign recover_to_idle    = is_recover & (state_n == e_idle);
assign branch_to_idle     = is_branch  & (state_n == e_idle);

assign commit_v_o         = compute_to_idle | branch_to_idle;

always_comb
  begin
    case (state_r)
      e_reset:
          state_n = reset_i                              ? e_reset   : e_boot;
      e_boot:
          state_n = (compute_cnt == reg_data_width_lp-1) ? e_idle    : e_boot;
      e_idle: 
          state_n = instr_v_i                            ? e_compute : e_idle;
      e_compute:
          state_n = (compute_cnt == reg_data_width_lp-1) 
                    ? npc_match_ex_i
                      ? (instr.opcode == `RV64_BRANCH_OP) & br_tgt_i
                        ? e_branch 
                        : e_idle
                      : e_recover
                    : e_compute;
      e_recover:
          state_n = (compute_cnt == reg_data_width_lp-1) ? e_idle    : e_recover;
      e_branch:
          state_n = (compute_cnt == reg_data_width_lp-1) ? e_idle    : e_branch;
      default:
          state_n = e_idle;
    endcase
  end

always_ff @(posedge clk_i) 
  begin
    if (reset_i) 
        state_r <= e_reset;
    else
      begin
        state_r <= state_n;
      end
  end

initial
  begin
    $monitor("[STC]: %s", state_r);
  end

endmodule : bp_be_bserial_ctl

