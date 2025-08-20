#!/bin/bash
source $(dirname $0)/functions.sh

tool=$1
end=$2
cfg=$3
cores=${4:-1}

suite=bp-tests
progs=(
	cache_flush
	cache_hammer
	constructor
	divide_hazard
	dram_stress
	eaddr_fault
	execute_dynamic_instruction
	fflags_haz
	fp_neg_zero_nanbox
	fp_precision
	hello_world
	jalr_illegal
	l2_cache_ops
	loop
	mapping
	map
	mstatus_fs
	nanboxing
	paging
	satp_nofence
	stream_hammer
	template
	unwinding
	vector
	virtual
	wfi    
)

export DROMAJO_COSIM=1
export CFG=${cfg}
bsg_run_task "building ${cfg}" make -C ${bsg_top}/${end}/${tool} build.${tool}
parallel -j${cores} do_single_sim ${tool} ${cfg} ${suite} {} ::: "${progs[@]}"

bsg_pass $(basename $0)

