/**
 *
 * Name:
 *   bp_be_detector.v
 *
 * Description:
 *
 *
 * Notes:
 *   We should get rid of the magic numbers here and replace with constants based on pipeline
 *     stages. However, like the calculator, this is a high risk change that should be postponed
 */

`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_detector
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   // Generated parameters
   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
   , localparam isd_status_width_lp = `bp_be_isd_status_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam dispatch_pkt_width_lp = `bp_be_dispatch_pkt_width(vaddr_width_p)
   , localparam commit_pkt_width_lp = `bp_be_commit_pkt_width(vaddr_width_p, paddr_width_p)
   , localparam wb_pkt_width_lp     = `bp_be_wb_pkt_width(vaddr_width_p)
   )
  (input                               clk_i
   , input                             reset_i

   , input [cfg_bus_width_lp-1:0]      cfg_bus_i

   // Dependency information
   , input [isd_status_width_lp-1:0]   isd_status_i
   , input                             cmd_full_i
   , input                             credits_full_i
   , input                             credits_empty_i
   , input                             idiv_ready_i
   , input                             fdiv_ready_i
   , input                             mem_ready_i
   , input                             ptw_busy_i
   , input                             irq_pending_i

   // Pipeline control signals from the checker to the calculator
   , output logic                      dispatch_v_o
   , output logic                      interrupt_v_o
   , input [dispatch_pkt_width_lp-1:0] dispatch_pkt_i
   , input [commit_pkt_width_lp-1:0]   commit_pkt_i
   , input [wb_pkt_width_lp-1:0]       iwb_pkt_i
   , input [wb_pkt_width_lp-1:0]       fwb_pkt_i
   );

  `declare_bp_cfg_bus_s(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  `bp_cast_i(bp_cfg_bus_s, cfg_bus);
  `bp_cast_i(bp_be_isd_status_s, isd_status);
  `bp_cast_i(bp_be_dispatch_pkt_s, dispatch_pkt);
  `bp_cast_i(bp_be_commit_pkt_s, commit_pkt);
  `bp_cast_i(bp_be_wb_pkt_s, iwb_pkt);
  `bp_cast_i(bp_be_wb_pkt_s, fwb_pkt);

  // Integer data hazards
  logic irs1_sb_raw_haz_v, irs2_sb_raw_haz_v;
  logic ird_sb_waw_haz_v;
  logic [2:0] irs1_data_haz_v , irs2_data_haz_v;
  // Floating point data hazards
  logic frs1_sb_raw_haz_v, frs2_sb_raw_haz_v, frs3_sb_raw_haz_v;
  logic frd_sb_waw_haz_v;
  logic [2:0] frs1_data_haz_v , frs2_data_haz_v, frs3_data_haz_v;
  logic [2:0] rs1_match_vector, rs2_match_vector, rs3_match_vector;

  bp_be_dep_status_s [3:0] dep_status_r;

  logic fence_haz_v, cmd_haz_v, fflags_haz_v, csr_haz_v;
  logic data_haz_v, control_haz_v, struct_haz_v;
  logic long_haz_v;
  logic mem_in_pipe_v;

  wire [reg_addr_width_gp-1:0] score_rd_li  = commit_pkt_cast_i.dcache_miss
    ? commit_pkt_cast_i.instr.t.fmatype.rd_addr
    : dispatch_pkt_cast_i.instr.t.fmatype.rd_addr;
  wire [reg_addr_width_gp-1:0] score_rs1_li = dispatch_pkt_cast_i.instr.t.fmatype.rs1_addr;
  wire [reg_addr_width_gp-1:0] score_rs2_li = dispatch_pkt_cast_i.instr.t.fmatype.rs2_addr;
  wire [reg_addr_width_gp-1:0] score_rs3_li = dispatch_pkt_cast_i.instr.t.fmatype.rs3_addr;
  wire [reg_addr_width_gp-1:0] clear_ird_li = iwb_pkt_cast_i.rd_addr;
  wire [reg_addr_width_gp-1:0] clear_frd_li = fwb_pkt_cast_i.rd_addr;

  logic [1:0] irs_match_lo;
  logic       ird_match_lo;
  wire score_int_v_li = (dispatch_pkt_cast_i.v & dispatch_pkt_cast_i.decode.late_iwb_v)
    || (commit_pkt_cast_i.dcache_miss & commit_pkt_cast_i.instr.t.fmatype.opcode inside {`RV64_LOAD_OP, `RV64_AMO_OP});
  wire clear_int_v_li = iwb_pkt_cast_i.ird_w_v & iwb_pkt_cast_i.late;
  bp_be_scoreboard
   #(.bp_params_p(bp_params_p), .num_rs_p(2))
   int_scoreboard
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.score_v_i(score_int_v_li)
     ,.score_rd_i(score_rd_li)

     ,.clear_v_i(clear_int_v_li)
     ,.clear_rd_i(clear_ird_li)

     ,.rs_i({score_rs2_li, score_rs1_li})
     ,.rd_i(score_rd_li)
     ,.rs_match_o(irs_match_lo)
     ,.rd_match_o(ird_match_lo)
     );

  logic [2:0] frs_match_lo;
  logic       frd_match_lo;
  wire score_fp_v_li = (dispatch_pkt_cast_i.v & dispatch_pkt_cast_i.decode.late_fwb_v)
    || (commit_pkt_cast_i.dcache_miss & commit_pkt_cast_i.instr.t.fmatype.opcode == `RV64_FLOAD_OP);
  wire clear_fp_v_li = fwb_pkt_cast_i.frd_w_v & fwb_pkt_cast_i.late;
  bp_be_scoreboard
   #(.bp_params_p(bp_params_p), .num_rs_p(3))
   fp_scoreboard
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.score_v_i(score_fp_v_li)
     ,.score_rd_i(score_rd_li)

     ,.clear_v_i(clear_fp_v_li)
     ,.clear_rd_i(clear_frd_li)

     ,.rs_i({score_rs3_li, score_rs2_li, score_rs1_li})
     ,.rd_i(score_rd_li)
     ,.rs_match_o(frs_match_lo)
     ,.rd_match_o(frd_match_lo)
     );

  always_comb
    begin
      // Generate matches for rs1, rs2. rs3
      // 3 stages because we only care about ex1, ex2, and iwb dependencies. fwb dependencies
      //   can be handled through forwarding
      for (integer i = 0; i < 3; i++)
        begin
          rs1_match_vector[i] = (isd_status_cast_i.rs1_addr == dep_status_r[i].rd_addr);
          rs2_match_vector[i] = (isd_status_cast_i.rs2_addr == dep_status_r[i].rd_addr);
          rs3_match_vector[i] = (isd_status_cast_i.rs3_addr == dep_status_r[i].rd_addr);
        end

      // Detect scoreboard hazards
      irs1_sb_raw_haz_v = (isd_status_cast_i.irs1_v & irs_match_lo[0]) & (isd_status_cast_i.rs1_addr != '0);
      irs2_sb_raw_haz_v = (isd_status_cast_i.irs2_v & irs_match_lo[1]) & (isd_status_cast_i.rs2_addr != '0);
      ird_sb_waw_haz_v = (isd_status_cast_i.iwb_v & ird_match_lo) & (isd_status_cast_i.rd_addr != '0);

      frs1_sb_raw_haz_v = (isd_status_cast_i.frs1_v & frs_match_lo[0]);
      frs2_sb_raw_haz_v = (isd_status_cast_i.frs2_v & frs_match_lo[1]);
      frs3_sb_raw_haz_v = (isd_status_cast_i.frs3_v & frs_match_lo[2]);

      frd_sb_waw_haz_v = (isd_status_cast_i.fwb_v & frd_match_lo);

      // Detect integer and float data hazards for EX1
      irs1_data_haz_v[0] = (isd_status_cast_i.irs1_v & rs1_match_vector[0])
                           & (isd_status_cast_i.rs1_addr != '0)
                           & (dep_status_r[0].aux_iwb_v | dep_status_r[0].mul_iwb_v | dep_status_r[0].emem_iwb_v | dep_status_r[0].fmem_iwb_v);

      irs2_data_haz_v[0] = (isd_status_cast_i.irs2_v & rs2_match_vector[0])
                           & (isd_status_cast_i.rs2_addr != '0)
                           & (dep_status_r[0].aux_iwb_v | dep_status_r[0].mul_iwb_v | dep_status_r[0].emem_iwb_v | dep_status_r[0].fmem_iwb_v);

      frs1_data_haz_v[0] = (isd_status_cast_i.frs1_v & rs1_match_vector[0])
                           & (dep_status_r[0].aux_fwb_v | dep_status_r[0].emem_fwb_v | dep_status_r[0].fmem_fwb_v | dep_status_r[0].fma_fwb_v);

      frs2_data_haz_v[0] = (isd_status_cast_i.frs2_v & rs2_match_vector[0])
                           & (dep_status_r[0].aux_fwb_v | dep_status_r[0].emem_fwb_v | dep_status_r[0].fmem_fwb_v | dep_status_r[0].fma_fwb_v);

      frs3_data_haz_v[0] = (isd_status_cast_i.frs3_v & rs3_match_vector[0])
                           & (dep_status_r[0].aux_fwb_v | dep_status_r[0].emem_fwb_v | dep_status_r[0].fmem_fwb_v | dep_status_r[0].fma_fwb_v);

      // Detect integer and float data hazards for EX2
      irs1_data_haz_v[1] = (isd_status_cast_i.irs1_v & rs1_match_vector[1])
                           & (isd_status_cast_i.rs1_addr != '0)
                           & (dep_status_r[1].fmem_iwb_v | dep_status_r[1].mul_iwb_v);

      irs2_data_haz_v[1] = (isd_status_cast_i.irs2_v & rs2_match_vector[1])
                           & (isd_status_cast_i.rs2_addr != '0)
                           & (dep_status_r[1].fmem_iwb_v | dep_status_r[1].mul_iwb_v);

      frs1_data_haz_v[1] = (isd_status_cast_i.frs1_v & rs1_match_vector[1])
                           & (dep_status_r[1].fmem_fwb_v | dep_status_r[1].fma_fwb_v);

      frs2_data_haz_v[1] = (isd_status_cast_i.frs2_v & rs2_match_vector[1])
                           & (dep_status_r[1].fmem_fwb_v | dep_status_r[1].fma_fwb_v);

      frs3_data_haz_v[1] = (isd_status_cast_i.frs3_v & rs3_match_vector[1])
                           & (dep_status_r[1].fmem_fwb_v | dep_status_r[1].fma_fwb_v);

      irs1_data_haz_v[2] = '0;

      irs2_data_haz_v[2] = '0;

      frs1_data_haz_v[2] = (isd_status_cast_i.frs1_v & rs1_match_vector[2])
                           & (dep_status_r[2].fma_fwb_v);

      frs2_data_haz_v[2] = (isd_status_cast_i.frs2_v & rs2_match_vector[2])
                           & (dep_status_r[2].fma_fwb_v);

      frs3_data_haz_v[2] = (isd_status_cast_i.frs3_v & rs3_match_vector[2])
                           & (dep_status_r[2].fma_fwb_v);

      mem_in_pipe_v      = dep_status_r[0].mem_v | dep_status_r[1].mem_v | dep_status_r[2].mem_v;
      fence_haz_v        = (isd_status_cast_i.fence_v & (~credits_empty_i | mem_in_pipe_v | ~mem_ready_i))
                           | (isd_status_cast_i.mem_v & credits_full_i);
      cmd_haz_v          = cmd_full_i;

      // TODO: Pessimistic, could have a separate fflags r/w_v
      fflags_haz_v = isd_status_cast_i.csr_v
                     & ((dep_status_r[0].fflags_w_v)
                        | (dep_status_r[1].fflags_w_v)
                        | (dep_status_r[2].fflags_w_v)
                        | (dep_status_r[3].fflags_w_v)
                        | ~fdiv_ready_i
                        );

      // TODO: This is pessimistic. Could instead flush currently
      //   executing instructions on trap, and only pause on dependency in
      //   EX4, rather than any instruction. Most likely not a huge
      //   performance problem at the moment.
      long_haz_v = isd_status_cast_i.long_v
                   & ((dep_status_r[0].instr_v)
                      | (dep_status_r[1].instr_v)
                      | (dep_status_r[2].instr_v)
                      );

      csr_haz_v     = isd_status_cast_i.csr_v
                      & ((dep_status_r[0].instr_v)
                         | (dep_status_r[1].instr_v)
                         | (dep_status_r[2].instr_v)
                         );

      control_haz_v = fence_haz_v | csr_haz_v | fflags_haz_v | long_haz_v;

      // Combine all data hazard information
      // TODO: Parameterize away floating point data hazards without hardware support
      data_haz_v = (|irs1_data_haz_v)
                   | (|irs2_data_haz_v)
                   | (|frs1_data_haz_v)
                   | (|frs2_data_haz_v)
                   | (|frs3_data_haz_v)
                   | (irs1_sb_raw_haz_v | irs2_sb_raw_haz_v | ird_sb_waw_haz_v)
                   | (frs1_sb_raw_haz_v | frs2_sb_raw_haz_v | frs3_sb_raw_haz_v | frd_sb_waw_haz_v);

      // Combine all structural hazard information
      struct_haz_v = cfg_bus_cast_i.freeze
                     | ptw_busy_i
                     | (~mem_ready_i & isd_status_cast_i.mem_v)
                     | (~fdiv_ready_i & isd_status_cast_i.long_v)
                     | (~idiv_ready_i & isd_status_cast_i.long_v)
                     | cmd_haz_v;
    end

  // Generate calculator control signals
  assign dispatch_v_o  = ~(control_haz_v | data_haz_v | struct_haz_v);
  assign interrupt_v_o = irq_pending_i & ~ptw_busy_i & ~cfg_bus_cast_i.freeze;

  bp_be_dep_status_s dep_status_n;
  always_comb
    begin
      dep_status_n.instr_v    = dispatch_pkt_cast_i.v;
      dep_status_n.mem_v      = dispatch_pkt_cast_i.decode.mem_v;
      dep_status_n.csr_v      = (dispatch_pkt_cast_i.decode.csr_w_v | dispatch_pkt_cast_i.decode.csr_r_v);
      dep_status_n.fflags_w_v = dispatch_pkt_cast_i.decode.fflags_w_v;
      dep_status_n.ctl_iwb_v  = dispatch_pkt_cast_i.decode.pipe_ctl_v & dispatch_pkt_cast_i.decode.irf_w_v;
      dep_status_n.int_iwb_v  = dispatch_pkt_cast_i.decode.pipe_int_v & dispatch_pkt_cast_i.decode.irf_w_v;
      dep_status_n.int_fwb_v  = dispatch_pkt_cast_i.decode.pipe_int_v & dispatch_pkt_cast_i.decode.frf_w_v;
      dep_status_n.aux_iwb_v  = dispatch_pkt_cast_i.decode.pipe_aux_v & dispatch_pkt_cast_i.decode.irf_w_v;
      dep_status_n.aux_fwb_v  = dispatch_pkt_cast_i.decode.pipe_aux_v & dispatch_pkt_cast_i.decode.frf_w_v;
      dep_status_n.emem_iwb_v = dispatch_pkt_cast_i.decode.pipe_mem_early_v & dispatch_pkt_cast_i.decode.irf_w_v;
      dep_status_n.emem_fwb_v = dispatch_pkt_cast_i.decode.pipe_mem_early_v & dispatch_pkt_cast_i.decode.frf_w_v;
      dep_status_n.fmem_iwb_v = dispatch_pkt_cast_i.decode.pipe_mem_final_v & dispatch_pkt_cast_i.decode.irf_w_v;
      dep_status_n.fmem_fwb_v = dispatch_pkt_cast_i.decode.pipe_mem_final_v & dispatch_pkt_cast_i.decode.frf_w_v;
      dep_status_n.mul_iwb_v  = dispatch_pkt_cast_i.decode.pipe_mul_v & dispatch_pkt_cast_i.decode.irf_w_v;
      dep_status_n.fma_fwb_v  = dispatch_pkt_cast_i.decode.pipe_fma_v & dispatch_pkt_cast_i.decode.frf_w_v;
      dep_status_n.rd_addr    = dispatch_pkt_cast_i.instr.t.rtype.rd_addr;
    end

  always_ff @(posedge clk_i)
    begin
      dep_status_r[0]   <= dispatch_pkt_cast_i.v ? dep_status_n : '0;
      dep_status_r[3:1] <= dep_status_r[2:0];
    end

endmodule

