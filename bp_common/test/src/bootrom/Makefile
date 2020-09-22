
RISCV_GCC = $(CROSS_COMPILE)gcc -fPIC -march=rv64im -mabi=lp64 -mcmodel=medany -static -nostdlib -nostartfiles

UCODE2BOOT = $(BP_COMMON_DIR)/software/py/ucode2boot.py
BOOT_INPUTS = --ucode=$(CCE_MEM_PATH)/$(CCE_MEM) --path=$(BP_COMMON_DIR)/test/src/bootrom
XXD ?= xxd

RISCV_OBJDUMP = $(CROSS_COMPILE)objdump -d -t -s
.DEFAULT: all

all: clean build dump
	
clean:
	@rm -f bootrom.riscv
	@rm -f cce_ucode.mem cce_ucode.bin

build:
	python3 $(UCODE2BOOT)	$(BOOT_INPUTS)
	$(XXD) -r -p cce_ucode.mem > cce_ucode.bin
	$(RISCV_GCC) bootrom.S -DDOMAIN_MASK=$(DOMAINS_P) -DSAC_MASK=$(SAC_P) -o bootrom.riscv -Tlink.ld -static -Wl,--no-gc-sections

dump:
	$(RISCV_OBJDUMP) bootrom.riscv > bootrom.dump
