#!/bin/sh

# Ugly bash magic to get all of the regression tests
i=`(ls $BP_BE_DIR/test/rom/v/rv64*_rom.v | xargs -n 1 basename)`
ISA_ROMS=`( for f in $i; do printf '%s\n' "${f%.v}" ; done )`

BENCH_ROMS="median_rom multiply_rom towers_rom vvadd_rom"

echo "################# BP_BE REGRESSION ###################"
for ROM in $ISA_ROMS ; do 
  echo -n "$ROM : "
  make -C $BP_BE_DIR/syn TEST_ROM=$ROM.v TRACE_ROM=$ROM.tr.v bp_be_trace_demo.run.v \
    | grep "PASS" || echo "FAIL"
done

echo "################# BP_BE BENCH ###################"
for ROM in $BENCH_ROMS ; do 
  echo -n "$ROM : "
  make -C $BP_BE_DIR/syn TEST_ROM=$ROM.v TRACE_ROM=$ROM.tr.v bp_be_trace_demo.run.v \
    | grep "PASS" || echo "FAIL"
done

echo "################# BP_BE_DCACHE AXE TEST ###################"
DCACHE_AXE_TEST_DIR=$BP_BE_DIR/test/tb/bp_be_dcache/dcache_axe_test

for lce in 2 4 8 16; do
  echo "Running $lce LCE AXE TEST"
  make -C $DCACHE_AXE_TEST_DIR NUM_LCE_P=$lce NUM_INSTR_P=2500 > /dev/null
  make -C $DCACHE_AXE_TEST_DIR axe | grep "OK" || echo "FAIL"
done

