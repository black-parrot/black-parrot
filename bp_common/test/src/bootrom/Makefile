
RISCV_GCC = $(CROSS_COMPILE)gcc -march=rv64im -mabi=lp64 -mcmodel=medany -static -nostdlib -nostartfiles

UCODE2BOOT = $(BP_COMMON_DIR)/software/py/ucode2boot.py

# Override these variables to change where the ucode comes from and where output goes to
BOOTROM_UCODE ?= $(CCE_MEM_PATH)/$(CCE_MEM)
BOOTROM_PATH ?= $(BP_COMMON_DIR)/test/src/bootrom

BOOTROM_INPUTS = --ucode=$(BOOTROM_UCODE) --path=$(BOOTROM_PATH)

XXD ?= xxd

.DEFAULT: all

all: clean build
	
clean:
	@rm -f bootrom.riscv
	@rm -f cce_ucode.mem cce_ucode.bin

build:
	python3 $(UCODE2BOOT)	$(BOOTROM_INPUTS)
	$(XXD) -r -p $(BOOTROM_PATH)/cce_ucode.mem > $(BOOTROM_PATH)/cce_ucode.bin
	$(RISCV_GCC) bootrom.S -I$(BOOTROM_PATH) -o $(BOOTROM_PATH)/bootrom.riscv -Tlink.ld -static -Wl,--no-gc-sections
