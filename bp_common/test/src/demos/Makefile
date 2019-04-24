
include Makefile.frag

RISCV_GCC  =riscv64-unknown-elf-gcc -fPIC -march=rv64i -mabi=lp64 -mcmodel=medany 
RISCV_GCC += -static -nostdlib -nostartfiles -T src/riscv.ld

RISCV_OBJDUMP  = riscv64-unknown-elf-objdump -D -M no-aliases,numeric

.PHONY: all bp-demo-riscv bp-demo-s

all: bp-demo-s bp-demo-riscv

bp-demo-riscv: $(foreach x,$(subst -,_,$(BP_DEMOS)),$(x).riscv)
bp-demo-s    : $(foreach x,$(subst -,_,$(BP_DEMOS_C)),$(x).s)

%.riscv:
	$(RISCV_GCC) -o $@ src/$*.s src/start.S src/exception.S src/emulation.c
	$(RISCV_OBJDUMP) $@ > $*.dump

queue_demo_%.s:
	$(RISCV_GCC) -DNUM_CORES=$(notdir $*) -S -o src/queue_demo_$(notdir $*).s src/queue_demo.c

reloc_queue_demo_%.s:
	$(RISCV_GCC) -DNUM_CORES=$(notdir $*) -S -o src/reloc_queue_demo_$(notdir $*).s src/reloc_queue_demo.c

%.s:
	$(RISCV_GCC) -S -o src/$@ src/$*.c 

clean:
	rm -f *.riscv
	rm -f *.dump

