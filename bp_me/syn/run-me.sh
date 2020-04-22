#! /bin/bash

NUM_INSTR=4096

protos=("ei" "msi" "mesi" "msi-nonspec" "mesi-nonspec")

mkdir -p results
rm -f results/regress_results.txt
touch results/regress_results.txt

for p in "${protos[@]}"
do
  make clean
  make regress.me.v NUM_INSTR_P=$NUM_INSTR COH_PROTO=$p
  passes=`grep -rE "PASS" reports/ | wc -l`
  echo "$p,$passes" >> results/regress_results.txt
done
