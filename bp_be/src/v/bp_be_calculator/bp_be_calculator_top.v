/**
 *
 * Name:
 *   bp_be_calculator_top.v
 * 
 * Description:
 *
 * Parameters:
 *
 * Inputs:
 *
 * Outputs:
 *   
 * Keywords:
 * 
 * Notes:
 * 
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
   
   // Generated parameters
   , localparam proc_cfg_width_lp       = `bp_proc_cfg_width
   , localparam issue_pkt_width_lp      = `bp_be_issue_pkt_width(branch_metadata_fwd_width_p)
   , localparam calc_status_width_lp    = `bp_be_calc_status_width(branch_metadata_fwd_width_p)
   , localparam exception_width_lp      = `bp_be_exception_width
   , localparam mmu_cmd_width_lp        = `bp_be_mmu_cmd_width
   , localparam mmu_resp_width_lp       = `bp_be_mmu_resp_width
   , localparam pipe_stage_reg_width_lp = `bp_be_pipe_stage_reg_width(branch_metadata_fwd_width_p)
   , localparam calc_result_width_lp    = `bp_be_calc_result_width(branch_metadata_fwd_width_p)

   // From BP BE specifications
   , localparam pipe_stage_els_lp = bp_be_pipe_stage_els_gp

   // From RISC-V specifications
   , localparam instr_width_lp    = rv64_instr_width_gp
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   , localparam reg_addr_width_lp = rv64_reg_addr_width_gp
   )
 (input logic                                 clk_i
  , input logic                               reset_i

  // Slow inputs
  , input logic[proc_cfg_width_lp-1:0]        proc_cfg_i

  // Calculator - Checker interface
  , input logic[issue_pkt_width_lp-1:0]       issue_pkt_i
  , input logic                               issue_pkt_v_i
  , output logic                              issue_pkt_rdy_o

  , input logic                               chk_dispatch_v_i

  , input logic                               chk_roll_i
  , input logic                               chk_psn_ex_i
  , input logic                               chk_psn_isd_i
  , output logic[calc_status_width_lp-1:0]    calc_status_o

  // MMU interface
  , output logic[mmu_cmd_width_lp-1:0]        mmu_cmd_o
  , output logic                              mmu_cmd_v_o
  , input logic                               mmu_cmd_rdy_i

  , input logic[mmu_resp_width_lp-1:0]        mmu_resp_i
  , input logic                               mmu_resp_v_i
  , output logic                              mmu_resp_rdy_o

  // Commit tracer
  , output logic[pipe_stage_reg_width_lp-1:0] cmt_trace_stage_reg_o
  , output logic[calc_result_width_lp-1:0]    cmt_trace_result_o
  , output logic[exception_width_lp-1:0]      cmt_trace_exc_o
  );

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

assign issue_pkt     = issue_pkt_i;
assign calc_status_o = calc_status;
assign mmu_cmd_o     = mmu_cmd;
assign mmu_resp      = mmu_resp_i;

// Declare intermediate signals
bp_be_issue_pkt_s        issue_pkt_r;
logic                    issue_pkt_v_r;
bp_be_pipe_stage_reg_s   dispatch_pkt;
bp_be_decode_s           decoded;

logic[reg_data_width_lp-1:0] int1_br_tgt;

// Register bypass network
logic[reg_data_width_lp-1:0] irf_rs1    , irf_rs2;
logic[reg_data_width_lp-1:0] frf_rs1    , frf_rs2;
logic[reg_data_width_lp-1:0] bypass_irs1, bypass_irs2;
logic[reg_data_width_lp-1:0] bypass_frs1, bypass_frs2;
logic[reg_data_width_lp-1:0] bypass_rs1 , bypass_rs2;

// E
logic decode_illegal_instr, mem3_cache_miss;

// Pipeline stage registers
bp_be_pipe_stage_reg_s[pipe_stage_els_lp-1:0] calc_stage_r, calc_stage_n;
bp_be_calc_result_s   [pipe_stage_els_lp-1:0] comp_stage_r, comp_stage_n;
bp_be_exception_s     [pipe_stage_els_lp-1:0]  exc_stage_r , exc_stage_n;

bp_be_calc_result_s nop_calc_result;
bp_be_calc_result_s int_calc_result; 
bp_be_calc_result_s mul_calc_result; 
bp_be_calc_result_s mem_calc_result; 
bp_be_calc_result_s fp_calc_result;

/* TODO: Explain isd :1 */
logic[pipe_stage_els_lp-1:1]                        comp_stage_n_slice_iwb_v;
logic[pipe_stage_els_lp-1:1]                        comp_stage_n_slice_fwb_v;
logic[pipe_stage_els_lp-1:1][reg_addr_width_lp-1:0] comp_stage_n_slice_rd_addr;
logic[pipe_stage_els_lp-1:1][reg_data_width_lp-1:0] comp_stage_n_slice_rd;

bp_proc_cfg_s proc_cfg;

assign proc_cfg = proc_cfg_i;

assign issue_pkt_rdy_o = (chk_dispatch_v_i | ~issue_pkt_v_r) & ~chk_roll_i & ~chk_psn_isd_i;

// Module instantiations
/* TODO: Add write->read forwarding */
bp_be_regfile #(
                ) irf
               (.clk_i(clk_i)
                ,.reset_i(reset_i)

                ,.issue_v_i(issue_pkt_v_i)
                ,.dispatch_v_i(chk_dispatch_v_i)

                ,.rd_w_v_i(calc_stage_r[3].decode.irf_w_v & ~(|exc_stage_r[3]))
                ,.rd_addr_i(calc_stage_r[3].decode.rd_addr)
                ,.rd_data_i(comp_stage_r[3].result)

                ,.rs1_r_v_i(issue_pkt.irs1_v)
                ,.rs1_addr_i(issue_pkt.rs1_addr)
                ,.rs1_data_o(irf_rs1)

                ,.rs2_r_v_i(issue_pkt.irs2_v)
                ,.rs2_addr_i(issue_pkt.rs2_addr)
                ,.rs2_data_o(irf_rs2)
                );

bp_be_regfile #(
                ) frf
               (.clk_i(clk_i)
                ,.reset_i(reset_i)

                ,.issue_v_i(issue_pkt_v_i)
                ,.dispatch_v_i(chk_dispatch_v_i)

                ,.rd_w_v_i(calc_stage_r[4].decode.frf_w_v & ~(|exc_stage_r[4]))
                ,.rd_addr_i(calc_stage_r[4].decode.rd_addr)
                ,.rd_data_i(comp_stage_r[4].result)

                ,.rs1_r_v_i(issue_pkt.frs1_v)
                ,.rs1_addr_i(issue_pkt.rs1_addr)
                ,.rs1_data_o(frf_rs1)

                ,.rs2_r_v_i(issue_pkt.frs2_v)
                ,.rs2_addr_i(issue_pkt.rs2_addr)
                ,.rs2_data_o(frf_rs2)
                );

bsg_dff_reset_en #(.width_p(issue_pkt_width_lp)
                   ) issue_reg
                  (.clk_i(clk_i)
                   ,.reset_i(reset_i | chk_roll_i)
                   ,.en_i(issue_pkt_v_i | chk_dispatch_v_i)

                   ,.data_i(issue_pkt)
                   ,.data_o(issue_pkt_r)
                   );

bsg_dff_reset_en #(.width_p(1)
                   ) issue_v_reg
                  (.clk_i(clk_i)
                   ,.reset_i(reset_i | chk_roll_i)
                   ,.en_i(issue_pkt_v_i | chk_dispatch_v_i)

                   ,.data_i(issue_pkt_v_i)
                   ,.data_o(issue_pkt_v_r)
                   );

bp_be_instr_decoder #(
                      ) instr_decoder
                     (.fe_nop_v_i(~issue_pkt_v_r)
                      ,.be_nop_v_i(~chk_dispatch_v_i &  mmu_cmd_rdy_i)
                      ,.me_nop_v_i(~chk_dispatch_v_i & ~mmu_cmd_rdy_i)
                      ,.instr_i(issue_pkt_r.instr)

                      ,.decode_o(decoded)
                      ,.illegal_instr_o(decode_illegal_instr)
                      );

bp_be_bypass #(.fwd_els_p(pipe_stage_els_lp-1)
                    ) int_bypass 
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

bp_be_bypass #(.fwd_els_p(pipe_stage_els_lp-1)
                    ) fp_bypass
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

bsg_mux #(.width_p(reg_data_width_lp)
          ,.els_p(2)
          ) bypass_xrs1_mux
         (.data_i({bypass_frs1, bypass_irs1})
          ,.sel_i(decoded.fp_not_int_v)
          ,.data_o(bypass_rs1)
          );

bsg_mux #(.width_p(reg_data_width_lp)
          ,.els_p(2)
          ) bypass_xrs2_mux
         (.data_i({bypass_frs2, bypass_irs2})
          ,.sel_i(decoded.fp_not_int_v)
          ,.data_o(bypass_rs2)
          );

bp_be_pipe_int #(
                 ) pipe_int
                (.clk_i(clk_i)
                 ,.reset_i(reset_i)
      
                 ,.decode_i(calc_stage_r[0].decode)
                 ,.pc_i(calc_stage_r[0].instr_metadata.pc)
                 ,.rs1_i(calc_stage_r[0].instr_operands.rs1)
                 ,.rs2_i(calc_stage_r[0].instr_operands.rs2)
                 ,.imm_i(calc_stage_r[0].instr_operands.imm)
                 ,.exc_i(exc_stage_r[0])

                 ,.mhartid_i(proc_cfg.mhartid)

                 ,.result_o(int_calc_result.result)
                 ,.br_tgt_o(int_calc_result.br_tgt)
                 );

bp_be_pipe_mul #(
                 )
        pipe_mul(.clk_i(clk_i)
                 ,.reset_i(reset_i)

                 ,.decode_i(calc_stage_r[0].decode)
                 ,.rs1_i(calc_stage_r[0].instr_operands.rs1)
                 ,.rs2_i(calc_stage_r[0].instr_operands.rs2)
                 ,.exc_i(exc_stage_r[0])

                 ,.result_o(mul_calc_result.result)
                 );

bp_be_pipe_mem #(
                 ) pipe_mem
                (.clk_i(clk_i)
                 ,.reset_i(reset_i)

                 ,.decode_i(calc_stage_r[0].decode)
                 ,.rs1_i(calc_stage_r[0].instr_operands.rs1)
                 ,.rs2_i(calc_stage_r[0].instr_operands.rs2)
                 ,.imm_i(calc_stage_r[0].instr_operands.imm)
                 ,.exc_i(exc_stage_r[0])

                 ,.mmu_cmd_o(mmu_cmd)
                 ,.mmu_cmd_v_o(mmu_cmd_v_o)
                 ,.mmu_cmd_rdy_i(mmu_cmd_rdy_i)

                 ,.mmu_resp_i(mmu_resp_i)
                 ,.mmu_resp_v_i(mmu_resp_v_i)
                 ,.mmu_resp_rdy_o(mmu_resp_rdy_o)

                 ,.result_o(mem_calc_result.result)
                 ,.cache_miss_o(mem3_cache_miss)
                 );

bp_be_pipe_fp #() pipe_fp
               (.clk_i(clk_i)
                ,.reset_i(reset_i)

                ,.decode_i(calc_stage_r[0].decode)
                ,.rs1_i(calc_stage_r[0].instr_operands.rs1)
                ,.rs2_i(calc_stage_r[0].instr_operands.rs2)
                ,.exc_i(exc_stage_r[0])

                ,.result_o(fp_calc_result.result)
               );

    bsg_dff #(.width_p(exception_width_lp*pipe_stage_els_lp)
              ) exc_stage_reg
             (.clk_i(clk_i)
              ,.data_i(exc_stage_n)
              ,.data_o(exc_stage_r)
              );

bsg_mux_segmented #(.segments_p(pipe_stage_els_lp)
                    ,.segment_width_p(calc_result_width_lp)
                    ) comp_stage_mux
                   (.data0_i({comp_stage_r[0+:pipe_stage_els_lp-1]
                              ,calc_result_width_lp'(0)
                              })
                    ,.data1_i({fp_calc_result
                               , mem_calc_result
                               , mul_calc_result
                               , int_calc_result
                               , nop_calc_result
                               })
                    ,.sel_i({calc_stage_r[3].decode.pipe_fp_v 
                             , calc_stage_r[2].decode.pipe_mem_v
                             , calc_stage_r[1].decode.pipe_mul_v
                             , calc_stage_r[0].decode.pipe_int_v
                             , 1'b1
                             })
                    ,.data_o(comp_stage_n)
                    );

bsg_dff #(.width_p(calc_result_width_lp*pipe_stage_els_lp)
          ) comp_stage_reg 
         (.clk_i(clk_i)
          ,.data_i(comp_stage_n)
          ,.data_o(comp_stage_r)
          );

assign calc_stage_n[0] = dispatch_pkt;
assign calc_stage_n[1+:pipe_stage_els_lp-1] = calc_stage_r[0+:pipe_stage_els_lp-1];
bsg_dff #(.width_p(pipe_stage_reg_width_lp*pipe_stage_els_lp)
          ) calc_stage_reg
         (.clk_i(clk_i)
          ,.data_i(calc_stage_n)
          ,.data_o(calc_stage_r)
          );

always_comb begin
    dispatch_pkt.instr_metadata     = issue_pkt_r.instr_metadata;
    dispatch_pkt.instr              = issue_pkt_r.instr;
    dispatch_pkt.instr_operands.rs1 = bypass_rs1;
    dispatch_pkt.instr_operands.rs2 = bypass_rs2;
    dispatch_pkt.instr_operands.imm = issue_pkt_r.imm;
    dispatch_pkt.decode             = decoded;

    calc_status.isd_v                    = issue_pkt_v_r;
    calc_status.isd_pc                   = issue_pkt_r.instr_metadata.pc;
    calc_status.isd_irs1_v               = issue_pkt_r.irs1_v;
    calc_status.isd_frs1_v               = issue_pkt_r.frs1_v;
    calc_status.isd_rs1_addr             = issue_pkt_r.rs1_addr;
    calc_status.isd_irs2_v               = issue_pkt_r.irs2_v;
    calc_status.isd_frs2_v               = issue_pkt_r.frs2_v;
    calc_status.isd_rs2_addr             = issue_pkt_r.rs2_addr;

    calc_status.int1_v                   = calc_stage_r[0].decode.pipe_int_v & ~|exc_stage_r[0];
    calc_status.int1_br_tgt              = int_calc_result.br_tgt;
    calc_status.int1_branch_metadata_fwd = calc_stage_r[0].instr_metadata.branch_metadata_fwd;
    calc_status.int1_btaken              = (calc_stage_r[0].decode.br_v & int_calc_result.result[0])
                                           | calc_stage_r[0].decode.jmp_v;
    calc_status.int1_br_or_jmp           = calc_stage_r[0].decode.br_v 
                                           | calc_stage_r[0].decode.jmp_v;

    calc_status.ex1_v                    = (calc_stage_r[0].decode.pipe_int_v
                                            | calc_stage_r[0].decode.pipe_mul_v
                                            | calc_stage_r[0].decode.pipe_mem_v
                                            | calc_stage_r[0].decode.pipe_fp_v
                                            )
                                           & ~|exc_stage_r[0];


    for(integer i=0;i<pipe_stage_els_lp;i+=1) begin : dep_statusard_status
        
        calc_status.dep_status[i].int_iwb_v      = calc_stage_r[i].decode.pipe_int_v 
                                            & ~|exc_stage_r[i] 
                                            & calc_stage_r[i].decode.irf_w_v;
        calc_status.dep_status[i].mul_iwb_v      = calc_stage_r[i].decode.pipe_mul_v 
                                            & ~|exc_stage_r[i] 
                                            & calc_stage_r[i].decode.irf_w_v;
        calc_status.dep_status[i].mem_iwb_v      = calc_stage_r[i].decode.pipe_mem_v 
                                            & ~|exc_stage_r[i] 
                                            & calc_stage_r[i].decode.irf_w_v;
        calc_status.dep_status[i].mem_fwb_v      = calc_stage_r[i].decode.pipe_mem_v 
                                            & ~|exc_stage_r[i] 
                                            & calc_stage_r[i].decode.frf_w_v;
        calc_status.dep_status[i].fp_fwb_v       = calc_stage_r[i].decode.pipe_fp_v  
                                            & ~|exc_stage_r[i] 
                                            & calc_stage_r[i].decode.frf_w_v;
        calc_status.dep_status[i].rd_addr        = calc_stage_r[i].decode.rd_addr;
    end

    calc_status.mem3_v                  = calc_stage_r[2].decode.pipe_mem_v & ~|exc_stage_r[2];
    calc_status.mem3_pc                 = calc_stage_r[2].instr_metadata.pc;
    calc_status.mem3_cache_miss_v       = mem3_cache_miss
                                          & (calc_stage_r[2].decode.dcache_r_v
                                             | calc_stage_r[2].decode.dcache_w_v
                                             )
                                          & ~|exc_stage_r[2];
    calc_status.mem3_exception_v        = 1'b0; /* TODO: Exception should come from pipe */
    calc_status.mem3_ret_v              = calc_stage_r[2].decode.ret_v;

    calc_status.instr_ckpt_v            = (calc_stage_r[2].decode.pipe_int_v
                                           | calc_stage_r[2].decode.pipe_mul_v
                                           | calc_stage_r[2].decode.pipe_mem_v
                                           | calc_stage_r[2].decode.pipe_fp_v
                                           )
                                          & ~exc_stage_n[3].roll_v;
        
    for(integer i=1;i<pipe_stage_els_lp;i=i+1) begin : comp_stage_slice
        comp_stage_n_slice_iwb_v[i]   = calc_stage_r[i-1].decode.irf_w_v 
                                        & (calc_stage_r[i-1].decode.pipe_int_v
                                           | calc_stage_r[i-1].decode.pipe_mul_v
                                           | calc_stage_r[i-1].decode.pipe_mem_v
                                           | calc_stage_r[i-1].decode.pipe_fp_v
                                           )
                                        & ~|exc_stage_r[i-1]; 
        comp_stage_n_slice_fwb_v[i]   = calc_stage_r[i-1].decode.frf_w_v
                                        & (calc_stage_r[i-1].decode.pipe_int_v
                                           | calc_stage_r[i-1].decode.pipe_mul_v
                                           | calc_stage_r[i-1].decode.pipe_mem_v
                                           | calc_stage_r[i-1].decode.pipe_fp_v
                                           )
                                        & ~|exc_stage_r[i-1]; 
        comp_stage_n_slice_rd_addr[i]   = calc_stage_r[i-1].decode.rd_addr;
        comp_stage_n_slice_rd[i]        = comp_stage_n[i].result;
    end

    for(integer i=0;i<pipe_stage_els_lp;i=i+1) begin : exc_stage
        exc_stage_n[i] = (i == 0) ? '0 : exc_stage_r[i-1];
    end
        exc_stage_n[0].psn_v           =                         chk_psn_isd_i;
        exc_stage_n[0].roll_v          =                         chk_roll_i;
        exc_stage_n[0].illegal_instr_v =                         decode_illegal_instr;
        exc_stage_n[1].psn_v           = exc_stage_r[0].psn_v  | chk_psn_ex_i;
        exc_stage_n[1].roll_v          = exc_stage_r[0].roll_v | chk_roll_i;
        exc_stage_n[2].psn_v           = exc_stage_r[1].psn_v  | chk_psn_ex_i;
        exc_stage_n[2].roll_v          = exc_stage_r[1].roll_v | chk_roll_i;
        exc_stage_n[3].cache_miss_v    = mem3_cache_miss
                                         & (calc_stage_r[2].decode.dcache_r_v 
                                            | calc_stage_r[2].decode.dcache_w_v
                                            )
                                         & ~|exc_stage_r[2];
        exc_stage_n[3].roll_v          = exc_stage_r[2].roll_v | chk_roll_i;

    cmt_trace_stage_reg_o = calc_stage_r[pipe_stage_els_lp-1];
    cmt_trace_result_o    = comp_stage_r[pipe_stage_els_lp-1];
    cmt_trace_exc_o       = exc_stage_r[pipe_stage_els_lp-1];
end

endmodule : bp_be_calculator_top

