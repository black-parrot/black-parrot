#Coremark makefile for BP

RISCV_GCC = riscv64-unknown-elf-gcc -mabi=lp64 -march=rv64ia -mcmodel=medany -fno-builtin-printf

RISCV_LINK = -O2 -static -nostartfiles -nostdlib -Wl,--start-group -lgloss -lc -lg -lm -lgcc -Wl,--end-group -T ../common/test.ld -L$(TEST_DIR)/lib 
RISCV_TESTS_DIR = ../../riscv-tests

COMMON_FILES = -I$(RISCV_TESTS_DIR)/env -I../common -I$(TEST_DIR)/include
COMMON_FILES += ../common/crt.S ../common/syscalls.c 

RISCV_OBJDUMP  = riscv64-unknown-elf-objdump -D -M no-aliases,numeric


.PHONY: fs

fs:
	$(RISCV_GCC) $(COMMON_FILES) -o littlefs_test.riscv $(wildcard *.c) $(RISCV_LINK)
	$(RISCV_OBJDUMP) littlefs_test.riscv > littlefs_test.dump

clean:
	rm -f *.riscv

