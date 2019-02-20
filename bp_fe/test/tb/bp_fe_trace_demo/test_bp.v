/**
 *
 * test_bp.v
 *
 */

`include "bsg_defines.v"

`include "bp_common_fe_be_if.vh"
`include "bp_common_me_if.vh"

`include "bp_be_internal_if_defines.vh"
`include "bp_be_rv64_defines.vh"

module test_bp
 #(
   parameter core_els_p="inv"
   ,parameter vaddr_width_p="inv"
   ,parameter paddr_width_p="inv"
   ,parameter asid_width_p="inv"
   ,parameter eaddr_width_p="inv"
   ,parameter branch_metadata_fwd_width_p="inv"
   ,parameter num_cce_p="inv"
   ,parameter num_lce_p="inv"
   ,parameter num_mem_p="inv"
   ,parameter lce_sets_p="inv"
   ,parameter lce_assoc_p="inv"
   ,parameter cce_block_size_in_bytes_p="inv"
   ,parameter cce_num_inst_ram_els_p="inv"

   ,parameter boot_rom_width_p="inv"
   ,parameter boot_rom_els_p="inv"

   ,parameter trace_data_width_p="inv"
   ,parameter trace_addr_width_p="inv"

   ,localparam cce_block_size_in_bits_lp=8*cce_block_size_in_bytes_p
   ,localparam lg_boot_rom_els_lp=`BSG_SAFE_CLOG2(boot_rom_els_p)
 );

`declare_bp_common_proc_cfg_s(core_els_p, num_lce_p)
`declare_bp_common_fe_be_if_structs(vaddr_width_p
                                    , paddr_width_p
                                    , asid_width_p
                                    , branch_metadata_fwd_width_p
                                    )
`declare_bp_lce_cce_req_s(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p);
`declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, paddr_width_p);
`declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_p, paddr_width_p, cce_block_size_in_bits_lp);
`declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p);
`declare_bp_cce_lce_data_cmd_s(num_cce_p, num_lce_p, paddr_width_p, cce_block_size_in_bits_lp, lce_assoc_p);
`declare_bp_lce_lce_tr_resp_s(num_lce_p, paddr_width_p, cce_block_size_in_bits_lp, lce_assoc_p);
`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   )

// Top-level interface connections
bp_fe_queue_s fe_fe_queue, be_fe_queue;
logic fe_fe_queue_v, be_fe_queue_v, fe_fe_queue_rdy, be_fe_queue_rdy;

logic fe_queue_clr, fe_queue_dequeue, fe_queue_rollback;

bp_fe_cmd_s fe_fe_cmd, be_fe_cmd;
logic fe_fe_cmd_v, be_fe_cmd_v, fe_fe_cmd_rdy, be_fe_cmd_rdy;

bp_lce_cce_req_s  lce_req, lce_cce_req;
logic  lce_cce_req_v, lce_cce_req_rdy;

bp_lce_cce_resp_s  lce_cce_resp;
logic  lce_cce_resp_v, lce_cce_resp_rdy;

bp_lce_cce_data_resp_s  lce_cce_data_resp;
logic  lce_cce_data_resp_v, lce_cce_data_resp_rdy;

bp_cce_lce_cmd_s  cce_lce_cmd;
logic  cce_lce_cmd_v, cce_lce_cmd_rdy;

bp_cce_lce_data_cmd_s  cce_lce_data_cmd;
logic  cce_lce_data_cmd_v, cce_lce_data_cmd_rdy;

bp_lce_lce_tr_resp_s  local_lce_tr_resp, remote_lce_tr_resp;
logic  local_lce_tr_resp_v, local_lce_tr_resp_rdy;
logic  remote_lce_tr_resp_v, remote_lce_tr_resp_rdy;

bp_proc_cfg_s proc_cfg;

logic [trace_data_width_p-1:0] trace_data;
logic [trace_addr_width_p-1:0] trace_addr;

logic [lg_boot_rom_els_lp-1:0] mrom_addr;
logic [boot_rom_width_p-1:0]   mrom_data;

bsg_nonsynth_clock_gen #(.cycle_time_p(10)
                         )
              clock_gen (.o(clk)
                         );

bsg_nonsynth_reset_gen #(.num_clocks_p(1)
                         ,.reset_cycles_lo_p(1)
                         ,.reset_cycles_hi_p(10)
                         )
               reset_gen(.clk_i(clk)
                         ,.async_reset_o(reset)
                         );

assign proc_cfg.mhartid = 1'b0;
assign proc_cfg.icache_id = 1'b0;
assign proc_cfg.dcache_id = 1'b1; // Unused

bp_fe_top
     #(.vaddr_width_p(vaddr_width_p)
       ,.paddr_width_p(paddr_width_p)
       ,.btb_indx_width_p(9)
       ,.bht_indx_width_p(5)
       ,.ras_addr_width_p(vaddr_width_p)
       ,.asid_width_p(10)
       ,.bp_first_pc_p(bp_pc_entry_point_gp) /* TODO: Not ideal to couple to RISCV-tests */

       ,.lce_sets_p(lce_sets_p)
       ,.lce_assoc_p(lce_assoc_p)
       ,.tag_width_p(10) /* TODO: This parameter should go away */
       ,.eaddr_width_p(64) /* '' */
       ,.inst_width_p(32) /* '' */
       ,.instr_width_p(32) /* '' */
       ,.data_width_p(64) /* '' */
       ,.num_cce_p(num_cce_p)
       ,.num_lce_p(num_lce_p)
       ,.block_size_in_bytes_p(8) /* TODO: This is ways not blocks (should be 64) */

       )
    fe(.clk_i(clk)
       ,.reset_i(reset)

       ,.icache_id_i(proc_cfg.icache_id)

       ,.bp_fe_queue_o(fe_fe_queue)
       ,.bp_fe_queue_v_o(fe_fe_queue_v)
       ,.bp_fe_queue_ready_i(fe_fe_queue_rdy)

       ,.bp_fe_cmd_i(fe_fe_cmd)
       ,.bp_fe_cmd_v_i(fe_fe_cmd_v)
       ,.bp_fe_cmd_ready_o(fe_fe_cmd_rdy)

       ,.lce_cce_req_o(lce_cce_req)
       ,.lce_cce_req_v_o(lce_cce_req_v)
       ,.lce_cce_req_ready_i(lce_cce_req_rdy)

       ,.lce_cce_resp_o(lce_cce_resp)
       ,.lce_cce_resp_v_o(lce_cce_resp_v)
       ,.lce_cce_resp_ready_i(lce_cce_resp_rdy)

       ,.lce_cce_data_resp_o(lce_cce_data_resp)
       ,.lce_cce_data_resp_v_o(lce_cce_data_resp_v)
       ,.lce_cce_data_resp_ready_i(lce_cce_data_resp_rdy)

       ,.cce_lce_cmd_i(cce_lce_cmd)
       ,.cce_lce_cmd_v_i(cce_lce_cmd_v)
       ,.cce_lce_cmd_ready_o(cce_lce_cmd_rdy)

       ,.cce_lce_data_cmd_i(cce_lce_data_cmd)
       ,.cce_lce_data_cmd_v_i(cce_lce_data_cmd_v)
       ,.cce_lce_data_cmd_ready_o(cce_lce_data_cmd_rdy)

       ,.lce_lce_tr_resp_i(local_lce_tr_resp)
       ,.lce_lce_tr_resp_v_i(local_lce_tr_resp_v)
       ,.lce_lce_tr_resp_ready_o(local_lce_tr_resp_rdy)

       ,.lce_lce_tr_resp_o(remote_lce_tr_resp)
       ,.lce_lce_tr_resp_v_o(remote_lce_tr_resp_v)
       ,.lce_lce_tr_resp_ready_i(remote_lce_tr_resp_rdy)
       );

    mock_be_trace #(
                 .vaddr_width_p(vaddr_width_p)
                 ,.paddr_width_p(paddr_width_p)
                 ,.asid_width_p(asid_width_p)
                 ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
                 ,.num_cce_p(num_cce_p)
                 ,.num_lce_p(num_lce_p)
                 ,.num_mem_p(num_mem_p)
                 ,.lce_assoc_p(lce_assoc_p)
                 ,.lce_sets_p(lce_sets_p)
                 ,.cce_block_size_in_bytes_p(cce_block_size_in_bytes_p)

                 ,.trace_addr_width_p(trace_addr_width_p)
                 ,.trace_data_width_p(trace_data_width_p)
		             ,.core_els_p(core_els_p)
                 )
              be(.clk_i(clk)
                 ,.reset_i(reset)

                 ,.bp_fe_queue_i(fe_fe_queue)
                 ,.bp_fe_queue_v_i(fe_fe_queue_v)
                 ,.bp_fe_queue_ready_o(fe_fe_queue_rdy)

                 ,.bp_fe_cmd_o(fe_fe_cmd)
                 ,.bp_fe_cmd_v_o(fe_fe_cmd_v)
                 ,.bp_fe_cmd_ready_i(fe_fe_cmd_rdy)

                 ,.trace_addr_o(trace_addr)
                 ,.trace_data_i(trace_data)
            );

    rv64ui_p_add_trace_rom #(.width_p  (trace_data_width_p)
            ,.addr_width_p(trace_addr_width_p)
            ) trace_rom(
	    .addr_i(trace_addr)
            ,.data_o(trace_data)
            );

bp_me_top 
 #(.num_lce_p(num_lce_p)
   ,.num_cce_p(num_cce_p)
   ,.addr_width_p(paddr_width_p)
   ,.lce_assoc_p(lce_assoc_p)
   ,.lce_sets_p(lce_sets_p)
   ,.block_size_in_bytes_p(cce_block_size_in_bytes_p)
   ,.num_inst_ram_els_p(cce_num_inst_ram_els_p)

   ,.boot_rom_els_p(boot_rom_els_p)
   ,.boot_rom_width_p(boot_rom_width_p)
   )
 me
  (.clk_i(clk)
   ,.reset_i(reset)

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

   ,.boot_rom_addr_o(mrom_addr)
   ,.boot_rom_data_i(mrom_data)
   );

bp_boot_rom 
 #(.width_p(boot_rom_width_p)
   ,.addr_width_p(lg_boot_rom_els_lp)
   ) 
 me_boot_rom 
  (.addr_i(mrom_addr)
   ,.data_o(mrom_data)
   );

endmodule : test_bp

