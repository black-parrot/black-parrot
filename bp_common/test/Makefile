## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

ZERO_MEM ?=$(BP_COMMON_DIR)/software/py/zero_mem.py
MEM2NBF  ?= $(BP_COMMON_DIR)/software/py/nbf.py

TEST_DIR       = $(BP_COMMON_DIR)/test
MEM_DIR        = $(TEST_DIR)/mem

RISCV_TARGET   = riscv64-unknown-elf-dramfs
CROSS_COMPILE  = $(RISCV_TARGET)-

RISCV_SIM      = spike
RISCV_OBJDUMP  = $(CROSS_COMPILE)objdump -D
RISCV_OBJCOPY  = $(CROSS_COMPILE)objcopy
DROMAJO        = dromajo

NC ?= 1
MEMSIZE ?= 32 # MB
DUMP_PERIOD ?= 0

export TEST_DIR

include $(TEST_DIR)/Makefile.frag

all: all_mem all_dump all_nbf all_spike

all_nbf: riscv_nbf coremark_nbf beebs_nbf littlefs_test_nbf demos_nbf zero_nbf

# We don't include riscvdv here because it requires VCS
all_mem: perch
all_mem: riscv_mem coremark_mem beebs_mem littlefs_test_mem demos_mem zero_mem

all_dump: riscv_dump coremark_dump beebs_dump littlefs_test_dump demos_dump

all_spike: riscv_spike coremark_spike beebs_spike littlefs_test_spike 

zero: zero_mem zero_nbf
riscv: riscv_mem riscv_nbf riscv_dump riscv_spike
coremark: coremark_mem coremark_nbf coremark_dump coremark_spike
beebs: beebs_mem beebs_nbf beebs_dump beebs_spike
littlefs_test: littlefs_test_mem littlefs_test_nbf littlefs_test_dump littlefs_test_spike
demos: demos_mem demos_nbf demos_dump
riscvdv: riscvdv_mem riscvdv_nbf riscvdv_dump riscvdv_spike

# Spec is separate because it is proprietary
spec: spec_mem spec_dump

perch:
	$(MAKE) -C $(TEST_DIR)/src/perch CROSS_COMPILE=$(CROSS_COMPILE)
	mkdir -p $(TEST_DIR)/lib
	mkdir -p $(TEST_DIR)/include
	cp $(TEST_DIR)/src/perch/libperch.a $(TEST_DIR)/lib
	cp $(TEST_DIR)/src/perch/*.h $(TEST_DIR)/include

riscv_elf: 
	cd $(TEST_DIR)/src/riscv-tests/ && ./configure --target=$(RISCV_TARGET)
	$(MAKE) -C $(TEST_DIR)/src/riscv-tests/
	find $(TEST_DIR)/src/riscv-tests/isa/ -executable -name "rv64ui-*" -execdir mv {} $(MEM_DIR)/{}.riscv \;
	find $(TEST_DIR)/src/riscv-tests/isa/ -executable -name "rv64ua-*" -execdir mv {} $(MEM_DIR)/{}.riscv \;
	find $(TEST_DIR)/src/riscv-tests/isa/ -executable -name "rv64mi-*" -execdir mv {} $(MEM_DIR)/{}.riscv \;
	find $(TEST_DIR)/src/riscv-tests/isa/ -executable -name "rv64si-*" -execdir mv {} $(MEM_DIR)/{}.riscv \;
	find $(TEST_DIR)/src/riscv-tests/isa/ -executable -name "rv64um-*" -execdir mv {} $(MEM_DIR)/{}.riscv \;
	find $(TEST_DIR)/src/riscv-tests/benchmarks/ -type f -executable -execdir mv {} $(MEM_DIR)/{} \;

coremark_elf:
	$(MAKE) -C $(TEST_DIR)/src/coremark/barebones/ CROSS_COMPILE=$(CROSS_COMPILE)
	find $(TEST_DIR)/src/coremark/barebones/ -type f -executable -execdir mv {} $(MEM_DIR)/{} \;

demos_elf:
	$(MAKE) -C $(TEST_DIR)/src/demos CROSS_COMPILE=$(CROSS_COMPILE)
	find $(TEST_DIR)/src/demos/ -executable -type f -execdir mv {} $(MEM_DIR)/{} \;

littlefs_test_elf:
	$(MAKE) -C $(TEST_DIR)/src/littlefs_newlib_test/ CROSS_COMPILE=$(CROSS_COMPILE)
	find $(TEST_DIR)/src/littlefs_newlib_test/ -type f -executable -execdir mv {} $(MEM_DIR)/{} \;

#Change the number of iterations per test by changing BOARD_REPEAT_FACTOR in beebs/support/support.h
beebs_elf:
	cd $(TEST_DIR)/src/beebs/ && ./configure --host=riscv64 --with-chip=black-parrot \
		 --includedir=$(TEST_DIR)/include --libdir=$(TEST_DIR)/lib
	$(MAKE) -C $(TEST_DIR)/src/beebs/
	find $(TEST_DIR)/src/beebs/src/ -type f -executable -execdir mv {} $(MEM_DIR)/{}.riscv \;

spec_elf:
	$(MAKE) -C $(TEST_DIR)/src/spec/ CROSS_COMPILE=$(CROSS_COMPILE)
	find $(TEST_DIR)/src/spec/ -executable -name "*.riscv" -type f -execdir mv {} $(MEM_DIR)/{} \;

riscvdv_elf: $(BP_RVDV)
$(BP_RVDV):
	rm -rf $(TEST_DIR)/src/riscv-dv/out/
	$(MAKE) -C $(TEST_DIR)/src/riscv-dv/ generate.$@ CROSS_COMPILE=$(CROSS_COMPILE)
	cp $(TEST_DIR)/src/riscv-dv/out/asm_tests/$@_0.o $(MEM_DIR)/$@.riscv

riscv_nbf: $(foreach x, $(RV64_P_TESTS) $(RV64_PT_TESTS) $(RV64_V_TESTS) $(RV64_VT_TESTS) $(RV64_BENCHMARKS), $(x).nbf)
riscv_mem: riscv_elf
riscv_mem: $(foreach x, $(RV64_P_TESTS) $(RV64_PT_TESTS) $(RV64_V_TESTS) $(RV64_VT_TESTS) $(RV64_BENCHMARKS), $(x).mem)
riscv_spike: $(foreach x, $(RV64_P_TESTS) $(RV64_PT_TESTS) $(RV64_V_TESTS) $(RV64_VT_TESTS) $(RV64_BENCHMARKS), $(x).spike)
riscv_dump: $(foreach x, $(RV64_P_TESTS) $(RV64_PT_TESTS) $(RV64_V_TESTS) $(RV64_VT_TESTS) $(RV64_BENCHMARKS), $(x).dump)

demos_nbf: $(foreach x, $(BP_DEMOS), $(x).nbf)
demos_mem: demos_elf
demos_mem: $(foreach x, $(BP_DEMOS), $(x).mem)
demos_spike: $(foreach x, $(BP_DEMOS), $(x).spike)
demos_dump: $(foreach x, $(BP_DEMOS), $(x).dump)

coremark_nbf: coremark.nbf
coremark_mem: coremark_elf
coremark_mem: coremark.mem
coremark_spike: coremark.spike
coremark_dump: coremark.dump

littlefs_test_nbf: littlefs_test.nbf
littlefs_test_mem: littlefs_test_elf
littlefs_test_mem: littlefs_test.mem
littlefs_test_spike: littlefs_test.spike
littlefs_test_dump: littlefs_test.dump

zero_nbf: zero.nbf
zero_mem:
	$(PYTHON) $(ZERO_MEM) > $(MEM_DIR)/zero.mem

beebs_nbf: $(foreach x, $(BEEBS_TESTS), $(x).nbf)
beebs_mem: beebs_elf
beebs_mem: $(foreach x, $(BEEBS_TESTS), $(x).mem)
beebs_spike: $(foreach x, $(BEEBS_TESTS), $(x).spike)
beebs_dump: $(foreach x, $(BEEBS_TESTS), $(x).dump)

spec_nbf: $(foreach x, $(BP_SPEC), $(x).nbf)
spec_mem: spec_elf
spec_mem: $(foreach x, $(BP_SPEC), $(x).mem)
spec_spike: $(foreach x, $(BP_SPEC), $(x).spike)
spec_dump: $(foreach x, $(BP_SPEC), $(x).dump)

riscvdv_nbf: $(foreach x, $(BP_RVDV), $(x).nbf)
riscvdv_mem: riscvdv_elf
riscvdv_mem: $(foreach x, $(BP_RVDV), $(x).mem)
riscvdv_spike: $(foreach x, $(BP_RVDV), $(x).spike)
riscvdv_dump: $(foreach x, $(BP_RVDV), $(x).dump)

%.mem: 
	$(RISCV_OBJCOPY) -O verilog $(MEM_DIR)/$*.riscv $(MEM_DIR)/$@

%.bin: 
	$(RISCV_OBJCOPY) -O binary $(MEM_DIR)/$*.riscv $(MEM_DIR)/$@

%.dump:
	$(RISCV_OBJDUMP) $(MEM_DIR)/$*.riscv > $(MEM_DIR)/$@

%.spike:
	$(RISCV_SIM) --isa=rv64ima -p$(NC) --log-commits $(MEM_DIR)/$*.riscv 2> $(MEM_DIR)/$@

%.dump:
	$(RISCV_OBJDUMP) $(MEM_DIR)/$*.riscv > $(MEM_DIR)/$@

%.nbf:
	$(PYTHON) $(MEM2NBF) $(MEM_DIR)/$*.mem > $(MEM_DIR)/$@

%.checkpoint:
	$(RISCV_OBJCOPY) --change-addresses 0x80000000 \
		 -I binary -O elf64-littleriscv -B riscv $*.mainram $(MEM_DIR)/$*.riscv
	$(RISCV_OBJCOPY) -O verilog $(MEM_DIR)/$*.riscv $(MEM_DIR)/$*.mem
	cp $*.bp_regs $(MEM_DIR)/$*.nbf
	cp $*.bootram $(MEM_DIR)/$*.bootram
	cp $*.mainram $(MEM_DIR)/$*.mainram
	echo -e "\
	{\n\
	  \"version\":1,\n\
	  \"machine\":\"riscv64\",\n\
	  \"bios\": \"prog.mainram\",\n\
	  \"load\": \"prog\",\n\
	  \"memory_base_addr\": 0x80000000,\n\
	  \"memory_size\": $(MEMSIZE),\n\
	  \"mmio_start\": 0x20000,\n\
	  \"mmio_end\": 0x80000000\n\
	}" > $(MEM_DIR)/$*.cfg
	rm $*.*

%.run_dromajo:
	$(DROMAJO) $(MEM_DIR)/$*.riscv --host --dump_period=$(DUMP_PERIOD) --maxinsn=$(MAXINSN) --save=$*.dromajo --memory_size=$(MEMSIZE)

%.dromajo: %.run_dromajo
	$(eval FILES := $(patsubst %.mainram, %, $(shell ls $**.mainram)))
	$(foreach f, $(FILES), $(MAKE) $f.checkpoint;)

clean:
	-$(MAKE) -C $(TEST_DIR)/src/perch clean
	-$(MAKE) -C $(TEST_DIR)/src/riscv-tests/benchmarks clean 
	-$(MAKE) -C $(TEST_DIR)/src/demos clean
	-$(MAKE) -C $(TEST_DIR)/src/coremark/barebones clean
	-$(MAKE) -C $(TEST_DIR)/src/littlefs_newlib_test clean
	-$(MAKE) -C $(TEST_DIR)/src/beebs clean
	-$(MAKE) -C $(TEST_DIR)/src/spec clean
	-$(MAKE) -C $(TEST_DIR)/src/riscv-dv clean
	-rm -rf $(TEST_DIR)/src/bsg_newlib_dramfs/build-newlib 
	-rm -rf $(TEST_DIR)/src/bsg_newlib_dramfs/install-newlib
	-rm -rf $(MEM_DIR)/*

