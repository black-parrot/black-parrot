CWD         := $(CURDIR)
BIN_DIR     := $(CWD)/bin
LIB_DIR     := $(CWD)/lib
INCLUDE_DIR := $(CWD)/include

VERILATOR_DIR := $(CWD)/verilator
GNU_DIR       := $(CWD)/riscv-gnu-toolchain
FESVR_DIR     := $(CWD)/riscv-fesvr
SPIKE_DIR     := $(CWD)/riscv-isa-sim
AXE_DIR       := $(CWD)/axe

.PHONY: all verilator gnu fesvr spike axe

all: gnu verilator fesvr spike axe

systemc:
	wget http://www.accellera.org/images/downloads/standards/systemc/systemc-2.3.3.gz \
	&& tar -xzf systemc-2.3.3.gz && rm systemc-2.3.3.gz                               \
	&& cd systemc-2.3.3 && ./configure --prefix=$(CWD)                                \
	&& make && make install && make clean

verilator:
	cd $(VERILATOR_DIR)                        \
	&& autoconf && ./configure --prefix=$(CWD) \
	&& make && make install

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

