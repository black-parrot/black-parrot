#!/bin/bash
source $(dirname $0)/functions.sh

tool=$1
end=$2
cfg=$3
cores=${4:-1}

# These tests don't pass in cosim for whatever reason
suite=bp-tests
progs=(
    aviary_rom
    coherent_accelerator_vdp
    streaming_accelerator_loopback
    streaming_accelerator_vdp
    streaming_accelerator_zipline
    domain fault
    epc
    fp_signed_zero
    instr_coherence
    l2_uncached
    m_external_interrupt
    s_external_interrupt
    misaligned_instructions_virtual_memory
    misaligned_instructions_advanced_jumps
    misaligned_instructions_basic_jumps
    misaligned_ldst
    readonly
    timer_interrupt
    uncached_mode
    unhandled_trap
)

export DROMAJO_COSIM=0
export CFG=${cfg}
bsg_run_task "building ${cfg}" make -C ${bsg_top}/${end}/${tool} build.${tool}
parallel -j${cores} do_single_sim ${tool} ${cfg} ${suite} {} ::: "${progs[@]}"

bsg_pass $(basename $0)

