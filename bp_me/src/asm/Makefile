###

INC_DIR=$(abspath ./include)
SRC_DIR=$(abspath ./src)

BSG_MEM_DIR=$(abspath ../../../external/basejump_stl/bsg_mem)

CXX=g++
COMMON_CFLAGS=-Wall -Wno-switch -Wno-format -Wno-unused-function
CXXFLAGS=-g -std=c++11 $(COMMON_CFLAGS)
CXXFLAGS +=-I$(INC_DIR)

LD=g++
LFLAGS=-g $(COMMON_FLAGS)

as_SRC=$(abspath $(wildcard $(SRC_DIR)/*.cc))

AS=bp-as

CODE=$(abspath ./microcode)
CODE_INC_DIR=$(CODE)/include
CCE_DIR=$(CODE)/cce
cce_SRC=$(abspath $(wildcard $(CCE_DIR)/*.S))
cce_PRE_SRC=$(cce_SRC:.S=.pre)
cce_MEM=$(cce_SRC:.S=.mem)
cce_DBG=$(cce_SRC:.S=.dbg)

.DEFAULT: echo
.SECONDARY: %.addr

echo:
	@echo "try running: 'make as'"

%.o: %.cc
	$(CXX) $(CXXFLAGS) -c -o $@ $<

as: $(as_SRC:.cc=.o)
	$(LD) $(LFLAGS) -o $(AS) $(as_SRC:.cc=.o)

%.addr: %.S
	python2 py/addr.py -i $< > $@

%.pre: %.S
	gcc -E $(COMMON_CFLAGS) -I$(CODE_INC_DIR) $< -o $@

%.mem: %.pre
	./$(AS) -b -i $< -o $@

%.dbg: %.pre
	./$(AS) -d -i $< -o $@

%.rom: %.mem
	python2 $(BSG_MEM_DIR)/bsg_ascii_to_rom.py $< bp_cce_inst_rom zero > bp_cce_inst_rom.v

tidy:
	rm -f $(as_SRC:.cc=.o) $(cce_PRE_SRC) $(cce_DBG)

clean:
	rm -f $(AS) $(as_SRC:.cc=.o) $(cce_PRE_SRC) $(cce_MEM) $(cce_DBG)
	rm -rf roms

roms: as ei msi mesi mesi-nonspec

ei: $(AS)
	python2 py/roms.py -i microcode/cce/ei --bsg $(BSG_MEM_DIR) --outdir ./roms/ei

msi: $(AS)
	python2 py/roms.py -i microcode/cce/msi --bsg $(BSG_MEM_DIR) --outdir ./roms/msi

mesi: $(AS)
	python2 py/roms.py -i microcode/cce/mesi --bsg $(BSG_MEM_DIR) --outdir ./roms/mesi

mesi-nonspec: $(AS)
	python2 py/roms.py -i microcode/cce/mesi-nonspec --bsg $(BSG_MEM_DIR) --outdir ./roms/mesi-nonspec

as_test: $(AS)
	python2 py/roms.py -i microcode/cce/test --bsg $(BSG_MEM_DIR) --outdir ./roms/test

