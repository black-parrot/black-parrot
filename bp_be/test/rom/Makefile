TOP            = $(CURDIR)/../../..
BP_TOP_PATH	   = $(TOP)/bp_top
BP_FE_PATH	   = $(TOP)/bp_fe
BP_BE_PATH	   = $(TOP)/bp_be
BP_ME_PATH 	   = $(TOP)/bp_me
BP_COMMON_PATH = $(TOP)/bp_common
EXTERNAL_PATH  = $(TOP)/external

BSG_IP_PATH	   = $(TOP)/bsg_ip_cores
SPIKE_MOD_PATH = $(TOP)/external/bin

TEST_DIR       = $(BP_TOP_PATH)/test
ROM_DIR        = $(TEST_DIR)/rom/v

HEX2BIN        = $(BP_TOP_PATH)/software/py/hex2binascii.py
SPIKE2TR       = $(BP_TOP_PATH)/software/py/spike2tr.py
BSG_ROM_GEN    = $(BSG_IP_PATH)/bsg_mem/bsg_ascii_to_rom.py
RISCV_ELF2HEX  = elf2hex
RISCV_SIM	     = $(SPIKE_MOD_PATH)/spike
RISCV_OBJDUMP  = riscv64-unknown-elf-objdump -D -M no-aliases,numeric
RISCV_GCC      = riscv64-unknown-elf-gcc -fPIC -march=rv64i -mabi=lp64 
RISCV_GCC     += -mcmodel=medany -static -nostdlib -nostartfiles -T demos/riscv.ld
RISCV_GCC_RAND = riscv64-unknown-elf-gcc -nostdlib -nostartfiles -Wa,-march=rv64g -I${RANDOM_FLD}p/ -T${RANDOM_FLD}p/link.ld
RANDOM_NUM=0
SEED=0

include Makefile.frag

all: isa benchmarks demos

isa: isa_elf isa_rom
benchmarks: benchmarks_elf benchmarks_rom

isa_elf: $(foreach x, $(subst -,_,$(RV64_TESTS)), $(x))
isa_rom: $(foreach x, $(subst -,_,$(RV64_TESTS)), $(x).v)

benchmarks_elf:
	make -C src/benchmarks/
	cp src/benchmarks/median.elf src/benchmarks/multiply.elf src/benchmarks/towers.elf src/benchmarks/vvadd.elf .

benchmarks_rom: 
	make median.v
	make multiply.v
	make towers.v
	make vvadd.v

#demo: demo_elf demo_rom

#demo_elf: $(foreach x, $(subst -,_,$(BP_DEMOS)),$(x))
#demo_rom: $(foreach x, $(subst -,_,$(BP_DEMOS)),$(x).v)

%.v: %.bin
	python $(BSG_ROM_GEN) $< bp_boot_rom zero > $*.vtmp \
	&& awk 'FNR==2{system("$(RISCV_OBJDUMP) $*.elf | sed 's-^-//-'")} 1' $*.vtmp \
		> $(ROM_DIR)/$*_rom.v  \
	&& rm $*.vtmp \
	&& rm $*.elf \
	&& rm $*.spike \
	&& rm $*.tr 

%.bin: %.hex
	python $(HEX2BIN) $< 512 > $@

%.hex: %.trace
	$(RISCV_ELF2HEX) 16 32768 $*.elf 2147483648  > $@

median.trace multiply.trace towers.trace vvadd.trace:
	$(RISCV_SIM) --pc=0x80000124 -l --end-pc=0x800001b0 $(basename $@).elf 2>$(basename $@).spike
	python $(SPIKE2TR) $(basename $@)
	python $(BSG_ROM_GEN) $(basename $@).tr bp_trace_rom zero > $(ROM_DIR)/$(basename $@)_rom.tr.v

%.trace: 
	$(RISCV_SIM) -l $*.elf 2> $*.spike
	python $(SPIKE2TR) $*
	python $(BSG_ROM_GEN) $*.tr bp_trace_rom zero > $(ROM_DIR)/$*_rom.tr.v
	
rv64ui_p_%: src/isa/rv64ui/%.S 
	make -C src/isa/ $@
	mv src/isa/$@ $@.elf
	
##########################################
