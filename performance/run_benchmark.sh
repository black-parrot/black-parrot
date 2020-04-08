#!/bin/bash

if [[ "$#" -ne 5 ]]; then
    echo "usage: $(basename $0) benchmark checkpoint_size warmup_size run_size threads"
    exit 1
fi

BENCH=$1
CPSZ=$2
WMSZ=$3
RNSZ=$4
N=$5

TOP=..

mkdir -p logs/
mkdir -p traces/
mkdir -p reports/
mkdir -p graphs/

rm -f logs/${BENCH}.*
rm -f reports/${BENCH}.*
rm -f traces/${BENCH}.*
rm -f graphs/${BENCH}.*

echo "Creating checkpoints of size: $CPSZ for benchmark: $BENCH"  | tee -a $BENCH.log
#make -C $TOP/bp_common/test $BENCH.dromajo DUMP_PERIOD=$CPSZ > logs/$BENCH.checkpoint.log 2>&1

echo "Building the cosimulation model with warmup: $WMSZ and execution: $RNSZ" | tee -a $BENCH.log
#make -C $TOP/bp_top/syn build.v COSIM_P=1 LOAD_NBF_P=1 WARMUP_INSTR_P=$WMSZ COSIM_INSTR_P=$RNSZ > logs/$BENCH.build.log 2>&1

echo "Generating checkpoint run commands" | tee -a $BENCH.log
checkpoints=()
for f in $(ls $TOP/bp_common/test/mem/$BENCH.dromajo.*.mem); do
    checkpoints=(${checkpoints[@]} $(basename $f .mem))
done

# Cap threads at max num checkpoints
N=$(($N<${#checkpoints[@]} ? $N : ${#checkpoints[@]}))
echo "Executing commands on $N threads" | tee -a $BENCH.log
cmd_base="make -C $TOP/bp_top/syn sim.v "
for c in ${checkpoints[@]}; do
    # Execute up to N at a time
    ((i=i%N)); ((i++==0)) && wait
    cmd="$cmd_base PROG=$c"
    echo "Executing $cmd" | tee -a $BENCH.log
    #eval $cmd > logs/$c.log 2>&1 &
done

echo "Extracting results" | tee -a $BENCH.log
for c in ${checkpoints[@]}; do
    grep "mIPC" $TOP/bp_top/syn/reports/vcs/bp_softcore.e_bp_softcore_cfg.sim.${c}.rpt \
        | sed "s/ //g" | sed "s/\t//g" | sed "s/:/ /g" >> reports/${BENCH}.rpt

    # TODO: enable bloodgraphs
    #cp $TOP/bp_top/syn/results/vcs/bp_softcore.e_bp_softcore_cfg.sim.${c}/blood_detailed.png graphs/${BENCH}_graph_detailed.png
    #cp $TOP/bp_top/syn/results/vcs/bp_softcore.e_bp_softcore_cfg.sim.${c}/key_detailed.png graphs/${BENCH}_key_detailed.png
done

echo "Averaging mIPC" | tee -a $BENCH.log
echo -n "Average IPC: " >> reports/${BENCH}.rpt | tee -a $BENCH.log
awk '{x+=$2} END {print x/(1000*(NR-1))}' reports/${BENCH}.rpt >> reports/${BENCH}.rpt

echo "${BENCH} Completed!! Average IPC: $(tail -n 1 reports/${BENCH}.rpt)" | tee -a $BENCH.log
