/**
 *
 * bp_multi_wrapper.v
 *
 */

`include "bsg_defines.v"

`include "bp_common_fe_be_if.vh"
`include "bp_common_me_if.vh"

`include "bp_be_internal_if_defines.vh"

module bp_multi_wrapper
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 #(parameter core_els_p="inv"
   ,parameter vaddr_width_p="inv"
   ,parameter paddr_width_p="inv"
   ,parameter asid_width_p="inv"
   ,parameter branch_metadata_fwd_width_p="inv"
   ,parameter num_cce_p="inv"
   ,parameter num_lce_p="inv"
   ,parameter lce_assoc_p="inv"
   ,parameter lce_sets_p="inv"
   ,parameter cce_block_size_in_bytes_p="inv"
   ,parameter cce_num_inst_ram_els_p="inv"
 
   ,parameter boot_rom_els_p="inv"
   ,parameter boot_rom_width_p="inv"
   ,localparam lg_boot_rom_els_lp=`BSG_SAFE_CLOG2(boot_rom_els_p)

   ,localparam lg_core_els_p=`BSG_SAFE_CLOG2(core_els_p)
   ,localparam lg_num_lce_p=`BSG_SAFE_CLOG2(num_lce_p)

   ,localparam cce_block_size_in_bits_lp=8*cce_block_size_in_bytes_p
   ,localparam fe_queue_width_lp=`bp_fe_queue_width(vaddr_width_p,branch_metadata_fwd_width_p)
   ,localparam fe_cmd_width_lp=`bp_fe_cmd_width(vaddr_width_p
                                                  , paddr_width_p
                                                  , asid_width_p
                                                  , branch_metadata_fwd_width_p
                                                  )
   ,localparam mhartid_width_lp = `bp_mhartid_width
   ,localparam lce_id_width_lp = `bp_lce_id_width
   ,localparam proc_cfg_width_lp = `bp_proc_cfg_width

   ,localparam icache_lce_id_lp=0
   ,localparam dcache_lce_id_lp=1

   ,localparam reg_data_width_lp=rv64_reg_data_width_gp
   )
  (input logic                  clk_i
   ,input logic                 reset_i
  );

`declare_bp_common_fe_be_if_structs(vaddr_width_p,paddr_width_p,asid_width_p
                                   ,branch_metadata_fwd_width_p);
`declare_bp_be_internal_if_structs(vaddr_width_p,paddr_width_p,asid_width_p
                                   ,branch_metadata_fwd_width_p);

/* TODO: Change to monolithic declare in bp_common */
/* TODO: Converge 'addr_width' and 'paddr_width', etc. */
`declare_bp_lce_cce_req_s(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p);
`declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, paddr_width_p);
`declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_p, paddr_width_p, cce_block_size_in_bits_lp);
`declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p);
`declare_bp_cce_lce_data_cmd_s(num_cce_p, num_lce_p, paddr_width_p, cce_block_size_in_bits_lp, lce_assoc_p);
`declare_bp_lce_lce_tr_resp_s(num_lce_p, paddr_width_p, cce_block_size_in_bits_lp, lce_assoc_p);

// Top-level interface connections
bp_fe_queue_s[core_els_p-1:0] fe_fe_queue, be_fe_queue;
logic[core_els_p-1:0] fe_fe_queue_v, be_fe_queue_v, fe_fe_queue_rdy, be_fe_queue_rdy;

logic [core_els_p-1:0] fe_queue_clr, fe_queue_ckpt_inc, fe_queue_rollback;

bp_fe_cmd_s[core_els_p-1:0] fe_fe_cmd, be_fe_cmd;
logic [core_els_p-1:0] fe_fe_cmd_v, be_fe_cmd_v, fe_fe_cmd_rdy, be_fe_cmd_rdy;

bp_lce_cce_req_s[num_lce_p-1:0] lce_req, lce_cce_req;
logic [num_lce_p-1:0] lce_cce_req_v, lce_cce_req_rdy;

bp_lce_cce_resp_s [num_lce_p-1:0] lce_cce_resp;
logic [num_lce_p-1:0] lce_cce_resp_v, lce_cce_resp_rdy;

bp_lce_cce_data_resp_s [num_lce_p-1:0] lce_cce_data_resp;
logic [num_lce_p-1:0] lce_cce_data_resp_v, lce_cce_data_resp_rdy;

bp_cce_lce_cmd_s [num_lce_p-1:0] cce_lce_cmd;
logic [num_lce_p-1:0] cce_lce_cmd_v, cce_lce_cmd_rdy;

bp_cce_lce_data_cmd_s [num_lce_p-1:0] cce_lce_data_cmd;
logic [num_lce_p-1:0] cce_lce_data_cmd_v, cce_lce_data_cmd_rdy;

bp_lce_lce_tr_resp_s [num_lce_p-1:0] local_lce_tr_resp, remote_lce_tr_resp;
logic [num_lce_p-1:0] local_lce_tr_resp_v, local_lce_tr_resp_rdy;
logic [num_lce_p-1:0] remote_lce_tr_resp_v, remote_lce_tr_resp_rdy;

bp_be_pipe_stage_reg_s[core_els_p-1:0] cmt_trace_stage_reg;
bp_be_calc_result_s   [core_els_p-1:0] cmt_trace_result;
bp_be_exception_s     [core_els_p-1:0] cmt_trace_exc;

bp_proc_cfg_s[core_els_p-1:0] proc_cfg;

// Module instantiations
/* TODO: Settle on parameter names and converge redundant parameters */
genvar core_id;
generate 
for(core_id = 0; core_id < core_els_p; core_id = core_id + 1) begin
    localparam mhartid = (mhartid_width_lp)'(core_id);
    localparam icache_id = (core_id*2+icache_lce_id_lp);
    localparam dcache_id = (core_id*2+dcache_lce_id_lp);

    assign proc_cfg[core_id].mhartid   = mhartid;
    assign proc_cfg[core_id].icache_id = icache_id[0+:lce_id_width_lp];
    assign proc_cfg[core_id].dcache_id = dcache_id[0+:lce_id_width_lp];

    bp_fe_top#(.vaddr_width_p(vaddr_width_p)
               ,.paddr_width_p(paddr_width_p)
               ,.eaddr_width_p(64)
               ,.btb_indx_width_p(9)
               ,.bht_indx_width_p(5)
               ,.ras_addr_width_p(vaddr_width_p)
               ,.asid_width_p(10)
               ,.instr_width_p(32)
               ,.bp_first_pc_p(bp_pc_entry_point_gp) /* TODO: Not ideal to couple to RISCV-tests */

               ,.data_width_p(64)
               ,.inst_width_p(32)
               ,.lce_sets_p(lce_sets_p)
               ,.lce_assoc_p(lce_assoc_p)
               ,.tag_width_p(12)
               ,.num_cce_p(num_cce_p)
               ,.num_lce_p(num_lce_p)
               ,.block_size_in_bytes_p(8) /* TODO: This is ways not blocks */

               )
            fe(.clk_i(clk_i)
               ,.reset_i(reset_i)

               ,.icache_id_i(proc_cfg[core_id].icache_id)

               ,.bp_fe_queue_o(fe_fe_queue[core_id])
               ,.bp_fe_queue_v_o(fe_fe_queue_v[core_id])
               ,.bp_fe_queue_ready_i(fe_fe_queue_rdy[core_id])

               ,.bp_fe_cmd_i(fe_fe_cmd[core_id])
               ,.bp_fe_cmd_v_i(fe_fe_cmd_v[core_id])
               ,.bp_fe_cmd_ready_o(fe_fe_cmd_rdy[core_id])

               ,.lce_cce_req_o(lce_cce_req[icache_id])
               ,.lce_cce_req_v_o(lce_cce_req_v[icache_id])
               ,.lce_cce_req_ready_i(lce_cce_req_rdy[icache_id])

               ,.lce_cce_resp_o(lce_cce_resp[icache_id])
               ,.lce_cce_resp_v_o(lce_cce_resp_v[icache_id])
               ,.lce_cce_resp_ready_i(lce_cce_resp_rdy[icache_id])

               ,.lce_cce_data_resp_o(lce_cce_data_resp[icache_id])
               ,.lce_cce_data_resp_v_o(lce_cce_data_resp_v[icache_id])
               ,.lce_cce_data_resp_ready_i(lce_cce_data_resp_rdy[icache_id])

               ,.cce_lce_cmd_i(cce_lce_cmd[icache_id])
               ,.cce_lce_cmd_v_i(cce_lce_cmd_v[icache_id])
               ,.cce_lce_cmd_ready_o(cce_lce_cmd_rdy[icache_id])

               ,.cce_lce_data_cmd_i(cce_lce_data_cmd[icache_id])
               ,.cce_lce_data_cmd_v_i(cce_lce_data_cmd_v[icache_id])
               ,.cce_lce_data_cmd_ready_o(cce_lce_data_cmd_rdy[icache_id])

               ,.lce_lce_tr_resp_i(local_lce_tr_resp[icache_id])
               ,.lce_lce_tr_resp_v_i(local_lce_tr_resp_v[icache_id])
               ,.lce_lce_tr_resp_ready_o(local_lce_tr_resp_rdy[icache_id])

               ,.lce_lce_tr_resp_o(remote_lce_tr_resp[icache_id])
               ,.lce_lce_tr_resp_v_o(remote_lce_tr_resp_v[icache_id])
               ,.lce_lce_tr_resp_ready_i(remote_lce_tr_resp_rdy[icache_id])
               );

    bsg_fifo_1r1w_rolly #(.width_p(fe_queue_width_lp)
                          ,.els_p(16)
                          ,.ready_THEN_valid_p(1)
                          )
            fe_queue_fifo(.clk_i(clk_i)
                          ,.reset_i(reset_i)

                          ,.clr_v_i(fe_queue_clr[core_id])
                          ,.ckpt_v_i(fe_queue_ckpt_inc[core_id])
                          ,.roll_v_i(fe_queue_rollback[core_id])

                          ,.data_i(fe_fe_queue[core_id])
                          ,.v_i(fe_fe_queue_v[core_id])
                          ,.ready_o(fe_fe_queue_rdy[core_id])

                          ,.data_o(be_fe_queue[core_id])
                          ,.v_o(be_fe_queue_v[core_id])
                          ,.yumi_i(be_fe_queue_rdy[core_id])
                          );

    bsg_fifo_1r1w_small #(.width_p(fe_cmd_width_lp)
                          ,.els_p(8)
                          ,.ready_THEN_valid_p(1)
                          )
              fe_cmd_fifo(.clk_i(clk_i)
                          ,.reset_i(reset_i)
                          
                          ,.data_i(be_fe_cmd[core_id])
                          ,.v_i(be_fe_cmd_v[core_id])
                          ,.ready_o(be_fe_cmd_rdy[core_id])
                    
                          ,.data_o(fe_fe_cmd[core_id])
                          ,.v_o(fe_fe_cmd_v[core_id])
                          ,.yumi_i(fe_fe_cmd_rdy[core_id])
                          );

    bp_be_top #(.vaddr_width_p(vaddr_width_p)
                ,.paddr_width_p(paddr_width_p)
                ,.asid_width_p(asid_width_p)
                ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
                ,.num_cce_p(num_cce_p)
                ,.num_lce_p(num_lce_p)
                ,.lce_assoc_p(lce_assoc_p)
                ,.lce_sets_p(lce_sets_p)
                ,.cce_block_size_in_bytes_p(cce_block_size_in_bytes_p)
                )
             be(.clk_i(clk_i)
                ,.reset_i(reset_i)

                ,.fe_queue_i(be_fe_queue[core_id])
                ,.fe_queue_v_i(be_fe_queue_v[core_id])
                ,.fe_queue_rdy_o(be_fe_queue_rdy[core_id])

                ,.fe_queue_clr_o(fe_queue_clr[core_id])
                ,.fe_queue_ckpt_inc_o(fe_queue_ckpt_inc[core_id])
                ,.fe_queue_rollback_o(fe_queue_rollback[core_id])

                ,.fe_cmd_o(be_fe_cmd[core_id])
                ,.fe_cmd_v_o(be_fe_cmd_v[core_id])
                ,.fe_cmd_rdy_i(be_fe_cmd_rdy[core_id])

                ,.lce_cce_req_o(lce_cce_req[dcache_id])
                ,.lce_cce_req_v_o(lce_cce_req_v[dcache_id])
                ,.lce_cce_req_rdy_i(lce_cce_req_rdy[dcache_id])

                ,.lce_cce_resp_o(lce_cce_resp[dcache_id])
                ,.lce_cce_resp_v_o(lce_cce_resp_v[dcache_id])
                ,.lce_cce_resp_rdy_i(lce_cce_resp_rdy[dcache_id])

                ,.lce_cce_data_resp_o(lce_cce_data_resp[dcache_id])
                ,.lce_cce_data_resp_v_o(lce_cce_data_resp_v[dcache_id])
                ,.lce_cce_data_resp_rdy_i(lce_cce_data_resp_rdy[dcache_id])

                ,.cce_lce_cmd_i(cce_lce_cmd[dcache_id])
                ,.cce_lce_cmd_v_i(cce_lce_cmd_v[dcache_id])
                ,.cce_lce_cmd_rdy_o(cce_lce_cmd_rdy[dcache_id])

                ,.cce_lce_data_cmd_i(cce_lce_data_cmd[dcache_id])
                ,.cce_lce_data_cmd_v_i(cce_lce_data_cmd_v[dcache_id])
                ,.cce_lce_data_cmd_rdy_o(cce_lce_data_cmd_rdy[dcache_id])

                ,.lce_lce_tr_resp_i(local_lce_tr_resp[dcache_id])
                ,.lce_lce_tr_resp_v_i(local_lce_tr_resp_v[dcache_id])
                ,.lce_lce_tr_resp_rdy_o(local_lce_tr_resp_rdy[dcache_id])

                ,.lce_lce_tr_resp_o(remote_lce_tr_resp[dcache_id])
                ,.lce_lce_tr_resp_v_o(remote_lce_tr_resp_v[dcache_id])
                ,.lce_lce_tr_resp_rdy_i(remote_lce_tr_resp_rdy[dcache_id])

                ,.proc_cfg_i(proc_cfg[core_id])

                ,.cmt_trace_stage_reg_o(cmt_trace_stage_reg[core_id])
                ,.cmt_trace_result_o(cmt_trace_result[core_id])
                ,.cmt_trace_exc_o(cmt_trace_exc[core_id])
                );

             bp_be_nonsynth_tracer #(.vaddr_width_p(vaddr_width_p)
                        ,.paddr_width_p(paddr_width_p)
                        ,.asid_width_p(asid_width_p)
                        ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
                        )
              be_tracer(.clk_i(clk_i)
                        ,.reset_i(reset_i)

                        ,.proc_cfg_i(proc_cfg[core_id])

                        ,.cmt_trace_stage_reg_i(cmt_trace_stage_reg[core_id])
                        ,.cmt_trace_result_i(cmt_trace_result[core_id])
                        ,.cmt_trace_exc_i(cmt_trace_exc[core_id])
                        );
end
endgenerate

bp_me_top #(.num_lce_p(num_lce_p)
            ,.num_cce_p(num_cce_p)
            ,.addr_width_p(paddr_width_p)
            ,.lce_assoc_p(lce_assoc_p)
            ,.lce_sets_p(lce_sets_p)
            ,.block_size_in_bytes_p(cce_block_size_in_bytes_p)
            ,.num_inst_ram_els_p(cce_num_inst_ram_els_p)

            ,.boot_rom_els_p(boot_rom_els_p)
            ,.boot_rom_width_p(boot_rom_width_p)
            )
         me(.clk_i(clk_i)
            ,.reset_i(reset_i)

            ,.lce_req_i(lce_cce_req)
            ,.lce_req_v_i(lce_cce_req_v)
            ,.lce_req_ready_o(lce_cce_req_rdy)

            ,.lce_resp_i(lce_cce_resp)
            ,.lce_resp_v_i(lce_cce_resp_v)
            ,.lce_resp_ready_o(lce_cce_resp_rdy)        

            ,.lce_data_resp_i(lce_cce_data_resp)
            ,.lce_data_resp_v_i(lce_cce_data_resp_v)
            ,.lce_data_resp_ready_o(lce_cce_data_resp_rdy)

            ,.lce_cmd_o(cce_lce_cmd)
            ,.lce_cmd_v_o(cce_lce_cmd_v)
            ,.lce_cmd_ready_i(cce_lce_cmd_rdy)

            ,.lce_data_cmd_o(cce_lce_data_cmd)
            ,.lce_data_cmd_v_o(cce_lce_data_cmd_v)
            ,.lce_data_cmd_ready_i(cce_lce_data_cmd_rdy)

            ,.lce_tr_resp_i(remote_lce_tr_resp)
            ,.lce_tr_resp_v_i(remote_lce_tr_resp_v)
            ,.lce_tr_resp_ready_o(remote_lce_tr_resp_rdy)

            ,.lce_tr_resp_o(local_lce_tr_resp)
            ,.lce_tr_resp_v_o(local_lce_tr_resp_v)
            ,.lce_tr_resp_ready_i(local_lce_tr_resp_rdy)
            );

endmodule : bp_multi_wrapper

