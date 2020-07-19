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

set BP_TOP_DIR       $::env(BP_TOP_DIR)
set BP_FE_DIR        $::env(BP_FE_DIR)
set BP_BE_DIR        $::env(BP_BE_DIR)
set BP_ME_DIR        $::env(BP_ME_DIR)
set BP_COMMON_DIR    $::env(BP_COMMON_DIR)

set BASEJUMP_STL_DIR $::env(BASEJUMP_STL_DIR)
set HARDFLOAT_DIR    $::env(HARDFLOAT_DIR)

set SYN_PATH $::env(SYN_PATH)
set TB_PATH  $::env(TB_PATH)

set STDCELL_DB $::env(STDCELL_DB)

#========================
# TOP-LEVEL PARAMETERS
#========================

# We grab the top-level parameters from the Makefile.frag flie for the
# specified testbench. This fragment has the HDL_PARAMS envvar which uses vcs
# pvalues to parameterize the top-level module. Here we string manipulate that
# variable to create the proper parameter list for the elaborate command. Each
# parameter in HDL_PARAMS is in the form -pvalue+<name>=<value> and is space
# delimited. We want the parameter to be just <name>=<value> and for the list
# to be comma delimited.

set param_list [list]
foreach param [join "$::env(DUT_PARAMS)"] {
    set idx_1 [string first "-" ${param}]
    set idx_2 [string first "+" ${param}]
    lappend param_list [string replace ${param} ${idx_1} ${idx_2} ""]
}
set param_str [join ${param_list} ","]

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

#========================
# ELABORATE
#========================

# Add a warning ELAB-395 if memory devices are inferred as latches.
set_app_var hdlin_check_no_latch true

if { ![elaborate ${DESIGN_NAME} -param ${param_str}] } {
  exit_failed
}

#========================
# LINK
#========================

if { ![link] } {
  exit_failed
}

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

