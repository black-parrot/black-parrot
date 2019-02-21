CWD         := $(CURDIR)
BIN_DIR     := $(CWD)/bin
LIB_DIR     := $(CWD)/lib
INCLUDE_DIR := $(CWD)/include

GNU_DIR   := $(CWD)/riscv-gnu-toolchain
FESVR_DIR := $(CWD)/riscv-fesvr
SPIKE_DIR := $(CWD)/riscv-isa-sim
AXE_DIR   := $(CWD)/axe

.PHONY: all gnu fesvr spike axe

all: gnu fesvr spike axe

spike:
	cd $(SPIKE_DIR)                                    \
	&& ./configure --with-fesvr=$(CWD) --prefix=$(CWD) \
	&& make && make install && make clean

axe: 
	cd $(AXE_DIR)/src    \
	&& ./make.sh         \
	&& cp axe $(BIN_DIR) && ./clean.sh

gnu:
	cd $(GNU_DIR)                  \
	&& ./configure --prefix=$(CWD) \
	&& make && make install && make clean

fesvr:
	cd $(FESVR_DIR)                \
	&& ./configure --prefix=$(CWD) \
	&& make && make install && make clean

