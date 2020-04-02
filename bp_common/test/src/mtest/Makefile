#Coremark makefile for BP

RISCV_GCC = riscv64-unknown-elf-gcc -mabi=lp64 -march=rv64ima -mcmodel=medany -fno-builtin-printf -I$(TEST_DIR)/include
RISCV_LINK = -static -nostartfiles -nostdlib -T src/test.ld -Wl,--start-group -lgloss -lc -lg -lm -lgcc -Wl,--end-group -L$(TEST_DIR)/lib 

COMMON_FILES += src/*.S src/*.c src/*.h

.PHONY: all

all:
	$(RISCV_GCC) -o mtest.riscv $(COMMON_FILES) $(RISCV_LINK) 
	$(RISCV_OBJDUMP) mtest.riscv > mtest.dump

clean:
	rm -f *.riscv

