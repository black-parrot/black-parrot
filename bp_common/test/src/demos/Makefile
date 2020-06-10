
include Makefile.frag

RISCV_GCC  = $(CROSS_COMPILE)gcc --static -nostartfiles -fPIC -march=rv64ima -mabi=lp64 -mcmodel=medany -I$(TEST_DIR)/include
RISCV_LINK = -static -nostartfiles -L$(TEST_DIR)/lib -T src/riscv.ld 

.PHONY: all

all: loop_test.s cache_flush.s

%.riscv:
	$(RISCV_GCC) $(RISCV_LINK) -o $@ src/$*.s -lperch

loop_test.s:
	$(RISCV_GCC) -O0 -S -o src/$@ src/loop_test.c

cache_flush.s:
	$(RISCV_GCC) -O0 -S -o src/$@ src/cache_flush.c

%.s:
	$(RISCV_GCC) -S -o src/$@ src/$*.c

clean:
	rm -f *.riscv
	rm -f src/loop_test.s
	rm -f src/cache_flush.s

