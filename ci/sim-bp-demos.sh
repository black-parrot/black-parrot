#!/bin/bash
source $(dirname $0)/functions.sh

tool=$1
end=$2
cfg=$3
cores=${4:-1}

suite=bp-demos
progs=(
    sample
    lfs_demo
)

export DROMAJO_COSIM=1
export CFG=${cfg}
bsg_run_task "building ${cfg}" make -C ${bsg_top}/${end}/${tool} build.${tool}
parallel -j${cores} do_single_sim ${tool} ${cfg} ${suite} {} ::: "${progs[@]}"

bsg_pass $(basename $0)

