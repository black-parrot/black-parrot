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

# Bash array to iterate over for configurations
cfgs=(\
    "e_bp_multicore_12_cce_ucode_cfg"
    "e_bp_multicore_12_cfg"
    "e_bp_multicore_8_cce_ucode_cfg"
    "e_bp_multicore_8_cfg"
    "e_bp_multicore_6_cce_ucode_cfg"
    "e_bp_multicore_6_cfg"
    "e_bp_multicore_4_cce_ucode_cfg"
    "e_bp_multicore_4_cfg"
    "e_bp_multicore_3_cce_ucode_cfg"
    "e_bp_multicore_3_cfg"
    "e_bp_multicore_2_cce_ucode_cfg"
    "e_bp_multicore_2_cfg"
    "e_bp_multicore_1_cce_ucode_cfg"
    "e_bp_multicore_1_megaparrot_cfg"
    "e_bp_multicore_1_miniparrot_cfg"
    "e_bp_multicore_1_cfg"

    "e_bp_unicore_megaparrot_cfg"
    "e_bp_unicore_miniparrot_cfg"
    "e_bp_unicore_tinyparrot_cfg"
    "e_bp_unicore_cfg"
    )

# Any setup needed for the job
echo "Cleaning bp_top"
make -C bp_top/syn clean

let JOBS=${#cfgs[@]}
let CORES_PER_JOB=${N}/${JOBS}+1

# Build configs
cmd_base="make -C bp_top/syn build.${SUFFIX} COSIM_P=1 DRAM=axi"
parallel --jobs ${JOBS} --results regress_logs --progress "$cmd_base CFG={}" ::: "${cfgs[@]}"

# Run the regression in parallel on each configuration
cmd_base="make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp-tests PROG=hello_world DRAM=axi"
echo "Running ${JOBS} jobs with ${CORES_PER_JOB} cores per job"
parallel --jobs ${JOBS} --results regress_logs --progress "$cmd_base CFG={}" ::: "${cfgs[@]}"

# Run a second set of tests
cmd_base="make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp-tests PROG=cache_hammer DRAM=axi"
echo "Running ${JOBS} jobs with ${CORES_PER_JOB} cores per job"
parallel --jobs ${JOBS} --results regress_logs --progress "$cmd_base CFG={}" ::: "${cfgs[@]}"

# Run a third set of tests
cmd_base="make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp-tests PROG=stream_hammer DRAM=axi"
echo "Running ${JOBS} jobs with ${CORES_PER_JOB} cores per job"
parallel --jobs ${JOBS} --results regress_logs --progress "$cmd_base CFG={}" ::: "${cfgs[@]}"

# Check for failures in the report directory
grep -cr "FAIL" bp_top/syn/reports/ && echo "[CI CHECK] $0: FAILED" && exit 1
echo "[CI CHECK] $0: PASSED" && exit 0
