RISCV_GCC = $(CROSS_COMPILE)gcc -mabi=lp64 -march=rv64imafd -mcmodel=medany  -I$(BP_TEST_DIR)/include
RISCV_LINK = -pedantic -Wall -Wextra -static -nostartfiles -Wl,--start-group -lgloss -lperch -lc -lg -lm -lgcc -Wl,--end-group -T riscv.ld -L$(BP_TEST_DIR)/lib

GCC = gcc -std=c99 -Wall

MKLFS = dramfs_mklfs
DROMAJO = /home/acme/ee599/black-parrot/external/dromajo/src/dromajo

# if RAND_SEED == 0, mkrandfile will randomly pick a seed for you
RAND_SEED = 0
RAND_SIZE = 128

RAND_TXT_FILE = rand_txt
RAND_DATA_FILE = rand_data


.PHONY: all clean

all:
	$(GCC) mkrandfile.c -o mkrandfile
	./mkrandfile -seed $(RAND_SEED) -size $(RAND_SIZE) -o $(RAND_DATA_FILE) > $(RAND_TXT_FILE)
	$(MKLFS) 128 64 $(RAND_DATA_FILE) > lfs.c


test:
	@$(RISCV_GCC) -o read_rand_test.riscv read_rand_test.c lfs.c $(RISCV_LINK)
	@$(DROMAJO) read_rand_test.riscv --host --save=dromajo | sed  '$$ d' > result.tmp
	@cat $(RAND_TXT_FILE) | sed '1,2d' | head -$(RAND_SIZE) > expect.tmp
	@if diff expect.tmp result.tmp > /dev/null ; then echo "Read test passed" ; else echo "Read test failed" ; fi
	@rm -f expect.tmp result.tmp

clean:
	@rm -f mkrandfile lfs.c read_rand_test.riscv $(RAND_TXT_FILE) $(RAND_DATA_FILE)
