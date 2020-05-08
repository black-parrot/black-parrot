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
  echo "Usage: $0 <verilator, vcs> <testlist> [num_cores]"
  exit 1
fi

# Default to 1 core
N=${2:-1}

# Bash array to iterate over for configurations
builds=(
    "make -C bp_top/syn build.${SUFFIX} CFG=e_bp_single_core_ucode_cce_cfg"
    "make -C bp_top/syn build.${SUFFIX} CFG=e_bp_single_core_cfg"
    "make -C bp_top/syn build.${SUFFIX} CFG=e_bp_dual_core_ucode_cce_cfg"
    "make -C bp_top/syn build.${SUFFIX} CFG=e_bp_dual_core_cfg"
    "make -C bp_top/syn build.${SUFFIX} CFG=e_bp_quad_core_ucode_cce_cfg"
    "make -C bp_top/syn build.${SUFFIX} CFG=e_bp_quad_core_cfg"
    )
if [ $1 == "vcs" ]
then
builds+=(
    "make -C bp_top/syn build.${SUFFIX} CFG=e_bp_oct_core_ucode_cce_cfg"
    "make -C bp_top/syn build.${SUFFIX} CFG=e_bp_oct_core_cfg"
    "make -C bp_top/syn build.${SUFFIX} CFG=e_bp_sexta_core_ucode_cce_cfg"
    "make -C bp_top/syn build.${SUFFIX} CFG=e_bp_sexta_core_cfg"
    )
fi

sims=(
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_single_core_ucode_cce_cfg PROG=mc_sanity_1"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_single_core_ucode_cce_cfg PROG=mc_rand_walk_1"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_single_core_ucode_cce_cfg PROG=mc_work_share_sort_1"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_single_core_cfg PROG=mc_sanity_1"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_single_core_cfg PROG=mc_rand_walk_1"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_single_core_cfg PROG=mc_work_share_sort_1"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_dual_core_ucode_cce_cfg PROG=mc_sanity_2"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_dual_core_ucode_cce_cfg PROG=mc_rand_walk_2"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_dual_core_ucode_cce_cfg PROG=mc_work_share_sort_2"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_dual_core_cfg PROG=mc_sanity_2"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_dual_core_cfg PROG=mc_rand_walk_2"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_dual_core_cfg PROG=mc_work_share_sort_2"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_quad_core_ucode_cce_cfg PROG=mc_sanity_4"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_quad_core_ucode_cce_cfg PROG=mc_rand_walk_4"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_quad_core_ucode_cce_cfg PROG=mc_work_share_sort_4"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_quad_core_cfg PROG=mc_sanity_4"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_quad_core_cfg PROG=mc_rand_walk_4"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_quad_core_cfg PROG=mc_work_share_sort_4"
    )
if [ $1 == "vcs" ]
then
sims+=(
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_oct_core_ucode_cce_cfg PROG=mc_sanity_8"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_oct_core_ucode_cce_cfg PROG=mc_rand_walk_8"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_oct_core_ucode_cce_cfg PROG=mc_work_share_sort_8"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_oct_core_cfg PROG=mc_sanity_8"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_oct_core_cfg PROG=mc_rand_walk_8"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_oct_core_cfg PROG=mc_work_share_sort_8"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_sexta_core_ucode_cce_cfg PROG=mc_sanity_16"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_sexta_core_ucode_cce_cfg PROG=mc_rand_walk_16"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_sexta_core_ucode_cce_cfg PROG=mc_work_share_sort_16"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_sexta_core_cfg PROG=mc_sanity_16"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_sexta_core_cfg PROG=mc_rand_walk_16"
    "make -C bp_top/syn sim.${SUFFIX} CFG=e_bp_sexta_core_cfg PROG=mc_work_share_sort_16"
    )
fi

let JOBS=${#sims[@]}
let CORES_PER_JOB=${N}/${JOBS}+1

# The base command to append the configuration to
build_base="make -C bp_top/syn build.${SUFFIX}"
sim_base="make -C bp_top/syn sim.${SUFFIX} SUITE=bp_tests"

# Any setup needed for the job
make -C bp_top/syn clean.${SUFFIX}

# Run the regression in parallel on each configuration
echo "Running ${JOBS} jobs with ${CORES_PER_JOB} cores per job"
parallel --jobs ${JOBS} --results regress_logs --progress "{}" ::: "${builds[@]}"
parallel --jobs ${JOBS} --results regress_logs --progress "{}" ::: "${sims[@]}"

# Check for failures in the report directory
grep -cr "FAIL" */syn/reports/ && echo "[CI CHECK] $0: FAILED" && exit 1
echo "[CI CHECK] $0: PASSED" && exit 0
