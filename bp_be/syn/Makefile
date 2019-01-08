## Top level source directory should include 
# bp_top, bp_fe, bp_be, bp_me, bp_common, bsg_ip_cores, verilator, systemc
TOP            = $(CURDIR)/../..
BP_TOP_PATH	   = $(TOP)/bp_top
BP_FE_PATH	   = $(TOP)/bp_fe
BP_BE_PATH	   = $(TOP)/bp_be
BP_ME_PATH 	   = $(TOP)/bp_me
BP_COMMON_PATH = $(TOP)/bp_common

CADENV_PATH    = $(TOP)/bsg_cadenv
BSG_IP_PATH	   = $(TOP)/bsg_ip_cores
VERILATOR_PATH = $(TOP)/verilator
SYSTEMC_PATH   = $(TOP)/systemc

SRC_PATH	= $(BP_BE_PATH)/v
TB_PATH		= $(BP_BE_PATH)/tb
SYN_PATH	= $(BP_BE_PATH)/syn

VTB_PATH    = $(TB_PATH)/v
SCTB_PATH   = $(TB_PATH)/sc

# All synthesizable sources 
# Nonsynth and test sources are added in tool-specific files
HDL_SOURCE = 										   			             \
			 $(BP_COMMON_PATH)/bp_common_pkg.vh	                             \
			 $(BP_COMMON_PATH)/bp_common_fe_be_if.vh                         \
			 $(BP_BE_PATH)/bp_dcache/include/bp_dcache_lce_pkg.vh 	         \
			 $(BP_BE_PATH)/bp_dcache/include/bp_dcache_pkg.vh 			     \
																             \
			 $(SRC_PATH)/bp_be_top.v                                         \
             $(SRC_PATH)/bp_be_checker.v                                     \
			 $(SRC_PATH)/bp_be_fe_adapter.v			                         \
			 $(SRC_PATH)/bp_be_calculator.v                                  \
			 $(SRC_PATH)/bp_be_instr_decoder.v                               \
			 $(SRC_PATH)/bp_be_calc_bypass.v		                         \
			 $(SRC_PATH)/bp_be_pipe_int.v                                    \
			 $(SRC_PATH)/bp_be_pipe_mul.v                                    \
			 $(SRC_PATH)/bp_be_pipe_mem.v                                    \
			 $(SRC_PATH)/bp_be_pipe_fp.v                                     \
			 $(SRC_PATH)/bp_be_mmu.v				                         \
			 $(SRC_PATH)/bp_be_int_alu.v                                     \
			 $(SRC_PATH)/bp_be_regfile.v			                         \
																			 \
			 $(BP_BE_PATH)/bp_dcache/v/bp_dcache.v							 \
			 $(BP_BE_PATH)/bp_dcache/v/bp_dcache_lce.v						 \
			 $(BP_BE_PATH)/bp_dcache/v/bp_dcache_lru_decode.v				 \
			 $(BP_BE_PATH)/bp_dcache/v/bp_dcache_lru_encode.v				 \
			 $(BP_BE_PATH)/bp_dcache/v/bp_dcache_wbuf_queue.v				 \
			 $(BP_BE_PATH)/bp_dcache/v/bp_dcache_wbuf.v				         \
			 $(BP_BE_PATH)/bp_dcache/v/bp_dcache_lce_cce_req.v				 \
			 $(BP_BE_PATH)/bp_dcache/v/bp_dcache_cce_lce_cmd.v				 \
			 $(BP_BE_PATH)/bp_dcache/v/bp_dcache_cce_lce_data_cmd.v		     \
			 $(BP_BE_PATH)/bp_dcache/v/bp_dcache_lce_lce_tr_resp_in.v		 \
			 										                         \
			 $(SRC_PATH)/bsg_decode.v                                        \
			 $(SRC_PATH)/bsg_dff_reset_en.v        	                         \
			 $(SRC_PATH)/bsg_fifo_1r1w_rolly.v		                         \
			 $(SRC_PATH)/bsg_circular_ptr_resval.v		                     \
			 $(SRC_PATH)/bsg_pipeline.v	                                     \
			 $(SRC_PATH)/bsg_scan.v 					                     \
			 													             \
			 $(BSG_IP_PATH)/bsg_dataflow/bsg_fifo_1r1w_small.v		         \
			 $(BSG_IP_PATH)/bsg_dataflow/bsg_fifo_tracker.v			         \
			 $(BSG_IP_PATH)/bsg_dataflow/bsg_shift_reg.v			         \
			 $(BSG_IP_PATH)/bsg_dataflow/bsg_two_fifo.v				         \
			 $(BSG_IP_PATH)/bsg_mem/bsg_mem_2r1w_sync_synth.v                \
			 $(BSG_IP_PATH)/bsg_mem/bsg_mem_1r1w.v		                     \
			 $(BSG_IP_PATH)/bsg_mem/bsg_mem_1r1w_sync.v						 \
			 $(BSG_IP_PATH)/bsg_mem/bsg_mem_1r1w_sync_synth.v		         \
			 $(BSG_IP_PATH)/bsg_mem/bsg_mem_1r1w_synth.v		             \
			 $(BSG_IP_PATH)/bsg_mem/bsg_mem_1rw_sync.v					     \
			 $(BSG_IP_PATH)/bsg_mem/bsg_mem_1rw_sync_synth.v			     \
			 $(BSG_IP_PATH)/bsg_mem/bsg_mem_1rw_sync_mask_write_bit_synth.v	 \
			 $(BSG_IP_PATH)/bsg_mem/bsg_mem_1rw_sync_mask_write_bit.v	     \
			 $(BSG_IP_PATH)/bsg_mem/bsg_mem_1rw_sync_mask_write_byte.v	 	 \
			 $(BSG_IP_PATH)/bsg_mem/bsg_mem_1rw_sync_mask_write_byte_synth.v \
			 $(BSG_IP_PATH)/bsg_misc/bsg_adder_ripple_carry.v  	             \
			 $(BSG_IP_PATH)/bsg_misc/bsg_circular_ptr.v			             \
			 $(BSG_IP_PATH)/bsg_misc/bsg_counter_clear_up.v		             \
			 $(BSG_IP_PATH)/bsg_misc/bsg_crossbar_o_by_i.v     	             \
			 $(BSG_IP_PATH)/bsg_misc/bsg_decode_with_v.v      	             \
			 $(BSG_IP_PATH)/bsg_misc/bsg_dff.v                 	             \
			 $(BSG_IP_PATH)/bsg_misc/bsg_dff_chain.v           	             \
			 $(BSG_IP_PATH)/bsg_misc/bsg_dff_en.v              	             \
			 $(BSG_IP_PATH)/bsg_misc/bsg_dff_reset.v        	             \
			 $(BSG_IP_PATH)/bsg_misc/bsg_encode_one_hot.v					 \
			 $(BSG_IP_PATH)/bsg_misc/bsg_mux.v                 	             \
			 $(BSG_IP_PATH)/bsg_misc/bsg_mux_one_hot.v         	             \
			 $(BSG_IP_PATH)/bsg_misc/bsg_mux_segmented.v      	             \
			 $(BSG_IP_PATH)/bsg_misc/bsg_priority_encode_one_hot_out.v       \
			 $(BSG_IP_PATH)/bsg_misc/bsg_priority_encode.v					 \
			 $(BSG_IP_PATH)/bsg_fsb/bsg_fsb_node_trace_replay.v				 \
	
# Tests that all BP repos are present
test_env:
		[ -d $(BP_TOP_PATH)    ] && [ -d $(BP_FE_PATH)      ] && \
		[ -d $(BP_BE_PATH)     ] && [ -d $(BP_ME_PATH)      ] && \
		[ -d $(COMMON_PATH)    ] && [ -d $(BSG_IP_PATH)     ] && \
		[ -d $(CADENV_PATH)	   ] && [ -d $(VERILATOR_PATH)  ] && \
		[ -d $(SYSTEMC_PATH)   ] && 							 \
		echo "BP environment correctly set up!"

clean:
	rm -rf $(SYN_PATH)/obj_dir
	rm -rf csrc
	rm -rf ucli.key
	rm -rf inter.vpd
	rm -rf DVEfiles
	rm -rf *vpd
	rm -rf *simv
	rm -rf *simv.daidir

include	$(SYN_PATH)/Makefile.verilator

include $(SYN_PATH)/Makefile.vcs

