#!/bin/bash
source $(dirname $0)/functions.sh

# initializing logging
bsg_check_var "JOB_LOG" || exit 1
bsg_check_var "JOB_OUT" || exit 1
bsg_check_var "JOB_RPT" || exit 1
bsg_check_var "JOB_LOGLEVEL" || exit 1
bsg_check_var "DOCKER_PLATFORM" || exit 1
bsg_check_var "CONTAINER_IMAGE" || exit 1
bsg_log_init ${JOB_LOG} ${JOB_RPT} ${JOB_OUT} ${JOB_LOGLEVEL} || exit 1

bsg_log_info "running ci"
bsg_log_raw "with arguments: $*"

# Check if there are no arguments
if [ "$#" -eq 0 ]; then
	bsg_log_error "no script specified"
	bsg_log_raw "usage: run-ci.sh <ci-script.sh>"
	exit 1
fi

# execute the command
exec "$@"

