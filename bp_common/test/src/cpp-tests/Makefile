
include Makefile.frag

RISCV_GCC = $(CROSS_COMPILE)g++
RISCV_GCC_OPTS  = -O2 -march=rv64imafd -mabi=lp64 -mcmodel=medany
RISCV_LINK_OPTS = -T $(BP_TEST_DIR)/src/perch/riscv.ld -static --sysroot=$(BP_TEST_DIR) -lperch

MKLFS = dramfs_mklfs 128 8

vpath %.cpp ./src

.PHONY: all

all: $(foreach x,$(UNIT_TESTS),$(x).riscv)

lfs.cpp:
	$(MKLFS) > $@

%.o: %.cpp
	$(RISCV_GCC) -o $@ -c $< $(RISCV_GCC_OPTS)

%.o: %.S
	$(RISCV_GCC) -o $@ -c $< $(RISCV_GCC_OPTS)

%.riscv: %.o lfs.o
	$(RISCV_GCC) -o $@ $^ $(RISCV_LINK_OPTS)

clean:
	rm -f *.riscv
	rm -f *.o
	rm -f lfs.cpp
