include Makefile.common

GCC = gcc -std=c99 -Wall
MKLFS = dramfs_mklfs


.PHONY: all clean test

all:
	$(GCC) mkrandfile.c -o mkrandfile
	./mkrandfile -seed $(RAND_SEED) -size $(RAND_SIZE) -o $(RAND_DATA_FILE) > $(RAND_TXT_FILE)
	$(MKLFS) 128 64 $(RAND_DATA_FILE) > lfs.c


test:
	make -C test/ test clean

clean:
	@rm -f mkrandfile lfs.c read_rand_test.riscv $(RAND_TXT_FILE) $(RAND_DATA_FILE)
	@make -C test/ clean
