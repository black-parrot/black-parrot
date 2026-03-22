## UVM Testbench Makefile for bp_be_pipe_int
## Requires: Verilator 5.020+ with UVM support

TOP      ?= $(shell git -C $(dir $(abspath $(lastword $(MAKEFILE_LIST)))) rev-parse --show-toplevel)
BP_DIR   ?= $(TOP)
UVM_DIR  ?= $(BP_DIR)/external/uvm
TB_DIR   := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Source flists
BP_FLIST := $(BP_DIR)/bp_be/flist.vcs

# UVM library
UVM_PKG  := $(UVM_DIR)/src/uvm_pkg.sv
UVM_INC  := +incdir+$(UVM_DIR)/src

# Verilator flags
VV       := verilator
VV_FLAGS := --binary --timing --sv \
            --top-module bp_be_pipe_int_tb_top \
            -Wno-WIDTHCONCAT -Wno-UNOPTFLAT \
            +define+UVM_NO_DPI \
            $(UVM_INC) \
            +incdir+$(BP_DIR)/bp_common/src/include \
            +incdir+$(BP_DIR)/bp_be/src/include \
            +incdir+$(BP_DIR)/external/basejump_stl/bsg_misc \
            +incdir+$(BP_DIR)/external/HardFloat/source/RISCV \
            -f $(BP_FLIST)

RESULTS_DIR := $(TB_DIR)/results
SIM_BIN     := $(RESULTS_DIR)/obj_dir/Vbp_be_pipe_int_tb_top

.PHONY: build sim sim_rand sim_alu sim_branch sim_flush clean help

## Build the simulation binary
build: $(SIM_BIN)

$(SIM_BIN): $(TB_DIR)/*.sv
	mkdir -p $(RESULTS_DIR)
	$(VV) $(VV_FLAGS) \
	  -o $(SIM_BIN) \
	  $(UVM_PKG) \
	  $(TB_DIR)/bp_be_pipe_int_tb_top.sv \
	  --Mdir $(RESULTS_DIR)/obj_dir

## Run tests
sim_rand: build
	$(SIM_BIN) +UVM_TESTNAME=bp_be_pipe_int_rand_test \
	           +UVM_VERBOSITY=UVM_MEDIUM \
	           | tee $(RESULTS_DIR)/rand_test.log

sim_alu: build
	$(SIM_BIN) +UVM_TESTNAME=bp_be_pipe_int_alu_test \
	           +UVM_VERBOSITY=UVM_MEDIUM \
	           | tee $(RESULTS_DIR)/alu_test.log

sim_branch: build
	$(SIM_BIN) +UVM_TESTNAME=bp_be_pipe_int_branch_test \
	           +UVM_VERBOSITY=UVM_MEDIUM \
	           | tee $(RESULTS_DIR)/branch_test.log

sim_flush: build
	$(SIM_BIN) +UVM_TESTNAME=bp_be_pipe_int_flush_test \
	           +UVM_VERBOSITY=UVM_MEDIUM \
	           | tee $(RESULTS_DIR)/flush_test.log

## Run all tests
sim: sim_rand sim_alu sim_branch sim_flush
	@echo "================================================"
	@echo "All UVM tests complete. Check results/ for logs."
	@echo "================================================"

clean:
	rm -rf $(RESULTS_DIR)

help:
	@echo "Targets: build | sim_rand | sim_alu | sim_branch | sim_flush | sim | clean"
