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

make build.v TB=bp_multicore CFG=e_bp_single_core${cce}cfg
make build.v TB=bp_multicore CFG=e_bp_dual_core${cce}cfg
make build.v TB=bp_multicore CFG=e_bp_tri_core${cce}cfg
make build.v TB=bp_multicore CFG=e_bp_quad_core${cce}cfg
make build.v TB=bp_multicore CFG=e_bp_hexa_core${cce}cfg
make build.v TB=bp_multicore CFG=e_bp_oct_core${cce}cfg
make build.v TB=bp_multicore CFG=e_bp_twelve_core${cce}cfg
make build.v TB=bp_multicore CFG=e_bp_sexta_core${cce}cfg

