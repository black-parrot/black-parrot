#!/bin/bash
case "$1" in
  tools)
    echo "Making tools and copying to CI_CACHE: $CI_CACHE"
    make tools -j $CI_CORES
    make tidy_tools
    cp -r external/* $CI_CACHE/bp-tools/
    ;;
  progs)
    echo "Making programs and copying to CI_CACHE: $CI_CACHE"
    make progs
    cp -r bp_common/test/mem/* $CI_CACHE/bp-tests/
    ;;
  link)
    echo "Relinking external tools and tests from CI_CACHE: $CI_CACHE"
    rm -rf external/*
    cp -r $CI_CACHE/bp-tools/* external/
    cp -r $CI_CACHE/bp-tests/* bp_common/test/mem/
    cp -r $CI_CACHE/bsg_cadenv/ external/
    make update_libs
    ;;
esac

