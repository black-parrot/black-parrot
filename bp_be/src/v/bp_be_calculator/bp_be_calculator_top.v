/**
 *
 * Name:
 *   bp_be_calculator_top.v
 * 
 * Description:
 *
 * Parameters:
 *   vaddr_width_p               - FE-BE structure sizing parameter
 *   paddr_width_p               - ''
 *   asid_width_p                - ''
 *   branch_metadata_fwd_width_p - ''   
 *
 * Inputs:
 *   clk_i                  -
 *   reset_i                -
 *
 *   issue_pkt_i            - An issued instruction, containing predecoded metadata
 *   issue_pkt_v_i          - "ready-then-valid" interface
 *   issue_pkt_ready_o      -
 *
 *   chk_dispatch_v_i       - Checker indicates the last issued instruction may be dispatched
 *   chk_roll_i             - Checker rolls back all uncommitted instructions
 *   chk_poison_ex_i        - Checker poisons all uncommitted instructions
 *   chk_poison_isd_i       - Checker poisons the currently issued instruction as it's dispatched
 *
 *   mmu_resp_i             - An MMU response containing load data and exception codes
 *   mmu_resp_v_i           - "ready-then-valid" interface
 *   mmu_resp_ready_o       -
 *   
 * Outputs:
 *   calc_status_o          - Packet containing execution status of pipeline, including dependency
 *                              information used by the checker to detect hazards
 *
 *   mmu_cmd_o              - An MMU command wrapping a D$ command
 *   mmu_cmd_v_o            - "ready-then-valid" interface
 *   mmu_cmd_ready_i        -
 *
 *   cmt_trace_stage_reg_o  - Commit status data used to monitor execution
 *   cmt_trace_result_o     - Committed calculated results
 *   cmt_trace_exc_o        - Committed exceptions 
 *
 * Keywords:
 *   calculator, pipeline, pipe, execution, registers
 * 
 * Notes:
 *   Should subdivide this module into a few helper modules to reduce complexity. Perhaps
 *     issuer, exe_pipe, completion_pipe, status_gen?
 *   Exception aggregation could be simplified with constants and more thought. Should fix
 *     once code is more stable, fixing in cleanup could cause regressions
 */

module bp_be_calculator_top 
 import bp_common_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_be_pkg::*;
 #(// Structure sizing parameters
   parameter vaddr_width_p                 = "inv"
   , parameter paddr_width_p               = "inv"
   , parameter asid_width_p                = "inv"
   , parameter branch_metadata_fwd_width_p = "inv"

   , parameter core_els_p                  = "inv"
   , parameter num_lce_p                   = "inv"
   , parameter lce_sets_p                  = "inv"
   , parameter cce_block_size_in_bytes_p   = "inv"
   
   // Generated parameters
   , localparam proc_cfg_width_lp       = `bp_proc_cfg_width(core_els_p, num_lce_p)
   , localparam issue_pkt_width_lp      = `bp_be_issue_pkt_width(branch_metadata_fwd_width_p)
   , localparam calc_status_width_lp    = `bp_be_calc_status_width(branch_metadata_fwd_width_p)
   , localparam exception_width_lp      = `bp_be_exception_width
   , localparam mmu_cmd_width_lp        = `bp_be_mmu_cmd_width(vaddr_width_p)
   , localparam mmu_resp_width_lp       = `bp_be_mmu_resp_width
   , localparam pipe_stage_reg_width_lp = `bp_be_pipe_stage_reg_width(branch_metadata_fwd_width_p)
   , localparam calc_result_width_lp    = `bp_be_calc_result_width(branch_metadata_fwd_width_p)

   // From BP BE specifications
   , localparam pipe_stage_els_lp = bp_be_pipe_stage_els_gp

   // From RISC-V specifications
   , localparam instr_width_lp    = rv64_instr_width_gp
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
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
  , input                                chk_poison_ex_i
  , input                                chk_poison_isd_i
   
  , output [calc_status_width_lp-1:0]    calc_status_o
   
  // MMU interface   
  , output [mmu_cmd_width_lp-1:0]        mmu_cmd_o
  , output                               mmu_cmd_v_o
  , input                                mmu_cmd_ready_i
   
  , input [mmu_resp_width_lp-1:0]        mmu_resp_i
  , input                                mmu_resp_v_i
  , output                               mmu_resp_ready_o

  // Commit tracer
  , output [pipe_stage_reg_width_lp-1:0] cmt_trace_stage_reg_o
  , output [calc_result_width_lp-1:0]    cmt_trace_result_o
  , output [exception_width_lp-1:0]      cmt_trace_exc_o

  // STD: TODO -- remove synth hack and find real solution
  ,output [`bp_be_fu_op_width-1:0] decoded_fu_op_o
  );

// Declare parameterizable structs
`declare_bp_be_mmu_structs(vaddr_width_p, lce_sets_p, cce_block_size_in_bytes_p)
`declare_bp_common_proc_cfg_s(core_els_p, num_lce_p)
`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   );

// Cast input and output ports 
bp_be_issue_pkt_s   issue_pkt;
bp_be_calc_status_s calc_status;
bp_be_mmu_cmd_s     mmu_cmd;
bp_be_mmu_resp_s    mmu_resp;
bp_proc_cfg_s       proc_cfg;

assign issue_pkt     = issue_pkt_i;
assign calc_status_o = calc_status;
assign mmu_cmd_o     = mmu_cmd;
assign mmu_resp      = mmu_resp_i;
assign proc_cfg      = proc_cfg_i;

// Declare intermediate signals
bp_be_issue_pkt_s       issue_pkt_r;
logic                   issue_pkt_v_r;
bp_be_pipe_stage_reg_s  dispatch_pkt;
bp_be_decode_s          decoded;

// Register bypass network
logic [reg_data_width_lp-1:0] irf_rs1    , irf_rs2;
logic [reg_data_width_lp-1:0] frf_rs1    , frf_rs2;
logic [reg_data_width_lp-1:0] bypass_irs1, bypass_irs2;
logic [reg_data_width_lp-1:0] bypass_frs1, bypass_frs2;
logic [reg_data_width_lp-1:0] bypass_rs1 , bypass_rs2;

// Exception signals
logic illegal_instr_isd, cache_miss_mem3;

// Pipeline stage registers
bp_be_pipe_stage_reg_s [pipe_stage_els_lp-1:0] calc_stage_r, calc_stage_n;
bp_be_calc_result_s    [pipe_stage_els_lp-1:0] comp_stage_r, comp_stage_n;
bp_be_exception_s      [pipe_stage_els_lp-1:0]  exc_stage_r , exc_stage_n;

bp_be_calc_result_s nop_calc_result;
bp_be_calc_result_s int_calc_result; 
bp_be_calc_result_s mul_calc_result; 
bp_be_calc_result_s mem_calc_result; 
bp_be_calc_result_s fp_calc_result;

// Forwarding information
logic [pipe_stage_els_lp-1:1]                        comp_stage_n_slice_iwb_v;
logic [pipe_stage_els_lp-1:1]                        comp_stage_n_slice_fwb_v;
logic [pipe_stage_els_lp-1:1][reg_addr_width_lp-1:0] comp_stage_n_slice_rd_addr;
logic [pipe_stage_els_lp-1:1][reg_data_width_lp-1:0] comp_stage_n_slice_rd;

// STD: TODO -- remove synth hack and find real solution
assign decoded_fu_op_o = decoded.fu_op;

// Handshakes
assign issue_pkt_ready_o = (chk_dispatch_v_i | ~issue_pkt_v_r) & ~chk_roll_i & ~chk_poison_isd_i;

// Module instantiations
// Register files
bp_be_regfile
 int_regfile
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.issue_v_i(issue_pkt_v_i)
   ,.dispatch_v_i(chk_dispatch_v_i)

   ,.rd_w_v_i(calc_stage_r[int_commit_point_lp].decode.irf_w_v 
              & ~(|exc_stage_r[int_commit_point_lp])
              )
   ,.rd_addr_i(calc_stage_r[int_commit_point_lp].decode.rd_addr)
   ,.rd_data_i(comp_stage_r[int_commit_point_lp].result)

   ,.rs1_r_v_i(issue_pkt.irs1_v)
   ,.rs1_addr_i(issue_pkt.rs1_addr)
   ,.rs1_data_o(irf_rs1)

   ,.rs2_r_v_i(issue_pkt.irs2_v)
   ,.rs2_addr_i(issue_pkt.rs2_addr)
   ,.rs2_data_o(irf_rs2)
   );

bp_be_regfile
 float_regfile
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.issue_v_i(issue_pkt_v_i)
   ,.dispatch_v_i(chk_dispatch_v_i)

   ,.rd_w_v_i(calc_stage_r[fp_commit_point_lp].decode.frf_w_v 
              & ~(|exc_stage_r[fp_commit_point_lp])
              )
   ,.rd_addr_i(calc_stage_r[fp_commit_point_lp].decode.rd_addr)
   ,.rd_data_i(comp_stage_r[fp_commit_point_lp].result)

   ,.rs1_r_v_i(issue_pkt.frs1_v)
   ,.rs1_addr_i(issue_pkt.rs1_addr)
   ,.rs1_data_o(frf_rs1)

   ,.rs2_r_v_i(issue_pkt.frs2_v)
   ,.rs2_addr_i(issue_pkt.rs2_addr)
   ,.rs2_data_o(frf_rs2)
   );

// Issued instruction registere
bsg_dff_reset_en 
 #(.width_p(issue_pkt_width_lp)
   ) 
 issue_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i | chk_roll_i)
   ,.en_i(issue_pkt_v_i | chk_dispatch_v_i)

   ,.data_i(issue_pkt)
   ,.data_o(issue_pkt_r)
   );

bsg_dff_reset_en 
 #(.width_p(1)
   ) 
 issue_v_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i | chk_roll_i)
   ,.en_i(issue_pkt_v_i | chk_dispatch_v_i)

   ,.data_i(issue_pkt_v_i)
   ,.data_o(issue_pkt_v_r)
   );

// Decode the dispatched instruction
bp_be_instr_decoder
 instr_decoder
  (.fe_nop_v_i(~issue_pkt_v_r)
   ,.be_nop_v_i(~chk_dispatch_v_i &  mmu_cmd_ready_i)
   ,.me_nop_v_i(~chk_dispatch_v_i & ~mmu_cmd_ready_i)
   ,.instr_i(issue_pkt_r.instr)

   ,.decode_o(decoded)
   ,.illegal_instr_o(illegal_instr_isd)
   );

// Bypass the instruction operands from written registers in the stack
bp_be_bypass 
 // Don't need to forward isd data
 #(.fwd_els_p(pipe_stage_els_lp-1)
   ) 
 int_bypass 
  (.id_rs1_v_i(issue_pkt_r.irs1_v)
   ,.id_rs1_addr_i(decoded.rs1_addr)
   ,.id_rs1_i(irf_rs1)

   ,.id_rs2_v_i(issue_pkt_r.irs2_v)
   ,.id_rs2_addr_i(decoded.rs2_addr)
   ,.id_rs2_i(irf_rs2)

   ,.fwd_rd_v_i(comp_stage_n_slice_iwb_v)
   ,.fwd_rd_addr_i(comp_stage_n_slice_rd_addr)
   ,.fwd_rd_i(comp_stage_n_slice_rd)

   ,.bypass_rs1_o(bypass_irs1)
   ,.bypass_rs2_o(bypass_irs2)
   );

bp_be_bypass 
 // Don't need to forward isd data
 #(.fwd_els_p(pipe_stage_els_lp-1)
   ) 
 fp_bypass
  (.id_rs1_v_i(issue_pkt_r.frs1_v)
   ,.id_rs1_addr_i(decoded.rs1_addr)
   ,.id_rs1_i(frf_rs1)

   ,.id_rs2_v_i(issue_pkt_r.frs2_v)
   ,.id_rs2_addr_i(decoded.rs2_addr)
   ,.id_rs2_i(frf_rs2)

   ,.fwd_rd_v_i(comp_stage_n_slice_fwb_v)
   ,.fwd_rd_addr_i(comp_stage_n_slice_rd_addr)
   ,.fwd_rd_i(comp_stage_n_slice_rd)

   ,.bypass_rs1_o(bypass_frs1)
   ,.bypass_rs2_o(bypass_frs2)
   );

bsg_mux 
 #(.width_p(reg_data_width_lp)
   ,.els_p(2)
   ) 
 bypass_xrs1_mux
  (.data_i({bypass_frs1, bypass_irs1})
   ,.sel_i(decoded.fp_not_int_v)
   ,.data_o(bypass_rs1)
   );

bsg_mux 
 #(.width_p(reg_data_width_lp)
   ,.els_p(2)
   ) 
 bypass_xrs2_mux
  (.data_i({bypass_frs2, bypass_irs2})
   ,.sel_i(decoded.fp_not_int_v)
   ,.data_o(bypass_rs2)
   );

// Computation pipelines
// Integer pipe: 1 cycle latency
bp_be_pipe_int 
 #(.core_els_p(core_els_p)
   )
 pipe_int
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
      
   ,.decode_i(calc_stage_r[dispatch_point_lp].decode)
   ,.pc_i(calc_stage_r[dispatch_point_lp].instr_metadata.pc)
   ,.rs1_i(calc_stage_r[dispatch_point_lp].instr_operands.rs1)
   ,.rs2_i(calc_stage_r[dispatch_point_lp].instr_operands.rs2)
   ,.imm_i(calc_stage_r[dispatch_point_lp].instr_operands.imm)
   ,.exc_i(exc_stage_r[dispatch_point_lp])

   ,.mhartid_i(proc_cfg.mhartid)

   ,.result_o(int_calc_result.result)
   ,.br_tgt_o(int_calc_result.br_tgt)
   );

// Multiplication pipe: 2 cycle latency
bp_be_pipe_mul
 pipe_mul
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.decode_i(calc_stage_r[dispatch_point_lp].decode)
   ,.rs1_i(calc_stage_r[dispatch_point_lp].instr_operands.rs1)
   ,.rs2_i(calc_stage_r[dispatch_point_lp].instr_operands.rs2)
   ,.exc_i(exc_stage_r[dispatch_point_lp])

   ,.result_o(mul_calc_result.result)
   );

// Memory pipe: 3 cycle latency
bp_be_pipe_mem
 #(.vaddr_width_p(vaddr_width_p)
   )
 pipe_mem
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.decode_i(calc_stage_r[dispatch_point_lp].decode)
   ,.rs1_i(calc_stage_r[dispatch_point_lp].instr_operands.rs1)
   ,.rs2_i(calc_stage_r[dispatch_point_lp].instr_operands.rs2)
   ,.imm_i(calc_stage_r[dispatch_point_lp].instr_operands.imm)
   ,.exc_i(exc_stage_r[dispatch_point_lp])

   ,.mmu_cmd_o(mmu_cmd)
   ,.mmu_cmd_v_o(mmu_cmd_v_o)
   ,.mmu_cmd_ready_i(mmu_cmd_ready_i)

   ,.mmu_resp_i(mmu_resp_i)
   ,.mmu_resp_v_i(mmu_resp_v_i)
   ,.mmu_resp_ready_o(mmu_resp_ready_o)

   ,.result_o(mem_calc_result.result)
   ,.cache_miss_o(cache_miss_mem3)
   );

// Floating point pipe: 4 cycle latency
bp_be_pipe_fp 
 pipe_fp
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.decode_i(calc_stage_r[dispatch_point_lp].decode)
   ,.rs1_i(calc_stage_r[dispatch_point_lp].instr_operands.rs1)
   ,.rs2_i(calc_stage_r[dispatch_point_lp].instr_operands.rs2)
   ,.exc_i(exc_stage_r[dispatch_point_lp])

   ,.result_o(fp_calc_result.result)
   );

// Execution pipelines
// Shift in dispatch pkt and move everything else down the pipe
bsg_dff 
 #(.width_p(pipe_stage_reg_width_lp*pipe_stage_els_lp)
   ) 
 calc_stage_reg
  (.clk_i(clk_i)
   ,.data_i({calc_stage_r[0+:pipe_stage_els_lp-1], dispatch_pkt})
   ,.data_o(calc_stage_r)
   );

// Completion pipeline
// If a pipeline has completed an instruction (pipe_xxx_v), then mux in the calculated result.
// Else, mux in the previous stage of the completion pipe. Since we are single issue and have
//   static latencies, we cannot have two pipelines complete at the same time.
bsg_mux_segmented 
 #(.segments_p(pipe_stage_els_lp)
   ,.segment_width_p(calc_result_width_lp)
   ) 
 comp_stage_mux
  (.data0_i({comp_stage_r[0+:pipe_stage_els_lp-1], calc_result_width_lp'(0)})
   ,.data1_i({fp_calc_result, mem_calc_result, mul_calc_result, int_calc_result, nop_calc_result})
   ,.sel_i({calc_stage_r  [fp_comp_idx_lp].decode.pipe_fp_v 
            , calc_stage_r[mem_comp_idx_lp].decode.pipe_mem_v
            , calc_stage_r[mul_comp_idx_lp].decode.pipe_mul_v
            , calc_stage_r[int_comp_idx_lp].decode.pipe_int_v
            , 1'b1
            })
   ,.data_o(comp_stage_n)
   );

bsg_dff 
 #(.width_p(calc_result_width_lp*pipe_stage_els_lp)
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
   ,.data_i(exc_stage_n)
   ,.data_o(exc_stage_r)
   );

always_comb 
  begin
    // Form dispatch packet
    dispatch_pkt.instr_metadata     = issue_pkt_r.instr_metadata;
    dispatch_pkt.instr              = issue_pkt_r.instr;
    dispatch_pkt.instr_operands.rs1 = bypass_rs1;
    dispatch_pkt.instr_operands.rs2 = bypass_rs2;
    dispatch_pkt.instr_operands.imm = issue_pkt_r.imm;
    dispatch_pkt.decode             = decoded;

    // Calculator status ISD stage
    calc_status.isd_v                    = issue_pkt_v_r;
    calc_status.isd_pc                   = issue_pkt_r.instr_metadata.pc;
    calc_status.isd_irs1_v               = issue_pkt_r.irs1_v;
    calc_status.isd_frs1_v               = issue_pkt_r.frs1_v;
    calc_status.isd_rs1_addr             = issue_pkt_r.rs1_addr;
    calc_status.isd_irs2_v               = issue_pkt_r.irs2_v;
    calc_status.isd_frs2_v               = issue_pkt_r.frs2_v;
    calc_status.isd_rs2_addr             = issue_pkt_r.rs2_addr;

    // Calculator status EX1 information
    calc_status.int1_v                   = calc_stage_r[0].decode.pipe_int_v 
                                           & ~|exc_stage_r[0];
    calc_status.int1_br_tgt              = int_calc_result.br_tgt;
    calc_status.int1_branch_metadata_fwd = calc_stage_r[0].instr_metadata.branch_metadata_fwd;
    calc_status.int1_btaken              = (calc_stage_r[0].decode.br_v & int_calc_result.result[0])
                                           | calc_stage_r[0].decode.jmp_v;
    calc_status.int1_br_or_jmp           = calc_stage_r[0].decode.br_v 
                                           | calc_stage_r[0].decode.jmp_v;
    calc_status.ex1_v                    = calc_stage_r[0].decode.instr_v
                                           & ~|exc_stage_r[0];

    // Dependency information for pipelines
    for (integer i = 0; i < pipe_stage_els_lp; i++) 
      begin : dep_status
        calc_status.dep_status[i].int_iwb_v = calc_stage_r[i].decode.pipe_int_v 
                                              & ~|exc_stage_r[i] 
                                              & calc_stage_r[i].decode.irf_w_v;
        calc_status.dep_status[i].mul_iwb_v = calc_stage_r[i].decode.pipe_mul_v 
                                              & ~|exc_stage_r[i] 
                                              & calc_stage_r[i].decode.irf_w_v;
        calc_status.dep_status[i].mem_iwb_v = calc_stage_r[i].decode.pipe_mem_v 
                                              & ~|exc_stage_r[i] 
                                              & calc_stage_r[i].decode.irf_w_v;
        calc_status.dep_status[i].mem_fwb_v = calc_stage_r[i].decode.pipe_mem_v 
                                              & ~|exc_stage_r[i] 
                                              & calc_stage_r[i].decode.frf_w_v;
        calc_status.dep_status[i].fp_fwb_v  = calc_stage_r[i].decode.pipe_fp_v  
                                              & ~|exc_stage_r[i] 
                                              & calc_stage_r[i].decode.frf_w_v;
        calc_status.dep_status[i].rd_addr     = calc_stage_r[i].decode.rd_addr;
      end

    // Additional commit point information
    calc_status.mem3_v            = calc_stage_r[2].decode.pipe_mem_v & ~|exc_stage_r[2];
    calc_status.mem3_pc           = calc_stage_r[2].instr_metadata.pc;
    calc_status.mem3_cache_miss_v = cache_miss_mem3
                                    & (calc_stage_r[2].decode.dcache_r_v
                                       | calc_stage_r[2].decode.dcache_w_v
                                       )
                                    & ~|exc_stage_r[2];
    calc_status.mem3_exception_v  = 1'b0; 
    calc_status.mem3_ret_v        = calc_stage_r[2].decode.ret_v;
    calc_status.instr_cmt_v       = calc_stage_r[2].decode.instr_v & ~exc_stage_n[3].roll_v;
          
    // Slicing the completion pipe for Forwarding information
    for (integer i = 1;i < pipe_stage_els_lp; i++) 
      begin : comp_stage_slice
        comp_stage_n_slice_iwb_v[i]   = calc_stage_r[i-1].decode.irf_w_v & ~|exc_stage_r[i-1]; 
        comp_stage_n_slice_fwb_v[i]   = calc_stage_r[i-1].decode.frf_w_v & ~|exc_stage_r[i-1]; 
        comp_stage_n_slice_rd_addr[i] = calc_stage_r[i-1].decode.rd_addr;
        comp_stage_n_slice_rd[i]      = comp_stage_n[i].result;
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
        exc_stage_n[0].poison_v        = chk_poison_isd_i;
        exc_stage_n[0].roll_v          = chk_roll_i;
        exc_stage_n[0].illegal_instr_v = illegal_instr_isd;
        exc_stage_n[1].poison_v        = exc_stage_r[0].poison_v | chk_poison_ex_i;
        exc_stage_n[1].roll_v          = exc_stage_r[0].roll_v   | chk_roll_i;
        exc_stage_n[2].poison_v        = exc_stage_r[1].poison_v | chk_poison_ex_i;
        exc_stage_n[2].roll_v          = exc_stage_r[1].roll_v   | chk_roll_i;
        exc_stage_n[3].cache_miss_v    = cache_miss_mem3;
        exc_stage_n[3].roll_v          = exc_stage_r[2].roll_v   | chk_roll_i;
  end

// Commit tracer
assign cmt_trace_stage_reg_o = calc_stage_r[pipe_stage_els_lp-1];
assign cmt_trace_result_o    = comp_stage_r[pipe_stage_els_lp-1];
assign cmt_trace_exc_o       = exc_stage_r[pipe_stage_els_lp-1];

endmodule : bp_be_calculator_top
