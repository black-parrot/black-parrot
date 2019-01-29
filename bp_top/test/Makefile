TOP            = $(CURDIR)/../..
BP_TOP_PATH	   = $(TOP)/bp_top
BP_FE_PATH	   = $(TOP)/bp_fe
BP_BE_PATH	   = $(TOP)/bp_be
BP_ME_PATH 	   = $(TOP)/bp_me
BP_COMMON_PATH = $(TOP)/bp_common

BSG_IP_PATH	   = $(TOP)/bsg_ip_cores

TEST_DIR       = $(BP_TOP_PATH)/test
ROM_DIR        = $(TEST_DIR)/rom/v
TRACE_ROM_DIR  = $(TEST_DIR)/trace_rom/v

HEX2BIN        = $(BP_TOP_PATH)/software/py/hex2binascii.py
SPIKE2TR       = $(BP_TOP_PATH)/software/py/spike2tr.py
BSG_ROM_GEN    = $(BSG_IP_PATH)/bsg_mem/bsg_ascii_to_rom.py
RISCV_ELF2HEX  = elf2hex
RISCV_SIM	   = spike
RISCV_OBJDUMP  = riscv64-unknown-elf-objdump -D -M no-aliases,numeric
RISCV_GCC=riscv64-unknown-elf-gcc -fPIC -march=rv64i -mabi=lp64 -mcmodel=medany -static -nostdlib -nostartfiles -T demos/riscv.ld

include Makefile.frag

#TODO: add demo rom generation
all: isa

isa: isa_elf isa_rom

isa_elf: $(foreach x, $(subst -,_,$(RV64_TESTS)), $(x))
isa_rom: $(foreach x, $(subst -,_,$(RV64_TESTS)), $(x).v)

#demo: $(foreach x, $(subst -,_,$(BP_DEMOS)),$(x).v)

%.v: %.bin
	python $(BSG_ROM_GEN) $< bp_be_boot_rom zero > $*.vtmp 			             \
	&& awk 'FNR==2{system("$(RISCV_OBJDUMP) $*.elf | sed 's-^-//-'")} 1' $*.vtmp   \
		> $(ROM_DIR)/$*_rom.v 													     \
	&& rm $*.vtmp

%.bin: %.hex
	python $(HEX2BIN) $< 512 > $@

%.hex: %.trace
	$(RISCV_ELF2HEX) 16 32768 $*.elf 2147483648  > $@
	rm $*.elf

%.trace: 
	$(RISCV_SIM) -l $*.elf 2> $*.spike
	python $(SPIKE2TR) $*
	python $(BSG_ROM_GEN) $*.tr bp_trace_rom zero > $(TRACE_ROM_DIR)/$*_rom.v
	rm $*.spike
	rm $*.tr
	
rv64ui_p_%: isa/rv64ui/%.S 
	make -C isa/ $@
	mv isa/$@ $@.elf
	
##########################################
