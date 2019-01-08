###

BP_INC_DIR=$(abspath ../include/c)
INC_DIR=$(abspath ./include)
SRC_DIR=$(abspath ./src)

BSG_MEM_DIR=$(abspath ../../bsg_ip_cores/bsg_mem)

CXX=g++
COMMON_CFLAGS=-Wall -Wno-switch -Wno-format -Wno-unused-function
CXXFLAGS=-g -std=c++11 $(COMMON_CFLAGS)
CXXFLAGS +=-I$(BP_INC_DIR) -I$(INC_DIR)

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

TEST_DIR=$(CODE)/tests
test_SRC=$(abspath $(wildcard $(TEST_DIR)/*.S))
test_PRE_SRC=$(test_SRC:.S=.pre)
test_MEM=$(test_SRC:.S=.mem)
test_DBG=$(test_SRC:.S=.dbg)

MEMTEST_DIR=$(CODE)/mem_test
memtest_SRC=$(abspath $(wildcard $(MEMTEST_DIR)/*.S))
memtest_PRE_SRC=$(memtest_SRC:.S=.pre)
memtest_MEM=$(memtest_SRC:.S=.mem)
memtest_DBG=$(memtest_SRC:.S=.dbg)

all: as

%.o: %.cc
	$(CXX) $(CXXFLAGS) -c -o $@ $<

as: $(as_SRC:.cc=.o)
	$(LD) $(LFLAGS) -o $(AS) $(as_SRC:.cc=.o)

cce: as $(cce_MEM)
cce-dbg: as $(cce_DBG)

tests: as $(test_MEM)

mem-test: as $(memtest_MEM)
mem-test-dbg: as $(memtest_DBG)

%.pre: %.S
	echo $(CFLAGS)
	gcc -E $(CFLAGS) -I$(CODE_INC_DIR) $< -o $@

%.mem: %.pre
	./$(AS) -b -i $< -o $@

%.dbg: %.pre
	./$(AS) -d -i $< -o $@

%.rom: %.mem
	python2 $(BSG_MEM_DIR)/bsg_ascii_to_rom.py $< bp_cce_inst_rom > bp_cce_inst_rom.v

clean:
	rm -f $(AS) $(as_SRC:.cc=.o) $(test_PRE_SRC) $(test_MEM) $(cce_PRE_SRC) $(cce_MEM) $(memtest_PRE_SRC) \
	$(memtest_MEM) $(cce_DBG) $(test_DBG) $(memtest_DBG)
