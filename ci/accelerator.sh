#!/bin/bash

# Command line arguments

# Default to 1 core
N=${1:-1}

cfgs=(\
    "e_bp_multicore_1_accelerator_cfg"
    )

progs=(
    "streaming_accelerator_loopback"
    "coherent_accelerator_demo"
    )

# The base command to append the configuration to
build_base="make -C bp_top/syn build_dump.v sim_dump.v SUITE=bp-tests"

# Any setup needed for the job
echo "Cleaning bp_top"
make -C bp_top/syn clean


# run simulations
sims=()
for cfg in "${cfgs[@]}"
do
  for prog in "${progs[@]}"
  do
    sims+=("make -C bp_top/syn build_dump.v sim_dump.v CFG=$cfg SUITE=bp-tests PROG=$prog")
  done
done

# build required configs
echo "Building: ${N} jobs with 1 core per job"
parallel --jobs ${N} --results regress_logs --progress "$build_base CFG={}" ::: "${cfgs[@]}"

# simulate
echo "Simulating: running parallel with ${N} jobs"
parallel --jobs ${N} --results regress_logs --progress "{}" ::: "${sims[@]}"

# Check for failures in the report directory
grep -cr "FAIL" bp_top/syn/reports/ && echo "[CI CHECK] $0: FAILED" && exit 1
echo "[CI CHECK] $0: PASSED" && exit 0


