#!/bin/bash
source $(dirname $0)/functions.sh

tool=$1
end=$2
cfg=$3
cores=${4:-1}

suite=riscv-dv
progs=(riscv_amo_test riscv_arithmetic_basic_test riscv_floating_point_arithmetic_test riscv_floating_point_mmu_stress_test riscv_floating_point_rand_test riscv_full_interrupt_test riscv_hint_instr_test riscv_invalid_csr_test riscv_jump_stress_test riscv_loop_test riscv_machine_mode_rand_test riscv_mmu_stress_test riscv_no_fence_test riscv_non_compressed_instr_test riscv_pmp_test riscv_privileged_mode_rand_test riscv_rand_instr_test riscv_rand_jump_test riscv_unaligned_load_store_test)

export DROMAJO_COSIM=1
export CFG=${cfg}
bsg_run_task "building ${cfg}" make -C ${bsg_top}/${end}/${tool} build.${tool}
#for K in $(seq 1 19); do
parallel -j${cores} do_single_sim ${tool} ${cfg} ${suite} '{1}_{2}' ::: "${progs[@]}" ::: $(seq 1 1)

bsg_pass $(basename $0)

