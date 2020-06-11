
include Makefile.frag

RISCV_GCC  = $(CROSS_COMPILE)gcc --static -nostartfiles -fPIC -march=rv64ima -mabi=lp64 -mcmodel=medany -I$(BP_TEST_DIR)/include
RISCV_LINK = -static -nostartfiles -L$(BP_TEST_DIR)/lib -lperch -T src/riscv.ld

.PHONY: all

all: $(addsuffix .riscv, $(BP_DEMOS))

%.riscv:
	$(RISCV_GCC) $(RISCV_LINK) -o $@ src/$*.c -lperch

clean:
	rm -f *.riscv

