#!/bin/bash
source $(dirname $0)/functions.sh

tool=$1
end=$2
cfg=$3

# do the actual job
LINT_CMD="make -C ${bsg_top}/${end}/${tool} lint.${tool} CFG=${cfg}"
bsg_run_task "linting ${cfg} with ${tool}" ${LINT_CMD}

# pass if no error
bsg_pass ${bsg_script}

