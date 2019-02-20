CWD       := $(CURDIR)
SPIKE_DIR := $(CWD)/riscv-isa-sim

.PHONY: all spike

all: spike

spike: check-env
	cd $(SPIKE_DIR)                                      \
	&& ./configure --with-fesvr=$(RISCV) --prefix=$(CWD) \
	&& make && make install                               

check-env: 
ifndef RISCV
	$(error Install riscv-tools (https://github.com/riscv/riscv-tools) \
		        and set environment variable RISCV to the install path)
endif

