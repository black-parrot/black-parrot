#!/bin/bash

# Command line arguments

# Priority is CI_CORES environment variable > argument of script > 1
CI_CORES=${CI_CORES:-1}
N=${1:-$CI_CORES}

# Bash array to iterate over for configurations
cfgs=(
    "e_bp_single_core_ucode_cce_cfg"
    "e_bp_single_core_cfg"
    "e_bp_softcore_cfg"
    "e_bp_quad_core_cfg"
    "e_bp_quad_core_ucode_cce_cfg"
    )

# The base command to append the configuration to
cmd_base="echo 'Foo-ifying'"

# Any setup needed for the job
echo "Beginning foo-ification"

let JOBS=${#cfgs[@]}
let CORES_PER_JOB=${N}/${JOBS}+1

# Run the regression in parallel on each configuration
echo "Running ${JOBS} jobs with ${CORES_PER_JOB} cores per job"
parallel --jobs ${JOBS} --results regress_logs --progress "$cmd_base CFG={}" ::: "${cfgs[@]}"

# Check for failures in the report directory
grep -cr "FAIL" */syn/reports/ && echo "[CI CHECK] $0: FAILED" && exit 1
echo "[CI CHECK] $0: PASSED" && exit 0
