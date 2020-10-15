#!/bin/bash

# Command line arguments
if [ "$ne" == '1' ]
then
  echo "Usage: $0 <verilator, vcs>"
  exit 1
elif [ $1 == "vcs" ]
then
    SUFFIX=v
elif [ $1 == "verilator" ]
then
    SUFFIX=sc
else
  echo "Usage: $0 <verilator, vcs>"
  exit 1
fi

# Default to 1 core
N=${2:-1}

# Bash array to iterate over for configurations
cfgs=(\
    "e_bp_unicore_cfg"
    "e_bp_multicore_1_cfg"
    "e_bp_multicore_1_cce_ucode_cfg"
    )

let JOBS=${#cfgs[@]}
let CORES_PER_JOB=${N}/${JOBS}+1

# The base command to append the configuration to
cmd_base="make -C bp_top/syn build.${SUFFIX} sim_sample.${SUFFIX} SUITE=beebs PROG=aha-compress CHECKPOINT_P=1 SAMPLE_START_P=1000 SAMPLE_MEMSIZE=64"

# Any setup needed for the job
make -C bp_top/syn clean.${SUFFIX}

# Run the regression in parallel on each configuration
echo "Running ${JOBS} jobs"
parallel --jobs ${JOBS} --results regress_logs --progress "$cmd_base CFG={}" ::: "${cfgs[@]}"

# Check for failures in the report directory
grep -cr "FAIL" */syn/reports/ && echo "[CI CHECK] $0: FAILED" && exit 1
echo "[CI CHECK] $0: PASSED" && exit 0
