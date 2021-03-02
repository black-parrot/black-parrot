
include Makefile.frag

RISCV_GCC       = $(CROSS_COMPILE)gcc
RISCV_GCC_OPTS  = -march=rv64imafd -mabi=lp64 -mcmodel=medany -I $(BP_TEST_DIR)/include
RISCV_LINK_OPTS = -T $(BP_TEST_DIR)/src/perch/riscv.ld -L$(BP_TEST_DIR)/lib -static -nostartfiles -lperch
MKLFS           = dramfs_mklfs 128 64


.PHONY: all

all: $(addsuffix .riscv, $(BP_DEMOS))

%.riscv:
	$(RISCV_GCC) -o $@ $(wildcard src/$*/*.c) $(RISCV_GCC_OPTS) $(RISCV_LINK_OPTS)

lfs_demo.riscv: $(BP_TEST_DIR)/src/perch/start.S ./src/lfs_demo/lfs.c ./src/lfs_demo/main.c
	$(RISCV_GCC) -o $@ $^ -D_DRAMFS $(RISCV_GCC_OPTS) $(RISCV_LINK_OPTS)

src/%/lfs.c:
	cd $(dir $@); \
		$(MKLFS) $($(addsuffix _input_files, $*)) > $(notdir $@)

clean:
	rm -f *.riscv
	rm -f $(wildcard src/*/lfs.c)

