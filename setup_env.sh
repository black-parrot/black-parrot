#!/bin/sh

CWD=$PWD

# Set common environment variables
export BSG_IP_CORES_DIR=$CWD/bsg_ip_cores
export BSG_CADENV_DIR=$CWD/bsg_cadenv
export BP_COMMON_DIR=$CWD/bp_common
export BP_FE_DIR=$CWD/bp_fe
export BP_BE_DIR=$CWD/bp_be
export BP_ME_DIR=$CWD/bp_me
export BP_TOP_DIR=$CWD/bp_top
export BP_EXTERNAL_DIR=$CWD/external

# Override these tool paths if needed
export VCS=${VCS:-vcs}
export VERILATOR=${VERILATOR:-verilator}

# Add external tools to path
export PATH=$CWD/external/bin:$PATH

if [ "$1" = "init" ]; then
  git submodule update --init --recursive

  # Make external tools (uncomment whichever individual tool you would like to build)
  #make -C $CWD/external all
  #make -C $CWD/external gnu
  make -C $CWD/external fesvr
  make -C $CWD/external spike
  make -C $CWD/external axe

  # Make test roms
  make -C $BP_FE_DIR/test/rom all
  make -C $BP_BE_DIR/test/rom all
  make -C $BP_TOP_DIR/test/rom all
fi

