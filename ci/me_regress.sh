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
  echo "Usage: $0 <verilator, vcs> <testlist> [num_cores]"
  exit 1
fi

# Default to 1 core
N=${2:-1}

# Bash array to iterate over for configurations
cfgs=(
    "e_bp_half_core_cfg"
    "e_bp_half_core_ucode_cce_cfg"
    )

# The base command to append the configuration to
cmd_base="make -C bp_me/syn run_testlist.${SUFFIX}"

# Any setup needed for the job

let JOBS=${#cfgs[@]}
let CORES_PER_JOB=${N}/${JOBS}+1

# Run the regression in parallel on each configuration
echo "Running ${JOBS} jobs with ${CORES_PER_JOB} cores per job"
# EI
parallel --jobs ${JOBS} --results regress_logs --progress "$cmd_base COH_PROTO=ei CFG={}" ::: ${cfgs}
# MSI
parallel --jobs ${JOBS} --results regress_logs --progress "$cmd_base COH_PROTO=msi CFG={}" ::: ${cfgs}
# MESI
parallel --jobs ${JOBS} --results regress_logs --progress "$cmd_base COH_PROTO=mesi CFG={}" ::: ${cfgs}
# MSI-Nonspec
parallel --jobs ${JOBS} --results regress_logs --progress "$cmd_base COH_PROTO=msi-nonspec CFG={}" ::: ${cfgs}
# MESI-Nonspec
parallel --jobs ${JOBS} --results regress_logs --progress "$cmd_base COH_PROTO=mesi-nonspec CFG={}" ::: ${cfgs}

# Check for failures in the report directory
grep -cr "FAIL" */syn/reports/ && echo "[CI CHECK] $0: FAILED" && exit 1
echo "[CI CHECK] $0: PASSED" && exit 0
