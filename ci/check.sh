#!/bin/bash

grep -cr "FAIL" $1/syn/reports/ && exit 1
exit 0

