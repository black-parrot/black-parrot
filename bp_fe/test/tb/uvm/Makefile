TOP ?= $(shell git rev-parse --show-toplevel)

# Include files for bp dependencies
include $(TOP)/Makefile.common

# Include directories to resolve cache dependencies
BP_UVM_DIR := $(BP_FE_DIR)/test/tb/uvm

# Original vcs command for icache testbench
#vcs -full64              -notice -V +v2k  -debug_access+all -sverilog  -assert svaext       +noportcoerce -timescale=1ps/1ps   -diag timescale -CFLAGS "-I/projectnb2/risc-v/chath/black-parrot-sim/rtl/tools/install/include -std=c++14 -I /projectnb2/risc-v/chath/black-parrot-sim/rtl/external/basejump_stl/bsg_test" -LDFLAGS "-L/projectnb2/risc-v/chath/black-parrot-sim/rtl/tools/install/lib -ldramsim3 -Wl,-rpath=/projectnb2/risc-v/chath/black-parrot-sim/rtl/tools/install/lib" +lint=TFIPC-L +plusarg_save /projectnb2/risc-v/chath/black-parrot-sim/rtl/tools/install/lib/libdromajo_cosim.a -top testbench -f flist.vcs +vcs+finish+5ms  +vcs+lic+wait               +libext+.v+.vlib+.vh         -pvalue+uce_p=1 -pvalue+cce_trace_p=0 -pvalue+lce_trace_p=0 -pvalue+dram_trace_p=0 -pvalue+icache_trace_p=0  +define+BP_SIM_CLK_PERIOD=1000 +define+den2048Mb+sg5+x16+FULL_MEM -o /projectnb2/risc-v/chath/black-parrot-sim/rtl/bp_fe/syn/results/vcs/bp_fe_icache.e_bp_test_unicore_half_cfg.none.build/simv 2>&1 | tee /projectnb2/risc-v/chath/black-parrot-sim/rtl/bp_fe/syn/logs/vcs/bp_fe_icache.e_bp_test_unicore_half_cfg.none.build.log

# All the uvm files directly sourced
#$(BP_DV_DIR)/bp_be_dcache_uvm_cfg_pkg.sv $(BP_DV_DIR)/bp_be_dcache_uvm_seq_pkg.sv $(BP_DV_DIR)/bp_be_dcache_uvm_subs_pkg.sv $(BP_DV_DIR)/bp_be_dcache_uvm_comp_pkg.sv $(BP_DV_DIR)/bp_be_dcache_uvm_tests_pkg.sv

# VCS options for BP
include $(BP_COMMON_DIR)/syn/Makefile.common
#include $(BP_COMMON_DIR)/syn/Makefile.vcs ##NOT WORKING?

all: clean comp run cov

clean:
	rm -rf simv* csrc *.log vc_hdrs.h ucli.key urg* *.vpd

comp:
	vcs -full64 -notice -V -debug_access+all -sverilog -assert svaext -timescale=1ns/10ps -ntb_opts uvm-1.2 +lint=TFIPC-L -f flist.vcs $(BP_UVM_DIR)/icache_uvm_top.sv -l comp.log -R +define+BP_SIM_CLK_PERIOD=1000 +vcs+vcdpluson

run:
	simv +UVM_NO_RELNOTES +UVM_VERBOSITY=UVM_LOW -l run.log

cov:
	urg -dir simv.vdb 
