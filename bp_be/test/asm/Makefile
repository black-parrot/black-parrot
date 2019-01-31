TOP            = $(CURDIR)/../../..
BP_TOP_PATH	   = $(TOP)/bp_top
BP_FE_PATH	   = $(TOP)/bp_fe
BP_BE_PATH	   = $(TOP)/bp_be
BP_ME_PATH 	   = $(TOP)/bp_me
BP_COMMON_PATH = $(TOP)/bp_common

BSG_IP_PATH	   = $(TOP)/bsg_ip_cores

TB_DIR         = $(BP_BE_PATH)/tb
ASM_DIR        = $(TB_DIR)/asm
ROM_DIR        = $(TB_DIR)/rom
TRACE_ROM_DIR  = $(TB_DIR)/trace_rom

HEX2BIN        = $(BP_BE_PATH)/software/py/hex2binascii.py
SPIKE2TR        = $(BP_BE_PATH)/software/py/spike2tr.py
BSG_ROM_GEN    = $(BSG_IP_PATH)/bsg_mem/bsg_ascii_to_rom.py
RISCV_ELF2HEX  = elf2hex
RISCV_SIM	   = spike
RISCV_OBJDUMP  = riscv64-unknown-elf-objdump -D -M no-aliases,numeric
RANDOM_FLD = ${BP_COMMON_PATH}/test_infra/bp_test_random/build/
RANDOM_GEN = ${RANDOM_FLD}/igen
RISCV_GCC = riscv64-unknown-elf-gcc -nostdlib -nostartfiles -Wa,-march=rv64g -I${RANDOM_FLD}p/ -T${RANDOM_FLD}p/link.ld
RANDOM_NUM=0
SEED=0
include $(ASM_DIR)/Makefile.frag

.default : all

rv64ui-test-roms: $(foreach x,$(subst -,_,$(RV64_TESTS)),$(x).v)

rv64ui-trace-roms: $(foreach x,$(subst -,_,$(RV64_TESTS)),$(x)_trace_rom.v)

rv_random:
	num=1; while [ $$num -le $(RANDOM_NUM) ]; do make test`expr $$num + 0`_random.v SEED=`expr $$num + 0`; num=`expr $$num + 1`; done

test: rv64ui_p_example.v 

all: rv64ui-test-roms

#TODO: Magic numbers everywhere
%_trace_rom.v: %.riscv
	$(RISCV_SIM) -l $*.riscv 2> $*.spike
	rm $*.riscv
	python $(SPIKE2TR) $* 10
	rm $*.spike
	python $(BSG_ROM_GEN) $*.tr $*_trace_rom zero > $(TRACE_ROM_DIR)/$*_trace_rom.v
	rm $*.tr

%.v: %.bin
	python $(BSG_ROM_GEN) $*.bin bp_be_boot_rom zero > $*.vtmp 			             \
	&& awk 'FNR==2{system("$(RISCV_OBJDUMP) $*.riscv | sed 's-^-//-'")} 1' $*.vtmp   \
		> $(ROM_DIR)/$*_rom.v 													     \
	&& rm $*.vtmp

%.bin: %.hex
	python $(HEX2BIN) $*.hex 512 > $@

%.hex: %.riscv
	$(RISCV_ELF2HEX) 16 32768 $< 2147483648  > $@

%_random.riscv:
	$(RANDOM_GEN) -seed $(SEED) -mem 50 20 -mode m -o $@.S
	${RISCV_GCC}  $@.S -o $@
	rm $@.S

%.riscv:
	make -C $(ASM_DIR)/isa/ $*
	mv $(ASM_DIR)/isa/$* $*.riscv

clean:
	rm $(ROM_DIR)/*.v
	rm $(TRACE_ROM_DIR)/*.v
