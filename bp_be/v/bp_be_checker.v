/**
 *
 * bp_be_checker.v
 *
 */

`include "bsg_defines.v"
`include "bp_be_internal_if.vh"

module bp_be_checker 
 #(parameter vaddr_width_p="inv"
   ,parameter paddr_width_p="inv"
   ,parameter asid_width_p="inv"
   ,parameter branch_metadata_fwd_width_p="inv"

   ,localparam calc_status_width_lp=`bp_be_calc_status_width(branch_metadata_fwd_width_p)
   ,localparam npc_status_width_lp=`bp_be_chk_npc_status_width(branch_metadata_fwd_width_p)

   ,localparam pc_entry_point_lp=bp_pc_entry_point_gp
   ,localparam reg_data_width_lp=RV64_reg_data_width_gp
   ,localparam eaddr_width_lp=RV64_eaddr_width_gp
   )
  (input logic                             clk_i
   ,input logic                            reset_i

   ,output logic [npc_status_width_lp-1:0] chk_npc_status_o
   ,output logic                           chk_instr_ckpt_v_o

   ,input logic [calc_status_width_lp-1:0] calc_status_i

   ,output logic                           chk_issue_v_o
   ,output logic                           chk_dispatch_v_o

   ,output logic                           chk_roll_o
   ,output logic                           chk_psn_isd_o
   ,output logic                           chk_psn_ex_o

   ,input logic                            mmu_cmd_rdy_i
  );

`declare_bp_be_internal_if_structs(vaddr_width_p,paddr_width_p,asid_width_p
                                   ,branch_metadata_fwd_width_p); 

// Cast input and output ports 
bp_be_calc_status_s    calc_status;
bp_be_chk_npc_status_s chk_npc_status;

assign calc_status      = calc_status_i;
assign chk_npc_status_o = chk_npc_status;

// Declare intermediate signals
logic npc_w_v;
logic[eaddr_width_lp-1:0] npc_n, npc_r, npc_expected;
logic[eaddr_width_lp-1:0] npc_plus4;
logic[eaddr_width_lp-1:0] br_mux_o, miss_mux_o, exception_mux_o, ret_mux_o;
logic[branch_metadata_fwd_width_p-1:0] branch_metadata_fwd_r;

// Module instantiations
bsg_dff_reset_en #(.width_p(eaddr_width_lp)
                   ,.reset_val_p(pc_entry_point_lp)
                   )
               npc(.clk_i(clk_i)
                   ,.reset_i(reset_i)
                   ,.en_i(npc_w_v)
  
                   ,.data_i(npc_n)
                   ,.data_o(npc_r)
                   );

    bsg_mux #(.width_p(eaddr_width_lp)
              ,.els_p(2)
              )
      nop_mux(.data_i({npc_n, npc_r})
              ,.sel_i(npc_w_v)
              ,.data_o(npc_expected)
              );

    bsg_mux #(.width_p(eaddr_width_lp)
              ,.els_p(2)
              )
exception_mux(.data_i({ret_mux_o, miss_mux_o})
              ,.sel_i(calc_status.mem3_exception_v)
              ,.data_o(npc_n)
              );

bsg_mux #(.width_p(eaddr_width_lp)
          ,.els_p(2)
          )
  miss_mux(.data_i({calc_status.mem3_pc, br_mux_o})
           ,.sel_i(calc_status.mem3_cache_miss_v)
           ,.data_o(miss_mux_o)
           );

bsg_mux #(.width_p(eaddr_width_lp)
          ,.els_p(2)
          )
   br_mux(.data_i({calc_status.int1_br_tgt, npc_plus4})
          ,.sel_i(calc_status.int1_v & calc_status.int1_br_or_jmp_v)
          ,.data_o(br_mux_o)
          );

bsg_mux #(.width_p(eaddr_width_lp)
          ,.els_p(2)
          )
  ret_mux(.data_i(/* TODO: {MTVAL, EPC} */)
          ,.sel_i(calc_status.mem3_ret_v)
          ,.data_o(ret_mux_o)
          );

bsg_adder_ripple_carry #(.width_p(eaddr_width_lp)
                         )
          npc_plus4_calc(.a_i(npc_r)
                         ,.b_i({{(eaddr_width_lp-3){1'b0}},{3'h4}})
                         ,.s_o(npc_plus4)
                         ,.c_o(/* No overflow is detected in RV */)
                        );

bsg_dff #(.width_p(branch_metadata_fwd_width_p)
          ) branch_metadata_fwd_reg
         (.clk_i(clk_i)
          ,.data_i(calc_status.int1_branch_metadata_fwd)
          ,.data_o(branch_metadata_fwd_r)
          );

always_comb begin
    npc_w_v = calc_status.ex1_v | (calc_status.mem3_v & calc_status.mem3_cache_miss_v);

    chk_dispatch_v_o = 
    ~((calc_status.isd_irs1_v & (calc_status.isd_rs1_addr != '0))
      & ((calc_status.isd_irs1_v & (calc_status.isd_rs1_addr == calc_status.haz[0].rd_addr)
          & (calc_status.haz[0].mul_iwb_v | calc_status.haz[0].mem_iwb_v))
         | (calc_status.isd_irs1_v & (calc_status.isd_rs1_addr == calc_status.haz[1].rd_addr)
            & (calc_status.haz[1].mem_iwb_v))
         ))
    &
    ~((calc_status.isd_frs1_v & (calc_status.isd_rs1_addr != '0))
      & ((calc_status.isd_frs1_v & (calc_status.isd_rs1_addr == calc_status.haz[0].rd_addr)
          & (calc_status.haz[0].mem_fwb_v | calc_status.haz[0].fp_fwb_v))
         | (calc_status.isd_frs1_v & (calc_status.isd_rs1_addr == calc_status.haz[1].rd_addr)
            & (calc_status.haz[1].mem_fwb_v | calc_status.haz[1].fp_fwb_v))
         | (calc_status.isd_frs1_v & (calc_status.isd_rs1_addr == calc_status.haz[2].rd_addr)
            & (calc_status.haz[2].fp_fwb_v))
         ))
    & 
    ~((calc_status.isd_irs2_v & (calc_status.isd_rs2_addr != '0))
      & ((calc_status.isd_irs2_v & (calc_status.isd_rs2_addr == calc_status.haz[0].rd_addr)
          & (calc_status.haz[0].mul_iwb_v | calc_status.haz[0].mem_iwb_v))
         | (calc_status.isd_irs2_v & (calc_status.isd_rs2_addr == calc_status.haz[1].rd_addr)
            & (calc_status.haz[1].mem_iwb_v))
         ))
    &
    ~((calc_status.isd_frs2_v & (calc_status.isd_rs2_addr != '0))
      & ((calc_status.isd_frs2_v & (calc_status.isd_rs2_addr == calc_status.haz[0].rd_addr)
          & (calc_status.haz[0].mem_fwb_v | calc_status.haz[0].fp_fwb_v))
         | (calc_status.isd_frs2_v & (calc_status.isd_rs2_addr == calc_status.haz[1].rd_addr)
            & (calc_status.haz[1].mem_fwb_v | calc_status.haz[1].fp_fwb_v))
         | (calc_status.isd_frs2_v & (calc_status.isd_rs2_addr == calc_status.haz[2].rd_addr)
            & (calc_status.haz[2].fp_fwb_v))
         ))
    &
    ~(~mmu_cmd_rdy_i);

    chk_issue_v_o = chk_dispatch_v_o | ~calc_status.isd_v;

    chk_roll_o    = calc_status.mem3_cache_miss_v;

    chk_psn_isd_o = reset_i 
                    | calc_status.mem3_cache_miss_v 
                    | calc_status.mem3_exception_v 
                    | calc_status.mem3_ret_v
                    | (calc_status.isd_v & (calc_status.isd_pc != npc_expected));

    chk_psn_ex_o   = reset_i
                     | calc_status.mem3_cache_miss_v 
                     | calc_status.mem3_exception_v 
                     | calc_status.mem3_ret_v;

    chk_instr_ckpt_v_o = ~calc_status.mem3_cache_miss_v & calc_status.instr_ckpt_v;

    /* TODO: Need to save the branch metadata, otherwise we'll end up sending
     * back weird stuff
     */
    chk_npc_status.isd_v               = calc_status.isd_v;
    chk_npc_status.npc_expected        = npc_expected;
    chk_npc_status.branch_metadata_fwd = calc_status.int1_v 
                                         ? calc_status.int1_branch_metadata_fwd
                                         : branch_metadata_fwd_r;
    chk_npc_status.incorrect_npc       = (npc_expected != calc_status.isd_pc);
    chk_npc_status.br_or_jmp_v         = calc_status.int1_br_or_jmp_v;
end

endmodule : bp_be_checker

