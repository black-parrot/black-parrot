#!/bin/sh

# Ugly bash magic to get all of the regression tests
i=`(ls /projectnb/risc-v/zazad/push_fe_pc_gen_cleanup/test_bugs_master/compressed_instructions/fork/pre-alpha-release/bp_top/test/rom/v/rv64*_rom.v | xargs -n 1 basename)`
ISA_ROMS=`( for f in $i; do printf '%s\n' "${f%.v}" ; done )`

BENCH_ROMS="median_rom multiply_rom towers_rom vvadd_rom"


echo "################# BP_TOP REGRESSION ###################"
for ROM in $ISA_ROMS ; do
  echo -n "$ROM : "
  make -C /projectnb/risc-v/zazad/push_fe_pc_gen_cleanup/test_bugs_master/compressed_instructions/fork/pre-alpha-release/bp_top/syn ROM_NAME=$ROM run.v \
    | grep "PASS" || echo "FAIL"
done


echo "################# BP_TOP BENCH ###################"
for ROM in $BENCH_ROMS ; do
  echo -n "$ROM : "
  make -C /projectnb/risc-v/zazad/push_fe_pc_gen_cleanup/test_bugs_master/compressed_instructions/fork/pre-alpha-release/bp_top/syn ROM_NAME=$ROM run.v \
    | grep "PASS" || echo "FAIL"
done


