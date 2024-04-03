#!/bin/bash

# Command line arguments
if [ "$ne" == '1' ]
then
  echo "Usage: $0 <verilator, vcs> [num_cores]"
  exit 1
elif [ $1 == "vcs" ]
then
    SUFFIX=vcs
elif [ $1 == "verilator" ]
then
    SUFFIX=verilator
else
  echo "Usage: $0 <verilator, vcs> [num_cores]"
  exit 1
fi

# Default to 1 core
N=${2:-1}

cfgs=(\
    "e_bp_unicore_cfg"
    "e_bp_multicore_1_cfg"
    "e_bp_multicore_1_cce_ucode_cfg"
    "e_bp_multicore_2_cfg"
    "e_bp_multicore_2_cce_ucode_cfg"
    "e_bp_multicore_4_cfg"
    "e_bp_multicore_4_cce_ucode_cfg"
    )

if [ $1 == "vcs" ]
then
cfgs+=(
    "e_bp_multicore_6_cfg"
    "e_bp_multicore_6_cce_ucode_cfg"
    "e_bp_multicore_8_cfg"
    "e_bp_multicore_8_cce_ucode_cfg"
    "e_bp_multicore_12_cfg"
    "e_bp_multicore_12_cce_ucode_cfg"
    "e_bp_multicore_16_cfg"
    "e_bp_multicore_16_cce_ucode_cfg"
    )
fi

progs=(
    "mc_sanity"
    "mc_rand_walk"
    "mc_work_share_sort"
    "mc_lrsc_add"
    )

# The base command to append the configuration to
build_base="make -C bp_top/syn build.${SUFFIX} COSIM_P=1"

# Any setup needed for the job
make -C bp_top/syn clean.${SUFFIX}

# run simulations
sims=()
for cfg in "${cfgs[@]}"
do
  for prog in "${progs[@]}"
  do
    sims+=("make -C bp_top/syn sim.${SUFFIX} CFG=$cfg COSIM_P=1 SUITE=bp-tests PROG=$prog")
  done
done

# build required configs
echo "Building: ${N} jobs with 1 core per job"
parallel --jobs ${N} --results regress_logs --progress "$build_base CFG={}" ::: "${cfgs[@]}"

# simulate
echo "Simulating: running parallel with ${N} jobs"
parallel --jobs ${N} --results regress_logs --progress "{}" ::: "${sims[@]}"

# Check for failures in the report directory
grep -cr "FAIL" bp_top/syn/reports/$1 && echo "[CI CHECK] $0: FAILED" && exit 1
echo "[CI CHECK] $0: PASSED" && exit 0
