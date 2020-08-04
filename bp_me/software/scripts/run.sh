#! /bin/bash

# pick the CCE to use based on input arg
# if only one arg, and it is equal to "fsm", use the FSM CCE
# else, use the microcode CCE
if [ $# -eq 1 ] && [ $1 == "fsm" ]
then
  cce="_"
else
  cce="_cce_ucode_"
fi

# coherence protocols
protos=("msi" "mesi" "msi-nonspec" "mesi-nonspec")

# configurations
cfgs=("single" "dual" "tri" "quad" "hexa" "oct" "twelve" "sexta")
nums=("1" "2" "3" "4" "6" "8" "12" "16")

# test programs
progs=("mc_sanity" "mc_rand_walk" "mc_work_share_sort")

rm -f regress${cce}results.txt
touch regress${cce}results.txt

for prog in "${progs[@]}"
do
  for p in "${protos[@]}"
  do
    # run experiments for (program,protocol) pair across all core counts
    for i in "${!nums[@]}"
    do
      make sim.v PROG=${prog}_${nums[$i]} TB=bp_multicore CFG=e_bp_${cfgs[$i]}_core${cce}cfg COH_PROTO=$p &
    done
    # wait for all simulations
    wait
    # collect results
    for i in "${!nums[@]}"
    do
      failures=`grep -rE "FAIL" reports/vcs/bp_multicore.e_bp_${cfgs[$i]}_core${cce}cfg.sim.${prog}_${nums[$i]}.rpt | wc -l`
      if [ $failures -gt 0 ]
      then
        echo "$prog,$p,${cfgs[$i]},FAIL" >> regress${cce}results.txt
      else
        echo "$prog,$p,${cfgs[$i]},PASS" >> regress${cce}results.txt
      fi
    done
  done
done

