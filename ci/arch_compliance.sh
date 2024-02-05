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
  echo "Usage: $0 <verilator, vcs> [num_cores]"
  exit 1
fi

# Default to 1 core
N=${2:-1}

TESTSTR=$(make -C bp_top/test/tb/bp_tethered/ -f Makefile.testlist -p -n | grep RVARCH)
TESTLIST=${TESTSTR:18:1000000}
progs=( $TESTLIST )

let JOBS=${#progs[@]}
let CORES_PER_JOB=${N}/${JOBS}+1

# The base command to append the configuration to
cmd_base="make -C bp_top/syn COSIM_P=0 sim.${SUFFIX} sigcheck.${SUFFIX}"

# Any setup needed for the job
make -C bp_top/syn clean.${SUFFIX} build.${SUFFIX}

# Run the regression in parallel on each configuration
echo "Running ${JOBS} jobs with ${CORES_PER_JOB} cores per job"
parallel --jobs ${JOBS} --results regress_logs --progress "$cmd_base SUITE=riscv-arch PROG={}" ::: "${progs[@]}"

# Check for failures in the report directory
grep -cr "FAIL" bp_top/syn/reports/ && echo "[CI CHECK] $0: FAILED" && exit 1
echo "[CI CHECK] $0: PASSED" && exit 0
