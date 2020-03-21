
RISCV_GCC = $(CROSS_COMPILE)gcc -mabi=lp64 -march=rv64ima -mcmodel=medany -fno-builtin-printf -I$(TEST_DIR)/include
RISCV_LINK = -O2 -static -nostartfiles -nostdlib -Wl,--start-group -lgloss -lperch -lc -lg -lm -lgcc -Wl,--end-group -T riscv.ld -L$(TEST_DIR)/lib
MKLFS = dramfs_mklfs

.PHONY: fs

fs:
	$(MKLFS) 128 64 hello.txt > lfs.c
	$(RISCV_GCC) -o littlefs_test.riscv main.c lfs.c $(RISCV_LINK)

clean:
	rm -f lfs.c
	rm -f *.riscv

