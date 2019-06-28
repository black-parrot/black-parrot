#Coremark makefile for BP

RISCV_GCC = riscv64-unknown-elf-gcc -mabi=lp64 -march=rv64ia -mcmodel=medany -fno-builtin-printf
RISCV_GCC += -static -nostartfiles -T src/test.ld

COMMON_FILES += src/*.S src/*.c src/*.h

.PHONY: all

all:
	$(RISCV_GCC) -o mtest.riscv $(COMMON_FILES)
	$(RISCV_OBJDUMP) mtest.riscv > mtest.dump

clean:
	rm -f *.riscv

