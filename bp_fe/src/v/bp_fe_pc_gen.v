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
 import bp_be_rv64_pkg::*;
 import bp_fe_pkg::*;
 import bp_common_aviary_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)

   `declare_bp_fe_be_if_widths(vaddr_width_p
                               ,paddr_width_p
                               ,asid_width_p
                               ,branch_metadata_fwd_width_p
                               )

   , localparam entry_width_lp = `bp_pte_entry_leaf_width(paddr_width_p)
   , localparam instr_width_lp = rv64_instr_width_gp
   )
  (input                                             clk_i
   , input                                           reset_i
    
   , output [vaddr_width_p-1:0]                      fetch_pc_o
   , output                                          fetch_v_o
   , input                                           fetch_ready_i

   , input [instr_width_lp-1:0]                      fetch_instr_i
   , input                                           fetch_instr_v_i
   , output                                          fetch_instr_ready_o

   , output                                          icache_poison_o
   , input                                           instr_access_fault_i

   , input logic                                     itlb_miss_i

   , output                                          itlb_fence_v_o
   , output                                          itlb_w_v_o
   , output [vaddr_width_p-page_offset_width_p-1:0]  itlb_w_vtag_o
   , output [entry_width_lp-1:0]                     itlb_w_entry_o

   , input [fe_cmd_width_lp-1:0]                     fe_cmd_i
   , input                                           fe_cmd_v_i
   , output logic                                    fe_cmd_yumi_o

   , output                                          fe_cmd_processed_o

   , output [fe_queue_width_lp-1:0]                  fe_queue_o
   , output                                          fe_queue_v_o
   , input                                           fe_queue_ready_i
   );

//the first level of structs
`declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

`declare_bp_fe_branch_metadata_fwd_s(btb_tag_width_p,btb_idx_width_p,bht_idx_width_p,ras_idx_width_p);

// pc pipeline
logic [vaddr_width_p-1:0]       pc_if1_n, pc_if1_r, pc_if2_r;
logic                           pc_v_if1_n, pc_v_if2_n, pc_v_if1_r, pc_v_if2_r;
// branch prediction wires
logic                           is_br_or_jmp;
logic [vaddr_width_p-1:0]       br_target;
logic                           ovr_taken, ovr_ntaken;
// btb io
logic [vaddr_width_p-1:0]       btb_br_tgt_lo;
logic                           btb_br_tgt_v_lo;

logic itlb_miss_if2_r;
logic btb_v_if1_r;

bp_fe_queue_s fe_queue_cast_o;
bp_fe_cmd_s fe_cmd_cast_i;

assign fe_cmd_cast_i = fe_cmd_i;
assign fe_queue_o = fe_queue_cast_o;

// Flags for valid FE commands
wire state_reset_v    = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_state_reset); 
wire pc_redirect_v    = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_pc_redirection);
wire itlb_fill_v      = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_itlb_fill_response);
wire icache_fence_v   = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_icache_fence);
wire itlb_fence_v     = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_itlb_fence);
wire attaboy_v        = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_attaboy);
wire cmd_nonattaboy_v = fe_cmd_v_i & (fe_cmd_cast_i.opcode != e_op_attaboy);

// Until we support C, must be aligned to 4 bytes
// There's also an interesting question about physical alignment (I/O devices, etc)
//   But let's punt that for now...
// TODO: misaligned is actually done by the branch target, not the PC
wire misalign_exception  = 1'b0;
wire itlb_miss_exception = pc_v_if2_r & itlb_miss_if2_r;
wire instr_access_fault_exception = pc_v_if2_r & instr_access_fault_i;

wire fetch_fail     = pc_v_if2_r & ~fe_queue_v_o;
wire queue_miss     = pc_v_if2_r & ~fe_queue_ready_i;
wire icache_miss    = pc_v_if2_r & ~fetch_instr_v_i;
wire flush          = itlb_miss_exception | icache_miss | queue_miss | cmd_nonattaboy_v;
wire fe_instr_v     = pc_v_if2_r & ~flush;
wire fe_exception_v = pc_v_if2_r & (instr_access_fault_exception | misalign_exception | itlb_miss_exception);

// FSM
enum bit [1:0] {e_wait=2'd0, e_run, e_stall} state_n, state_r;
logic [vaddr_width_p-1:0] pc_resume_r, pc_resume_n;

// Decoded state signals
wire is_wait  = (state_r == e_wait);
wire is_run   = (state_r == e_run);
wire is_stall = (state_r == e_stall);

always_comb
  begin
    // Change the resume pc on redirect command, else save the PC in IF2 while running
    pc_resume_n = cmd_nonattaboy_v ? fe_cmd_cast_i.vaddr : is_run ? pc_if2_r : pc_resume_r;

    case (state_r)
      // Wait for FE cmd
      e_wait : state_n = cmd_nonattaboy_v ? e_stall : e_wait;
      // Stall until we can start valid fetch
      e_stall: state_n = pc_v_if1_n ? e_run : e_stall;
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
  end

// Register state logic
always_ff @(posedge clk_i)
  begin
    pc_resume_r <= pc_resume_n;

    if (reset_i)
        state_r  <= e_wait;
    else
      begin
        state_r <= state_n;
      end
  end

// Next PC calculation
always_comb
  // load boot pc on reset command
  if(state_reset_v)
      pc_if1_n = fe_cmd_cast_i.vaddr;
  // if we need to redirect
  else if (pc_redirect_v | icache_fence_v | itlb_fence_v)
      pc_if1_n = fe_cmd_cast_i.vaddr;
  else if (state_r != e_run) 
      pc_if1_n = pc_resume_r;
  else if (btb_br_tgt_v_lo)
      pc_if1_n = btb_br_tgt_lo;
  else if (ovr_taken)
      pc_if1_n = br_target;
  else if (ovr_ntaken)
      pc_if1_n = pc_if2_r + 4;
  else
    begin
      pc_if1_n = pc_if1_r + 4;
    end

// PC pipeline
// We can't fetch from wait state, only run and coming out of stall.
// We wait until both the FE queue and I$ are ready, but flushes invalidate the fetch.
// The next PC is valid during a FE cmd, since it is a non-speculative
//   command and we must accept it immediately.
// This may cause us to fetch during an I$ miss or a with a full queue.  
// FE cmds normally flush the queue, so we don't expect this to affect
//   power much in practice.
assign pc_v_if1_n = ~is_wait & (cmd_nonattaboy_v || (fe_queue_ready_i & fetch_ready_i & ~flush));
assign pc_v_if2_n = pc_v_if1_r & ~flush;

// We use reset flops for status signals in the pipeline
always_ff @(posedge clk_i) 
  begin
    if (reset_i) 
      begin
        pc_v_if1_r      <= '0;
        pc_v_if2_r      <= '0;
        btb_v_if1_r     <= '0;
        itlb_miss_if2_r <= '0;
      end
    else
      begin
        pc_v_if1_r      <= pc_v_if1_n;
        pc_v_if2_r      <= pc_v_if2_n;
        btb_v_if1_r     <= btb_br_tgt_v_lo;
        itlb_miss_if2_r <= itlb_miss_i;
      end
  end

// We gate the PC data pipeline for power
//synopsys sync_set_reset "reset_i"
always_ff @(posedge clk_i) 
  if (reset_i)
    begin
      pc_if1_r <= '0;
      pc_if2_r <= '0;
    end
  else if (state_n == e_run) 
    begin
      pc_if1_r <= pc_if1_n;
      pc_if2_r <= pc_if1_r;
    end


// Branch prediction logic
bp_fe_branch_metadata_fwd_s fe_queue_cast_o_branch_metadata, fe_queue_cast_o_branch_metadata_r;

assign fe_queue_cast_o_branch_metadata = '{btb_tag: pc_if2_r[2+btb_idx_width_p+:btb_tag_width_p]
                                           , btb_idx: pc_if2_r[2+:btb_idx_width_p]
                                           , default: '0
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
   ,.r_addr_i(pc_if1_n)
   ,.r_v_i(pc_v_if1_n)
   ,.br_tgt_o(btb_br_tgt_lo)
   ,.br_tgt_v_o(btb_br_tgt_v_lo)

   ,.w_tag_i(fe_cmd_branch_metadata.btb_tag) 
   ,.w_idx_i(fe_cmd_branch_metadata.btb_idx)
   ,.w_v_i(pc_redirect_v & fe_cmd_yumi_o)
   ,.br_tgt_i(fe_cmd_cast_i.vaddr)
   );
 
bp_fe_instr_scan_s scan_instr;
instr_scan 
 #(.vaddr_width_p(vaddr_width_p)
   ,.instr_width_p(instr_width_lp)
   ) 
 instr_scan_1 
  (.instr_i(fetch_instr_i)
   ,.scan_o(scan_instr)
   );

// TODO: Should use an instruction cast
//   We don't want to wait until after expanding the immediate, though
// TODO: This functionality is broken. Should predict taken branches based on BHT and override BTB
wire is_br      = fetch_instr_v_i & (scan_instr.instr_scan_class == e_rvi_branch);
wire is_jal     = fetch_instr_v_i & (scan_instr.instr_scan_class == e_rvi_jal);
wire is_back_br = fetch_instr_i[instr_width_lp-1];
assign ovr_taken  = 1'b0; //pc_v_if2_r & ~flush & ((is_br & is_back_br) | (is_jal)) & ~btb_v_if1_r & icache_pc_gen_v_i;
assign ovr_ntaken = 1'b0; 
assign br_target  = pc_if2_r + fetch_instr_i[20+:12];

// Organize the FE queue message
always_comb
  begin
    // Set padding to 0
    fe_queue_cast_o = '0;

    if (fe_exception_v)
      begin
        fe_queue_cast_o.msg_type                     = e_fe_exception;
        fe_queue_cast_o.msg.exception.vaddr          = pc_if2_r; 
        fe_queue_cast_o.msg.exception.exception_code = misalign_exception
                                                       ? e_instr_misaligned
                                                       : itlb_miss_exception
                                                         ? e_itlb_miss
                                                         : e_instr_access_fault;
      end
    else 
      begin
        fe_queue_cast_o.msg_type                      = e_fe_fetch;
        fe_queue_cast_o.msg.fetch.pc                  = pc_if2_r;
        fe_queue_cast_o.msg.fetch.instr               = fetch_instr_i;
        fe_queue_cast_o.msg.fetch.branch_metadata_fwd = fe_queue_cast_o_branch_metadata_r;
      end
  end

// Organize the TLB commands
assign itlb_fence_v_o = itlb_fence_v;
assign itlb_w_v_o = itlb_fill_v;
assign itlb_w_vtag_o = fe_cmd_cast_i.vaddr[vaddr_width_p-1:page_offset_width_p];
assign itlb_w_entry_o = fe_cmd_cast_i.operands.itlb_fill_response.pte_entry_leaf;
   
// icache to icache
assign icache_poison_o = cmd_nonattaboy_v;

assign fetch_pc_o = pc_if1_n;
assign fetch_v_o  = fetch_ready_i & pc_v_if1_n;

// Handshaking signals
assign fe_cmd_yumi_o      = fe_cmd_v_i; // Always accept FE commands
assign fe_cmd_processed_o = fe_cmd_yumi_o; // All FE cmds are processed in 1 cycle, for now
assign fe_queue_v_o       = fe_queue_ready_i & (fe_instr_v | fe_exception_v);

endmodule

