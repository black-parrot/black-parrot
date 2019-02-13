RISCV_GCC=riscv64-unknown-elf-gcc -fPIC -march=rv64i -mabi=lp64 -mcmodel=medany -static -nostdlib -nostartfiles -T src/riscv.ld


include Makefile.frag
all: make-tests 

bp-demo-roms: $(foreach x,$(subst -,_,$(BP_DEMOS)),$(x).elf)

%.elf:
	$(RISCV_GCC) -o $@ src/$*.s src/start.S

%.s:
	$(RISCV_GCC) -S -o src/$@ src/$*.c
