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

cfgs=(\
    "e_bp_multicore_1_acc_scratchpad_cfg"
    "e_bp_multicore_1_acc_vdp_cfg"
    "e_bp_multicore_1_acc_vdp_cfg"
    "e_bp_multicore_4_acc_scratchpad_cfg"
    "e_bp_multicore_4_acc_vdp_cfg"
    )

progs=(
    "streaming_accelerator_loopback"
    "streaming_accelerator_vdp"
    "coherent_accelerator_vdp"
    )
# TODO:
# This script does not currently run simulation with the quad-core accelerator configs.
# The accelerator test programs need to be rewritten/revised to match the new configs, which
# disallow mixing of loopback and vdp accelerators. The loopback configs now only instantiate
# the streaming accelerator complex, while the vdp configs instantiate both coherent and
# streaming accelerators. Once fixed, the appropriate test programs can be added to the end of
# the progs list and run on the quad-core accelerator configs.

#"streaming_accelerator_loopback"
#"coherent_accelerator_vdp"

# The base command to append the configuration to
build_base="make -C bp_top/syn build.v NBF_CONFIG_P=1"

# Any setup needed for the job
echo "Cleaning bp_top"
make -C bp_top/syn clean

# run simulations
sims=()
for i in "${!progs[@]}"
do
    sims+=("make -C bp_top/syn sim.v NBF_CONFIG_P=1 CFG=${cfgs[$i]} SUITE=bp-tests PROG=${progs[$i]}")
done

# build required configs
build_cfgs=($(echo ${cfgs[*]} | tr ' ' '\012' | uniq))
echo "Building: ${N} jobs with 1 core per job"
parallel --jobs ${N} --results regress_logs --progress "$build_base CFG={}" ::: "${build_cfgs[@]}"

# simulate
echo "Simulating: running parallel with ${N} jobs"
parallel --jobs ${N} --results regress_logs --progress "{}" ::: "${sims[@]}"

# Check for failures in the report directory
grep -cr "FAIL" bp_top/syn/reports/ && echo "[CI CHECK] $0: FAILED" && exit 1
echo "[CI CHECK] $0: PASSED" && exit 0


