#!/bin/bash
source $(dirname $0)/functions.sh

tool=$1
end=$2
cfg=$3
cores=${4:-1}

suite=bp-tests
progs=(
	mc_amo_add
	mc_lrsc_add
	mc_rand_walk
	mc_sanity
	mc_template
	mc_work_share_sort
)

# don't support multicore cosim for now
#export DROMAJO_COSIM=0
export CFG=${cfg}
bsg_run_task "building ${cfg}" make -C ${bsg_top}/${end}/${tool} build.${tool}
parallel -j${cores} do_single_sim ${tool} ${cfg} ${suite} {} ::: "${progs[@]}"

bsg_pass $(basename $0)

