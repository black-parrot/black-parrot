set proj_name "blackparrot_test"

#set part "xc7k325tffg900-2"
set part "xc7a200tfbg676-2"
create_project -force $proj_name ./$proj_name -part $part

if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

set fileset_obj [get_filesets sources_1]
set f [split [string trim [read [open "flist.vcs" r]]] "\n"]
set flist [list ]
foreach x $f {
  # If the item has a file to be added, it starts with $BP_*_DIR
  if {[string match "\$" [string index $x 0]]} {
    set env_var [string trimleft $x "\$"]
    regexp {([A-Za-z_]*)} $env_var a
    regexp {([/][A-Za-z0-9_./]*)} $x b
    # Get the environment variable
    set expanded $::env($a)
    append expanded $b
    # If not already in the list, add this file to the list
    if {[lsearch -exact $flist $expanded] < 0} {
      lappend flist [file normalize $expanded]
    }
  # If the item starts with +incdir+, directory files may need to be added
  } elseif {[string match "+incdir+*" $x]} {
      set trimchars "+incdir+\$"
      set temp [string trimleft $x $trimchars]
      regexp {([A-Za-z_]*)} $temp a
      regexp {([/][A-Za-z0-9_./]*)} $temp b
      set expanded $::env($a)
      append expanded $b
      append expanded "/*v*"
      if {[string match "*top*" $expanded]} continue
      # Get the files in the directory
      set check [glob $expanded]
      foreach item $check {
        puts $item
        if {[lsearch -exact $flist $item] < 0} {
          # Need to add bsg_defines and the HardFloat .vi files
          if {(([string match "*bsg_defines.v*" $item]) || ([string match "*.vi" $item]))} {
            lappend flist $item
          # Need to add only those .vh files not included later in the flist file, like the pkg files
          } elseif {([string match "*vh" $item]) && !([string match "*pkg*" $item])} {
              puts "Adding to list"
              lappend flist $item
            }
        }
      }
  }
}
# Add a top wrapper
set filepath "BP_COMMON_DIR"
set top "$::env($filepath)/syn/tcl/design_wrapper.v"
lappend flist $top
add_files -norecurse -fileset $fileset_obj $flist

# Set the type for the files
foreach new_file $flist {
  set this_file $new_file
  set this_file [file normalize $this_file]
  set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$this_file"]]
  if {[string match "*pkg*" $new_file]} {
    set_property -name "file_type" -value "SystemVerilog" -objects $file_obj
  } elseif {[string match "*vh" $new_file]} {
    set_property -name "file_type" -value "Verilog Header" -objects $file_obj
  } elseif {[string match "*bsg_defines.v*" $new_file]} {
    set_property -name "file_type" -value "Verilog Header" -objects $file_obj
  } elseif {[string match "*.vi" $new_file]} {
    set_property -name "file_type" -value "Verilog Header" -objects $file_obj
  } elseif {[string match "*.mem" $new_file]} {
    set_property -name "file_type" -value "Memory File" -objects $file_obj
  } else {
    set_property -name "file_type" -value "SystemVerilog" -objects $file_obj
  }
}

set obj [get_filesets sources_1]

# Ensure there are no warnings or errors
check_syntax -fileset sources_1
# Set the design wrapper as the top module
set_property -name "top" -value "design_wrapper" -objects $obj
set_property -name "top_auto_set" -value "0" -objects $obj

# Create 'constrs_1' fileset (if not found)
if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}

# Set 'constrs_1' fileset object
set obj [get_filesets constrs_1]

# Add/Import constrs file and set constrs file properties
set filepath "BP_COMMON_DIR"
set file "[file normalize "$::env($filepath)/syn/xdc/design.xdc"]"
add_files -norecurse -fileset $obj [list $file]
set file_obj [get_files -of_objects [get_filesets constrs_1] [list "*$file"]]
set_property -name "file_type" -value "XDC" -objects $file_obj

# Set 'constrs_1' fileset properties
set obj [get_filesets constrs_1]
set_property -name "target_part" -value $part -objects $obj

# Run synthesis
current_run -synthesis [get_runs synth_1]
synth_design -part $part -constrset constrs_1
set filepath "BP_TOP_DIR"
# Generate a hierarchical utilization report
report_utilization -file $::env($filepath)/syn/logs/hierarchical.rpt -hierarchical -hierarchical_percentages
