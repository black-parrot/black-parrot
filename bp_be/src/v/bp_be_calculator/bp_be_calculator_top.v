/**
 *
 * Name:
 *   bp_be_calculator_top.v
 * 
 * Description:
 *
 * Notes:
 *   Should subdivide this module into a few helper modules to reduce complexity. Perhaps
 *     issuer, exe_pipe, completion_pipe, status_gen?
 *   Exception aggregation could be simplified with constants and more thought. Should fix
 *     once code is more stable, fixing in cleanup could cause regressions
 */

module bp_be_calculator_top 
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
    `declare_bp_proc_params(cfg_p)
    `declare_bp_fe_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
    `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

   // Default parameters
   , parameter fp_en_p                  = 0

   // Generated parameters
   , localparam proc_cfg_width_lp       = `bp_proc_cfg_width(num_core_p, num_cce_p, num_lce_p)
   , localparam issue_pkt_width_lp      = `bp_be_issue_pkt_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam isd_status_width_lp     = `bp_be_isd_status_width
   , localparam calc_status_width_lp    = `bp_be_calc_status_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam exception_width_lp      = `bp_be_exception_width
   , localparam mmu_cmd_width_lp        = `bp_be_mmu_cmd_width(vaddr_width_p)
   , localparam csr_cmd_width_lp        = `bp_be_csr_cmd_width
   , localparam mem_resp_width_lp       = `bp_be_mem_resp_width(vaddr_width_p)
   , localparam dispatch_pkt_width_lp   = `bp_be_dispatch_pkt_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam pipe_stage_reg_width_lp = `bp_be_pipe_stage_reg_width(vaddr_width_p)

   // From BP BE specifications
   , localparam pipe_stage_els_lp = 5 
   , localparam ecode_dec_width_lp = `bp_be_ecode_dec_width

   // From RISC-V specifications
   , localparam reg_addr_width_lp = rv64_reg_addr_width_gp

   // Local constants
   , localparam dispatch_point_lp   = 0
   , localparam int_commit_point_lp = 3
   , localparam fp_commit_point_lp  = 4

   , localparam int_comp_idx_lp = 0
   , localparam mul_comp_idx_lp = 1
   , localparam mem_comp_idx_lp = 2
   , localparam fp_comp_idx_lp  = 3
   )
 (input                                  clk_i
  , input                                reset_i
   
  // Slow inputs   
  , input [proc_cfg_width_lp-1:0]        proc_cfg_i
   
  // Calculator - Checker interface   
  , input [issue_pkt_width_lp-1:0]       issue_pkt_i
  , input                                issue_pkt_v_i
  , output                               issue_pkt_ready_o
   
  , input                                chk_dispatch_v_i
  , input                                chk_roll_i
  , input                                chk_poison_iss_i
  , input                                chk_poison_isd_i
  , input                                chk_poison_ex1_i
  , input                                chk_poison_ex2_i
   
  , output [isd_status_width_lp-1:0]     isd_status_o
  , output [calc_status_width_lp-1:0]    calc_status_o
   
  // Mem interface   
  , output [mmu_cmd_width_lp-1:0]        mmu_cmd_o
  , output                               mmu_cmd_v_o
  , input                                mmu_cmd_ready_i
   
  , output [csr_cmd_width_lp-1:0]        csr_cmd_o
  , output                               csr_cmd_v_o
  , input                                csr_cmd_ready_i

  , input [mem_resp_width_lp-1:0]        mem_resp_i
  , input                                mem_resp_v_i
  , output                               mem_resp_ready_o

  // CSRs
  , output                               instret_mem3_o
  , output [vaddr_width_p-1:0]           pc_mem3_o
  , output [instr_width_p-1:0]          instr_mem3_o
  , output                               pc_v_mem3_o
  );

// Declare parameterizable structs
`declare_bp_be_mmu_structs(vaddr_width_p, ppn_width_p, lce_sets_p, cce_block_width_p / 8)
`declare_bp_common_proc_cfg_s(num_core_p, num_cce_p, num_lce_p)
`declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

// Cast input and output ports 
bp_be_issue_pkt_s   issue_pkt;
bp_be_isd_status_s  isd_status;
bp_be_calc_status_s calc_status;
bp_be_mem_resp_s    mem_resp;
bp_proc_cfg_s       proc_cfg;

assign issue_pkt = issue_pkt_i;
assign mem_resp = mem_resp_i;
assign proc_cfg = proc_cfg_i;
assign calc_status_o = calc_status;
assign isd_status_o = isd_status;

// Declare intermediate signals
logic                   chk_poison_iss_r;
bp_be_issue_pkt_s       issue_pkt_r;
logic                   issue_pkt_v_r;
bp_be_dispatch_pkt_s    dispatch_pkt, dispatch_pkt_r;
logic                   dispatch_pkt_v_r;
bp_be_decode_s          decoded;

// Register bypass network
logic [dword_width_p-1:0] irf_rs1    , irf_rs2;
logic [dword_width_p-1:0] frf_rs1    , frf_rs2;
logic [dword_width_p-1:0] bypass_irs1, bypass_irs2;
logic [dword_width_p-1:0] bypass_frs1, bypass_frs2;
logic [dword_width_p-1:0] bypass_rs1 , bypass_rs2;

// Exception signals
logic load_misaligned_mem1, store_misaligned_mem3;

// Pipeline stage registers
bp_be_pipe_stage_reg_s [pipe_stage_els_lp-1:0] calc_stage_r;
bp_be_pipe_stage_reg_s                         calc_stage_isd;
bp_be_exception_s      [pipe_stage_els_lp-1:0] exc_stage_r;
bp_be_exception_s      [pipe_stage_els_lp  :0] exc_stage_n;

logic [pipe_stage_els_lp-1:0][dword_width_p-1:0] comp_stage_r, comp_stage_n;

logic [dword_width_p-1:0] pipe_nop_data_lo;
logic [dword_width_p-1:0] pipe_int_data_lo, pipe_mul_data_lo, pipe_mem_data_lo, pipe_fp_data_lo;

logic nop_pipe_result_v;
logic pipe_int_data_lo_v, pipe_mul_data_lo_v, pipe_mem_data_lo_v, pipe_fp_data_lo_v;
logic pipe_mem_exc_v_lo, pipe_mem_miss_v_lo;

logic [vaddr_width_p-1:0] br_tgt_int1;

// Forwarding information
logic [pipe_stage_els_lp-1:1]                        comp_stage_n_slice_iwb_v;
logic [pipe_stage_els_lp-1:1]                        comp_stage_n_slice_fwb_v;
logic [pipe_stage_els_lp-1:1][reg_addr_width_lp-1:0] comp_stage_n_slice_rd_addr;
logic [pipe_stage_els_lp-1:1][dword_width_p-1:0] comp_stage_n_slice_rd;

// Handshakes
assign issue_pkt_ready_o = (chk_dispatch_v_i | ~issue_pkt_v_r);

// Module instantiations
// Register files
bp_be_regfile
#(.cfg_p(cfg_p))
 int_regfile
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.issue_v_i(issue_pkt_v_i)
   ,.dispatch_v_i(chk_dispatch_v_i)

   ,.rd_w_v_i(calc_stage_r[int_commit_point_lp].irf_w_v & ~exc_stage_r[int_commit_point_lp].poison_v)
   ,.rd_addr_i(calc_stage_r[int_commit_point_lp].instr.fields.rtype.rd_addr)
   ,.rd_data_i(comp_stage_r[int_commit_point_lp])

   ,.rs1_r_v_i(issue_pkt.irs1_v)
   ,.rs1_addr_i(issue_pkt.instr.fields.rtype.rs1_addr)
   ,.rs1_data_o(irf_rs1)

   ,.rs2_r_v_i(issue_pkt.irs2_v)
   ,.rs2_addr_i(issue_pkt.instr.fields.rtype.rs2_addr)
   ,.rs2_data_o(irf_rs2)
   );

if (fp_en_p)
  begin : fp_rf
    bp_be_regfile
    #(.cfg_p(cfg_p))
     float_regfile
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
    
       ,.issue_v_i(issue_pkt_v_i)
       ,.dispatch_v_i(chk_dispatch_v_i)
    
       ,.rd_w_v_i(calc_stage_r[fp_commit_point_lp].frf_w_v & ~exc_stage_r[fp_commit_point_lp].poison_v)
       ,.rd_addr_i(calc_stage_r[fp_commit_point_lp].rd_addr)
       ,.rd_data_i(comp_stage_r[fp_commit_point_lp])
    
       ,.rs1_r_v_i(issue_pkt.frs1_v)
       ,.rs1_addr_i(issue_pkt.instr.fields.rtype.rs1_addr)
       ,.rs1_data_o(frf_rs1)
    
       ,.rs2_r_v_i(issue_pkt.frs2_v)
       ,.rs2_addr_i(issue_pkt.instr.fields.rtype.rs2_addr)
       ,.rs2_data_o(frf_rs2)
       );

    bp_be_bypass 
     // Don't need to forward isd data
     #(.fwd_els_p(pipe_stage_els_lp-1))
     fp_bypass
      (.id_rs1_addr_i(issue_pkt_r.instr.fields.rtype.rs1_addr)
       ,.id_rs1_i(frf_rs1)
    
       ,.id_rs2_addr_i(issue_pkt_r.instr.fields.rtype.rs2_addr)
       ,.id_rs2_i(frf_rs2)
    
       ,.fwd_rd_v_i(comp_stage_n_slice_fwb_v)
       ,.fwd_rd_addr_i(comp_stage_n_slice_rd_addr)
       ,.fwd_rd_i(comp_stage_n_slice_rd)
    
       ,.bypass_rs1_o(bypass_frs1)
       ,.bypass_rs2_o(bypass_frs2)
       );
    
    bsg_mux 
     #(.width_p(dword_width_p)
       ,.els_p(2)
       ) 
     bypass_xrs1_mux
      (.data_i({bypass_frs1, bypass_irs1})
       ,.sel_i(issue_pkt_r.frs1_v)
       ,.data_o(bypass_rs1)
       );
    
    bsg_mux 
     #(.width_p(dword_width_p)
       ,.els_p(2)
       ) 
     bypass_xrs2_mux
      (.data_i({bypass_frs2, bypass_irs2})
       ,.sel_i(issue_pkt_r.frs2_v)
       ,.data_o(bypass_rs2)
       );
  end
else
  begin : no_fp_rf
    assign frf_rs1 = '0;
    assign frf_rs2 = '0;

    assign bypass_frs1 = '0;
    assign bypass_frs2 = '0;

    assign bypass_rs1 = bypass_irs1;
    assign bypass_rs2 = bypass_irs2;
  end

// Issued instruction register
bsg_dff_reset_en 
 #(.width_p(1+issue_pkt_width_lp))
 issue_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i | chk_roll_i)
   ,.en_i(issue_pkt_v_i | chk_dispatch_v_i)

   ,.data_i({issue_pkt_v_i, issue_pkt})
   ,.data_o({issue_pkt_v_r, issue_pkt_r})
   );
   
// Register the issue poison
bsg_dff_reset_en 
 #(.width_p(1))
 issue_psn_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(issue_pkt_v_i | chk_dispatch_v_i | chk_poison_iss_i)

   ,.data_i(chk_poison_iss_i)
   ,.data_o(chk_poison_iss_r)
   );

// Decode the dispatched instruction
logic                  fe_exc_not_instr_isd;
bp_fe_exception_code_e fe_exc_isd;
// Decode the dispatched instruction
bp_be_instr_decoder
 instr_decoder
  (.instr_v_i(issue_pkt_v_r)
   ,.instr_i(issue_pkt_r.instr)
   ,.fe_exc_not_instr_i(issue_pkt_r.fe_exception_not_instr)
   ,.fe_exc_i(issue_pkt_r.fe_exception_code)

   ,.decode_o(decoded)
   );

// Bypass the instruction operands from written registers in the stack
bp_be_bypass 
 // Don't need to forward isd data
 #(.fwd_els_p(pipe_stage_els_lp-1))
 int_bypass 
  (.id_rs1_addr_i(issue_pkt_r.instr.fields.rtype.rs1_addr)
   ,.id_rs1_i(irf_rs1)

   ,.id_rs2_addr_i(issue_pkt_r.instr.fields.rtype.rs2_addr)
   ,.id_rs2_i(irf_rs2)

   ,.fwd_rd_v_i(comp_stage_n_slice_iwb_v)
   ,.fwd_rd_addr_i(comp_stage_n_slice_rd_addr)
   ,.fwd_rd_i(comp_stage_n_slice_rd)

   ,.bypass_rs1_o(bypass_irs1)
   ,.bypass_rs2_o(bypass_irs2)
   );

// Computation pipelines
// Integer pipe: 1 cycle latency
bp_be_pipe_int 
 #(.vaddr_width_p(vaddr_width_p))
 pipe_int
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
 
   ,.kill_ex1_i(exc_stage_n[1].poison_v)

   ,.decode_i(dispatch_pkt_r.decode)
   ,.pc_i(dispatch_pkt_r.pc)
   ,.rs1_i(dispatch_pkt_r.rs1)
   ,.rs2_i(dispatch_pkt_r.rs2)
   ,.imm_i(dispatch_pkt_r.imm)

   ,.data_o(pipe_int_data_lo)
   
   ,.br_tgt_o(br_tgt_int1)
   );

// Multiplication pipe: 2 cycle latency
bp_be_pipe_mul
 pipe_mul
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.kill_ex1_i(exc_stage_n[1].poison_v)
   ,.kill_ex2_i(exc_stage_n[2].poison_v)

   ,.decode_i(dispatch_pkt_r.decode)
   ,.rs1_i(dispatch_pkt_r.rs1)
   ,.rs2_i(dispatch_pkt_r.rs2)

   ,.data_o(pipe_mul_data_lo)
   );

// Memory pipe: 3 cycle latency
bp_be_pipe_mem
 #(.cfg_p(cfg_p))
 pipe_mem
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.kill_ex1_i(exc_stage_n[1].poison_v)
   ,.kill_ex2_i(exc_stage_n[2].poison_v)
   ,.kill_ex3_i(exc_stage_r[2].poison_v) 

   ,.decode_i(dispatch_pkt_r.decode)
   ,.pc_i(dispatch_pkt_r.pc)
   ,.instr_i(dispatch_pkt_r.instr)
   ,.rs1_i(dispatch_pkt_r.rs1)
   ,.rs2_i(dispatch_pkt_r.rs2)
   ,.imm_i(dispatch_pkt_r.imm)

   ,.mmu_cmd_o(mmu_cmd_o)
   ,.mmu_cmd_v_o(mmu_cmd_v_o)
   ,.mmu_cmd_ready_i(mmu_cmd_ready_i)

   ,.csr_cmd_o(csr_cmd_o)
   ,.csr_cmd_v_o(csr_cmd_v_o)
   ,.csr_cmd_ready_i(csr_cmd_ready_i)

   ,.mem_resp_i(mem_resp_i)
   ,.mem_resp_v_i(mem_resp_v_i)
   ,.mem_resp_ready_o(mem_resp_ready_o)

   ,.exc_v_o(pipe_mem_exc_v_lo)
   ,.miss_v_o(pipe_mem_miss_v_lo)
   ,.data_o(pipe_mem_data_lo)
   );

  // Floating point pipe: 4 cycle latency
  bp_be_pipe_fp 
   pipe_fp
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
  
     ,.kill_ex1_i(exc_stage_n[1].poison_v)
     ,.kill_ex2_i(exc_stage_n[2].poison_v)
     ,.kill_ex3_i(exc_stage_n[3].poison_v) 
     ,.kill_ex4_i(exc_stage_n[4].poison_v) 
  
     ,.decode_i(dispatch_pkt_r.decode)
     ,.rs1_i(dispatch_pkt_r.rs1)
     ,.rs2_i(dispatch_pkt_r.rs2)
  
     ,.data_o(pipe_fp_data_lo)
     );

// Execution pipelines
// Shift in dispatch pkt and move everything else down the pipe
bsg_dff
 #(.width_p(pipe_stage_reg_width_lp*pipe_stage_els_lp))
 calc_stage_reg
  (.clk_i(clk_i)
   ,.data_i({calc_stage_r[0+:pipe_stage_els_lp-1], calc_stage_isd})
   ,.data_o(calc_stage_r)
   );

bsg_dff
 #(.width_p(1+dispatch_pkt_width_lp))
 dispatch_pkt_reg
  (.clk_i(clk_i)
   ,.data_i({(issue_pkt_v_r & chk_dispatch_v_i), dispatch_pkt})
   ,.data_o({dispatch_pkt_v_r, dispatch_pkt_r})
   );

// If a pipeline has completed an instruction (pipe_xxx_v), then mux in the calculated result.
// Else, mux in the previous stage of the completion pipe. Since we are single issue and have
//   static latencies, we cannot have two pipelines complete at the same time.
assign pipe_fp_data_lo_v  = calc_stage_r[3].pipe_fp_v;
assign pipe_mem_data_lo_v = calc_stage_r[2].pipe_mem_v;
assign pipe_mul_data_lo_v = calc_stage_r[1].pipe_mul_v;
assign pipe_int_data_lo_v = calc_stage_r[0].pipe_int_v;

assign pipe_nop_data_lo = '0;

logic [pipe_stage_els_lp-1:0][dword_width_p-1:0] comp_stage_mux_li;
logic [pipe_stage_els_lp-1:0]                        comp_stage_mux_sel_li;

assign comp_stage_mux_li = {pipe_fp_data_lo, pipe_mem_data_lo, pipe_mul_data_lo, pipe_int_data_lo, pipe_nop_data_lo};
assign comp_stage_mux_sel_li = {pipe_fp_data_lo_v, pipe_mem_data_lo_v, pipe_mul_data_lo_v, pipe_int_data_lo_v, 1'b1};
bsg_mux_segmented 
 #(.segments_p(pipe_stage_els_lp)
   ,.segment_width_p(dword_width_p)
   ) 
 comp_stage_mux
  (.data0_i({comp_stage_r[0+:pipe_stage_els_lp-1], dword_width_p'(0)})
   ,.data1_i(comp_stage_mux_li)
   ,.sel_i(comp_stage_mux_sel_li)
   ,.data_o(comp_stage_n)
   );

bsg_dff 
 #(.width_p(dword_width_p*pipe_stage_els_lp)
   ) 
 comp_stage_reg 
  (.clk_i(clk_i)
   ,.data_i(comp_stage_n)
   ,.data_o(comp_stage_r)
   );

// Exception pipeline
bsg_dff 
 #(.width_p(exception_width_lp*pipe_stage_els_lp)
   ) 
 exc_stage_reg
  (.clk_i(clk_i)
   ,.data_i(exc_stage_n[0+:pipe_stage_els_lp])
   ,.data_o(exc_stage_r)
   );

wire fe_nop_v = chk_dispatch_v_i & ~issue_pkt_v_r;
wire be_nop_v = ~chk_dispatch_v_i &  mmu_cmd_ready_i;
wire me_nop_v = ~chk_dispatch_v_i & ~mmu_cmd_ready_i;

always_comb 
  begin
    // Form dispatch packet
    dispatch_pkt.pc                  = issue_pkt_r.pc;
    dispatch_pkt.branch_metadata_fwd = issue_pkt_r.branch_metadata_fwd;
    dispatch_pkt.instr               = issue_pkt_r.instr;
    dispatch_pkt.rs1                 = bypass_rs1;
    dispatch_pkt.rs2                 = bypass_rs2;
    dispatch_pkt.imm                 = issue_pkt_r.imm;

      if (fe_nop_v) dispatch_pkt = '0;
      else if (be_nop_v) dispatch_pkt = '0;
      else if (me_nop_v) dispatch_pkt = '0;
      else               dispatch_pkt.decode = decoded;

    // Strip out elements of the dispatch packet that we want to save for later
    calc_stage_isd.pc             = dispatch_pkt.pc;
    calc_stage_isd.instr          = dispatch_pkt.instr;
    calc_stage_isd.v              = dispatch_pkt.decode.v;
    calc_stage_isd.instr_v        = dispatch_pkt.decode.instr_v;
    calc_stage_isd.pipe_int_v     = dispatch_pkt.decode.pipe_int_v;
    calc_stage_isd.pipe_mul_v     = dispatch_pkt.decode.pipe_mul_v;
    calc_stage_isd.pipe_mem_v     = dispatch_pkt.decode.pipe_mem_v;
    calc_stage_isd.pipe_fp_v      = dispatch_pkt.decode.pipe_fp_v;
    calc_stage_isd.mem_v          = dispatch_pkt.decode.mem_v;
    calc_stage_isd.csr_v          = dispatch_pkt.decode.csr_v;
    calc_stage_isd.irf_w_v        = dispatch_pkt.decode.irf_w_v;
    calc_stage_isd.frf_w_v        = dispatch_pkt.decode.frf_w_v;

    // Calculator status ISD stage
    isd_status.isd_fence_v  = issue_pkt_v_r & issue_pkt_r.fence_v;
    isd_status.isd_mem_v    = issue_pkt_v_r & issue_pkt_r.mem_v;
    isd_status.isd_irs1_v   = issue_pkt_v_r & issue_pkt_r.irs1_v;
    isd_status.isd_frs1_v   = issue_pkt_v_r & issue_pkt_r.frs1_v;
    isd_status.isd_rs1_addr = issue_pkt_r.instr.fields.rtype.rs1_addr;
    isd_status.isd_irs2_v   = issue_pkt_v_r & issue_pkt_r.irs2_v;
    isd_status.isd_frs2_v   = issue_pkt_v_r & issue_pkt_r.frs2_v;
    isd_status.isd_rs2_addr = issue_pkt_r.instr.fields.rtype.rs2_addr;

    // Calculator status EX1 information
    calc_status.int1_v                   = dispatch_pkt_r.decode.pipe_int_v;
    calc_status.int1_br_tgt              = br_tgt_int1;
    calc_status.int1_branch_metadata_fwd = dispatch_pkt_r.branch_metadata_fwd;
    calc_status.int1_btaken              = (dispatch_pkt_r.decode.br_v & pipe_int_data_lo[0])
                                           | dispatch_pkt_r.decode.jmp_v;
    calc_status.int1_br_or_jmp           = dispatch_pkt_r.decode.br_v 
                                           | dispatch_pkt_r.decode.jmp_v;
    calc_status.ex1_v                    = dispatch_pkt_r.decode.v & ~exc_stage_r[0].poison_v;
    calc_status.ex1_pc                   = dispatch_pkt_r.pc;
    calc_status.ex1_instr_v              = dispatch_pkt_r.decode.instr_v & ~exc_stage_r[0].poison_v;
    calc_status.mem1_fencei_v            = dispatch_pkt_r.decode.fencei_v;

    // Dependency information for pipelines
    for (integer i = 0; i < pipe_stage_els_lp; i++) 
      begin : dep_status
        calc_status.dep_status[i].int_iwb_v = calc_stage_r[i].pipe_int_v 
                                              & ~exc_stage_n[i+1].poison_v
                                              & calc_stage_r[i].irf_w_v;
        calc_status.dep_status[i].mul_iwb_v = calc_stage_r[i].pipe_mul_v 
                                              & ~exc_stage_n[i+1].poison_v
                                              & calc_stage_r[i].irf_w_v;
        calc_status.dep_status[i].mem_iwb_v = calc_stage_r[i].pipe_mem_v 
                                              & ~exc_stage_n[i+1].poison_v
                                              & calc_stage_r[i].irf_w_v;
        calc_status.dep_status[i].mem_fwb_v = calc_stage_r[i].pipe_mem_v 
                                              & ~exc_stage_n[i+1].poison_v
                                              & calc_stage_r[i].frf_w_v;
        calc_status.dep_status[i].fp_fwb_v  = calc_stage_r[i].pipe_fp_v  
                                              & ~exc_stage_n[i+1].poison_v
                                              & calc_stage_r[i].frf_w_v;
        calc_status.dep_status[i].rd_addr   = calc_stage_r[i].instr.fields.rtype.rd_addr;
        calc_status.dep_status[i].mem_v     = calc_stage_r[i].mem_v & ~exc_stage_n[i+1].poison_v;
        calc_status.dep_status[i].serial_v  = calc_stage_r[i].csr_v & ~exc_stage_n[i+1].poison_v;
      end

    // Additional commit point information
    calc_status.mem3_pc     = calc_stage_r[2].pc;
    calc_status.mem3_miss_v = pipe_mem_miss_v_lo & ~exc_stage_r[2].poison_v;
    calc_status.mem3_cmt_v  = calc_stage_r[2].v & ~exc_stage_r[2].roll_v;
    
    // Slicing the completion pipe for Forwarding information
    for (integer i = 1; i < pipe_stage_els_lp; i++) 
      begin : comp_stage_slice
        comp_stage_n_slice_iwb_v[i]   = calc_stage_r[i-1].irf_w_v & ~exc_stage_n[i].poison_v; 
        comp_stage_n_slice_fwb_v[i]   = calc_stage_r[i-1].frf_w_v & ~exc_stage_n[i].poison_v; 
        comp_stage_n_slice_rd_addr[i] = calc_stage_r[i-1].instr.fields.rtype.rd_addr;

        comp_stage_n_slice_rd[i]      = comp_stage_n[i];
      end
  end

always_comb 
  begin
    // Exception aggregation
    for (integer i = 0; i < pipe_stage_els_lp; i++) 
      begin : exc_stage
        // Normally, shift down in the pipe
        exc_stage_n[i] = (i == 0) ? '0 : exc_stage_r[i-1];
      end
        // If there are new exceptions, add them to the list
        exc_stage_n[0].fe_nop_v        = fe_nop_v;
        exc_stage_n[0].be_nop_v        = be_nop_v;
        exc_stage_n[0].me_nop_v        = me_nop_v;

        exc_stage_n[0].roll_v          =                           chk_roll_i;
        exc_stage_n[1].roll_v          = exc_stage_r[0].roll_v   | chk_roll_i;
        exc_stage_n[2].roll_v          = exc_stage_r[1].roll_v   | chk_roll_i;
        exc_stage_n[3].roll_v          = exc_stage_r[2].roll_v   | chk_roll_i;

        exc_stage_n[0].poison_v        = chk_poison_iss_r        | chk_poison_isd_i;
        exc_stage_n[1].poison_v        = exc_stage_r[0].poison_v | chk_poison_ex1_i;
        exc_stage_n[2].poison_v        = exc_stage_r[1].poison_v | chk_poison_ex2_i;
        exc_stage_n[3].poison_v        = exc_stage_r[2].poison_v | pipe_mem_miss_v_lo | pipe_mem_exc_v_lo;
  end

assign instret_mem3_o = calc_stage_r[2].instr_v & ~exc_stage_n[3].poison_v;
assign pc_mem3_o      = calc_stage_r[2].pc;
assign pc_v_mem3_o    = calc_stage_r[2].v & ~exc_stage_r[2].poison_v;
assign instr_mem3_o   = calc_stage_r[2].instr;

endmodule

