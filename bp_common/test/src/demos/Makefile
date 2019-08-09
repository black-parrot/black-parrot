
include Makefile.frag

RISCV_GCC  = riscv64-unknown-elf-gcc --static -nostdlib -nostartfiles -fPIC -march=rv64ia -mabi=lp64 -mcmodel=medany -I$(TEST_DIR)/include
RISCV_LINK = -static -nostdlib -nostartfiles -L$(TEST_DIR)/lib -T src/riscv.ld 

.PHONY: all bp-demo-riscv bp-demo-s

all: bp-demo-s bp-demo-riscv

bp-demo-riscv: $(foreach x,$(subst -,_,$(BP_DEMOS)),$(x).riscv)
bp-demo-s    : $(foreach x,$(subst -,_,$(BP_DEMOS_C)),$(x).s)

%.riscv:
	$(RISCV_GCC) $(RISCV_LINK) -o $@ src/$*.s -lperch

uc_simple.riscv:
	$(RISCV_GCC) -o $@ src/uc_simple.s src/uc_start.S

queue_demo_%.s:
	$(RISCV_GCC) -DNUM_CORES=$(notdir $*) -S -o src/queue_demo_$(notdir $*).s src/queue_demo.c

atomic_queue_demo_%.s:
	$(RISCV_GCC) -DNUM_CORES=$(notdir $*) -S -o src/atomic_queue_demo_$(notdir $*).s src/atomic_queue_demo.c

write_demo_%.s:
	$(RISCV_GCC) -DNUM_CORES=$(notdir $*) -S -o src/write_demo_$(notdir $*).s src/write_demo.c

%.s:
	$(RISCV_GCC) -S -o src/$@ src/$*.c

clean:
	rm -f *.riscv
	rm -f src/atomic_queue_demo_*.s
	rm -f src/write_demo_*.s

