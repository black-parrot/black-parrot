include ../Makefile.common

RISCV_GCC = $(CROSS_COMPILE)gcc -mabi=lp64 -march=rv64imafd -mcmodel=medany  -I$(BP_TEST_DIR)/include
RISCV_LINK = -pedantic -Wall -Wextra -static -nostartfiles -Wl,--start-group -lgloss -lperch -lc -lg -lm -lgcc -Wl,--end-group -T riscv.ld -L$(BP_TEST_DIR)/lib

DROMAJO = /home/acme/ee599/black-parrot/external/dromajo/src/dromajo

# if RAND_SEED == 0, mkrandfile will randomly pick a seed for you


.PHONY: test clean


test:
	@$(RISCV_GCC) -o read_rand_test.riscv read_rand_test.c ../lfs.c $(RISCV_LINK)
	@$(DROMAJO) read_rand_test.riscv --host --save=dromajo | sed  '$$ d' > result.tmp
	@cat ../$(RAND_TXT_FILE) | sed '1,2d' | head -$(RAND_SIZE) > expect.tmp
	@if diff expect.tmp result.tmp > /dev/null ; then echo "Read test passed" ; else echo "Read test failed" ; fi

clean:
	@rm -f expect.tmp result.tmp *.riscv
