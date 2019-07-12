# cmurphi protocol verification

TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

CMURPHI_DIR = $(TOP)/external/cmurphi
##$(abspath ./cmurphi5.4.9.1)
CMURPHI_SRC_DIR = $(CMURPHI_DIR)/src
CMURPHI = $(CMURPHI_SRC_DIR)/mu
CMURPHI_INC_DIR = $(CMURPHI_DIR)/include

CXX=g++
CXX_FLAGS=
OXX_FLAGS=-O3
LD_FLAGS=-lm

M_FILE=mesi.m
CPP_FILE=$(M_FILE:.m=.cpp)
EXE=$(M_FILE:.m=)

mu: $(CMURPHI)

$(CMURPHI):
	make -C $(CMURPHI_SRC_DIR) mu

build: $(CMURPHI)
	$(CMURPHI) -b -c --disk $(M_FILE)
	$(CXX) $(CXX_FLAGS) $(OXX_FLAGS) -o $(EXE) $(CPP_FILE) -I$(CMURPHI_INC_DIR) $(LD_FLAGS)

dbg:
	./$(EXE) -p -pr -tf -ta -tv -d ./ > run.log

ndl:
	./$(EXE) -ndl

run:
	./$(EXE) -p5

states:
	grep -Ei "rule|homenode\.state|Procs\[proc_[12]\]\.state" deadlock.trace > states.log

clean:
	make -C $(CMURPHI_SRC_DIR) clean
	rm -f $(CPP_FILE) $(EXE)
	rm -f run.log deadlock.trace states.log

cleanall: clean
	make -C $(CMURPHI_SRC_DIR) cleanall
