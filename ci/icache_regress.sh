#!/bin/bash

# Command line arguments

# Default to 1 core
N=${1:-1}

# Bash array to iterate over for configurations
cfgs=(
    "e_bp_half_core_cfg"
    )

# The base command to append the configuration to
cmd_base="make -C bp_fe/syn run_testlist.v"

# Any setup needed for the job
make -C bp_fe/syn clean

let JOBS=${#cfgs[@]}
let CORES_PER_JOB=${N}/${JOBS}+1

# Run the regression in parallel on each configuration
echo "Running ${JOBS} jobs with ${CORES_PER_JOB} cores per job"
parallel --jobs ${JOBS} --results regress_logs --progress "$cmd_base CFG={}" ::: "${cfgs[@]}"

# Check for failures in the report directory
grep -cr "FAIL" */syn/reports/ && echo "[CI CHECK] $0: FAILED" && exit 1
echo "[CI CHECK] $0: PASSED" && exit 0
