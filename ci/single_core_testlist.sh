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
    "e_bp_unicore_cfg"
    "e_bp_multicore_1_cfg"
    "e_bp_multicore_1_cce_ucode_cfg"
    )

let JOBS=${#cfgs[@]}
let CORES_PER_JOB=${N}/${JOBS}+1

# The base command to append the configuration to
cmd_base="make -j ${CORES_PER_JOB} -C bp_top/syn COSIM_P=1 run_testlist.${SUFFIX} TESTLIST=$TESTLIST"

# Any setup needed for the job
make -C bp_top/syn clean.${SUFFIX}

# Run the regression in parallel on each configuration
echo "Running ${JOBS} jobs with ${CORES_PER_JOB} cores per job"
parallel --jobs ${JOBS} --results regress_logs --progress "$cmd_base CFG={}" ::: "${cfgs[@]}"

# Check for failures in the report directory
grep -cr "FAIL" bp_top/syn/reports/ && echo "[CI CHECK] $0: FAILED" && exit 1
echo "[CI CHECK] $0: PASSED" && exit 0
