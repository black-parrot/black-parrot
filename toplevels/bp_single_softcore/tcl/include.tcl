#------------------------------------------------------------
# Do NOT arbitrarily change the order of files. Some module
# and macro definitions may be needed by the subsequent files
#------------------------------------------------------------

set basejump_stl_dir       $::env(BASEJUMP_STL_DIR)
set bsg_designs_dir        $::env(BSG_DESIGNS_DIR)
set bsg_designs_target_dir $::env(BSG_DESIGNS_TARGET_DIR)
set blackparrot_dir        $::env(BLACKPARROT_DIR)

set bsg_packaging_foundry    $::env(BSG_PACKAGING_FOUNDRY)
set bsg_pinout               $::env(BSG_PINOUT)
set bsg_pinout_foundry       $::env(BSG_PINOUT_FOUNDRY)
set bsg_pinout_iopad_mapping $::env(BSG_PINOUT_IOPAD_MAPPING)

set bp_common_dir ${blackparrot_dir}/bp_common
set bp_top_dir    ${blackparrot_dir}/bp_top
set bp_fe_dir     ${blackparrot_dir}/bp_fe
set bp_be_dir     ${blackparrot_dir}/bp_be
set bp_me_dir     ${blackparrot_dir}/bp_me

set BASEJUMP_STL_DIR       $::env(BASEJUMP_STL_DIR)
set BSG_DESIGNS_DIR        $::env(BSG_DESIGNS_DIR)
set BSG_DESIGNS_TARGET_DIR $::env(BSG_DESIGNS_TARGET_DIR)
set BLACKPARROT_DIR        $::env(BLACKPARROT_DIR)

set BSG_PACKAGING_FOUNDRY    $::env(BSG_PACKAGING_FOUNDRY)
set BSG_PINOUT               $::env(BSG_PINOUT)
set BSG_PINOUT_FOUNDRY       $::env(BSG_PINOUT_FOUNDRY)
set BSG_PINOUT_IOPAD_MAPPING $::env(BSG_PINOUT_IOPAD_MAPPING)

set BP_COMMON_DIR ${blackparrot_dir}/bp_common
set BP_TOP_DIR    ${blackparrot_dir}/bp_top
set BP_FE_DIR     ${blackparrot_dir}/bp_fe
set BP_BE_DIR     ${blackparrot_dir}/bp_be
set BP_ME_DIR     ${blackparrot_dir}/bp_me

set bsg_sverilog_include_paths_old [join "
  $basejump_stl_dir/bsg_clk_gen
  $basejump_stl_dir/bsg_dataflow
  $basejump_stl_dir/bsg_mem
  $basejump_stl_dir/bsg_misc
  $basejump_stl_dir/bsg_noc
  $basejump_stl_dir/bsg_tag
  $basejump_stl_dir/bsg_test
  $bp_common_dir/src/include
  $bp_be_dir/src/include
  $bp_be_dir/src/include/bp_be_dcache
  $bp_fe_dir/src/include
  $bp_me_dir/src/include/v
  $bp_top_dir/src/include
"]

set bsg_sverilog_include_paths [join "
    $BASEJUMP_STL_DIR/bsg_dataflow
    $BASEJUMP_STL_DIR/bsg_mem
    $BASEJUMP_STL_DIR/bsg_misc
    $BASEJUMP_STL_DIR/bsg_test
    $BASEJUMP_STL_DIR/bsg_noc
    $BP_COMMON_DIR/src/include
    $BP_FE_DIR/src/include
    $BP_BE_DIR/src/include
    $BP_BE_DIR/src/include/bp_be_dcache
    $BP_ME_DIR/src/include/v
    $BP_TOP_DIR/src/include
"]

