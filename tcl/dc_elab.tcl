#========================
# UTIL PROCS
#========================

proc exit_success {} {
  puts {                                        }
  puts { _____ _       _     _              _ _ }
  puts {|  ___(_)_ __ (_)___| |__   ___  __| | |}
  puts {| |_  | | '_ \| / __| '_ \ / _ \/ _` | |}
  puts {|  _| | | | | | \__ \ | | |  __/ (_| |_|}
  puts {|_|   |_|_| |_|_|___/_| |_|\___|\__,_(_)}
  puts {                                        }

  post_synth_message

  exit 0
}

proc exit_failed {} {
  puts {                                }
  puts { _____     _ _          _       }
  puts {|  ___|_ _| (_) ___  __| |      }
  puts {| |_ / _` | | |/ _ \/ _` |      }
  puts {|  _| (_| | | |  __/ (_| |_ _ _ }
  puts {|_|  \__,_|_|_|\___|\__,_(_|_|_)}
  puts {                                }

  post_synth_message

  exit 0 ; # Don't throw an error code, we want the mk target to continue.
}

proc post_synth_message {} {
  puts ""
  puts "## All reports can be found inside results/dc/ "
  puts "## Please check the error log (<design_name>.check.syn.err) for problematic"
  puts "## messages that we found during elaboration. This file should be empty, otherwise"
  puts "## please search through the main log (<design_name>.check.syn.log) to find more"
  puts "## context about the problematic message. Finally, use the check_design reports to"
  puts "## get information about potential issues in the design"
  puts "## (<design_name>.check_design.{summary,full}.rpt). The full report also has an"
  puts "## HTML version (<design_name>.check_design.full.html) that can be opened in"
  puts "## firefox. You can lookup any errors, warnings, or info messages that have a"
  puts "## code (e.g. LINT-1) by running the makefile target <code>.lookup.syn."
  puts ""
}

#========================
# DESIGN SETUP
#========================

set DESIGN_NAME   $::env(DESIGN_NAME)

#========================
# DIRECTORY SETUP
#========================

# Directories defined in environment variables. These should be set by the
# makefile infrastructure invoking the DC script.

set BP_DIR           $::env(BP_DIR)
set BP_TOP_DIR       $::env(BP_DIR)/bp_top
set BP_FE_DIR        $::env(BP_DIR)/bp_fe
set BP_BE_DIR        $::env(BP_DIR)/bp_be
set BP_ME_DIR        $::env(BP_DIR)/bp_me
set BP_COMMON_DIR    $::env(BP_DIR)/bp_common

set BASEJUMP_STL_DIR $::env(BP_DIR)/external/basejump_stl
set HARDFLOAT_DIR    $::env(BP_DIR)/external/HardFloat

set STDCELL_DB $::env(STDCELL_DB)

exec echo "${BP_DIR}"
exec ls "${BP_DIR}"

#========================
# LIBRARY SETUP
#========================

# We are just making sure that DC can elaborate the design, we are not going to
# be process mapping therefore we have no link library and the target library
# should be the generic and synthetic libraries that DC uses by default.

set_app_var link_library ${STDCELL_DB}
set_app_var target_library ${STDCELL_DB}

#========================
# ANALYSIS
#========================

# Read in all the HDL. Uses the same filelist used by VCS to define files and
# include directories. This step is mainly syntax checking and making sure that
# all the files are accounted for.

define_design_lib WORK -path ./${DESIGN_NAME}_dclib

if { ![analyze -format sverilog -vcs "-f flist.vcs"] } {
  exit_failed
}

set_app_var hdlin_sv_interface_only_modules {
	bsg_mem_1r1w_sync_mask_write_bit_synth
	bsg_mem_1r1w_sync_mask_write_byte_synth
	bsg_mem_1r1w_sync_synth
	bsg_mem_1r1w_synth
	bsg_mem_1rw_sync_mask_write_bit_synth
	bsg_mem_1rw_sync_mask_write_byte_synth
	bsg_mem_1rw_sync_synth
	bsg_mem_2r1w_sync_synth
	bsg_mem_2r1w_synth
	bsg_mem_2rw_sync_mask_write_bit_synth
	bsg_mem_2rw_sync_mask_write_byte_synth
	bsg_mem_2rw_sync_synth
	bsg_mem_3r1w_sync_synth
	bsg_mem_3r1w_synth
}

#========================
# ELABORATE
#========================

# Add a warning ELAB-395 if memory devices are inferred as latches.
#set_app_var hdlin_check_no_latch true

if { ![elaborate ${DESIGN_NAME}] } {
  exit_failed
}

write_file -hierarchy -format verilog -output ${DESIGN_NAME}.elab.v

#========================
# LINK
#========================

if { ![link] } {
  exit_failed
}

write_file -hierarchy -format verilog -output ${DESIGN_NAME}.link.v

if { ${STDCELL_DB} != "" } {
  redirect -tee ${DESIGN_NAME}.check_design.loop.rpt { report_timing -loop }
}

#========================
# OUTPUT FILES
#========================

redirect -tee ${DESIGN_NAME}.check_design.summary.rpt { check_design -summary }
redirect -tee ${DESIGN_NAME}.check_design.full.rpt    { check_design -html ${DESIGN_NAME}.check_design.full.html }

#========================
# EXIT
#========================

exit_success

