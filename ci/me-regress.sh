#!/bin/bash
source $(dirname $0)/functions.sh

tool=$1
end=$2
cfg=$3
cores=${4:-1}

all_cohs=(
    ei
    mesi
    mesi-nonspec
    moesif
    msi
    msi-nonspec
)

# me_test cce lce
tests=(
    "0 0 0 random_test"
    "0 0 1 random_test"
    "0 0 2 random_test"
    "0 1 1 random_test"
    "1 0 0 set_test"
    "1 0 1 set_test"
    "1 0 2 set_test"
    "1 1 1 set_test"
    "2 0 0 ld_st"
    "2 0 0 mixed"
)

if [[ "${cfg}" == "e_bp_test_multicore_half_cce_ucode_cfg" ]]; then
    cfg_cohs=("${all_cohs[@]}")
else
    cfg_cohs=(msi)
fi
export CFG=${cfg}
export RUN_CMD="make -C ${bsg_top}/${end}/${tool} sim.${tool}"
parallel --colsep ' ' -j${cores} --progress '
    export COH_PROTO={1}
    export ME_TEST_P={2}
    export CCE_MODE_P={3}
    export LCE_MODE_P={4}
    export TRACE_FILE_P={5}.trace

    export TAG={1}.{2}.{3}.{4}.{5}

    bsg_run_task "running sim" ${RUN_CMD}
' ::: "${cfg_cohs[@]}" ::: "${tests[@]}"


# pass if no error
bsg_pass $(basename $0)

