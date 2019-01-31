if [ "rv64ui_p_add_rom.v" != "bp_be_boot_rom.v" ]; then						    \
		ln -sf /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_top/test/rom/v/rv64ui_p_add_rom.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_top/test/rom/v/bp_be_boot_rom.v;	\
	fi;
\
	vcs +notimingcheck +vcs+loopdetect +vcs+loopreport -timescale=1ps/1ps -full64 +v2k +vc -sverilog -debug_pp +vcs+lic+wait +multisource_int_delays +neg_tchk +libext+.v+.vlib+.vh +vcs+finish+1000000ps +incdir+/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common +incdir+/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v +incdir+/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_top/test/tb +incdir+/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/include +incdir+/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/testing/v +incdir+/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v +incdir+/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include +incdir+/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_dataflow +incdir+/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem +incdir+/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc +incdir+/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_test +incdir+/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_noc -o /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_top/test/tb/bp_single_demo/simv -top test_bp               \
		/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_pkg.vh /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/include/bp_dcache_lce_pkg.vh /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/include/bp_dcache_pkg.vh /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_top.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_checker.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_fe_adapter.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_calculator.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_instr_decoder.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_calc_bypass.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_int.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_mul.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_mem.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_fp.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_mmu.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_int_alu.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_regfile.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_lce.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_lru_decode.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_lru_encode.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_wbuf_queue.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_wbuf.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_lce_cce_req.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_cce_lce_cmd.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_cce_lce_data_cmd.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_lce_lce_tr_resp_in.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_decode.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_dff_reset_en.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_fifo_1r1w_rolly.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_circular_ptr_resval.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_pipeline.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_scan.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_dataflow/bsg_fifo_1r1w_small.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_dataflow/bsg_fifo_tracker.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_dataflow/bsg_shift_reg.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_dataflow/bsg_two_fifo.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_2r1w_sync_synth.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1r1w.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1r1w_sync.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1r1w_sync_synth.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1r1w_synth.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1rw_sync.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1rw_sync_synth.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1rw_sync_mask_write_bit_synth.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1rw_sync_mask_write_bit.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1rw_sync_mask_write_byte.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1rw_sync_mask_write_byte_synth.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_adder_ripple_carry.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_circular_ptr.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_counter_clear_up.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_crossbar_o_by_i.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_decode_with_v.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_dff.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_dff_chain.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_dff_en.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_dff_reset.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_encode_one_hot.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_mux.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_mux_one_hot.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_mux_segmented.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_priority_encode_one_hot_out.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_priority_encode.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_fsb/bsg_fsb_node_trace_replay.v  /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/roms/demo-v2/bp_cce_inst_rom_demo-v2_lce2_wg16_assoc8.v -pvalue+vaddr_width_p=22 -pvalue+paddr_width_p=22 -pvalue+asid_width_p=10 -pvalue+branch_metadata_fwd_width_p=36 -pvalue+core_els_p=1 -pvalue+num_cce_p=1 -pvalue+num_lce_p=2 -pvalue+num_mem_p=1 -pvalue+coh_states_p=4 -pvalue+lce_sets_p=16 -pvalue+cce_block_size_in_bytes_p=64 -pvalue+cce_num_inst_ram_els_p=256 -pvalue+lce_assoc_p=8 -pvalue+boot_rom_els_p=512 -pvalue+boot_rom_width_p=512  /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_pc_gen_pkg.vh /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_itlb_pkg.vh /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_lce.vh /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_pc_gen.vh /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_icache.vh /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_top.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_itlb.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_branch_predictor.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_pc_gen.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_icache.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_lce.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_cce_lce_cmd.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_cce_lce_data_cmd.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_lce_cce_req.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_lce_lce_tr_resp_in.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_bht.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_btb.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_instr_scan.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_inst_pkg.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_noc/bsg_noc_pkg.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/test/common/bp_me_top.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_top.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_alu.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_dir.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_gad.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_inst_decode.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_pc.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_reg.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/network/bp_coherence_network.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/network/bp_coherence_network_channel.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_noc/bsg_mesh_router_buffered.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_noc/bsg_mesh_router.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_round_robin_arb.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_test/bsg_nonsynth_clock_gen.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_test/bsg_nonsynth_reset_gen.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_top_wrapper.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_multi_wrapper.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_top_wrapper.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe_top_wrapper.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe_trace.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_mmu.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_tracer.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_multi_nonsynth_mock_fe_top_wrapper.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/testing/v/mock_tlb.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/test/common/bp_cce_test.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/test/common/bp_mem.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_top/test/rom/v/bp_be_boot_rom.v  /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_top/test/tb/bp_single_demo/test_bp.v
                         Chronologic VCS (TM)
     Version L-2016.06-SP2-15_Full64 -- Sat Jan 26 22:00:48 2019
               Copyright (c) 1991-2016 by Synopsys Inc.
                         ALL RIGHTS RESERVED

This program is proprietary and confidential information of Synopsys Inc.
and may be used and disclosed only as authorized in a license agreement
controlling such use and disclosure.

Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_pkg.vh'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/include/bp_dcache_lce_pkg.vh'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/include/bp_dcache_pkg.vh'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_top.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_top.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_top.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_top.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_rv_defines.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.

Note-[SV-LCM-PPWI] Package previously wildcard imported
/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh, 16
$unit
  Package 'bp_common_pkg' already wildcard imported. 
  Ignoring bp_common_pkg::*
  See the System Verilog LRM(1800-2005), section 18.1.

Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_top.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_checker.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_checker.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_checker.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_fe_adapter.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_fe_adapter.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_fe_adapter.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_fe_adapter.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_rv_defines.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_fe_adapter.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_fe_adapter.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_calculator.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_calculator.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_calculator.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_instr_decoder.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_instr_decoder.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_rv_defines.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_instr_decoder.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_instr_decoder.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_calc_bypass.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_calc_bypass.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_calc_bypass.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_int.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_int.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_int.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_mul.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_mul.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_mul.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_mem.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_mem.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_mem.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_fp.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_fp.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_fp.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_mmu.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_mmu.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_mmu.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_mmu.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/include/bp_dcache_pkt.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_mmu.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_int_alu.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_int_alu.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_int_alu.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_regfile.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_regfile.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/include/bp_dcache_pkt.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/include/bp_dcache_lce_pkt.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_lce.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/include/bp_dcache_lce_pkt.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_lce.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_lce.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_lru_decode.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_lru_encode.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_wbuf_queue.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_wbuf.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_lce_cce_req.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_lce_cce_req.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_cce_lce_cmd.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_cce_lce_data_cmd.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_lce_lce_tr_resp_in.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_decode.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_decode.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_dff_reset_en.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_fifo_1r1w_rolly.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_fifo_1r1w_rolly.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_circular_ptr_resval.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_circular_ptr_resval.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_pipeline.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_pipeline.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_scan.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_dataflow/bsg_fifo_1r1w_small.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_dataflow/bsg_fifo_tracker.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_dataflow/bsg_shift_reg.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_dataflow/bsg_two_fifo.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_2r1w_sync_synth.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1r1w.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1r1w_sync.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1r1w_sync_synth.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1r1w_synth.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1rw_sync.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1rw_sync_synth.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1rw_sync_mask_write_bit_synth.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1rw_sync_mask_write_bit.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1rw_sync_mask_write_byte.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1rw_sync_mask_write_byte_synth.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_adder_ripple_carry.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_circular_ptr.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_circular_ptr.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_counter_clear_up.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_crossbar_o_by_i.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_decode_with_v.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_dff.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_dff_chain.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_dff_en.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_dff_reset.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_encode_one_hot.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_mux.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_mux.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_mux_one_hot.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_mux_segmented.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_priority_encode_one_hot_out.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_priority_encode.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_fsb/bsg_fsb_node_trace_replay.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_fsb/bsg_fsb_node_trace_replay.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/roms/demo-v2/bp_cce_inst_rom_demo-v2_lce2_wg16_assoc8.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_pc_gen_pkg.vh'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_itlb_pkg.vh'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_lce.vh'

Note-[SV-LCM-PPWI] Package previously wildcard imported
/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_lce.vh, 14
$unit
  Package 'bp_common_pkg' already wildcard imported. 
  Ignoring bp_common_pkg::*
  See the System Verilog LRM(1800-2005), section 18.1.

Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_pc_gen.vh'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_pc_gen.vh'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_icache.vh'

Note-[SV-LCM-PPWI] Package previously wildcard imported
/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_icache.vh, 17
$unit
  Package 'bp_common_pkg' already wildcard imported. 
  Ignoring bp_common_pkg::*
  See the System Verilog LRM(1800-2005), section 18.1.

Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_top.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_itlb.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_top.v'.

Note-[SV-LCM-PPWI] Package previously wildcard imported
/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_top.v, 29
$unit
  Package 'pc_gen_pkg' already wildcard imported. 
  Ignoring pc_gen_pkg::*
  See the System Verilog LRM(1800-2005), section 18.1.


Error-[IND] Identifier not declared
/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_top.v, 131
  Identifier 'branch_metadata_fwd_width_p' has not been declared yet. If this 
  error is not expected, please check if you have set `default_nettype to 
  none.
  

Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_itlb.v'

Note-[SV-LCM-PPWI] Package previously wildcard imported
/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_itlb.v, 32
$unit
  Package 'itlb_pkg' already wildcard imported. 
  Ignoring itlb_pkg::*
  See the System Verilog LRM(1800-2005), section 18.1.

Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_branch_predictor.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_pc_gen.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_icache.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_lce.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_cce_lce_cmd.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_cce_lce_data_cmd.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_lce_cce_req.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_lce_lce_tr_resp_in.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_bht.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_btb.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_instr_scan.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_inst_pkg.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_inst_pkg.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_noc/bsg_noc_pkg.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/test/common/bp_me_top.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_top.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_top.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_top.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_inst_pkg.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_top.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_internal_if.vh'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_internal_if.vh'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_inst_pkg.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_top.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_alu.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_alu.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_inst_pkg.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_alu.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_dir.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_dir.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_inst_pkg.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_dir.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_gad.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_inst_pkg.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_gad.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_gad.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_inst_decode.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_inst_decode.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_inst_decode.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_inst_pkg.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_inst_decode.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_inst_decode.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_pc.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_pc.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_inst_pkg.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_pc.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_reg.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_reg.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_reg.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_inst_pkg.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_reg.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_reg.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_inst_pkg.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/network/bp_coherence_network.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/network/bp_coherence_network.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/network/bp_coherence_network.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/network/bp_coherence_network_channel.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_noc/bsg_noc_links.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/network/bp_coherence_network_channel.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/network/bp_coherence_network_channel.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_noc/bsg_mesh_router_buffered.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_noc/bsg_noc_links.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_noc/bsg_mesh_router_buffered.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_noc/bsg_mesh_router.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_round_robin_arb.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_test/bsg_nonsynth_clock_gen.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_test/bsg_nonsynth_reset_gen.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_top_wrapper.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_top_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_top_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_top_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_top_wrapper.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_multi_wrapper.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_multi_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_multi_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_multi_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_multi_wrapper.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_top_wrapper.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_top_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_top_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_top_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_top_wrapper.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe_top_wrapper.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe_top_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe_top_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe_top_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe_top_wrapper.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_rv_defines.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe_trace.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe_trace.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_rv_defines.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe_trace.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_mmu.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_mmu.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_mmu.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_mmu.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_rv_defines.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_mmu.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_tracer.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_tracer.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_tracer.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_tracer.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_rv_defines.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_tracer.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_multi_nonsynth_mock_fe_top_wrapper.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_multi_nonsynth_mock_fe_top_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_multi_nonsynth_mock_fe_top_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_multi_nonsynth_mock_fe_top_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_multi_nonsynth_mock_fe_top_wrapper.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/testing/v/mock_tlb.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/test/common/bp_cce_test.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/test/common/bp_cce_test.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/test/common/bp_mem.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/test/common/bp_mem.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/test/common/bp_mem.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_inst_pkg.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/test/common/bp_mem.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/test/common/bp_mem.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_top/test/rom/v/bp_be_boot_rom.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_top/test/tb/bp_single_demo/test_bp.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_top/test/tb/bp_single_demo/test_bp.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_top/test/tb/bp_single_demo/test_bp.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_top/test/tb/bp_single_demo/test_bp.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_top/test/tb/bp_single_demo/test_bp.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_rv_defines.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_top/test/tb/bp_single_demo/test_bp.v'.
1 error
CPU time: .434 seconds to compile
if [ "rv64ui_p_add_rom.v" != "bp_be_boot_rom.v" ]; then						    \
		ln -sf /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_top/test/rom/v/rv64ui_p_add_rom.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_top/test/rom/v/bp_be_boot_rom.v;	\
	fi;
\
	vcs +notimingcheck +vcs+loopdetect +vcs+loopreport -timescale=1ps/1ps -full64 +v2k +vc -sverilog -debug_pp +vcs+lic+wait +multisource_int_delays +neg_tchk +libext+.v+.vlib+.vh +vcs+finish+1000000ps +incdir+/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common +incdir+/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v +incdir+/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_top/test/tb +incdir+/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/include +incdir+/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/testing/v +incdir+/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v +incdir+/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include +incdir+/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_dataflow +incdir+/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem +incdir+/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc +incdir+/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_test +incdir+/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_noc -o /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_top/test/tb/bp_single_demo/simv -top test_bp               \
		/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_pkg.vh /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/include/bp_dcache_lce_pkg.vh /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/include/bp_dcache_pkg.vh /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_top.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_checker.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_fe_adapter.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_calculator.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_instr_decoder.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_calc_bypass.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_int.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_mul.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_mem.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_fp.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_mmu.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_int_alu.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_regfile.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_lce.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_lru_decode.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_lru_encode.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_wbuf_queue.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_wbuf.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_lce_cce_req.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_cce_lce_cmd.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_cce_lce_data_cmd.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_lce_lce_tr_resp_in.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_decode.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_dff_reset_en.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_fifo_1r1w_rolly.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_circular_ptr_resval.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_pipeline.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_scan.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_dataflow/bsg_fifo_1r1w_small.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_dataflow/bsg_fifo_tracker.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_dataflow/bsg_shift_reg.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_dataflow/bsg_two_fifo.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_2r1w_sync_synth.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1r1w.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1r1w_sync.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1r1w_sync_synth.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1r1w_synth.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1rw_sync.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1rw_sync_synth.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1rw_sync_mask_write_bit_synth.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1rw_sync_mask_write_bit.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1rw_sync_mask_write_byte.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1rw_sync_mask_write_byte_synth.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_adder_ripple_carry.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_circular_ptr.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_counter_clear_up.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_crossbar_o_by_i.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_decode_with_v.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_dff.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_dff_chain.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_dff_en.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_dff_reset.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_encode_one_hot.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_mux.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_mux_one_hot.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_mux_segmented.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_priority_encode_one_hot_out.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_priority_encode.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_fsb/bsg_fsb_node_trace_replay.v  /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/roms/demo-v2/bp_cce_inst_rom_demo-v2_lce2_wg16_assoc8.v -pvalue+vaddr_width_p=22 -pvalue+paddr_width_p=22 -pvalue+asid_width_p=10 -pvalue+branch_metadata_fwd_width_p=36 -pvalue+core_els_p=1 -pvalue+num_cce_p=1 -pvalue+num_lce_p=2 -pvalue+num_mem_p=1 -pvalue+coh_states_p=4 -pvalue+lce_sets_p=16 -pvalue+cce_block_size_in_bytes_p=64 -pvalue+cce_num_inst_ram_els_p=256 -pvalue+lce_assoc_p=8 -pvalue+boot_rom_els_p=512 -pvalue+boot_rom_width_p=512  /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_pc_gen_pkg.vh /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_itlb_pkg.vh /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_lce.vh /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_pc_gen.vh /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_icache.vh /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_top.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_itlb.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_branch_predictor.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_pc_gen.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_icache.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_lce.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_cce_lce_cmd.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_cce_lce_data_cmd.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_lce_cce_req.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_lce_lce_tr_resp_in.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_bht.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_btb.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_instr_scan.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_inst_pkg.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_noc/bsg_noc_pkg.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/test/common/bp_me_top.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_top.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_alu.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_dir.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_gad.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_inst_decode.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_pc.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_reg.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/network/bp_coherence_network.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/network/bp_coherence_network_channel.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_noc/bsg_mesh_router_buffered.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_noc/bsg_mesh_router.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_round_robin_arb.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_test/bsg_nonsynth_clock_gen.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_test/bsg_nonsynth_reset_gen.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_top_wrapper.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_multi_wrapper.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_top_wrapper.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe_top_wrapper.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe_trace.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_mmu.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_tracer.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_multi_nonsynth_mock_fe_top_wrapper.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/testing/v/mock_tlb.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/test/common/bp_cce_test.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/test/common/bp_mem.v /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_top/test/rom/v/bp_be_boot_rom.v  /usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_top/test/tb/bp_single_demo/test_bp.v
                         Chronologic VCS (TM)
     Version L-2016.06-SP2-15_Full64 -- Sat Jan 26 22:11:20 2019
               Copyright (c) 1991-2016 by Synopsys Inc.
                         ALL RIGHTS RESERVED

This program is proprietary and confidential information of Synopsys Inc.
and may be used and disclosed only as authorized in a license agreement
controlling such use and disclosure.

Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_pkg.vh'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/include/bp_dcache_lce_pkg.vh'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/include/bp_dcache_pkg.vh'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_top.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_top.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_top.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_top.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_rv_defines.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.

Note-[SV-LCM-PPWI] Package previously wildcard imported
/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh, 16
$unit
  Package 'bp_common_pkg' already wildcard imported. 
  Ignoring bp_common_pkg::*
  See the System Verilog LRM(1800-2005), section 18.1.

Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_top.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_checker.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_checker.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_checker.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_fe_adapter.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_fe_adapter.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_fe_adapter.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_fe_adapter.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_rv_defines.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_fe_adapter.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_fe_adapter.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_calculator.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_calculator.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_calculator.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_instr_decoder.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_instr_decoder.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_rv_defines.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_instr_decoder.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_instr_decoder.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_calc_bypass.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_calc_bypass.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_calc_bypass.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_int.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_int.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_int.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_mul.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_mul.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_mul.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_mem.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_mem.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_mem.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_fp.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_fp.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_pipe_fp.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_mmu.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_mmu.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_mmu.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_mmu.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/include/bp_dcache_pkt.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_mmu.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_int_alu.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_int_alu.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_int_alu.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_regfile.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_regfile.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/include/bp_dcache_pkt.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/include/bp_dcache_lce_pkt.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_lce.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/include/bp_dcache_lce_pkt.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_lce.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_lce.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_lru_decode.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_lru_encode.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_wbuf_queue.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_wbuf.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_lce_cce_req.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_lce_cce_req.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_cce_lce_cmd.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_cce_lce_data_cmd.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/v/bp_dcache_lce_lce_tr_resp_in.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_decode.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_decode.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_dff_reset_en.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_fifo_1r1w_rolly.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_fifo_1r1w_rolly.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_circular_ptr_resval.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_circular_ptr_resval.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_pipeline.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_pipeline.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bsg_scan.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_dataflow/bsg_fifo_1r1w_small.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_dataflow/bsg_fifo_tracker.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_dataflow/bsg_shift_reg.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_dataflow/bsg_two_fifo.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_2r1w_sync_synth.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1r1w.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1r1w_sync.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1r1w_sync_synth.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1r1w_synth.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1rw_sync.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1rw_sync_synth.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1rw_sync_mask_write_bit_synth.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1rw_sync_mask_write_bit.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1rw_sync_mask_write_byte.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_mem/bsg_mem_1rw_sync_mask_write_byte_synth.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_adder_ripple_carry.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_circular_ptr.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_circular_ptr.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_counter_clear_up.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_crossbar_o_by_i.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_decode_with_v.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_dff.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_dff_chain.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_dff_en.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_dff_reset.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_encode_one_hot.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_mux.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_mux.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_mux_one_hot.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_mux_segmented.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_priority_encode_one_hot_out.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_priority_encode.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_fsb/bsg_fsb_node_trace_replay.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_fsb/bsg_fsb_node_trace_replay.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/roms/demo-v2/bp_cce_inst_rom_demo-v2_lce2_wg16_assoc8.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_pc_gen_pkg.vh'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_itlb_pkg.vh'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_lce.vh'

Note-[SV-LCM-PPWI] Package previously wildcard imported
/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_lce.vh, 14
$unit
  Package 'bp_common_pkg' already wildcard imported. 
  Ignoring bp_common_pkg::*
  See the System Verilog LRM(1800-2005), section 18.1.

Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_pc_gen.vh'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_pc_gen.vh'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_icache.vh'

Note-[SV-LCM-PPWI] Package previously wildcard imported
/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_icache.vh, 17
$unit
  Package 'bp_common_pkg' already wildcard imported. 
  Ignoring bp_common_pkg::*
  See the System Verilog LRM(1800-2005), section 18.1.

Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_top.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/include/bp_fe_itlb.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_top.v'.

Note-[SV-LCM-PPWI] Package previously wildcard imported
/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_top.v, 29
$unit
  Package 'pc_gen_pkg' already wildcard imported. 
  Ignoring pc_gen_pkg::*
  See the System Verilog LRM(1800-2005), section 18.1.


Error-[IND] Identifier not declared
/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_top.v, 132
  Identifier 'branch_metadata_fwd_width_p' has not been declared yet. If this 
  error is not expected, please check if you have set `default_nettype to 
  none.
  

Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_itlb.v'

Note-[SV-LCM-PPWI] Package previously wildcard imported
/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_itlb.v, 32
$unit
  Package 'itlb_pkg' already wildcard imported. 
  Ignoring itlb_pkg::*
  See the System Verilog LRM(1800-2005), section 18.1.

Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_branch_predictor.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_pc_gen.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_icache.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_lce.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_cce_lce_cmd.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_cce_lce_data_cmd.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_lce_cce_req.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_lce_lce_tr_resp_in.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_bht.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_btb.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_fe/src/v/bp_fe_instr_scan.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_inst_pkg.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_inst_pkg.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_noc/bsg_noc_pkg.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/test/common/bp_me_top.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_top.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_top.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_top.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_inst_pkg.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_top.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_internal_if.vh'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_internal_if.vh'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_inst_pkg.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_top.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_alu.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_alu.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_inst_pkg.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_alu.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_dir.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_dir.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_inst_pkg.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_dir.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_gad.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_inst_pkg.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_gad.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_gad.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_inst_decode.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_inst_decode.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_inst_decode.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_inst_pkg.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_inst_decode.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_inst_decode.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_pc.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_pc.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_inst_pkg.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_pc.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_reg.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_reg.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_reg.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_inst_pkg.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_reg.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce_reg.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_inst_pkg.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/cce/bp_cce.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/network/bp_coherence_network.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/network/bp_coherence_network.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/network/bp_coherence_network.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/network/bp_coherence_network_channel.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_noc/bsg_noc_links.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/network/bp_coherence_network_channel.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/v/network/bp_coherence_network_channel.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_noc/bsg_mesh_router_buffered.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_noc/bsg_noc_links.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_noc/bsg_mesh_router_buffered.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_noc/bsg_mesh_router.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_round_robin_arb.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_test/bsg_nonsynth_clock_gen.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_test/bsg_nonsynth_reset_gen.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_top_wrapper.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_top_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_top_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_top_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_top_wrapper.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_multi_wrapper.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_multi_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_multi_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_multi_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_multi_wrapper.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_top_wrapper.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_top_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_top_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_top_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_top_wrapper.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe_top_wrapper.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe_top_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe_top_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe_top_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe_top_wrapper.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_rv_defines.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe_trace.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe_trace.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_rv_defines.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_fe_trace.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_mmu.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_mmu.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_mmu.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_mmu.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_rv_defines.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_mock_mmu.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_tracer.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_tracer.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_tracer.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_tracer.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_rv_defines.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_be_nonsynth_tracer.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_multi_nonsynth_mock_fe_top_wrapper.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_multi_nonsynth_mock_fe_top_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_multi_nonsynth_mock_fe_top_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_multi_nonsynth_mock_fe_top_wrapper.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/tb/common/bp_multi_nonsynth_mock_fe_top_wrapper.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/bp_dcache/testing/v/mock_tlb.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/test/common/bp_cce_test.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/test/common/bp_cce_test.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/test/common/bp_mem.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/test/common/bp_mem.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/test/common/bp_mem.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_inst_pkg.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/test/common/bp_mem.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/src/include/v/bp_cce_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_me/test/common/bp_mem.v'.
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_top/test/rom/v/bp_be_boot_rom.v'
Parsing design file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_top/test/tb/bp_single_demo/test_bp.v'
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bsg_ip_cores/bsg_misc/bsg_defines.v'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_top/test/tb/bp_single_demo/test_bp.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_fe_be_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_top/test/tb/bp_single_demo/test_bp.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_common/bp_common_me_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_top/test/tb/bp_single_demo/test_bp.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_internal_if.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_top/test/tb/bp_single_demo/test_bp.v'.
Parsing included file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_be/v/bp_be_rv_defines.vh'.
Back to file '/usr3/graduate/fe/pymtl/clean_code_cleanup/pre-alpha-release/bp_top/syn/../../bp_top/test/tb/bp_single_demo/test_bp.v'.
1 error
CPU time: .419 seconds to compile
