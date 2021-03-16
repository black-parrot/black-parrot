#!/bin/bash

SUITE=bp-tests
PROG=cache_hammer

# Run a test with DRAMsim3
make -C bp_top/syn clean build.v sim.v COSIM_P=1 SUITE=${SUITE} PROG=${PROG} USE_DRAMSIM3=1
grep -cr "FAIL" */syn/reports/ && echo "[CI CHECK] $0: FAILED" && exit 1
# Run a test with BSG DMC
make -C bp_top/syn clean build.v sim.v COSIM_P=1 SUITE=${SUITE} PROG=${PROG} USE_DDR=1
grep -cr "FAIL" */syn/reports/ && echo "[CI CHECK] $0: FAILED" && exit 1
echo "[CI CHECK] $0: PASSED" && exit 0
