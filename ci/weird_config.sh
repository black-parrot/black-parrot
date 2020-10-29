#!/bin/bash

# Command line arguments
TESTLIST=$2
if [ "$ne" == '1' ]
then
  echo "Usage: $0 <verilator, vcs> <testlist> [num_cores]"
  exit 1
elif [ $1 == "vcs" ]
then
    SUFFIX=v
elif [ $1 == "verilator" ]
then
    SUFFIX=sc
else
  echo "Usage: $0 <verilator, vcs> <testlist> [num_cores]"
  exit 1
fi

# Default to 1 core
N=${3:-1}

# Bash array to iterate over for configurations
cfgs=(\
    "e_bp_multicore_16_cce_ucode_cfg"
    "e_bp_multicore_16_cfg"
    "e_bp_multicore_12_cce_ucode_cfg"
    "e_bp_multicore_12_cfg"
    "e_bp_multicore_8_cce_ucode_cfg"
    "e_bp_multicore_8_cfg"
    "e_bp_multicore_6_cce_ucode_cfg"
    "e_bp_multicore_6_cfg"
    "e_bp_multicore_4_accelerator_cfg"
    "e_bp_multicore_4_cce_ucode_cfg"
    "e_bp_multicore_4_cfg"
    "e_bp_multicore_3_cce_ucode_cfg"
    "e_bp_multicore_3_cfg"
    "e_bp_multicore_2_cce_ucode_cfg"
    "e_bp_multicore_2_cfg"
    "e_bp_multicore_1_cce_ucode_cfg"
    "e_bp_multicore_1_no_l2_cfg"
    "e_bp_multicore_1_l1_medium_cfg"
    "e_bp_multicore_1_l1_small_cfg"
    "e_bp_multicore_1_cfg"

    "e_bp_unicore_writethrough_cfg"
    "e_bp_unicore_no_l2_cfg"
    "e_bp_unicore_l1_medium_cfg"
    "e_bp_unicore_l1_small_cfg"
    "e_bp_unicore_cfg"
    )

# The base command to append the configuration to
cmd_base="make -C bp_top/syn build.${SUFFIX} sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests PROG=cache_hammer"

# Any setup needed for the job
echo "Cleaning bp_top"
make -C bp_top/syn clean.syn

let JOBS=${#cfgs[@]}
let CORES_PER_JOB=${N}/${JOBS}+1

# Run the regression in parallel on each configuration
echo "Running ${JOBS} jobs with ${CORES_PER_JOB} cores per job"
parallel --jobs ${JOBS} --results regress_logs --progress "$cmd_base CFG={}" ::: "${cfgs[@]}"

# Check for failures in the report directory
grep -cr "FAIL" */syn/reports/ && echo "[CI CHECK] $0: FAILED" && exit 1
echo "[CI CHECK] $0: PASSED" && exit 0
