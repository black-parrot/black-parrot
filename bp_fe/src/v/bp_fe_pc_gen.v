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

   `declare_bp_fe_pc_gen_if_widths(vaddr_width_p, branch_metadata_fwd_width_p)

   , localparam instr_width_lp    = rv64_instr_width_gp
   )
  (input                                             clk_i
   , input                                           reset_i
    
   , output logic [bp_fe_pc_gen_icache_width_lp-1:0] pc_gen_icache_o
   , output logic                                    pc_gen_icache_v_o
   , input                                           pc_gen_icache_ready_i

   , input [bp_fe_icache_pc_gen_width_lp-1:0]        icache_pc_gen_i
   , input                                           icache_pc_gen_v_i
   , output logic                                    icache_pc_gen_ready_o
   , input                                           icache_miss_i

   , output logic [bp_fe_pc_gen_itlb_width_lp-1:0]   pc_gen_itlb_o
   , output logic                                    pc_gen_itlb_v_o
   , input                                           pc_gen_itlb_ready_i
     
   , output logic [bp_fe_pc_gen_width_o_lp-1:0]      pc_gen_fe_o
   , output logic                                    pc_gen_fe_v_o
   , input                                           pc_gen_fe_ready_i

   , input [bp_fe_pc_gen_width_i_lp-1:0]             fe_pc_gen_i
   , input                                           fe_pc_gen_v_i
   , output logic                                    fe_pc_gen_ready_o

   , input logic                                     itlb_miss_i
   );

//the first level of structs
`declare_bp_fe_structs(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_p)
`declare_bp_fe_pc_gen_cmd_s(vaddr_width_p, branch_metadata_fwd_width_p);
`declare_bp_fe_pc_gen_icache_s(vaddr_width_p);
`declare_bp_fe_pc_gen_itlb_s(vaddr_width_p);
`declare_bp_fe_icache_pc_gen_s(vaddr_width_p);
`declare_bp_fe_branch_metadata_fwd_s(btb_tag_width_p,btb_idx_width_p,bht_idx_width_p,ras_idx_width_p);

// pc pipeline
logic [vaddr_width_p-1:0]       pc_if1_n, pc_if1_r, pc_if2_r;
logic                           pc_v_if1_n, pc_v_if2_n, pc_v_if1_r, pc_v_if2_r;
// branch prediction wires
logic [vaddr_width_p-1:0]       br_target;
logic                           ovr_taken, ovr_ntaken;
// btb io
logic [vaddr_width_p-1:0]       btb_br_tgt_lo;
logic                           btb_br_tgt_v_lo;

logic itlb_miss_if2_r;
logic btb_v_if1_r;

// Port casting
bp_fe_pc_gen_queue_s  pc_gen_queue;
bp_fe_pc_gen_cmd_s    fe_pc_gen_cmd;
bp_fe_pc_gen_icache_s pc_gen_icache;
bp_fe_pc_gen_itlb_s   pc_gen_itlb;
bp_fe_icache_pc_gen_s icache_pc_gen;

assign pc_gen_fe_o     = pc_gen_queue;
assign fe_pc_gen_cmd   = fe_pc_gen_i;
assign pc_gen_icache_o = pc_gen_icache;
assign pc_gen_itlb_o   = pc_gen_itlb;
assign icache_pc_gen   = icache_pc_gen_i;

// Flags for valid FE commands
wire state_reset_v    = fe_pc_gen_v_i & fe_pc_gen_cmd.reset_valid;
wire pc_redirect_v    = fe_pc_gen_v_i & fe_pc_gen_cmd.pc_redirect_valid;
wire itlb_fill_v      = fe_pc_gen_v_i & fe_pc_gen_cmd.itlb_fill_valid;
wire icache_fence_v   = fe_pc_gen_v_i & fe_pc_gen_cmd.icache_fence_valid;
wire itlb_fence_v     = fe_pc_gen_v_i & fe_pc_gen_cmd.itlb_fence_valid;
wire attaboy_v        = fe_pc_gen_v_i & fe_pc_gen_cmd.attaboy_valid;
wire cmd_nonattaboy_v = fe_pc_gen_v_i & ~fe_pc_gen_cmd.attaboy_valid;

// Until we support C, must be aligned to 4 bytes
// There's also an interesting question about physical alignment (I/O devices, etc)
//   But let's punt that for now...
wire misalign_exception  = pc_if2_r[1:0] != 2'b00; 
wire itlb_miss_exception = pc_v_if2_r & itlb_miss_if2_r;

wire fetch_fail     = pc_v_if2_r & ~pc_gen_fe_v_o & ~cmd_nonattaboy_v;
wire queue_miss     = pc_v_if2_r & ~pc_gen_fe_ready_i;
wire flush          = itlb_miss_if2_r | icache_miss_i | queue_miss | cmd_nonattaboy_v;
wire fe_instr_v     = pc_v_if2_r & ~flush;
wire fe_exception_v = pc_v_if2_r & (misalign_exception | itlb_miss_exception) & ~cmd_nonattaboy_v;

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
    pc_resume_n = cmd_nonattaboy_v ? fe_pc_gen_cmd.pc : is_run ? pc_if2_r : pc_resume_r;

    case (state_r)
      // Wait for FE cmd
      e_wait : state_n = cmd_nonattaboy_v ? e_stall : e_wait;
      // Stall until we can start valid fetch
      e_stall: state_n = pc_v_if1_n ? e_run : e_stall;
      // Run state -- PCs are actually being fetched
      // Transition to wait if there's a TLB miss while we wait for fill
      // Transition to stall if we don't successfully complete the fetch for whatever reason
      e_run  : state_n = itlb_miss_exception ? e_wait : fetch_fail ? e_stall : e_run;
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
      pc_if1_n = fe_pc_gen_cmd.pc;
  // if we need to redirect
  else if (pc_redirect_v | icache_fence_v | itlb_fence_v)
      pc_if1_n = fe_pc_gen_cmd.pc;
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
// We can't fetch from wait state, only run and coming out of stall
assign pc_v_if1_n = ~is_wait & pc_gen_itlb_ready_i & pc_gen_fe_ready_i & pc_gen_icache_ready_i;
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
bp_fe_branch_metadata_fwd_s fe_queue_branch_metadata, fe_queue_branch_metadata_r;

assign fe_queue_branch_metadata = '{btb_tag: icache_pc_gen.addr[2+btb_idx_width_p+:btb_tag_width_p]
                                    , btb_idx: icache_pc_gen.addr[2+:btb_idx_width_p]
                                    , default: '0
                                    };
bsg_dff_reset_en
 #(.width_p(branch_metadata_fwd_width_p))
 branch_metadata_fwd_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i) 
   ,.en_i(pc_gen_fe_v_o)

   ,.data_i(fe_queue_branch_metadata)
   ,.data_o(fe_queue_branch_metadata_r)
   );

// Casting branch metadata forwarded from BE
bp_fe_branch_metadata_fwd_s fe_cmd_branch_metadata;
assign fe_cmd_branch_metadata = fe_pc_gen_cmd.branch_metadata_fwd;
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
   ,.w_v_i(pc_redirect_v & fe_pc_gen_ready_o)
   ,.br_tgt_i(fe_pc_gen_cmd.pc)
   );
 
bp_fe_instr_scan_s scan_instr;
instr_scan 
 #(.vaddr_width_p(vaddr_width_p)
   ,.instr_width_p(instr_width_lp)
   ) 
 instr_scan_1 
  (.instr_i(icache_pc_gen.instr)
   ,.scan_o(scan_instr)
   );

// TODO: Should use an instruction cast
//   We don't want to wait until after expanding the immediate, though
// TODO: This functionality is broken. Should predict taken branches based on BHT and override BTB
wire is_br      = icache_pc_gen_v_i & (scan_instr.instr_scan_class == e_rvi_branch);
wire is_jal     = icache_pc_gen_v_i & (scan_instr.instr_scan_class == e_rvi_jal);
wire is_back_br = icache_pc_gen.instr[instr_width_lp-1];
assign ovr_taken  = 1'b0; //pc_v_if2_r & ~flush & ((is_br & is_back_br) | (is_jal)) & ~btb_v_if1_r & icache_pc_gen_v_i;
assign ovr_ntaken = 1'b0; 
assign br_target  = vaddr_width_p'(icache_pc_gen.addr + icache_pc_gen.instr[20+:12]); 

// Organize the FE queue message
always_comb
  begin
    // Set padding to 0
    pc_gen_queue = '0;

    // TODO: Don't need to be structs, just send out pc_o from pc_gen
    pc_gen_icache.virt_addr = pc_if1_n;
    pc_gen_itlb.virt_addr   = pc_if1_n;

    if (fe_exception_v)
      begin
        pc_gen_queue.msg_type                     = e_fe_exception;
        pc_gen_queue.msg.exception.vaddr          = pc_if2_r; 
        pc_gen_queue.msg.exception.exception_code = misalign_exception
                                                    ? e_instr_misaligned
                                                    : itlb_miss_exception
                                                      ? e_itlb_miss
                                                      : e_illegal_instr;
      end
    else 
      begin
        pc_gen_queue.msg_type                      = e_fe_fetch;
        pc_gen_queue.msg.fetch.pc                  = icache_pc_gen.addr;
        pc_gen_queue.msg.fetch.instr               = icache_pc_gen.instr;
        pc_gen_queue.msg.fetch.branch_metadata_fwd = fe_queue_branch_metadata_r;
      end
  end
   
// Handshaking signals
assign fe_pc_gen_ready_o     = fe_pc_gen_v_i; // Always accept FE commands
assign pc_gen_fe_v_o         = pc_gen_fe_ready_i & (fe_instr_v | fe_exception_v);
assign pc_gen_icache_v_o     = pc_gen_icache_ready_i & pc_v_if1_n;
assign icache_pc_gen_ready_o = 1'b1; // Always ready for icache data return
assign pc_gen_itlb_v_o       = pc_gen_itlb_ready_i & pc_v_if1_n;

endmodule

