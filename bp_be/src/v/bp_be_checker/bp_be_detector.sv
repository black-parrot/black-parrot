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
   `declare_bp_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p, fetch_ptr_p, issue_ptr_p)

   // Generated parameters
   )
  (input                               clk_i
   , input                             reset_i

   // Dependency information
   , input [issue_pkt_width_lp-1:0]    issue_pkt_i
   , input                             cmd_full_i
   , input                             credits_full_i
   , input                             credits_empty_i
   , input                             idiv_busy_i
   , input                             fdiv_busy_i
   , input                             mem_busy_i
   , input                             mem_ordered_i

   // Pipeline control signals from the checker to the calculator
   , output logic                      hazard_v_o
   , output logic                      ordered_v_o
   , input [dispatch_pkt_width_lp-1:0] dispatch_pkt_i
   , input [commit_pkt_width_lp-1:0]   commit_pkt_i

   , input [wb_pkt_width_lp-1:0]       late_wb_pkt_i
   , input                             late_wb_yumi_i

   , output logic                      ispec_v_o
   );

  `declare_bp_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p, fetch_ptr_p, issue_ptr_p);

  `bp_cast_i(bp_be_issue_pkt_s, issue_pkt);
  `bp_cast_i(bp_be_dispatch_pkt_s, dispatch_pkt);
  `bp_cast_i(bp_be_commit_pkt_s, commit_pkt);
  `bp_cast_i(bp_be_wb_pkt_s, late_wb_pkt);

  // Integer data hazards
  logic irs1_sb_raw_haz_v, irs2_sb_raw_haz_v;
  logic ird_sb_waw_haz_v;
  logic [2:0] irs1_data_haz_v , irs2_data_haz_v;
  // Floating point data hazards
  logic frs1_sb_raw_haz_v, frs2_sb_raw_haz_v, frs3_sb_raw_haz_v;
  logic frd_sb_waw_haz_v;
  logic [2:0] frs1_data_haz_v, frs2_data_haz_v, frs3_data_haz_v;
  logic [2:0] rs1_match_vector, rs2_match_vector, rs3_match_vector, rd_match_vector;
  logic score_rs1_match, score_rs2_match, score_rs3_match, score_rd_match;

  bp_be_decode_s decode;
  rv64_instr_s instr;
  assign decode = issue_pkt_cast_i.decode;
  bp_be_dep_status_s [3:0] dep_status_r;

  logic fence_haz_v, cmd_haz_v, fflags_haz_v, iscore_haz_v, fscore_haz_v;
  logic data_haz_v, control_haz_v, struct_haz_v;

  wire [reg_addr_width_gp-1:0] score_rd_li  = commit_pkt_cast_i.instr.t.fmatype.rd_addr;
  wire [reg_addr_width_gp-1:0] check_rs1_li = issue_pkt_cast_i.instr.t.fmatype.rs1_addr;
  wire [reg_addr_width_gp-1:0] check_rs2_li = issue_pkt_cast_i.instr.t.fmatype.rs2_addr;
  wire [reg_addr_width_gp-1:0] check_rs3_li = issue_pkt_cast_i.instr.t.fmatype.rs3_addr;
  wire [reg_addr_width_gp-1:0] check_rd_li  = issue_pkt_cast_i.instr.t.fmatype.rd_addr;

  wire [reg_addr_width_gp-1:0] clear_rd_li = late_wb_pkt_cast_i.rd_addr;

  wire irs1_ispec_v = decode.irs1_r_v & rs1_match_vector[0]
    & decode.pipe_int_v
    & (dep_status_r[0].aux_iwb_v | dep_status_r[0].emem_iwb_v | dep_status_r[0].fint_iwb_v)
    & integer_support_p[e_catchup];

  wire irs2_ispec_v = decode.irs2_r_v & rs2_match_vector[0]
    & decode.pipe_int_v
    & (dep_status_r[0].aux_iwb_v | dep_status_r[0].emem_iwb_v | dep_status_r[0].fint_iwb_v)
    & integer_support_p[e_catchup];

  wire irs2_store_v = decode.irs2_r_v & rs2_match_vector[0]
    & decode.dcache_w_v
    & (dep_status_r[0].aux_iwb_v | dep_status_r[0].emem_iwb_v | dep_status_r[0].fint_iwb_v)
    & integer_support_p[e_catchup];

  assign ispec_v_o = irs1_ispec_v | irs2_ispec_v;

  logic [1:0] irs_match_lo;
  logic       ird_match_lo;
  wire score_int_v_li = commit_pkt_cast_i.iscore_v;
  wire clear_int_v_li = late_wb_pkt_cast_i.ird_w_v & late_wb_yumi_i;
  bp_be_scoreboard
   #(.bp_params_p(bp_params_p), .num_rs_p(2))
   int_scoreboard
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.score_v_i(score_int_v_li)
     ,.score_rd_i(score_rd_li)

     ,.clear_v_i(clear_int_v_li)
     ,.clear_rd_i(clear_rd_li)

     ,.check_rs_i({check_rs2_li, check_rs1_li})
     ,.check_rd_i(check_rd_li)
     ,.rs_match_o(irs_match_lo)
     ,.rd_match_o(ird_match_lo)
     );

  logic [2:0] frs_match_lo;
  logic       frd_match_lo;
  wire score_fp_v_li = commit_pkt_cast_i.fscore_v;
  wire clear_fp_v_li = late_wb_pkt_cast_i.frd_w_v & late_wb_yumi_i;
  bp_be_scoreboard
   #(.bp_params_p(bp_params_p), .num_rs_p(3))
   fp_scoreboard
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.score_v_i(score_fp_v_li)
     ,.score_rd_i(score_rd_li)

     ,.clear_v_i(clear_fp_v_li)
     ,.clear_rd_i(clear_rd_li)

     ,.check_rs_i({check_rs3_li, check_rs2_li, check_rs1_li})
     ,.check_rd_i(check_rd_li)
     ,.rs_match_o(frs_match_lo)
     ,.rd_match_o(frd_match_lo)
     );

  always_comb
    begin
      // Generate matches for rs1, rs2, rs3
      // 3 stages because we only care about ex1, ex2, and iwb dependencies. fwb dependencies
      //   can be handled through forwarding
      for (int i = 0; i < 3; i++)
        begin
          rs1_match_vector[i] = (issue_pkt_cast_i.instr.t.fmatype.rs1_addr == dep_status_r[i].rd_addr);
          rs2_match_vector[i] = (issue_pkt_cast_i.instr.t.fmatype.rs2_addr == dep_status_r[i].rd_addr);
          rs3_match_vector[i] = (issue_pkt_cast_i.instr.t.fmatype.rs3_addr == dep_status_r[i].rd_addr);
          rd_match_vector [i] = (issue_pkt_cast_i.instr.t.fmatype.rd_addr  == dep_status_r[i].rd_addr);
        end
      score_rs1_match = (issue_pkt_cast_i.instr.t.fmatype.rs1_addr == score_rd_li);
      score_rs2_match = (issue_pkt_cast_i.instr.t.fmatype.rs2_addr == score_rd_li);
      score_rs3_match = (issue_pkt_cast_i.instr.t.fmatype.rs3_addr == score_rd_li);
      score_rd_match  = (issue_pkt_cast_i.instr.t.fmatype.rd_addr  == score_rd_li);

      // Detect scoreboard hazards
      irs1_sb_raw_haz_v = (decode.irs1_r_v & irs_match_lo[0]);
      irs2_sb_raw_haz_v = (decode.irs2_r_v & irs_match_lo[1]);
      ird_sb_waw_haz_v  = (decode.irf_w_v  & ird_match_lo);

      frs1_sb_raw_haz_v = (decode.frs1_r_v & frs_match_lo[0]);
      frs2_sb_raw_haz_v = (decode.frs2_r_v & frs_match_lo[1]);
      frs3_sb_raw_haz_v = (decode.frs3_r_v & frs_match_lo[2]);
      frd_sb_waw_haz_v  = (decode.frf_w_v  & frd_match_lo);

      iscore_haz_v       = (decode.irf_w_v & dep_status_r[0].long_iwb_v & rd_match_vector[0])
                           | (decode.irf_w_v & dep_status_r[1].long_iwb_v & rd_match_vector[1])
                           | (decode.irf_w_v & dep_status_r[2].long_iwb_v & rd_match_vector[2]);

      fscore_haz_v       = (decode.frf_w_v & dep_status_r[0].long_fwb_v & rd_match_vector[0])
                           | (decode.frf_w_v & dep_status_r[1].long_fwb_v & rd_match_vector[1])
                           | (decode.frf_w_v & dep_status_r[2].long_fwb_v & rd_match_vector[2]);

      // Detect integer and float data hazards for EX1
      irs1_data_haz_v[0] = (decode.irs1_r_v & rs1_match_vector[0])
                           & (dep_status_r[0].fint_iwb_v | dep_status_r[0].aux_iwb_v | dep_status_r[0].mul_iwb_v | dep_status_r[0].emem_iwb_v | dep_status_r[0].fmem_iwb_v | dep_status_r[0].long_iwb_v)
                           & ~irs1_ispec_v;

      irs2_data_haz_v[0] = (decode.irs2_r_v & rs2_match_vector[0])
                           & (dep_status_r[0].fint_iwb_v | dep_status_r[0].aux_iwb_v | dep_status_r[0].mul_iwb_v | dep_status_r[0].emem_iwb_v | dep_status_r[0].fmem_iwb_v | dep_status_r[0].long_iwb_v)
                           & ~irs2_ispec_v
                           & ~irs2_store_v;

      frs1_data_haz_v[0] = (decode.frs1_r_v & rs1_match_vector[0])
                           & (dep_status_r[0].fint_fwb_v | dep_status_r[0].aux_fwb_v | dep_status_r[0].emem_fwb_v | dep_status_r[0].fmem_fwb_v | dep_status_r[0].fma_fwb_v | dep_status_r[0].long_fwb_v);

      frs2_data_haz_v[0] = (decode.frs2_r_v & rs2_match_vector[0])
                           & (dep_status_r[0].fint_fwb_v | dep_status_r[0].aux_fwb_v | dep_status_r[0].emem_fwb_v | dep_status_r[0].fmem_fwb_v | dep_status_r[0].fma_fwb_v | dep_status_r[0].long_fwb_v);

      frs3_data_haz_v[0] = (decode.frs3_r_v & rs3_match_vector[0])
                           & (dep_status_r[0].fint_fwb_v | dep_status_r[0].aux_fwb_v | dep_status_r[0].emem_fwb_v | dep_status_r[0].fmem_fwb_v | dep_status_r[0].fma_fwb_v | dep_status_r[0].long_fwb_v);

      // Detect integer and float data hazards for EX2
      irs1_data_haz_v[1] = (decode.irs1_r_v & rs1_match_vector[1])
                           & (dep_status_r[1].fmem_iwb_v | dep_status_r[1].mul_iwb_v | dep_status_r[1].long_iwb_v);

      irs2_data_haz_v[1] = (decode.irs2_r_v & rs2_match_vector[1])
                           & (dep_status_r[1].fmem_iwb_v | dep_status_r[1].mul_iwb_v | dep_status_r[1].long_iwb_v);

      frs1_data_haz_v[1] = (decode.frs1_r_v & rs1_match_vector[1])
                           & (dep_status_r[1].fmem_fwb_v | dep_status_r[1].fma_fwb_v | dep_status_r[1].long_fwb_v);

      frs2_data_haz_v[1] = (decode.frs2_r_v & rs2_match_vector[1])
                           & (dep_status_r[1].fmem_fwb_v | dep_status_r[1].fma_fwb_v | dep_status_r[1].long_fwb_v);

      frs3_data_haz_v[1] = (decode.frs3_r_v & rs3_match_vector[1])
                           & (dep_status_r[1].fmem_fwb_v | dep_status_r[1].fma_fwb_v | dep_status_r[1].long_fwb_v);

      irs1_data_haz_v[2] = (decode.irs1_r_v & rs1_match_vector[2])
                           & (dep_status_r[2].long_iwb_v);

      irs2_data_haz_v[2] = (decode.irs2_r_v & rs2_match_vector[2])
                           & (dep_status_r[2].long_iwb_v);

      frs1_data_haz_v[2] = (decode.frs1_r_v & rs1_match_vector[2])
                           & (dep_status_r[2].fma_fwb_v | dep_status_r[2].long_fwb_v);

      frs2_data_haz_v[2] = (decode.frs2_r_v & rs2_match_vector[2])
                           & (dep_status_r[2].fma_fwb_v | dep_status_r[2].long_fwb_v);

      frs3_data_haz_v[2] = (decode.frs3_r_v & rs3_match_vector[2])
                           & (dep_status_r[2].fma_fwb_v | dep_status_r[2].long_fwb_v);

      fence_haz_v        = decode.fence_v & ~mem_ordered_i;
      cmd_haz_v          = cmd_full_i;

      fflags_haz_v = (decode.csr_r_v | decode.csr_w_v)
                     & (dep_status_r[0].fflags_v
                        | dep_status_r[1].fflags_v
                        | dep_status_r[2].fflags_v
                        | dep_status_r[3].fflags_v
                        | fdiv_busy_i
                        );

      control_haz_v = fence_haz_v | fflags_haz_v;

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
      struct_haz_v = cmd_haz_v
                     | fscore_haz_v | iscore_haz_v
                     | (mem_busy_i & decode.pipe_mem_early_v)
                     | (mem_busy_i & decode.pipe_mem_final_v)
                     | (fdiv_busy_i & decode.pipe_long_v)
                     | (idiv_busy_i & decode.pipe_long_v);
    end

  assign hazard_v_o = struct_haz_v | control_haz_v | data_haz_v;
  assign ordered_v_o = ~(mem_busy_i | fdiv_busy_i | idiv_busy_i) & mem_ordered_i;

  bp_be_decode_s dep_decode;
  bp_be_dep_status_s dep_status_n;
  assign dep_decode = dispatch_pkt_cast_i.decode;
  always_comb
    begin
      dep_status_n.v           = dispatch_pkt_cast_i.v;
      // nspec == writeback, could reduce to only fflags setting
      dep_status_n.fflags_v    = dispatch_pkt_cast_i.nspec_v | dep_decode.pipe_aux_v | dep_decode.pipe_fma_v;
      dep_status_n.eint_iwb_v  = dep_decode.pipe_int_v       & dep_decode.irf_w_v  & ~ispec_v_o;
      dep_status_n.eint_fwb_v  = dep_decode.pipe_int_v       & dep_decode.frf_w_v;
      dep_status_n.fint_iwb_v  = dep_decode.pipe_int_v       & dep_decode.irf_w_v  &  ispec_v_o;
      dep_status_n.fint_fwb_v  = dep_decode.pipe_int_v       & dep_decode.frf_w_v;
      dep_status_n.aux_iwb_v   = dep_decode.pipe_aux_v       & dep_decode.irf_w_v;
      dep_status_n.aux_fwb_v   = dep_decode.pipe_aux_v       & dep_decode.frf_w_v;
      dep_status_n.emem_iwb_v  = dep_decode.pipe_mem_early_v & dep_decode.irf_w_v;
      dep_status_n.emem_fwb_v  = dep_decode.pipe_mem_early_v & dep_decode.frf_w_v;
      dep_status_n.fmem_iwb_v  = dep_decode.pipe_mem_final_v & dep_decode.irf_w_v;
      dep_status_n.fmem_fwb_v  = dep_decode.pipe_mem_final_v & dep_decode.frf_w_v;
      dep_status_n.mul_iwb_v   = dep_decode.pipe_mul_v       & dep_decode.irf_w_v;
      dep_status_n.mul_fwb_v   = dep_decode.pipe_mul_v       & dep_decode.frf_w_v;
      dep_status_n.fma_iwb_v   = dep_decode.pipe_fma_v       & dep_decode.irf_w_v;
      dep_status_n.fma_fwb_v   = dep_decode.pipe_fma_v       & dep_decode.frf_w_v;
      dep_status_n.long_iwb_v  = dep_decode.pipe_long_v      & dep_decode.irf_w_v;
      dep_status_n.long_fwb_v  = dep_decode.pipe_long_v      & dep_decode.frf_w_v;
      dep_status_n.rd_addr     = dispatch_pkt_cast_i.instr.t.rtype.rd_addr;
    end

  always_ff @(posedge clk_i)
    begin
      dep_status_r[0]   <= dispatch_pkt_cast_i.v ? dep_status_n : '0;
      dep_status_r[3:1] <= dep_status_r[2:0];
    end

endmodule

