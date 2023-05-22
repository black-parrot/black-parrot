#!/bin/bash

# Command line arguments

# Default to 1 core
N=${1:-1}

# Bash array to iterate over for configurations
# Only works with tinyparrot_cfg at the moment
cfgs=(\
    "e_bp_unicore_tinyparrot_cfg"
    )

# The base command to append the configuration to
cmd_base="make -C bp_top/syn convert.bsg_sv2v synth.yosys build_yosys.v sim_yosys.v"

# Any setup needed for the job
echo "Cleaning bp_top"
make -C bp_top/syn clean

let JOBS=${#cfgs[@]}
let CORES_PER_JOB=${N}/${JOBS}+1

# Run the regression in parallel on each configuration
echo "Running ${JOBS} jobs with ${CORES_PER_JOB} cores per job"
parallel --jobs ${JOBS} --results regress_logs --progress "$cmd_base CFG={}" ::: "${cfgs[@]}"

# Check for failures in the report directory
grep -cr "FAIL" */syn/reports/ && echo "[CI CHECK] $0: FAILED" && exit 1
echo "[CI CHECK] $0: PASSED" && exit 0
