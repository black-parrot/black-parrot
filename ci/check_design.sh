#!/bin/bash

# Priority is CI_CORES environment variable > last argument of script > 1
CI_CORES=${CI_CORES:-1}
N=${1:-$CI_CORES}

# Bash array to iterate over for configurations
cfgs=(\
    "e_bp_single_core_ucode_cce_cfg" \
    "e_bp_single_core_cfg" \
    "e_bp_softcore_cfg" \
    "e_bp_quad_core_cfg" \
    "e_bp_quad_core_ucode_cce_cfg"\
    )

# The base command to append the configuration to
cmd_base="make -C bp_top/syn check_design.syn"

# Any setup needed for the job
echo "Cleaning bp_top"
make -C bp_top/syn clean.syn

# Run the regression in parallel on each configuration
echo "Running regression with $N jobs"
parallel --jobs $N --results regress_logs --progress "$cmd_base CFG={}" ::: "${cfgs[@]}"

# Check for failures in the report directory
grep -cr "FAIL" */syn/reports/ && echo "[CI CHECK] $0: FAILED" && exit 1
echo "[CI CHECK] $0: PASSED" && exit 0
