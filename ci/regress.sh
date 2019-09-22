#!/bin/bash

CI_CORES=${CI_CORES:-1}

echo "Executing regression $1 on end $2"
make -C $2/syn $1 -j $CI_CORES

grep -cr "FAILED" $2/syn/reports/ && exit 1
exit 0

