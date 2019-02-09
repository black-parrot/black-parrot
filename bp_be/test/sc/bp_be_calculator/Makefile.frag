HDL_SOURCE=bp_be_calculator.v       \
			bp_be_instr_decoder.v    \
			bp_be_pipe_int.v         \
			bp_be_int_alu.v          \
			bsg_pipeline.v	         \
			bsg_decode.v             \
			bsg_mux.v                \
			bsg_dff.v                \
			bsg_dff_reset.v          \
			bsg_adder_ripple_carry.v 

HDL_PARAMS=-pvalue+branch_metadata_fwd_width_p=74

