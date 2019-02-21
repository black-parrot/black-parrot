CWD         := $(CURDIR)
BIN_DIR     := $(CWD)/bin
LIB_DIR     := $(CWD)/lib
INCLUDE_DIR := $(CWD)/include

SPIKE_DIR := $(CWD)/riscv-isa-sim
AXE_DIR   := $(CWD)/axe

.PHONY: all spike axe

all: spike axe

spike: check-env
	cd $(SPIKE_DIR)                                      \
	&& ./configure --with-fesvr=$(RISCV) --prefix=$(CWD) \
	&& make && make install                               

axe: 
	cd $(AXE_DIR)/src    \
	&& ./make.sh         \
	&& cp axe $(BIN_DIR)

check-env: 
ifndef RISCV
	$(error Install riscv-tools (https://github.com/riscv/riscv-tools) \
		        and set environment variable RISCV to the install path)
endif

