RISCV_GCC=riscv64-unknown-elf-gcc -fPIC -march=rv64i -mabi=lp64 -mcmodel=medany -static -nostdlib -nostartfiles -T test.ld
COMMON_FILES = pt.S start.S -I../env util.h -I../env/p/

all: median.elf multiply.elf towers.elf vvadd.elf

median.elf: 
	$(RISCV_GCC) -o median.elf median.c median.h median_dataset.h median_main.c $(COMMON_FILES)

multiply.elf:
	$(RISCV_GCC) -o multiply.elf multiply.c multiply.h multiply_dataset.h multiply_main.c $(COMMON_FILES)

towers.elf:
	$(RISCV_GCC) -o towers.elf towers_main.c $(COMMON_FILES)

vvadd.elf:
	$(RISCV_GCC) -o vvadd.elf vvadd_main.c vvadd_dataset.h $(COMMON_FILES)

clean:
	rm median.elf multiply.elf towers.elf vvadd.elf
