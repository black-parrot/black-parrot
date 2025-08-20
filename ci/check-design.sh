#!/bin/bash
source $(dirname $0)/functions.sh

tool=$1
end=$2
cfg=$3

BUILD_CMD="make -C ${bsg_top}/${end}/${tool} check_design.${tool} CFG=$cfg"
bsg_run_task "building ${cfg}" ${BUILD_CMD}

# pass if no error
bsg_pass $(basename $0)

