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
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_fe_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
    `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

   // Default parameters
   , parameter fp_en_p                  = 0

   // Generated parameters
   , localparam cfg_bus_width_lp       = `bp_cfg_bus_width(vaddr_width_p, num_core_p, num_cce_p, num_lce_p, cce_pc_width_p, cce_instr_width_p)
   , localparam calc_status_width_lp    = `bp_be_calc_status_width(vaddr_width_p)
   , localparam exception_width_lp      = `bp_be_exception_width
   , localparam mmu_cmd_width_lp        = `bp_be_mmu_cmd_width(vaddr_width_p)
   , localparam csr_cmd_width_lp        = `bp_be_csr_cmd_width
   , localparam mem_resp_width_lp       = `bp_be_mem_resp_width(vaddr_width_p)
   , localparam dispatch_pkt_width_lp   = `bp_be_dispatch_pkt_width(vaddr_width_p)
   , localparam pipe_stage_reg_width_lp = `bp_be_pipe_stage_reg_width(vaddr_width_p)
   , localparam commit_pkt_width_lp     = `bp_be_commit_pkt_width(vaddr_width_p)
   , localparam wb_pkt_width_lp         = `bp_be_wb_pkt_width(vaddr_width_p)

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
 (input                                 clk_i
  , input                               reset_i
   
  // Calculator - Checker interface   
  , input [dispatch_pkt_width_lp-1:0]   dispatch_pkt_i
   
  , input                               flush_i
   
  , output [calc_status_width_lp-1:0]   calc_status_o
   
  // Mem interface   
  , output [mmu_cmd_width_lp-1:0]       mmu_cmd_o
  , output                              mmu_cmd_v_o
  , input                               mmu_cmd_ready_i
   
  , output [csr_cmd_width_lp-1:0]       csr_cmd_o
  , output                              csr_cmd_v_o
  , input                               csr_cmd_ready_i

  , input [mem_resp_width_lp-1:0]       mem_resp_i
  , input                               mem_resp_v_i
  , output                              mem_resp_ready_o

  , output [commit_pkt_width_lp-1:0]    commit_pkt_o
  , output [wb_pkt_width_lp-1:0]        wb_pkt_o
  );

// Declare parameterizable structs
`declare_bp_be_mmu_structs(vaddr_width_p, ppn_width_p, lce_sets_p, cce_block_width_p / 8)
`declare_bp_cfg_bus_s(vaddr_width_p, num_core_p, num_cce_p, num_lce_p, cce_pc_width_p, cce_instr_width_p);
`declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

// Cast input and output ports 
bp_be_dispatch_pkt_s   dispatch_pkt;
bp_be_calc_status_s    calc_status;
bp_be_mem_resp_s       mem_resp;
bp_cfg_bus_s          cfg_bus;
bp_be_wb_pkt_s         wb_pkt;
bp_be_commit_pkt_s     commit_pkt;

assign dispatch_pkt = dispatch_pkt_i;
assign mem_resp = mem_resp_i;
assign calc_status_o = calc_status;
assign wb_pkt_o = wb_pkt;
assign commit_pkt_o = commit_pkt;

// Declare intermediate signals

// Register bypass network
logic [dword_width_p-1:0] irf_rs1    , irf_rs2;
logic [dword_width_p-1:0] frf_rs1    , frf_rs2;
logic [dword_width_p-1:0] bypass_irs1, bypass_irs2;
logic [dword_width_p-1:0] bypass_frs1, bypass_frs2;
logic [dword_width_p-1:0] bypass_rs1 , bypass_rs2;

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

if (fp_en_p)
  begin : fp_rf
    bp_be_bypass 
     // Don't need to forward isd data
     #(.fwd_els_p(pipe_stage_els_lp-1))
     fp_bypass
      (.id_rs1_addr_i(dispatch_pkt.instr.fields.rtype.rs1_addr)
       ,.id_rs1_i(frf_rs1)
    
       ,.id_rs2_addr_i(dispatch_pkt.instr.fields.rtype.rs2_addr)
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
       ,.sel_i(dispatch_pkt.frs1_v)
       ,.data_o(bypass_rs1)
       );
    
    bsg_mux 
     #(.width_p(dword_width_p)
       ,.els_p(2)
       ) 
     bypass_xrs2_mux
      (.data_i({bypass_frs2, bypass_irs2})
       ,.sel_i(dispatch_pkt.frs2_v)
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

// Bypass the instruction operands from written registers in the stack
bp_be_bypass 
 // Don't need to forward isd data
 #(.fwd_els_p(pipe_stage_els_lp-1))
 int_bypass 
  (.id_rs1_addr_i(dispatch_pkt.instr.fields.rtype.rs1_addr)
   ,.id_rs1_i(dispatch_pkt.rs1)

   ,.id_rs2_addr_i(dispatch_pkt.instr.fields.rtype.rs2_addr)
   ,.id_rs2_i(dispatch_pkt.rs2)

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
 
   ,.decode_i(reservation_r.decode)
   ,.pc_i(reservation_r.pc)
   ,.rs1_i(reservation_r.rs1)
   ,.rs2_i(reservation_r.rs2)
   ,.imm_i(reservation_r.imm)

   ,.data_o(pipe_int_data_lo)
   
   ,.br_tgt_o(br_tgt_int1)
   );

// Multiplication pipe: 2 cycle latency
bp_be_pipe_mul
 pipe_mul
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.decode_i(reservation_r.decode)
   ,.rs1_i(reservation_r.rs1)
   ,.rs2_i(reservation_r.rs2)

   ,.data_o(pipe_mul_data_lo)
   );

// Memory pipe: 3 cycle latency
bp_be_pipe_mem
 #(.bp_params_p(bp_params_p))
 pipe_mem
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.kill_ex1_i(exc_stage_n[1].poison_v)
   ,.kill_ex2_i(exc_stage_n[2].poison_v)
   ,.kill_ex3_i(exc_stage_r[2].poison_v) 

   ,.decode_i(reservation_r.decode)
   ,.pc_i(reservation_r.pc)
   ,.instr_i(reservation_r.instr)
   ,.rs1_i(reservation_r.rs1)
   ,.rs2_i(reservation_r.rs2)
   ,.imm_i(reservation_r.imm)

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
  
     ,.decode_i(reservation_r.decode)
     ,.rs1_i(reservation_r.rs1)
     ,.rs2_i(reservation_r.rs2)
  
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

bp_be_dispatch_pkt_s reservation_n, reservation_r;
always_comb
  begin
    reservation_n        = dispatch_pkt_i;
    reservation_n.decode = dispatch_pkt.v ? dispatch_pkt.decode : '0;
    reservation_n.rs1    = bypass_rs1;
    reservation_n.rs2    = bypass_rs2;
  end

bsg_dff
 #(.width_p(dispatch_pkt_width_lp))
 reservation_reg
  (.clk_i(clk_i)
   ,.data_i(reservation_n)
   ,.data_o(reservation_r)
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

always_comb 
  begin
    // Strip out elements of the dispatch packet that we want to save for later
    calc_stage_isd.pc             = reservation_n.pc;
    calc_stage_isd.instr          = reservation_n.instr;
    calc_stage_isd.v              = reservation_n.decode.v;
    calc_stage_isd.instr_v        = reservation_n.decode.instr_v;
    calc_stage_isd.pipe_int_v     = reservation_n.decode.pipe_int_v;
    calc_stage_isd.pipe_mul_v     = reservation_n.decode.pipe_mul_v;
    calc_stage_isd.pipe_mem_v     = reservation_n.decode.pipe_mem_v;
    calc_stage_isd.pipe_fp_v      = reservation_n.decode.pipe_fp_v;
    calc_stage_isd.mem_v          = reservation_n.decode.mem_v;
    calc_stage_isd.csr_v          = reservation_n.decode.csr_v;
    calc_stage_isd.irf_w_v        = reservation_n.decode.irf_w_v;
    calc_stage_isd.frf_w_v        = reservation_n.decode.frf_w_v;

    // Calculator status EX1 information
    calc_status.ex1_v                    = reservation_r.decode.v & ~exc_stage_r[0].poison_v;
    calc_status.ex1_npc                  = br_tgt_int1;
    calc_status.ex1_br_or_jmp            = reservation_r.decode.br_v | reservation_r.decode.jmp_v;
    calc_status.ex1_instr_v              = reservation_r.decode.instr_v & ~exc_stage_r[0].poison_v;
    calc_status.mem1_fencei_v            = reservation_r.decode.fencei_v;

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
        // TODO: Fix
        exc_stage_n[0].fe_nop_v        = ~dispatch_pkt.v;
        exc_stage_n[0].be_nop_v        = ~dispatch_pkt.v;
        exc_stage_n[0].me_nop_v        = ~dispatch_pkt.v;

        exc_stage_n[0].roll_v          =                           pipe_mem_miss_v_lo;
        exc_stage_n[1].roll_v          = exc_stage_r[0].roll_v   | pipe_mem_miss_v_lo;
        exc_stage_n[2].roll_v          = exc_stage_r[1].roll_v   | pipe_mem_miss_v_lo;
        exc_stage_n[3].roll_v          = exc_stage_r[2].roll_v   | pipe_mem_miss_v_lo;

        exc_stage_n[0].poison_v        = dispatch_pkt.poison     | flush_i;
        exc_stage_n[1].poison_v        = exc_stage_r[0].poison_v | flush_i;
        exc_stage_n[2].poison_v        = exc_stage_r[1].poison_v | flush_i;
        exc_stage_n[3].poison_v        = exc_stage_r[2].poison_v | flush_i;
  end

assign commit_pkt.v          = calc_stage_r[2].v & ~exc_stage_r[2].roll_v;
assign commit_pkt.instret    = calc_stage_r[2].instr_v & ~exc_stage_n[3].poison_v;
assign commit_pkt.cache_miss = pipe_mem_miss_v_lo & ~exc_stage_r[2].poison_v;
assign commit_pkt.tlb_miss   = 1'b0; // TODO: Add to mem resp
assign commit_pkt.pc         = calc_stage_r[2].pc;
assign commit_pkt.instr      = calc_stage_r[2].instr;

assign wb_pkt.rd_w_v  = calc_stage_r[3].irf_w_v & ~exc_stage_r[3].poison_v;
assign wb_pkt.rd_addr = calc_stage_r[3].instr.fields.rtype.rd_addr;
assign wb_pkt.rd_data = comp_stage_r[3];

endmodule

