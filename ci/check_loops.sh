#!/bin/bash

# Command line arguments

# Default to 1 core
N=${1:-1}

# Bash array to iterate over for configurations
cfgs=(\
    "e_bp_unicore_cfg"
    "e_bp_multicore_1_cfg"
    "e_bp_multicore_1_cce_ucode_cfg"
    "e_bp_multicore_4_cfg"
    "e_bp_multicore_4_cce_ucode_cfg"
    )

# The base command to append the configuration to
cmd_base="make -C bp_top/syn check_loops.syn"

# Any setup needed for the job
echo "Cleaning bp_top"
make -C bp_top/syn clean.syn

let JOBS=${#cfgs[@]}
let CORES_PER_JOB=${N}/${JOBS}+1

# Run the regression in parallel on each configuration
echo "Running ${JOBS} jobs with ${CORES_PER_JOB} cores per job"
parallel --jobs ${JOBS} --results regress_logs --progress "$cmd_base CFG={}" ::: "${cfgs[@]}"

echo "Running check_loops on bp_me"
make -C bp_me/syn CFG=e_bp_half_core_cfg & 
make -C bp_me/syn CFG=e_bp_half_core_ucode_cce_cfg &
wait

# Check for failures in the report directory
grep -cr "FAIL" */syn/reports/ && echo "[CI CHECK] $0: FAILED" && exit 1
echo "[CI CHECK] $0: PASSED" && exit 0
