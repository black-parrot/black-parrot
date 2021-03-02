
include Makefile.frag

RISCV_GCC       = $(CROSS_COMPILE)gcc
RISCV_GCC_OPTS  = -march=rv64imafd -mabi=lp64 -mcmodel=medany -I $(BP_TEST_DIR)/include
RISCV_LINK_OPTS = -T $(BP_TEST_DIR)/src/perch/riscv.ld -L$(BP_TEST_DIR)/lib -static -nostartfiles -lperch
MKLFS           = dramfs_mklfs 128 64


.PHONY: all

all: $(addsuffix .riscv, $(BP_DEMOS))

%.riscv:
	$(RISCV_GCC) -o $@ $(wildcard src/$*/*.c) $(RISCV_GCC_OPTS) $(RISCV_LINK_OPTS)

lfs.riscv: $(BP_TEST_DIR)/src/perch/start.S ./src/lfs/lfs.c
	$(RISCV_GCC) -o $@ $^ $(wildcard src/lfs/*.c) -D_DRAMFS $(RISCV_GCC_OPTS) $(RISCV_LINK_OPTS)

%/lfs.c:
	cd $*; \
		$(MKLFS) $(notdir $(wildcard $*/*.txt)) > $(notdir $@)

clean:
	rm -f *.riscv
	rm -f $(wildcard src/*/lfs.c)

