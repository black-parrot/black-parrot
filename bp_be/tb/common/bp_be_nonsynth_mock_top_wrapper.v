/**
 *
 * bp_be_nonsynth_mock_top_wrapper.v
 *
 */

`include "bsg_defines.v"

`include "bp_common_fe_be_if.vh"
`include "bp_common_me_if.vh"

`include "bp_be_internal_if.vh"

module bp_be_nonsynth_mock_top_wrapper
 #(parameter mhartid_p="inv"
   ,parameter vaddr_width_p="inv"
   ,parameter paddr_width_p="inv"
   ,parameter asid_width_p="inv"
   ,parameter branch_metadata_fwd_width_p="inv"
   ,parameter num_cce_p="inv"
   ,parameter num_lce_p="inv"
   ,parameter num_mem_p="inv"
   ,parameter coh_states_p="inv"
   ,parameter lce_assoc_p="inv"
   ,parameter lce_sets_p="inv"
   ,parameter cce_block_size_in_bytes_p="inv"
   ,parameter dcache_id_p="inv"
   ,parameter boot_rom_els_p="inv"
   ,parameter boot_rom_width_p="inv"

   ,localparam lg_boot_rom_els_lp=`BSG_SAFE_CLOG2(boot_rom_els_p)
 
   ,localparam cce_block_size_in_bits_lp=8*cce_block_size_in_bytes_p
   ,localparam fe_queue_width_lp=`bp_fe_queue_width(vaddr_width_p,branch_metadata_fwd_width_p)
   ,localparam fe_cmd_width_lp=104
   ,localparam pipe_stage_reg_width_lp=`bp_be_pipe_stage_reg_width(branch_metadata_fwd_width_p)
   ,localparam calc_result_width_lp=`bp_be_calc_result_width(branch_metadata_fwd_width_p)
   ,localparam exception_width_lp=`bp_be_exception_width

   ,localparam lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p
                                                          ,num_lce_p
                                                          ,paddr_width_p
                                                          ,lce_assoc_p
                                                          )
   ,localparam lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p
                                                            ,num_lce_p
                                                            ,paddr_width_p
                                                            )
   ,localparam lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p
                                                                      ,num_lce_p
                                                                      ,paddr_width_p
                                                                      ,cce_block_size_in_bits_lp
                                                                      )
   ,localparam cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p
                                                          ,num_lce_p
                                                          ,paddr_width_p
                                                          ,lce_assoc_p
                                                          ,coh_states_p
                                                          )
   ,localparam cce_lce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p
                                                                    ,num_lce_p
                                                                    ,paddr_width_p
                                                                    ,cce_block_size_in_bits_lp
                                                                    ,lce_assoc_p
                                                                    )
   ,localparam lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_p
                                                                  ,paddr_width_p
                                                                  ,cce_block_size_in_bits_lp
                                                                  ,lce_assoc_p
                                                                  )

   ,localparam reg_data_width_lp=RV64_reg_data_width_gp
   )
  (input logic                                    clk_i
   ,input logic                                   reset_i
  );

`declare_bp_be_internal_if_structs(vaddr_width_p
                                   ,paddr_width_p
                                   ,asid_width_p
                                   ,branch_metadata_fwd_width_p);

// Top-level interface connections
bp_be_fe_adapter_issue_s fe_adapter_issue;
logic fe_adapter_issue_v;

bp_be_calc_status_s      calc_status;
bp_be_chk_npc_status_s   chk_npc_status;

logic chk_issue_v, chk_dispatch_v, chk_psn_isd, chk_psn_ex, chk_roll, chk_instr_ckpt_v;

bp_be_mmu_cmd_s mmu_cmd;
logic mmu_cmd_v, mmu_cmd_rdy;

bp_be_mmu_resp_s mmu_resp;
logic mmu_resp_v, mmu_resp_rdy;

bp_fe_cmd_s mock_fe_cmd, fe_cmd;
logic mock_fe_cmd_v, fe_cmd_v, mock_fe_cmd_rdy, fe_cmd_rdy;

bp_fe_queue_s mock_fe_queue, fe_queue;
logic mock_fe_queue_v, fe_queue_v, mock_fe_queue_rdy, fe_queue_rdy;

bp_be_exception_s calc_trace_exc;
bp_be_pipe_stage_reg_s calc_trace_stage_reg;
bp_be_calc_result_s calc_trace_result;

logic[lg_boot_rom_els_lp-1:0] irom_addr;
logic[boot_rom_width_p-1:0]  irom_data;

logic[lg_boot_rom_els_lp-1:0] drom_addr;
logic[boot_rom_width_p-1:0]  drom_data;
// Module instantiations

bp_be_nonsynth_mock_fe #(.vaddr_width_p(vaddr_width_p)
                         ,.paddr_width_p(paddr_width_p)
                         ,.asid_width_p(asid_width_p)
                         ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)

                         ,.boot_rom_els_p(boot_rom_els_p)
                         ,.boot_rom_width_p(boot_rom_width_p)
                         )
               mock_fe  (.clk_i(clk_i)
                         ,.reset_i(reset_i)

                         ,.fe_cmd_i(mock_fe_cmd)
                         ,.fe_cmd_v_i(mock_fe_cmd_v)
                         ,.fe_cmd_rdy_o(mock_fe_cmd_rdy)

                         ,.fe_queue_o(mock_fe_queue)
                         ,.fe_queue_v_o(mock_fe_queue_v)
                         ,.fe_queue_rdy_i(mock_fe_queue_rdy)

                         ,.boot_rom_addr_o(irom_addr)
                         ,.boot_rom_data_i(irom_data)
                         );

bsg_fifo_1r1w_rolly #(.width_p(fe_queue_width_lp)
                      ,.els_p(32)
                      ,.ready_THEN_valid_p(1)
                      )
        fe_queue_fifo(.clk_i(clk_i)
                      ,.reset_i(reset_i)

                      ,.clr_v_i(fe_queue_clr)
                      ,.ckpt_v_i(fe_queue_ckpt_inc)
                      ,.roll_v_i(fe_queue_rollback)

                      ,.data_i(mock_fe_queue)
                      ,.v_i(mock_fe_queue_v)
                      ,.ready_o(mock_fe_queue_rdy)

                      ,.data_o(fe_queue)
                      ,.v_o(fe_queue_v)
                      ,.yumi_i(fe_queue_rdy & fe_queue_v)
                      );
 
bsg_fifo_1r1w_small #(.width_p(104)
                      ,.els_p(8)
                      )
          fe_cmd_fifo(.clk_i(clk_i)
                      ,.reset_i(reset_i)

                      ,.data_i(fe_cmd)
                      ,.v_i(fe_cmd_v)
                      ,.ready_o(fe_cmd_rdy)

                      ,.data_o(mock_fe_cmd)
                      ,.v_o(mock_fe_cmd_v)
                      ,.yumi_i(mock_fe_cmd_rdy & mock_fe_cmd_v)
                      );

bp_be_fe_adapter #(.vaddr_width_p(vaddr_width_p)
                   ,.paddr_width_p(paddr_width_p)
                   ,.asid_width_p(asid_width_p)
                   ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
                   )
        fe_adapter(.clk_i(clk_i)
                   ,.reset_i(reset_i)

                   ,.fe_queue_i(fe_queue)
                   ,.fe_queue_v_i(fe_queue_v)
                   ,.fe_queue_rdy_o(fe_queue_rdy)

                   ,.fe_queue_clr_o(fe_queue_clr)
                   ,.fe_queue_ckpt_inc_o(fe_queue_ckpt_inc)
                   ,.fe_queue_rollback_o(fe_queue_rollback)

                   ,.fe_cmd_o(fe_cmd)
                   ,.fe_cmd_v_o(fe_cmd_v)
                   ,.fe_cmd_rdy_i(fe_cmd_rdy)

                   ,.chk_npc_status_i(chk_npc_status)
                   ,.chk_issue_v_i(chk_issue_v)
                   ,.chk_instr_ckpt_v_i(chk_instr_ckpt_v)
                   ,.chk_roll_i(chk_roll)

                   ,.fe_adapter_issue_o(fe_adapter_issue)
                   ,.fe_adapter_issue_v_o(fe_adapter_issue_v)
                   );

bp_be_checker #(.vaddr_width_p(vaddr_width_p)
                ,.paddr_width_p(paddr_width_p)
                ,.asid_width_p(asid_width_p)
                ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
                )
     be_checker(.clk_i(clk_i)
                ,.reset_i(reset_i)

                ,.chk_npc_status_o(chk_npc_status)
                ,.chk_instr_ckpt_v_o(chk_instr_ckpt_v)

                ,.calc_status_i(calc_status)

                ,.chk_issue_v_o(chk_issue_v)
                ,.chk_dispatch_v_o(chk_dispatch_v)

                ,.chk_roll_o(chk_roll)
                ,.chk_psn_isd_o(chk_psn_isd)
                ,.chk_psn_ex_o(chk_psn_ex)

                ,.mmu_cmd_rdy_i(mmu_cmd_rdy)
                );

bp_be_calculator #(.mhartid_p(mhartid_p)
                   ,.vaddr_width_p(vaddr_width_p)
                   ,.paddr_width_p(paddr_width_p)
                   ,.asid_width_p(asid_width_p)
                   ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
                   )
     be_calculator(.clk_i(clk_i)
                   ,.reset_i(reset_i)

                   ,.fe_adapter_issue_i(fe_adapter_issue)
                   ,.fe_adapter_issue_v_i(fe_adapter_issue_v)
                   
                   ,.chk_issue_v_i(chk_issue_v)
                   ,.chk_dispatch_v_i(chk_dispatch_v)

                   ,.chk_roll_i(chk_roll)
                   ,.chk_psn_ex_i(chk_psn_ex)
                   ,.chk_psn_isd_i(chk_psn_isd)

                   ,.calc_status_o(calc_status)

                   ,.mmu_cmd_o(mmu_cmd)
                   ,.mmu_cmd_v_o(mmu_cmd_v)
                   ,.mmu_cmd_rdy_i(mmu_cmd_rdy)

                   ,.mmu_resp_i(mmu_resp) 
                   ,.mmu_resp_v_i(mmu_resp_v)
                   ,.mmu_resp_rdy_o(mmu_resp_rdy)        

                   ,.calc_trace_stage_reg_o(calc_trace_stage_reg)
                   ,.calc_trace_result_o(calc_trace_result)
                   ,.calc_trace_exc_o(calc_trace_exc)
                  );

/* TODO: Remove redundant tracer */
bp_be_nonsynth_tracer #(.vaddr_width_p(vaddr_width_p)
                        ,.paddr_width_p(paddr_width_p)
                        ,.asid_width_p(asid_width_p)
                        ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
                        ,.mhartid_p(mhartid_p)
                        )
              be_tracer(.clk_i(clk_i)
                        ,.reset_i(reset_i)

                        ,.calc_trace_stage_reg_i(calc_trace_stage_reg)
                        ,.calc_trace_result_i(calc_trace_result)
                        ,.calc_trace_exc_i(calc_trace_exc)
                        );

bp_be_nonsynth_mock_mmu #(.vaddr_width_p(vaddr_width_p)
            ,.paddr_width_p(paddr_width_p)
            ,.asid_width_p(asid_width_p)
            ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)

            ,.num_cce_p(num_cce_p)
            ,.num_lce_p(num_lce_p)
            ,.num_mem_p(num_mem_p)
            ,.coh_states_p(coh_states_p)
            ,.cce_block_size_in_bytes_p(cce_block_size_in_bytes_p)
            ,.lce_assoc_p(lce_assoc_p)
            ,.lce_sets_p(lce_sets_p)

            ,.dcache_id_p(dcache_id_p)
            )
        mmu(.clk_i(clk_i)
            ,.reset_i(reset_i)

            ,.mmu_cmd_i(mmu_cmd)
            ,.mmu_cmd_v_i(mmu_cmd_v)
            ,.mmu_cmd_rdy_o(mmu_cmd_rdy)

            ,.chk_psn_ex_i(chk_psn_ex)

            ,.mmu_resp_o(mmu_resp)
            ,.mmu_resp_v_o(mmu_resp_v)
            ,.mmu_resp_rdy_i(mmu_resp_rdy)      

            ,.boot_rom_addr_o(drom_addr)
            ,.boot_rom_data_i(drom_data)
            );

bp_be_boot_rom #(.width_p(boot_rom_width_p)
                 ,.addr_width_p(lg_boot_rom_els_lp)
                 )
          irom  (.addr_i(irom_addr)
                 ,.data_o(irom_data)
                 );

bp_be_boot_rom #(.width_p(boot_rom_width_p)
                 ,.addr_width_p(lg_boot_rom_els_lp)
                 )
          drom  (.addr_i(drom_addr)
                 ,.data_o(drom_data)
                 );

endmodule : bp_be_nonsynth_mock_top_wrapper

