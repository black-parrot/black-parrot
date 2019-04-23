## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

SPIKE_MOD_PATH = $(BP_EXTERNAL_DIR)/bin

TEST_DIR       = $(BP_TOP_DIR)/test
ROM_DIR        = $(TEST_DIR)/rom/v
MEM_DIR        = $(TEST_DIR)/mem

HEX2BIN        = $(BP_TOP_DIR)/software/py/hex2binascii.py
SPIKE2TR       = $(BP_TOP_DIR)/software/py/spike2tr.py
BSG_ROM_GEN    = $(BSG_IP_CORES_DIR)/bsg_mem/bsg_ascii_to_rom.py
RISCV_ELF2HEX  = elf2hex
RISCV_SIM      = $(SPIKE_MOD_PATH)/spike
RISCV_OBJDUMP  = riscv64-unknown-elf-objdump -D -M no-aliases,numeric
RISCV_OBJCOPY  = riscv64-unknown-elf-objcopy -O verilog
RISCV_GCC_RAND  = riscv64-unknown-elf-gcc -nostdlib -nostartfiles -Wa,-march=rv64g 
RISCV_GCC_RAND += -I${RANDOM_FLD}p/ -T${RANDOM_FLD}p/link.ld

include Makefile.frag

all: isa isa_v benchmarks demos

isa: isa_elf isa_rom clean
isa_v: isa_v_elf isa_v_rom clean
benchmarks: benchmarks_elf benchmarks_rom clean
demos: demos_elf demos_rom

isa_elf:
	make -C src/isa
	mv src/isa/rv64ui_p*.elf .

isa_v_elf:
	make -C src/isa
	mv src/isa/rv64ui_v*.elf .

benchmarks_elf:
	make -C src/benchmarks
	mv src/benchmarks/*.elf . 

demos_elf:
	make -C src/demos
	mv src/demos/*.elf .

isa_rom: SPIKE_OPTS := 
isa_rom: $(foreach x, $(subst -,_,$(RV64_TESTS)), $(x).trace)
isa_rom: $(foreach x, $(subst -,_,$(RV64_TESTS)), $(x).mem)

benchmarks_rom: SPIKE_OPTS := --pc=0x80000124 --end-pc=0x800001b0
benchmarks_rom: $(foreach x, $(subst -,_,$(RV64_BENCHMARKS)), $(x).trace)
benchmarks_rom: $(foreach x, $(subst -,_,$(RV64_BENCHMARKS)), $(x).mem)

demos_rom: $(foreach x, $(subst -,_,$(BP_DEMOS)), $(x).mem)
demos_rom: $(foreach x, $(subst -,_,$(BP_DEMOS)), $(x).fake_trace)

%.bin: %.hex
	python $(HEX2BIN) $< 512 > $@

# 64 kB ROM with a 0x80000000 offset
%.hex:
	$(RISCV_ELF2HEX) 16 65536 $*.elf 2147483648  > $@

%.mem: 
	$(RISCV_OBJCOPY) $*.elf $(MEM_DIR)/$@

%.trace: 
	$(RISCV_SIM) -l $(SPIKE_OPTS) $(basename $@).elf 2>$(basename $@).spike
	python $(SPIKE2TR) $(basename $@) 10
	python $(BSG_ROM_GEN) $(basename $@).tr bp_trace_rom zero > $(ROM_DIR)/$(basename $@).tr.v

%.fake_trace:
	touch $(ROM_DIR)/$(basename $@).tr.v

clean:
	rm -f *.elf
	rm -f *.bin
	rm -f *.hex
	rm -f *.tr
	rm -f *.spike

####### These targets are not maintained at the moment

%_random.riscv:
	$(RANDOM_GEN) -seed $(SEED) -mem 50 20 -mode m -o $@.S
	${RISCV_GCC_RAND}  $@.S -o $@
	rm $@.S

rv_random:
	num=1; while [ $$num -le $(RANDOM_NUM) ]; do \
  make test`expr $$num + 0`_random.v SEED=`expr $$num + 0`; \
  num=`expr $$num + 1`; \
  done

##########################################
