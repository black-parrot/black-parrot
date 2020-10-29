#!/bin/bash

# TODO: This script is ugly because we have to run specific tests on specific hardware
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

# Bash array to iterate over for configurations
builds=(
    "make -C bp_top/syn build.${SUFFIX} COSIM_P=1 CFG=e_bp_unicore_cfg"
    "make -C bp_top/syn build.${SUFFIX} COSIM_P=1 CFG=e_bp_multicore_1_cfg"
    "make -C bp_top/syn build.${SUFFIX} COSIM_P=1 CFG=e_bp_multicore_1_cce_ucode_cfg"
    "make -C bp_top/syn build.${SUFFIX} COSIM_P=1 CFG=e_bp_multicore_2_cfg"
    "make -C bp_top/syn build.${SUFFIX} COSIM_P=1 CFG=e_bp_multicore_2_cce_ucode_cfg"
    "make -C bp_top/syn build.${SUFFIX} COSIM_P=1 CFG=e_bp_multicore_4_cfg"
    "make -C bp_top/syn build.${SUFFIX} COSIM_P=1 CFG=e_bp_multicore_4_cce_ucode_cfg"
    )
if [ $1 == "vcs" ]
then
builds+=(
    "make -C bp_top/syn build.${SUFFIX} COSIM_P=1 CFG=e_bp_multicore_8_cce_ucode_cfg"
    "make -C bp_top/syn build.${SUFFIX} COSIM_P=1 CFG=e_bp_multicore_8_cfg"
    "make -C bp_top/syn build.${SUFFIX} COSIM_P=1 CFG=e_bp_multicore_16_cce_ucode_cfg"
    "make -C bp_top/syn build.${SUFFIX} COSIM_P=1 CFG=e_bp_multicore_16_cfg"
    )
fi

sims=(
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_unicore_cfg PROG=mc_sanity_1"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_unicore_cfg PROG=mc_rand_walk_1"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_unicore_cfg PROG=mc_work_share_sort_1"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_1_cce_ucode_cfg PROG=mc_sanity_1"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_1_cce_ucode_cfg PROG=mc_rand_walk_1"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_1_cce_ucode_cfg PROG=mc_work_share_sort_1"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_1_cfg PROG=mc_sanity_1"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_1_cfg PROG=mc_rand_walk_1"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_1_cfg PROG=mc_work_share_sort_1"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_2_cfg PROG=mc_sanity_2"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_2_cfg PROG=mc_rand_walk_2"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_2_cfg PROG=mc_work_share_sort_2"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_2_cce_ucode_cfg PROG=mc_sanity_2"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_2_cce_ucode_cfg PROG=mc_rand_walk_2"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_2_cce_ucode_cfg PROG=mc_work_share_sort_2"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_4_cfg PROG=mc_sanity_4"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_4_cfg PROG=mc_rand_walk_4"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_4_cfg PROG=mc_work_share_sort_4"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_4_cce_ucode_cfg PROG=mc_sanity_4"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_4_cce_ucode_cfg PROG=mc_rand_walk_4"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_4_cce_ucode_cfg PROG=mc_work_share_sort_4"
    )
if [ $1 == "vcs" ]
then
sims+=(
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_8_cfg PROG=mc_sanity_8"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_8_cfg PROG=mc_rand_walk_8"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_8_cfg PROG=mc_work_share_sort_8"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_8_cce_ucode_cfg PROG=mc_sanity_8"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_8_cce_ucode_cfg PROG=mc_rand_walk_8"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_8_cce_ucode_cfg PROG=mc_work_share_sort_8"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_16_cfg PROG=mc_sanity_16"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_16_cfg PROG=mc_rand_walk_16"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_16_cfg PROG=mc_work_share_sort_16"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_16_cce_ucode_cfg PROG=mc_sanity_16"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_16_cce_ucode_cfg PROG=mc_rand_walk_16"
    "make -C bp_top/syn sim.${SUFFIX} COSIM_P=1 SUITE=bp_tests CFG=e_bp_multicore_16_cce_ucode_cfg PROG=mc_work_share_sort_16"
    )
fi

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
