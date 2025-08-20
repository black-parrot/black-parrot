#!/bin/bash

# source-only guard
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && return
# include guard
[ -n "${_LOCAL_SH_INCLUDE}" ] && return

# disable automatic export
set -o allexport

# constants
readonly _LOCAL_SH_INCLUDE=1

# runs a single simulation and exits on failure
# usage: do_single_sim dromajo beebs aha-compress 1
do_single_sim() {
    _bsg_parse_args 4 tool cfg suite prog "$1" "$2" "$3" "$4"

    bsg_log_init ${JOB_LOG} ${JOB_RPT} ${JOB_OUT} ${JOB_LOGLEVEL} || exit 1
    echo "tool: ${_tool} cfg: ${_cfg} suite: ${_suite} prog: ${_prog}"

    # find test components
    PROG_PATH=$(find "${BP_RISCV_DIR}/${_suite}" -name "${_prog}.riscv")
    bsg_log_info "program found at ${PROG_PATH}"

    ## do the actual job
    SIM_CMD="make -C bp_top/${_tool} sim.${_tool} CFG=${_cfg} SUITE=${_suite} PROG=${_prog}"
    bsg_run_task "executing ${_prog} with ${_tool}" ${SIM_CMD}
    bsg_sentinel_fail '.*CORE.*FSH.*FAIL'
    bsg_sentinel_cont '.*CORE.*FSH.*PASS'
}

# check for binaries in path
export TAG=$(basename ${0%.*})

# disable automatic export
set +o allexport

