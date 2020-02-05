/*
 * bp_fe_pc_gen.v
 *
 * pc_gen.v provides the interfaces for the pc_gen logics and also interfacing
 * other modules in the frontend. PC_gen provides the pc for the itlb and icache.
 * PC_gen also provides the BTB, BHT and RAS indexes for the backend (the queue
 * between the frontend and the backend, i.e. the frontend queue).
*/

module bp_fe_pc_gen
 import bp_common_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_fe_pkg::*;
 import bp_common_aviary_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_fe_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)

   , localparam mem_cmd_width_lp  = `bp_fe_mem_cmd_width(vaddr_width_p, vtag_width_p, ptag_width_p)
   , localparam mem_resp_width_lp = `bp_fe_mem_resp_width
   )
  (input                                             clk_i
   , input                                           reset_i
 
   , output [mem_cmd_width_lp-1:0]                   mem_cmd_o
   , output                                          mem_cmd_v_o
   , input                                           mem_cmd_yumi_i

   , output [rv64_priv_width_gp-1:0]                 mem_priv_o
   , output                                          mem_translation_en_o
   , output                                          mem_poison_o

   , input [mem_resp_width_lp-1:0]                   mem_resp_i
   , input                                           mem_resp_v_i
   , output                                          mem_resp_ready_o

   , input [fe_cmd_width_lp-1:0]                     fe_cmd_i
   , input                                           fe_cmd_v_i
   , output                                          fe_cmd_yumi_o

   , output [fe_queue_width_lp-1:0]                  fe_queue_o
   , output                                          fe_queue_v_o
   , input                                           fe_queue_ready_i
   );

`declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
`declare_bp_fe_branch_metadata_fwd_s(btb_tag_width_p, btb_idx_width_p, bht_idx_width_p,ras_idx_width_p);
`declare_bp_fe_mem_structs(vaddr_width_p, lce_sets_p, cce_block_width_p, vtag_width_p, ptag_width_p)
`declare_bp_fe_pc_gen_stage_s(vaddr_width_p);

bp_fe_mem_cmd_s mem_cmd_cast_o;
bp_fe_mem_resp_s mem_resp_cast_i;

assign mem_cmd_o       = mem_cmd_cast_o;
assign mem_resp_cast_i = mem_resp_i;

// branch prediction wires
logic [vaddr_width_p-1:0]       br_target;
logic                           ovr_taken, ovr_ntaken;
// btb io
logic [vaddr_width_p-1:0]       btb_br_tgt_lo;
logic                           btb_br_tgt_v_lo;

bp_fe_queue_s fe_queue_cast_o;
bp_fe_cmd_s fe_cmd_cast_i;

assign fe_cmd_cast_i = fe_cmd_i;
assign fe_queue_o = fe_queue_cast_o;

bp_fe_pc_gen_stage_s [1:0] pc_gen_stage_n, pc_gen_stage_r;

// Helper signals
wire                      v_if1 = pc_gen_stage_r[0].v;
wire                      v_if2 = pc_gen_stage_r[1].v;
wire [vaddr_width_p-1:0] pc_if1 = pc_gen_stage_r[0].pc;
wire [vaddr_width_p-1:0] pc_if2 = pc_gen_stage_r[1].pc;

// Flags for valid FE commands
wire fetch_v          = mem_cmd_yumi_i & (mem_cmd_cast_o.op == e_fe_op_fetch);
wire state_reset_v    = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_state_reset); 
wire pc_redirect_v    = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_pc_redirection);
wire itlb_fill_v      = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_itlb_fill_response);
wire icache_fence_v   = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_icache_fence);
wire itlb_fence_v     = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_itlb_fence);
wire attaboy_v        = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_attaboy);
wire cmd_nonattaboy_v = fe_cmd_v_i & (fe_cmd_cast_i.opcode != e_op_attaboy);

wire trap_v = pc_redirect_v & (fe_cmd_cast_i.operands.pc_redirect_operands.subopcode == e_subop_trap);
wire br_res_v = pc_redirect_v
                & (fe_cmd_cast_i.operands.pc_redirect_operands.subopcode == e_subop_branch_mispredict)
                & (fe_cmd_cast_i.operands.pc_redirect_operands.misprediction_reason == e_incorrect_prediction);

logic [rv64_priv_width_gp-1:0] shadow_priv_n, shadow_priv_r;
wire shadow_priv_w = state_reset_v | trap_v;
assign shadow_priv_n = fe_cmd_cast_i.operands.pc_redirect_operands.priv;
bsg_dff_reset_en
 #(.width_p(rv64_priv_width_gp))
 shadow_priv_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(shadow_priv_w)

   ,.data_i(shadow_priv_n)
   ,.data_o(shadow_priv_r)
   );
   
logic shadow_translation_en_n, shadow_translation_en_r;
wire shadow_translation_en_w = state_reset_v | trap_v | itlb_fence_v;
assign shadow_translation_en_n = fe_cmd_cast_i.operands.pc_redirect_operands.translation_enabled;
bsg_dff_reset_en
 #(.width_p(1))
 shadow_translation_en_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(shadow_translation_en_w)

   ,.data_i(shadow_translation_en_n)
   ,.data_o(shadow_translation_en_r)
   );

// Until we support C, must be aligned to 4 bytes
// There's also an interesting question about physical alignment (I/O devices, etc)
//   But let's punt that for now...
// TODO: misaligned is actually done by the branch target, not the PC
wire misalign_exception           = 1'b0;
wire itlb_miss_exception          = v_if2 & (mem_resp_v_i & mem_resp_cast_i.itlb_miss);
wire instr_access_fault_exception = v_if2 & (mem_resp_v_i & mem_resp_cast_i.instr_access_fault);
wire instr_page_fault_exception   = v_if2 & (mem_resp_v_i & mem_resp_cast_i.instr_page_fault);

wire fetch_fail     = v_if2 & ~fe_queue_v_o;
wire queue_miss     = v_if2 & ~fe_queue_ready_i;
wire icache_miss    = v_if2 & (mem_resp_v_i & mem_resp_cast_i.icache_miss);
wire fe_exception_v = v_if2 & (instr_page_fault_exception | instr_access_fault_exception | misalign_exception | itlb_miss_exception);
wire flush          = fe_exception_v | icache_miss | queue_miss | cmd_nonattaboy_v;
wire fe_instr_v     = v_if2 & mem_resp_v_i & ~flush;

// FSM
enum bit [1:0] {e_wait=2'd0, e_run, e_stall} state_n, state_r;

// Decoded state signals
wire is_wait  = (state_r == e_wait);
wire is_run   = (state_r == e_run);
wire is_stall = (state_r == e_stall);

// Change the resume pc on redirect command, else save the PC in IF2 while running
logic [vaddr_width_p-1:0] pc_resume_n, pc_resume_r;
assign pc_resume_n = cmd_nonattaboy_v ? fe_cmd_cast_i.vaddr :  pc_gen_stage_r[1].pc;
bsg_dff_reset_en
 #(.width_p(vaddr_width_p))
 pc_resume_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(cmd_nonattaboy_v | is_run)

   ,.data_i(pc_resume_n)
   ,.data_o(pc_resume_r)
   );

// Controlling state machine
always_comb
  case (state_r)
    // Wait for FE cmd
    e_wait : state_n = cmd_nonattaboy_v ? e_stall : e_wait;
    // Stall until we can start valid fetch
    e_stall: state_n = pc_gen_stage_n[0].v ? e_run : e_stall;
    // Run state -- PCs are actually being fetched
    // Stay in run if there's an incoming cmd, the next pc will automatically be valid 
    // Transition to wait if there's a TLB miss while we wait for fill
    // Transition to stall if we don't successfully complete the fetch for whatever reason
    e_run  : state_n = cmd_nonattaboy_v 
                       ? e_run 
                       : fetch_fail 
                         ? e_stall 
                         : fe_exception_v 
                           ? e_wait 
                           : e_run;
    default: state_n = e_wait;
  endcase

always_ff @(posedge clk_i)
  if (reset_i)
      state_r <= e_wait;
  else
    begin 
      state_r <= state_n;
    end

always_comb
  begin
    pc_gen_stage_n[0].v          = fetch_v;
    pc_gen_stage_n[0].pred_taken = btb_br_tgt_v_lo | ovr_taken;
    pc_gen_stage_n[0].ovr        = ovr_taken | ovr_ntaken;

    // Next PC calculation
    // load boot pc on reset command
    if (state_reset_v)
        pc_gen_stage_n[0].pc = fe_cmd_cast_i.vaddr;
    // if we need to redirect
    else if (pc_redirect_v | icache_fence_v | itlb_fence_v)
        pc_gen_stage_n[0].pc = fe_cmd_cast_i.vaddr;
    else if (state_r != e_run) 
        pc_gen_stage_n[0].pc = pc_resume_r;
    else if (ovr_taken)
        pc_gen_stage_n[0].pc = br_target;
    else if (ovr_ntaken)
        pc_gen_stage_n[0].pc = pc_gen_stage_r[1].pc + 4;
    else if (btb_br_tgt_v_lo)
        pc_gen_stage_n[0].pc = btb_br_tgt_lo;
    else
      begin
        pc_gen_stage_n[0].pc = pc_gen_stage_r[0].pc + 4;
      end

    pc_gen_stage_n[1]    = pc_gen_stage_r[0];
    pc_gen_stage_n[1].v &= ~flush & ~(ovr_taken || ovr_ntaken);
  end

bsg_dff_reset
 #(.width_p($bits(bp_fe_pc_gen_stage_s)*2))
 pc_gen_stage_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.data_i(pc_gen_stage_n)
   ,.data_o(pc_gen_stage_r)
   );

// Branch prediction logic
bp_fe_branch_metadata_fwd_s fe_queue_cast_o_branch_metadata, fe_queue_cast_o_branch_metadata_r;
wire                    pred_taken_if2 = pc_gen_stage_r[1].pred_taken;
wire [btb_tag_width_p-1:0] btb_tag_if2 = pc_if2[2+btb_idx_width_p+:btb_tag_width_p];
wire [btb_idx_width_p-1:0] btb_idx_if2 = pc_if2[2+:btb_idx_width_p];
wire [bht_idx_width_p-1:0] bht_idx_if2 = pc_if2[2+:bht_idx_width_p];

assign fe_queue_cast_o_branch_metadata = 
  '{pred_taken: pred_taken_if2
    ,btb_tag  : btb_tag_if2
    ,btb_idx  : btb_idx_if2
    ,bht_idx  : bht_idx_if2
    ,default  : '0
    };

bsg_dff_reset_en
 #(.width_p(branch_metadata_fwd_width_p))
 branch_metadata_fwd_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i) 
   ,.en_i(fe_queue_v_o)

   ,.data_i(fe_queue_cast_o_branch_metadata)
   ,.data_o(fe_queue_cast_o_branch_metadata_r)
   );

// Casting branch metadata forwarded from BE
bp_fe_branch_metadata_fwd_s fe_cmd_branch_metadata;
assign fe_cmd_branch_metadata = fe_cmd_cast_i.operands.pc_redirect_operands.branch_metadata_fwd;
bp_fe_btb
 #(.vaddr_width_p(vaddr_width_p)
   ,.btb_tag_width_p(btb_tag_width_p)
   ,.btb_idx_width_p(btb_idx_width_p)
   )
 btb
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.r_addr_i(pc_gen_stage_n[0].pc)
   ,.r_v_i(pc_gen_stage_n[0].v)
   ,.br_tgt_o(btb_br_tgt_lo)
   ,.br_tgt_v_o(btb_br_tgt_v_lo)

   ,.w_tag_i(fe_cmd_branch_metadata.btb_tag) 
   ,.w_idx_i(fe_cmd_branch_metadata.btb_idx)
   // Literature says that we should only update btb on taken branches, but I'd like to see
   // benchmarks...
   ,.w_v_i((br_res_v | attaboy_v) & fe_cmd_yumi_o) // & fe_cmd_branch_metadata.pred_taken)
   ,.br_tgt_i(fe_cmd_cast_i.vaddr)
   );

logic bht_pred_lo;
bp_fe_bht
 #(.bht_idx_width_p(bht_idx_width_p))
 bp_fe_bht
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.r_v_i(1'b1)
   ,.idx_r_i(fe_queue_cast_o_branch_metadata.bht_idx)
   ,.predict_o(bht_pred_lo)

   ,.w_v_i((br_res_v | attaboy_v) & fe_cmd_yumi_o)
   ,.idx_w_i(fe_cmd_branch_metadata.bht_idx)
   ,.correct_i(attaboy_v)
   );

`declare_bp_fe_instr_scan_s(vaddr_width_p)
bp_fe_instr_scan_s scan_instr;
bp_fe_instr_scan 
 #(.bp_params_p(bp_params_p))
 instr_scan
  (.instr_i(mem_resp_cast_i.data)

   ,.scan_o(scan_instr)
   );

wire is_br        = mem_resp_v_i & (scan_instr.scan_class == e_rvi_branch);
wire is_jal       = mem_resp_v_i & (scan_instr.scan_class == e_rvi_jal);
assign ovr_taken  = pc_gen_stage_r[1].v & ~pc_gen_stage_r[0].ovr & ~pc_gen_stage_r[0].pred_taken & ((is_br &  bht_pred_lo) | is_jal);
assign ovr_ntaken = pc_gen_stage_r[1].v & ~pc_gen_stage_r[0].ovr &  pc_gen_stage_r[0].pred_taken &  (is_br & ~bht_pred_lo);
assign br_target  = pc_gen_stage_r[1].pc + scan_instr.imm;

// We can't fetch from wait state, only run and coming out of stall.
// We wait until both the FE queue and I$ are ready, but flushes invalidate the fetch.
// The next PC is valid during a FE cmd, since it is a non-speculative
//   command and we must accept it immediately.
// This may cause us to fetch during an I$ miss or a with a full queue.  
// FE cmds normally flush the queue, so we don't expect this to affect
//   power much in practice.
assign mem_cmd_v_o = cmd_nonattaboy_v || (~is_wait & fe_queue_ready_i & ~flush);
always_comb
  begin
    mem_cmd_cast_o = '0;

    if (itlb_fence_v)
      begin
        mem_cmd_cast_o.op                   = e_fe_op_tlb_fence;
        mem_cmd_cast_o.operands.fetch.vaddr = fe_cmd_cast_i.vaddr;
      end
    else if (itlb_fill_v)
      begin
        mem_cmd_cast_o.op                  = e_fe_op_tlb_fill;
        mem_cmd_cast_o.operands.fill.vtag  = fe_cmd_cast_i.vaddr[vaddr_width_p-1:page_offset_width_p];
        mem_cmd_cast_o.operands.fill.entry = fe_cmd_cast_i.operands.itlb_fill_response.pte_entry_leaf;
      end
    else
      begin
        mem_cmd_cast_o.op                   = e_fe_op_fetch;
        mem_cmd_cast_o.operands.fetch.vaddr = pc_gen_stage_n[0].pc;
      end
  end

assign mem_poison_o         = pc_gen_stage_r[0].v & ~pc_gen_stage_n[1].v;
assign mem_priv_o           = shadow_priv_w ? shadow_priv_n : shadow_priv_r;
assign mem_translation_en_o = shadow_translation_en_w ? shadow_translation_en_n : shadow_translation_en_r;

assign mem_resp_ready_o = 1'b1;

// Handshaking signals
assign fe_cmd_yumi_o      = fe_cmd_v_i; // Always accept FE commands
                                        // All FE cmds are processed in 1 cycle, for now                                      

// Organize the FE queue message
assign fe_queue_v_o = fe_queue_ready_i & (fe_instr_v | fe_exception_v);
always_comb
  begin
    // Set padding to 0
    fe_queue_cast_o = '0;

    if (fe_exception_v)
      begin
        fe_queue_cast_o.msg_type                     = e_fe_exception;
        fe_queue_cast_o.msg.exception.vaddr          = pc_if2;
        fe_queue_cast_o.msg.exception.exception_code = misalign_exception
                                                       ? e_instr_misaligned
                                                       : itlb_miss_exception
                                                         ? e_itlb_miss
                                                         : instr_page_fault_exception
                                                           ? e_instr_page_fault
                                                           : e_instr_access_fault;
      end
    else 
      begin
        fe_queue_cast_o.msg_type                      = e_fe_fetch;
        fe_queue_cast_o.msg.fetch.pc                  = pc_if2;
        fe_queue_cast_o.msg.fetch.instr               = mem_resp_cast_i.data;
        fe_queue_cast_o.msg.fetch.branch_metadata_fwd = fe_queue_cast_o_branch_metadata_r;
      end
  end

endmodule

