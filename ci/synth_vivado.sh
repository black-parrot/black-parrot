#!/bin/bash

# Command line arguments

# Default to 1 core
N=${1:-1}

# Bash array to iterate over for configurations
cfgs=(\
    "e_bp_unicore_cfg"
    "e_bp_multicore_1_cfg"
    "e_bp_multicore_1_cce_ucode_cfg"
    "e_bp_multicore_2_cfg"
    "e_bp_multicore_2_cce_ucode_cfg"
    )

# Any setup needed for the job
echo "Cleaning bp_top"
make -C bp_top/syn clean

let JOBS=${#cfgs[@]}
let CORES_PER_JOB=${N}/${JOBS}+1

cmd_base="make -C bp_top/syn synth.vivado"
# Run the regression in parallel on each configuration
echo "Running ${JOBS} jobs with ${CORES_PER_JOB} cores per job"
parallel --jobs ${JOBS} --results regress_logs --progress "$cmd_base CFG={}" ::: "${cfgs[@]}"

cmd_base="make -C bp_top/syn build_vivado.v"
# Run the regression in parallel on each configuration
echo "Running ${JOBS} jobs with ${CORES_PER_JOB} cores per job"
parallel --jobs ${JOBS} --results regress_logs --progress "$cmd_base CFG={}" ::: "${cfgs[@]}"

cmd_base="make -C bp_top/syn sim_vivado.v SUITE=bp-tests PROG=cache_hammer"
# Run the regression in parallel on each configuration
echo "Running ${JOBS} jobs with ${CORES_PER_JOB} cores per job"
parallel --jobs ${JOBS} --results regress_logs --progress "$cmd_base CFG={}" ::: "${cfgs[@]}"

# Check for failures in the report directory
grep -cr "ERROR" */syn/reports/ && echo "[CI CHECK] $0: FAILED" && exit 1

echo "[CI CHECK] $0: PASSED" && exit 0
