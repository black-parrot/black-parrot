
include Makefile.frag

RISCV_GCC = $(CROSS_COMPILE)g++
RISCV_GCC_OPTS  = -O2 -march=rv64imafd -mabi=lp64 -mcmodel=medany -D_DRAMFS -I $(BP_TEST_DIR)/include
RISCV_LINK_OPTS = -T $(BP_TEST_DIR)/src/perch/riscv.ld -static -nostartfiles -L$(BP_TEST_DIR)/lib -lperch -lgcc

MKLFS = dramfs_mklfs 128 8

vpath %.cpp ./src
vpath %.S   $(BP_TEST_DIR)/src/perch

.PHONY: all

all: $(foreach x,$(UNIT_TESTS),$(x).riscv)

lfs.cpp:
	$(MKLFS) > $@

%.o: %.cpp
	$(RISCV_GCC) -o $@ -c $< $(RISCV_GCC_OPTS)

%.o: %.S
	$(RISCV_GCC) -o $@ -c $< $(RISCV_GCC_OPTS)

%.riscv: %.o lfs.o start.o
	$(RISCV_GCC) -o $@ $^ $(RISCV_LINK_OPTS)

clean:
	rm -f *.riscv
	rm -f *.o
	rm -f lfs.cpp
