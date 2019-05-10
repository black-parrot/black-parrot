## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

SPIKE_MOD_PATH = $(BP_EXTERNAL_DIR)/bin

TEST_DIR       = $(BP_COMMON_DIR)/test
MEM_DIR        = $(TEST_DIR)/mem

RISCV_SIM      = spike
RISCV_OBJDUMP  = riscv64-unknown-elf-objdump -D -M no-aliases,numeric
RISCV_OBJCOPY  = riscv64-unknown-elf-objcopy -O verilog

include Makefile.frag

all: riscv demos
riscv: riscv_mem 
opensbi: opensbi_mem
demos: demos_mem 

riscv_elf: 
	cd $(TEST_DIR)/src/riscv-tests/ && ./configure
	$(MAKE) -C $(TEST_DIR)/src/riscv-tests/
	find $(TEST_DIR)/src/riscv-tests/isa/ -executable -name "rv64ui-*" -execdir mv {} $(MEM_DIR)/{}.riscv \;
	find $(TEST_DIR)/src/riscv-tests/isa/ -name "rv64ui-*dump" -execdir mv {} $(MEM_DIR)/{} \;
	find $(TEST_DIR)/src/riscv-tests/isa/ -executable -name "rv64ua-*" -execdir mv {} $(MEM_DIR)/{}.riscv \;
	find $(TEST_DIR)/src/riscv-tests/isa/ -name "rv64ua-*dump" -execdir mv {} $(MEM_DIR)/{} \;
	find $(TEST_DIR)/src/riscv-tests/isa/ -executable -name "rv64si-*" -execdir mv {} $(MEM_DIR)/{}.riscv \;
	find $(TEST_DIR)/src/riscv-tests/isa/ -name "rv64si-*dump" -execdir mv {} $(MEM_DIR)/{} \;
	find $(TEST_DIR)/src/riscv-tests/benchmarks/ -type f -executable -execdir mv {} $(MEM_DIR)/{} \;
	find $(TEST_DIR)/src/riscv-tests/benchmarks/ -type f -name "*dump" -execdir mv {} $(MEM_DIR)/{} \;

demos_elf:
	make -C src/demos
	find $(TEST_DIR)/src/demos/ -executable -type f -execdir mv {} $(MEM_DIR)/{} \;
	find $(TEST_DIR)/src/demos/ -name "*.dump" -execdir mv {} $(MEM_DIR)/{} \;

opensbi_elf:
	make -C src/opensbi CROSS_COMPILE=riscv64-unknown-elf-  PLATFORM=blackparrot

riscv_mem: riscv_elf
riscv_mem: $(foreach x, $(RV64_P_TESTS) $(RV64_V_TESTS) $(RV64_BENCHMARKS), $(x).mem)
riscv_mem: $(foreach x, $(RV64_P_TESTS) $(RV64_V_TESTS) $(RV64_BENCHMARKS), $(x).spike)

demos_mem: demos_elf
demos_mem: $(foreach x, $(BP_DEMOS), $(x).mem)
# Need to kill spike at the end of demos for this to work
#demos_mem: $(foreach x, $(BP_DEMOS), $(x).spike)

%.mem: 
	$(RISCV_OBJCOPY) $(MEM_DIR)/$*.riscv $(MEM_DIR)/$@

%.spike:
	$(RISCV_SIM) -l $(MEM_DIR)/$*.riscv 2> $(MEM_DIR)/$@

clean:
	$(MAKE) -C src/riscv-tests clean 
	$(MAKE) -C src/demos clean
	rm -f $(MEM_DIR)/*

####### These targets are not maintained at the moment
#
#%_random.riscv:
#	$(RANDOM_GEN) -seed $(SEED) -mem 50 20 -mode m -o $@.S
#	${RISCV_GCC_RAND}  $@.S -o $@
#	rm $@.S
#
#rv_random:
#	num=1; while [ $$num -le $(RANDOM_NUM) ]; do \
#  make test`expr $$num + 0`_random.v SEED=`expr $$num + 0`; \
#  num=`expr $$num + 1`; \
#  done
#
##########################################
