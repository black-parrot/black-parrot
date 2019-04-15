find-dir-with = $(shell /usr/bin/perl -e 'chomp($$_ = `pwd`); while ($$_ ne "" && ! -e "$$_/$(1)") { m:(.*)/[^/]+/??:; $$_ = $$1; } print;')

src_dir := .

include $(src_dir)/rv64ui/Makefrag

default: all

#--------------------------------------------------------------------
# Build rules
#--------------------------------------------------------------------

RISCV_PREFIX ?= riscv64-unknown-elf-
RISCV_GCC ?= $(RISCV_PREFIX)gcc
ENTROPY ?= -DENTROPY=$(shell echo $$$$)
RISCV_GCC_OPTS ?= $(ENTROPY) -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles -march=rv64g
RISCV_SIM ?= spike
XLEN ?= 64

vpath %.S $(src_dir)

#------------------------------------------------------------
# Build assembly tests

define compile_template

$$($(1)_p_tests): $(1)_p_%: $(1)/%.S
	$$(RISCV_GCC) pt.S $(2) $$(RISCV_GCC_OPTS) -I$(src_dir)/../env/p -I$(src_dir)/macros/scalar -T$(src_dir)/../env/p/link.ld $$< -o $$@.elf
$(1)_tests += $$($(1)_p_tests)

.PHONY: $(1)

tests += $$($(1)_tests)

endef

ifeq ($(XLEN),64)
$(eval $(call compile_template,rv64ui))
endif

junk += $(tests) 

#------------------------------------------------------------
# Default

all: $(tests)

#------------------------------------------------------------
# Clean up

clean:
	rm -rf $(junk)
