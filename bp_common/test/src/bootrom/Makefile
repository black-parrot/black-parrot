
RISCV_GCC = $(CROSS_COMPILE)gcc -march=rv64im -mabi=lp64 -mcmodel=medany -static -nostdlib -nostartfiles

UCODE2BOOT = $(BP_COMMON_DIR)/software/py/ucode2boot.py

BOOT_INPUTS = --ucode=$(CCE_MEM_PATH)/$(CCE_MEM)
BOOT_INPUTS += --path=$(BP_COMMON_DIR)/test/src/bootrom

XXD ?= xxd

.DEFAULT: all

all: clean build
	
clean:
	@rm -f bootrom.riscv
	@rm -f cce_ucode.mem cce_ucode.bin

build:
	python3 $(UCODE2BOOT)	$(BOOT_INPUTS)
	$(XXD) -r -p cce_ucode.mem > cce_ucode.bin
	$(RISCV_GCC) bootrom.S -o bootrom.riscv -Tlink.ld -static -Wl,--no-gc-sections
