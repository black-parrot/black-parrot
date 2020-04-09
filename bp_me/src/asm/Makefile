###

TOP ?= $(shell git rev-parse --show-toplevel)

AS_INC_DIR=$(abspath ./include)
AS_SRC_DIR=$(abspath ./src)
UCODE_INC_DIR=$(abspath ./microcode/include)
UCODE_SRC_DIR=$(abspath ./microcode/cce)

ROMS_DIR=$(abspath ./roms)

BSG_MEM_DIR=$(abspath $(TOP)/external/basejump_stl/bsg_mem)
BSG_ROM_SCRIPT=$(BSG_MEM_DIR)/bsg_ascii_to_rom.py

CXX=g++
COMMON_CFLAGS=-Wall -Wno-switch -Wno-format -Wno-unused-function
CXXFLAGS=-g -std=c++11 $(COMMON_CFLAGS)
CXXFLAGS +=-I$(AS_INC_DIR)

LD=g++
LFLAGS=-g $(COMMON_FLAGS)

AS_SRC=$(abspath $(wildcard $(AS_SRC_DIR)/*.cc))
AS_OBJ=$(AS_SRC:.cc=.o)
AS=bp-as

UCODE_SRC=$(wildcard $(UCODE_SRC_DIR)/*.S)
UCODE_BUILD_SRC=$(addprefix $(ROMS_DIR)/, $(notdir $(UCODE_SRC)))
UCODE_MEM=$(UCODE_BUILD_SRC:.S=.mem)
UCODE_ADDR=$(UCODE_BUILD_SRC:.S=.addr)
UCODE_BIN=$(UCODE_BUILD_SRC:.S=.bin)
UCODE_DBG=$(UCODE_BUILD_SRC:.S=.dbg)
UCODE_ROM=$(UCODE_BUILD_SRC:.S=.rom)

MODULE_NAME ?= bp_cce_inst_rom

.DEFAULT: echo

echo:
	@echo "try running: 'make as'"

# Assembler

%.o: %.cc
	$(CXX) $(CXXFLAGS) -c -o $@ $<

$(AS): $(AS_OBJ)
	$(LD) $(LFLAGS) -o $(AS) $(AS_OBJ)

as: $(AS)

# Microcode

dirs:
	mkdir -p $(ROMS_DIR)
	cp $(UCODE_SRC_DIR)/* $(ROMS_DIR)/

%.addr: %.S
	python2 py/addr.py -i $< > $@

%.pre: %.S
	gcc -E $(COMMON_CFLAGS) -I$(UCODE_INC_DIR) $< -o $@

%.mem: %.pre
	./$(AS) -b -i $< -o $@

%.dbg: %.pre
	./$(AS) -d -i $< -o $@

%.rom: %.mem
	python2 $(BSG_ROM_SCRIPT) $< $(MODULE_NAME) zero > $@

%.bin: %.mem
	xxd -r -p $< > $@

roms: dirs $(AS) $(UCODE_ADDR) $(UCODE_MEM) $(UCODE_BIN) $(UCODE_ROM)

tidy:
	rm -f $(AS_OBJ)

clean: tidy
	rm -f $(AS)
	rm -rf $(ROMS_DIR)

