RISCV_PREFIX ?= riscv64-unknown-elf-
RISCV_GCC ?= $(RISCV_PREFIX)gcc
ENTROPY ?= -DENTROPY=$(shell echo $$$$)
RISCV_GCC_OPTS ?= $(ENTROPY) -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles -march=rv64g -std=gnu99 -O2

COMMON_FILES ?= -I../env ../env/v/entry.S ../env/v/*.c ../env/v/*.h ../env/p/*.h  util.h start.S -T../env/v/link.ld

all: median.elf multiply.elf towers.elf vvadd.elf

median.elf: 
	$(RISCV_GCC) $(RISCV_GCC_OPTS) -o median.elf median.c median.h median_dataset.h median_main.c $(COMMON_FILES)

multiply.elf:
	$(RISCV_GCC) $(RISCV_GCC_OPTS) -o multiply.elf multiply.c multiply.h multiply_dataset.h multiply_main.c $(COMMON_FILES)

towers.elf:
	$(RISCV_GCC) $(RISCV_GCC_OPTS) -o towers.elf towers_main.c $(COMMON_FILES)

vvadd.elf:
	$(RISCV_GCC) $(RISCV_GCC_OPTS) -o vvadd.elf vvadd_main.c vvadd_dataset.h $(COMMON_FILES)

clean:
	rm median.elf multiply.elf towers.elf vvadd.elf
