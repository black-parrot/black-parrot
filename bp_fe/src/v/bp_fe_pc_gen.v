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
   , input                                           v_i
    
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

// Suppress unused signal warnings
wire unused0 = v_i;

//the first level of structs
`declare_bp_fe_structs(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_p)
//fe to pc_gen
`declare_bp_fe_pc_gen_cmd_s(vaddr_width_p, branch_metadata_fwd_width_p);
//pc_gen to icache
`declare_bp_fe_pc_gen_icache_s(vaddr_width_p);
//pc_gen to itlb
`declare_bp_fe_pc_gen_itlb_s(vaddr_width_p);
//icache to pc_gen
`declare_bp_fe_icache_pc_gen_s(vaddr_width_p);
//the second level structs definitions
`declare_bp_fe_branch_metadata_fwd_s(btb_tag_width_p,btb_idx_width_p,bht_idx_width_p,ras_idx_width_p);

   
//the first level structs instatiations
bp_fe_pc_gen_queue_s        pc_gen_queue;
bp_fe_pc_gen_cmd_s          fe_pc_gen_cmd;
bp_fe_pc_gen_icache_s       pc_gen_icache;
bp_fe_pc_gen_itlb_s         pc_gen_itlb;
bp_fe_branch_metadata_fwd_s branch_metadata_fwd_o;
bp_fe_icache_pc_gen_s       icache_pc_gen;

//the second level structs instatiations
bp_fe_fetch_s            pc_gen_fetch;
bp_fe_exception_s        pc_gen_exception;
bp_fe_instr_scan_s       scan_instr;
   
// FSM Variables
enum bit [1:0] {e_wait=2'd0, e_run=2'd1, e_stall=2'd2} state_n, state_r;
   
// pc pipeline
logic [vaddr_width_p-1:0]       pc_n, pc_f1, pc_f2;
logic [vaddr_width_p-1:0]       pc_resume_r, pc_resume_n;
logic                           pc_v_f1_n, pc_v_f1, pc_v_f2;
logic                           flush_f1, flush_f2;
// branch prediction wires
logic                           is_br;
logic                           is_jal;
logic [vaddr_width_p-1:0]       br_target;
logic                           is_back_br;
logic                           predict_taken;
// btb io
bp_fe_branch_metadata_fwd_s     fe_cmd_branch_metadata;
logic [vaddr_width_p-1:0]       btb_br_tgt_lo;
logic                           btb_br_tgt_v_lo;
// miss wires
logic                           itlb_miss_f2;
//command control signals
logic                           state_reset_v, pc_redirect_v, itlb_fill_v, icache_fence_v, itlb_fence_v;
//instr and exception valid
logic                           fe_instr_v;
logic                           fe_exception_v, misalign_exception, itlb_miss_exception;

bp_fe_branch_metadata_fwd_s fe_queue_branch_metadata, fe_queue_branch_metadata_r;

logic btb_pred_f1_r;

//connect pc_gen to the rest of the FE submodules as well as FE top module   
assign pc_gen_icache_o = pc_gen_icache;
assign pc_gen_itlb_o   = pc_gen_itlb;
assign pc_gen_fe_o     = pc_gen_queue;
assign fe_pc_gen_cmd   = fe_pc_gen_i;
assign icache_pc_gen   = icache_pc_gen_i;


assign state_reset_v = fe_pc_gen_v_i & fe_pc_gen_cmd.reset_valid;
assign pc_redirect_v = fe_pc_gen_v_i & fe_pc_gen_cmd.pc_redirect_valid;
assign itlb_fill_v   = fe_pc_gen_v_i & fe_pc_gen_cmd.itlb_fill_valid;
assign icache_fence_v = fe_pc_gen_v_i & fe_pc_gen_cmd.icache_fence_valid;
assign itlb_fence_v   = fe_pc_gen_v_i & fe_pc_gen_cmd.itlb_fence_valid;

assign fe_instr_v         = pc_v_f2 & ~flush_f2;
assign fe_exception_v     = misalign_exception | itlb_miss_exception;
assign misalign_exception = pc_redirect_v 
                            & ~fe_pc_gen_cmd.pc[1:0] == 2'b00;
                            
assign itlb_miss_exception = pc_v_f2 & itlb_miss_f2;
/* output wiring */
// there should be fixes to the pc signal sent out according to the valid/ready signal pairs

assign pc_gen_queue.msg_type            = (fe_exception_v) ? e_fe_exception : e_fe_fetch;
assign pc_gen_queue.msg                 = (fe_exception_v) ? pc_gen_exception : pc_gen_fetch;
    
assign pc_gen_exception.exception_code  = (misalign_exception) ? e_instr_misaligned
                                          : ((itlb_miss_exception)? e_itlb_miss
                                          : e_illegal_instr);
assign pc_gen_exception.vaddr           = pc_f2[0+:vaddr_width_p];
assign pc_gen_exception.padding         = '0;
    
assign pc_gen_fetch.pc                  = icache_pc_gen.addr;
assign pc_gen_fetch.instr               = icache_pc_gen.instr;
assign pc_gen_fetch.branch_metadata_fwd = fe_queue_branch_metadata_r;
assign pc_gen_fetch.padding             = '0;
    
assign pc_gen_icache.virt_addr          = pc_n;
assign pc_gen_itlb.virt_addr            = pc_n;
   
//valid-ready signals assignments
assign fe_pc_gen_ready_o     = fe_pc_gen_v_i;
assign pc_gen_fe_v_o         = (fe_instr_v | fe_exception_v) & pc_gen_fe_ready_i;
assign pc_gen_icache_v_o     = pc_v_f1_n & pc_gen_icache_ready_i;
assign icache_pc_gen_ready_o = 1'b1;
assign pc_gen_itlb_v_o       = pc_gen_icache_v_o & pc_gen_itlb_ready_i;

// FSM
always_ff @(posedge clk_i) begin
   if (reset_i) begin
      state_r <= e_wait;
   end else begin
      state_r <= state_n;
   end
end

always_comb begin
  state_n = state_r;

  case (state_r)
    e_wait : begin
      // In the wait state
      if (fe_pc_gen_v_i & ~fe_pc_gen_cmd.attaboy_valid) begin
        // FE command received
        if(pc_v_f1_n)
          state_n = e_run;
        else
          state_n = e_stall;
      end
    end
    e_run : begin
      // In the run state
      if (pc_v_f2 & itlb_miss_f2) begin
        state_n = e_wait;
      end
      else if(pc_v_f2 & !icache_pc_gen_v_i) begin
            state_n = e_stall;
      end
    end
    e_stall : begin
      // In the stall state
      if (pc_v_f1_n)
        state_n = e_run;
    end
    default: state_n = e_wait;
  endcase
end

always_ff @(posedge clk_i) begin
  pc_resume_r <= pc_resume_n;
end

always_comb begin
  if(fe_pc_gen_v_i & ~fe_pc_gen_cmd.attaboy_valid) begin
    pc_resume_n = fe_pc_gen_cmd.pc;
  end
  else if(state_r == e_run) begin
    pc_resume_n = pc_f2;
  end
  else begin
    pc_resume_n = pc_resume_r;
  end
end

always_ff @(posedge clk_i) begin
   if (reset_i) begin
      itlb_miss_f2 <= 1'd0;
   end else begin
      itlb_miss_f2 <= itlb_miss_i & ~flush_f2;
   end
end

always_comb
begin
    // load boot pc on reset command
    if(state_reset_v) begin
        pc_n = fe_pc_gen_cmd.pc;
    end
    // if we need to redirect
    else if (pc_redirect_v | icache_fence_v | itlb_fence_v) begin
        pc_n = fe_pc_gen_cmd.pc;
    end
    else if (state_r != e_run) begin
        pc_n = pc_resume_r;
    end
    else if (btb_br_tgt_v_lo)
    begin
        pc_n = btb_br_tgt_lo;
    end
    else if (predict_taken)
    begin
        pc_n = br_target;
    end
    else
    begin
        pc_n = pc_f1 + 4;
    end
end

assign flush_f1 = (itlb_miss_f2 | icache_miss_i) & ~(pc_redirect_v | icache_fence_v | itlb_fence_v);
assign flush_f2 = itlb_miss_f2 | icache_miss_i | pc_redirect_v | icache_fence_v | itlb_fence_v;
assign pc_v_f1_n = pc_gen_itlb_ready_i & pc_gen_fe_ready_i & pc_gen_icache_ready_i;
always_ff @(posedge clk_i) begin
  if (reset_i) begin
    pc_f1 <= '0;
    pc_f2 <= '0;

    pc_v_f1 <= '0;
    pc_v_f2 <= '0;

    btb_pred_f1_r <= '0;
  end else begin
    pc_v_f1 <= pc_v_f1_n & ~flush_f1;
    pc_v_f2 <= pc_v_f1   & ~flush_f2;

    if (state_n != e_run) begin
      pc_f1 <= pc_f1;
      pc_f2 <= pc_f2;

      btb_pred_f1_r <= btb_pred_f1_r;
    end else begin
      pc_f1 <= pc_n;
      pc_f2 <= pc_f1;

      btb_pred_f1_r <= btb_br_tgt_v_lo;
    end
  end
end

assign fe_queue_branch_metadata = '{btb_tag: pc_gen_fetch.pc[2+btb_idx_width_p+:btb_tag_width_p]
                                    , btb_idx: pc_gen_fetch.pc[2+:btb_idx_width_p]
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

assign fe_cmd_branch_metadata = fe_pc_gen_cmd.branch_metadata_fwd;
bp_fe_btb
 #(.vaddr_width_p(vaddr_width_p)
   ,.btb_tag_width_p(btb_tag_width_p)
   ,.btb_idx_width_p(btb_idx_width_p)
   )
 btb
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.r_addr_i(pc_n)
   ,.r_v_i(pc_v_f1_n)
   ,.br_tgt_o(btb_br_tgt_lo)
   ,.br_tgt_v_o(btb_br_tgt_v_lo)

   ,.w_tag_i(fe_cmd_branch_metadata.btb_tag) 
   ,.w_idx_i(fe_cmd_branch_metadata.btb_idx)
   ,.w_v_i(pc_redirect_v & fe_pc_gen_ready_o)
   ,.br_tgt_i(fe_pc_gen_cmd.pc)
   );
 
instr_scan 
 #(.vaddr_width_p(vaddr_width_p)
   ,.instr_width_p(instr_width_lp)
   ) 
 instr_scan_1 
  (.instr_i(icache_pc_gen.instr)
   ,.scan_o(scan_instr)
   );

assign is_br = icache_pc_gen_v_i & (scan_instr.instr_scan_class == e_rvi_branch);
assign is_jal = icache_pc_gen_v_i & (scan_instr.instr_scan_class == e_rvi_jal);
assign br_target = vaddr_width_p'(icache_pc_gen.addr + scan_instr.imm); 
assign is_back_br = scan_instr.imm[63];
assign predict_taken = pc_v_f2 & ((is_br & is_back_br) | (is_jal)) & ~btb_pred_f1_r & icache_pc_gen_v_i;

endmodule
