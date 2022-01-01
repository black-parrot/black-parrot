#!/bin/bash

# Command line arguments
if [ "$ne" == '1' ]
then
  echo "Usage: $0 <verilator, vcs> [num_cores]"
  exit 1
elif [ $1 == "vcs" ]
then
    SUFFIX=v
elif [ $1 == "verilator" ]
then
    SUFFIX=sc
else
  echo "Usage: $0 <verilator, vcs> [num_cores]"
  exit 1
fi

# Default to 1 core
N=${2:-1}

cfgs=(\
    "e_bp_multicore_1_acc_loopback_cfg"
    "e_bp_multicore_1_acc_vdp_cfg" 
    "e_bp_multicore_1_acc_vdp_cfg"
    "e_bp_multicore_4_acc_loopback_cfg"
    "e_bp_multicore_4_acc_vdp_cfg"
    )

progs=(
    "streaming_accelerator_loopback"
    "streaming_accelerator_vdp"
    "coherent_accelerator_vdp"
    "accelerator_loopback_multicore_4"
    "streaming_accelerator_loopback"
    "coherent_accelerator_vdp"
    )

# The base command to append the configuration to
build_base="make -C bp_top/syn build_dump.v SUITE=bp-tests"

# Any setup needed for the job
echo "Cleaning bp_top"
make -C bp_top/syn clean

# run simulations
sims=()
for i in "${!cfgs[@]}"
do
    sims+=("make -C bp_top/syn sim_dump.v CFG=${cfgs[$i]} SUITE=bp-tests PROG=${progs[$i]}")
done

# build required configs
build_cfgs=($(echo ${cfgs[*]} | tr ' ' '\012' | uniq))
echo "Building: ${N} jobs with 1 core per job"
parallel --jobs ${N} --results regress_logs --progress "$build_base CFG={}" ::: "${build_cfgs[@]}"

# simulate
echo "Simulating: running parallel with ${N} jobs"
parallel --jobs ${N} --results regress_logs --progress "{}" ::: "${sims[@]}"

# Check for failures in the report directory
grep -cr "FAIL" bp_top/syn/reports/ && echo "[CI CHECK] $0: FAILED" && exit 1
echo "[CI CHECK] $0: PASSED" && exit 0


