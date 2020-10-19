
RISCV_GCC = $(CROSS_COMPILE)gcc -march=rv64im -mabi=lp64 -mcmodel=medany -static -nostdlib -nostartfiles

.DEFAULT: all

all: clean build
	
clean:
	@rm -f bootrom.riscv

build: $(shell pwd)/bootrom.riscv
%/bootrom.riscv:
	$(RISCV_GCC) bootrom.S -I$(@D) -o $@ -Tlink.ld -static -Wl,--no-gc-sections
