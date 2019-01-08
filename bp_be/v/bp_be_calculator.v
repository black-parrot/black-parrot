/**
 *
 * bp_be_calculator.v
 *
 */

`include "bsg_defines.v"
`include "bp_be_internal_if.vh"

module bp_be_calculator 
 #(parameter mhartid_p="inv"
   , parameter vaddr_width_p="inv"
   , parameter paddr_width_p="inv"
   , parameter asid_width_p="inv"
   , parameter branch_metadata_fwd_width_p="inv"

   , parameter dcache_id_p="inv"
   
   , localparam fe_adapter_issue_width_lp=`bp_be_fe_adapter_issue_width(branch_metadata_fwd_width_p)
   , localparam calc_status_width_lp=`bp_be_calc_status_width(branch_metadata_fwd_width_p)
   , localparam exception_width_lp=`bp_be_exception_width
   , localparam mmu_cmd_width_lp=`bp_be_mmu_cmd_width
   , localparam mmu_resp_width_lp=`bp_be_mmu_resp_width

   , localparam pipe_stage_reg_width_lp=`bp_be_pipe_stage_reg_width(branch_metadata_fwd_width_p)
   , localparam calc_result_width_lp=`bp_be_calc_result_width(branch_metadata_fwd_width_p)

   , localparam pipe_els_lp=2**$size(bp_be_pipe_e)
   , localparam pipe_int_stage_els_lp=1
   , localparam pipe_mul_stage_els_lp=2
   , localparam pipe_mem_stage_els_lp=3
   , localparam pipe_fp_stage_els_lp=4
   , localparam pipe_calc_stage_els_lp=5
   , localparam pipe_comp_stage_els_lp=5
   , localparam pipe_exc_stage_els_lp=5

   , localparam irf_els_lp=RV64_irf_els_gp
   , localparam frf_els_lp=RV64_frf_els_gp
   , localparam instr_width_lp=RV64_instr_width_gp
   , localparam reg_data_width_lp=RV64_reg_data_width_gp
   , localparam reg_addr_width_lp=RV64_reg_addr_width_gp
   )
 (input logic                                  clk_i
  , input logic                                reset_i

  , input logic[fe_adapter_issue_width_lp-1:0] fe_adapter_issue_i
  , input logic                                fe_adapter_issue_v_i

  , input logic                                chk_issue_v_i
  , input logic                                chk_dispatch_v_i

  , input logic                                chk_roll_i
  , input logic                                chk_psn_ex_i
  , input logic                                chk_psn_isd_i

  , output logic[calc_status_width_lp-1:0]     calc_status_o

  , output logic[mmu_cmd_width_lp-1:0]         mmu_cmd_o
  , output logic                               mmu_cmd_v_o
  , input logic                                mmu_cmd_rdy_i

  , input logic[mmu_resp_width_lp-1:0]         mmu_resp_i
  , input logic                                mmu_resp_v_i
  , output logic                               mmu_resp_rdy_o

  , output logic[pipe_stage_reg_width_lp-1:0]  calc_trace_stage_reg_o
  , output logic[calc_result_width_lp-1:0]     calc_trace_result_o
  , output logic[exception_width_lp-1:0]       calc_trace_exc_o
  );

`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   );

// Cast input and output ports 
bp_be_fe_adapter_issue_s fe_adapter_issue;
bp_be_calc_status_s      calc_status;
bp_be_calc_result_s      calc_trace;
bp_be_mmu_cmd_s          mmu_cmd;
bp_be_mmu_resp_s         mmu_resp;

assign fe_adapter_issue = fe_adapter_issue_i;
assign calc_status_o    = calc_status;
assign calc_trace_o     = calc_trace;
assign mmu_cmd_o        = mmu_cmd;
assign mmu_resp         = mmu_resp_i;

// Declare intermediate signals
logic fe_adapter_issue_v_r;
bp_be_fe_adapter_issue_s fe_adapter_issue_r;
bp_be_decode_s           decoded;
bp_be_pipe_stage_reg_s   dispatch_pkt;
logic[pipe_els_lp-1:0]   pipe_dispatch_mask;

logic[reg_data_width_lp-1:0] nop_result, int_result, mul_result, mem_result, fp_result;
logic[reg_data_width_lp-1:0] int1_br_tgt;

logic[reg_data_width_lp-1:0] irf_rs1, irf_rs2;
logic[reg_data_width_lp-1:0] frf_rs1, frf_rs2;
logic[reg_data_width_lp-1:0] bypass_irs1, bypass_irs2, bypass_frs1, bypass_frs2;
logic[reg_data_width_lp-1:0] bypass_rs1, bypass_rs2;

logic decode_illegal_instr, mem3_cache_miss;

// Pipeline stage registers
bp_be_pipe_stage_reg_s[pipe_calc_stage_els_lp-1:0] calc_stage_r, calc_stage_n;
bp_be_calc_result_s   [pipe_comp_stage_els_lp-1:0] comp_stage_r, comp_stage_n;
bp_be_exception_s     [pipe_exc_stage_els_lp-1:0]  exc_stage_r , exc_stage_n;

bp_be_calc_result_s nop_calc_result;
bp_be_calc_result_s int_calc_result; 
bp_be_calc_result_s mul_calc_result; 
bp_be_calc_result_s mem_calc_result; 
bp_be_calc_result_s fp_calc_result;

/* TODO: Explain isd :1 */
logic[pipe_comp_stage_els_lp-1:1]                        comp_stage_n_slice_v;
logic[pipe_comp_stage_els_lp-1:1]                        comp_stage_n_slice_irf_w_v;
logic[pipe_comp_stage_els_lp-1:1]                        comp_stage_n_slice_frf_w_v;
logic[pipe_comp_stage_els_lp-1:1][reg_addr_width_lp-1:0] comp_stage_n_slice_rd_addr;
logic[pipe_comp_stage_els_lp-1:1][reg_data_width_lp-1:0] comp_stage_n_slice_rd;

// Module instantiations
/* TODO: Add write->read forwarding */
bp_be_regfile #(.width_p(reg_data_width_lp)
                ,.els_p(irf_els_lp)
                ) irf
               (.clk_i(clk_i)
                ,.reset_i(reset_i)

                ,.issue_v_i(chk_issue_v_i)

                ,.rd_w_v_i(calc_stage_r[3].decode.irf_w_v & ~(|exc_stage_r[3]))
                ,.rd_addr_i(calc_stage_r[3].decode.rd_addr)
                ,.rd_data_i(comp_stage_r[3].result)

                ,.rs1_r_v_i(fe_adapter_issue.irs1_v)
                ,.rs1_addr_i(fe_adapter_issue.rs1_addr)
                ,.rs1_data_o(irf_rs1)

                ,.rs2_r_v_i(fe_adapter_issue.irs2_v)
                ,.rs2_addr_i(fe_adapter_issue.rs2_addr)
                ,.rs2_data_o(irf_rs2)
                );

bp_be_regfile #(.width_p(reg_data_width_lp)
                ,.els_p(frf_els_lp)
                ) frf
               (.clk_i(clk_i)
                ,.reset_i(reset_i)

                ,.issue_v_i(chk_issue_v_i)

                ,.rd_w_v_i(calc_stage_r[4].decode.frf_w_v & ~(|exc_stage_r[4]))
                ,.rd_addr_i(calc_stage_r[4].decode.rd_addr)
                ,.rd_data_i(comp_stage_r[4].result)

                ,.rs1_r_v_i(fe_adapter_issue.frs1_v)
                ,.rs1_addr_i(fe_adapter_issue.rs1_addr)
                ,.rs1_data_o(frf_rs1)

                ,.rs2_r_v_i(fe_adapter_issue.frs2_v)
                ,.rs2_addr_i(fe_adapter_issue.rs2_addr)
                ,.rs2_data_o(frf_rs2)
                );

bsg_dff_reset_en #(.width_p(fe_adapter_issue_width_lp)
                   ) issue_reg
                  (.clk_i(clk_i)
                   ,.reset_i(reset_i)
                   ,.en_i(chk_issue_v_i)

                   ,.data_i(fe_adapter_issue)
                   ,.data_o(fe_adapter_issue_r)
                   );

bsg_dff_reset_en #(.width_p(1)
                   ) issue_v_reg
                  (.clk_i(clk_i)
                   ,.reset_i(reset_i)
                   ,.en_i(chk_issue_v_i | chk_dispatch_v_i)

                   ,.data_i(fe_adapter_issue_v_i)
                   ,.data_o(fe_adapter_issue_v_r)
                   );

bp_be_instr_decoder #(.vaddr_width_p(vaddr_width_p)
                      ,.paddr_width_p(paddr_width_p)
                      ,.asid_width_p(asid_width_p)
                      ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
                      ) instr_decoder
                     (.fe_nop_v_i(~fe_adapter_issue_v_r)
                      ,.be_nop_v_i(~chk_dispatch_v_i &  mmu_cmd_rdy_i)
                      ,.me_nop_v_i(~chk_dispatch_v_i & ~mmu_cmd_rdy_i)
                      ,.instr_i(fe_adapter_issue_r.instr)

                      ,.decode_o(decoded)
                      ,.illegal_instr_o(decode_illegal_instr)
                      );

bp_be_calc_bypass #(.num_pipe_els_p(pipe_comp_stage_els_lp-1)
                    ) int_bypass 
                   (.id_rs1_v_i(fe_adapter_issue_r.irs1_v)
                    ,.id_rs1_addr_i(decoded.rs1_addr)
                    ,.id_rs1_i(irf_rs1)

                    ,.id_rs2_v_i(fe_adapter_issue_r.irs2_v)
                    ,.id_rs2_addr_i(decoded.rs2_addr)
                    ,.id_rs2_i(irf_rs2)

                    ,.comp_v_i(comp_stage_n_slice_v)
                    ,.comp_rf_w_v_i(comp_stage_n_slice_irf_w_v)
                    ,.comp_rd_addr_i(comp_stage_n_slice_rd_addr)
                    ,.comp_rd_i(comp_stage_n_slice_rd)

                    ,.bypass_rs1_o(bypass_irs1)
                    ,.bypass_rs2_o(bypass_irs2)
                    );

bp_be_calc_bypass #(.num_pipe_els_p(pipe_comp_stage_els_lp-1)
                    ) fp_bypass
                   (.id_rs1_v_i(fe_adapter_issue_r.frs1_v)
                    ,.id_rs1_addr_i(decoded.rs1_addr)
                    ,.id_rs1_i(frf_rs1)

                    ,.id_rs2_v_i(fe_adapter_issue_r.frs2_v)
                    ,.id_rs2_addr_i(decoded.rs2_addr)
                    ,.id_rs2_i(frf_rs2)

                    /* TODO: Update to be same as irf */
                    ,.comp_v_i(comp_stage_n_slice_v)
                    ,.comp_rf_w_v_i(comp_stage_n_slice_frf_w_v)
                    ,.comp_rd_addr_i(comp_stage_n_slice_rd_addr)
                    ,.comp_rd_i(comp_stage_n_slice_rd)

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

assign nop_result = '0;

bp_be_pipe_int #(.mhartid_p(mhartid_p)
                 ,.vaddr_width_p(vaddr_width_p)
                 ,.paddr_width_p(paddr_width_p)
                 ,.asid_width_p(asid_width_p)
                 ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
                 ) pipe_int
                (.clk_i(clk_i)
                 ,.reset_i(reset_i)
      
                 ,.stage_i(calc_stage_r[0])
                 ,.exc_i(exc_stage_r[0])

                 ,.result_o(int_result)
                 ,.br_tgt_o(int1_br_tgt)
                 );

bp_be_pipe_mul #(.vaddr_width_p(vaddr_width_p)
                 ,.paddr_width_p(paddr_width_p)
                 ,.asid_width_p(asid_width_p)
                 ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
                 )
        pipe_mul(.clk_i(clk_i)
                 ,.reset_i(reset_i)

                 ,.stage_i(calc_stage_r[0])
                 ,.exc_i(exc_stage_r[0])

                 ,.result_o(mul_result)
                 );

bp_be_pipe_mem #(.vaddr_width_p(vaddr_width_p)
                 ,.paddr_width_p(paddr_width_p)
                 ,.asid_width_p(asid_width_p)
                 ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
                 ) pipe_mem
                (.clk_i(clk_i)
                 ,.reset_i(reset_i)

                 ,.stage_i(calc_stage_r[0])
                 ,.exc_i(exc_stage_r[0])

                 ,.result_o(mem_result)

                 ,.mmu_cmd_o(mmu_cmd)
                 ,.mmu_cmd_v_o(mmu_cmd_v_o)
                 ,.mmu_cmd_rdy_i(mmu_cmd_rdy_i)

                 ,.mmu_resp_i(mmu_resp_i)
                 ,.mmu_resp_v_i(mmu_resp_v_i)
                 ,.mmu_resp_rdy_o(mmu_resp_rdy_o)

                 ,.cache_miss_o(mem3_cache_miss)
                 );

bp_be_pipe_fp #(.vaddr_width_p(vaddr_width_p)
                ,.paddr_width_p(paddr_width_p)
                ,.asid_width_p(asid_width_p)
                ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
                ) pipe_fp
               (.clk_i(clk_i)
                ,.reset_i(reset_i)

                ,.stage_i(calc_stage_r[0])
                ,.exc_i(exc_stage_r[0])

                ,.result_o(fp_result)
               );

    bsg_dff #(.width_p(exception_width_lp*pipe_exc_stage_els_lp)
              ) exc_stage_reg
             (.clk_i(clk_i)
              ,.data_i(exc_stage_n)
              ,.data_o(exc_stage_r)
              );

bsg_mux_segmented #(.segments_p(pipe_comp_stage_els_lp)
                    ,.segment_width_p(calc_result_width_lp)
                    ) comp_stage_mux
                   (.data0_i({comp_stage_r[0+:pipe_comp_stage_els_lp-1]
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

bsg_dff #(.width_p(calc_result_width_lp*pipe_comp_stage_els_lp)
          ) comp_stage_reg 
         (.clk_i(clk_i)
          ,.data_i(comp_stage_n)
          ,.data_o(comp_stage_r)
          );

assign calc_stage_n[0] = dispatch_pkt;
assign calc_stage_n[1+:pipe_calc_stage_els_lp-1] = calc_stage_r[0+:pipe_calc_stage_els_lp-1];
bsg_dff #(.width_p(pipe_stage_reg_width_lp*pipe_calc_stage_els_lp)
          ) calc_stage_reg
         (.clk_i(clk_i)
          ,.data_i(calc_stage_n)
          ,.data_o(calc_stage_r)
          );

always_comb begin
    dispatch_pkt.instr_metadata     = fe_adapter_issue_r.instr_metadata;
    dispatch_pkt.instr              = fe_adapter_issue_r.instr;
    dispatch_pkt.instr_operands.rs1 = bypass_rs1;
    dispatch_pkt.instr_operands.rs2 = bypass_rs2;
    dispatch_pkt.instr_operands.imm = fe_adapter_issue_r.imm;
    dispatch_pkt.decode             = decoded;

    int_calc_result.result    = int_result;
    mul_calc_result.result    = mul_result;
    mem_calc_result.result    = mem_result;
    fp_calc_result.result     = fp_result;

    int_calc_result.br_tgt    = int1_br_tgt;

    calc_status.isd_v                    = fe_adapter_issue_v_r;
    calc_status.isd_pc                   = fe_adapter_issue_r.instr_metadata.pc;
    calc_status.isd_irs1_v               = fe_adapter_issue_r.irs1_v;
    calc_status.isd_frs1_v               = fe_adapter_issue_r.frs1_v;
    calc_status.isd_rs1_addr             = fe_adapter_issue_r.rs1_addr;
    calc_status.isd_irs2_v               = fe_adapter_issue_r.irs2_v;
    calc_status.isd_frs2_v               = fe_adapter_issue_r.frs2_v;
    calc_status.isd_rs2_addr             = fe_adapter_issue_r.rs2_addr;

    calc_status.int1_v                   = calc_stage_r[0].decode.pipe_int_v & ~|exc_stage_r[0];
    calc_status.int1_br_tgt              = int1_br_tgt;
    calc_status.int1_branch_metadata_fwd = calc_stage_r[0].instr_metadata.branch_metadata_fwd;
    calc_status.int1_br_or_jmp_v         = calc_stage_r[0].decode.br_v 
                                           | calc_stage_r[0].decode.jmp_v;

    calc_status.ex1_v                    = (calc_stage_r[0].decode.pipe_int_v
                                            | calc_stage_r[0].decode.pipe_mul_v
                                            | calc_stage_r[0].decode.pipe_mem_v
                                            | calc_stage_r[0].decode.pipe_fp_v
                                            )
                                           & ~|exc_stage_r[0];


    for(integer i=0;i<pipe_calc_stage_els_lp;i+=1) begin : hazard_status
        
        calc_status.haz[i].int_iwb_v      = calc_stage_r[i].decode.pipe_int_v 
                                            & ~|exc_stage_r[i] 
                                            & calc_stage_r[i].decode.irf_w_v;
        calc_status.haz[i].mul_iwb_v      = calc_stage_r[i].decode.pipe_mul_v 
                                            & ~|exc_stage_r[i] 
                                            & calc_stage_r[i].decode.irf_w_v;
        calc_status.haz[i].mem_iwb_v      = calc_stage_r[i].decode.pipe_mem_v 
                                            & ~|exc_stage_r[i] 
                                            & calc_stage_r[i].decode.irf_w_v;
        calc_status.haz[i].mem_fwb_v      = calc_stage_r[i].decode.pipe_mem_v 
                                            & ~|exc_stage_r[i] 
                                            & calc_stage_r[i].decode.frf_w_v;
        calc_status.haz[i].fp_fwb_v       = calc_stage_r[i].decode.pipe_fp_v  
                                            & ~|exc_stage_r[i] 
                                            & calc_stage_r[i].decode.frf_w_v;
        calc_status.haz[i].rd_addr        = calc_stage_r[i].decode.rd_addr;
    end

    calc_status.mem3_v                  = calc_stage_r[2].decode.pipe_mem_v & ~|exc_stage_r[2];
    calc_status.mem3_pc                 = calc_stage_r[2].instr_metadata.pc;
    calc_status.mem3_cache_miss_v       = mem3_cache_miss
                                          & (calc_stage_r[2].decode.dcache_r_v
                                             | calc_stage_r[2].decode.dcache_w_v
                                             )
                                          & ~|exc_stage_r[2];
    calc_status.mem3_exception_v        = calc_stage_r[2].decode.exception_v;
    calc_status.mem3_ret_v              = calc_stage_r[2].decode.ret_v;

    calc_status.instr_ckpt_v            = (calc_stage_r[2].decode.pipe_int_v
                                           | calc_stage_r[2].decode.pipe_mul_v
                                           | calc_stage_r[2].decode.pipe_mem_v
                                           | calc_stage_r[2].decode.pipe_fp_v
                                           )
                                          & ~exc_stage_n[3].roll_v;
        
    for(integer i=1;i<pipe_comp_stage_els_lp;i=i+1) begin : comp_stage_slice
        comp_stage_n_slice_v[i]         = (calc_stage_r[i-1].decode.pipe_int_v
                                           | calc_stage_r[i-1].decode.pipe_mul_v
                                           | calc_stage_r[i-1].decode.pipe_mem_v
                                           | calc_stage_r[i-1].decode.pipe_fp_v
                                           )
                                          & ~|exc_stage_r[i-1]; 
        comp_stage_n_slice_irf_w_v[i]   = calc_stage_r[i-1].decode.irf_w_v;
        comp_stage_n_slice_frf_w_v[i]   = calc_stage_r[i-1].decode.frf_w_v;
        comp_stage_n_slice_rd_addr[i]   = calc_stage_r[i-1].decode.rd_addr;
        comp_stage_n_slice_rd[i]        = comp_stage_n[i].result;
    end

    for(integer i=0;i<pipe_exc_stage_els_lp;i=i+1) begin : exc_stage
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

    calc_trace_stage_reg_o = calc_stage_r[pipe_calc_stage_els_lp-1];
    calc_trace_result_o    = comp_stage_r[pipe_comp_stage_els_lp-1];
    calc_trace_exc_o       = exc_stage_r[pipe_exc_stage_els_lp-1];
end

endmodule : bp_be_calculator

