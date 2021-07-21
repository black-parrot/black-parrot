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

#CORES=(1 2 3 4 6 8 12 16)
CORES=( 2 )
FLAGS="LCE_TRACE_P=1 CCE_TRACE_P=1"

builds=()
sims=()

for c in ${CORES[@]}; do
  builds+=(
    "make -C bp_top/syn build.${SUFFIX} ${FLAGS} CFG=e_bp_multicore_${c}_cfg"
    "make -C bp_top/syn build.${SUFFIX} ${FLAGS} CFG=e_bp_multicore_${c}_cce_ucode_cfg"
    )
  sims+=(
    "make -C bp_top/syn sim.${SUFFIX} ${FLAGS} SUITE=bp-tests CFG=e_bp_multicore_${c}_cfg PROG=mc_sanity_${c}"
    "make -C bp_top/syn sim.${SUFFIX} ${FLAGS} SUITE=bp-tests CFG=e_bp_multicore_${c}_cfg PROG=mc_rand_walk_${c}"
    "make -C bp_top/syn sim.${SUFFIX} ${FLAGS} SUITE=bp-tests CFG=e_bp_multicore_${c}_cfg PROG=mc_work_share_sort_${c}"
    "make -C bp_top/syn sim.${SUFFIX} ${FLAGS} SUITE=bp-tests CFG=e_bp_multicore_${c}_cce_ucode_cfg PROG=mc_sanity_${c}"
    "make -C bp_top/syn sim.${SUFFIX} ${FLAGS} SUITE=bp-tests CFG=e_bp_multicore_${c}_cce_ucode_cfg PROG=mc_rand_walk_${c}"
    "make -C bp_top/syn sim.${SUFFIX} ${FLAGS} SUITE=bp-tests CFG=e_bp_multicore_${c}_cce_ucode_cfg PROG=mc_work_share_sort_${c}"
    )
done

let JOBS=${#sims[@]}
let CORES_PER_JOB=${N}/${JOBS}+1

# Any setup needed for the job
make -C bp_top/syn clean.${SUFFIX}

# Run the regression in parallel on each configuration
echo "Running ${JOBS} jobs with ${CORES_PER_JOB} cores per job"
parallel --jobs ${JOBS} --results regress_logs --progress "{}" ::: "${builds[@]}"
parallel --jobs ${JOBS} --results regress_logs --progress "{}" ::: "${sims[@]}"

# Check for failures in the report directory
grep -cr "FAIL" bp_top/syn/reports/$1 && echo "[CI CHECK] $0: FAILED" && exit 1
echo "[CI CHECK] $0: PASSED" && exit 0

