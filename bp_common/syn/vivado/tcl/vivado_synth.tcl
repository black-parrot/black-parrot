# Genesys 2 - xc7k325tffg900-2
# Artix 7   - xc7a200tfbg676-2

set BP_TOP_DIR $::env(BP_TOP_DIR)
set BP_COMMON_DIR $::env(BP_COMMON_DIR)
set BP_BE_DIR $::env(BP_BE_DIR)
set BP_FE_DIR $::env(BP_FE_DIR)
set BP_ME_DIR $::env(BP_ME_DIR)
set BASEJUMP_STL_DIR $::env(BASEJUMP_STL_DIR)
set HARDFLOAT_DIR $::env(HARDFLOAT_DIR)

set f [split [string trim [read [open "flist.vcs" r]]] "\n"]
set flist [list ]
set dir_list [list ]
foreach x $f {
  # If the item has a file to be added, it starts with $BP_*_DIR
  if {[string match "\$" [string index $x 0]]} {
    set expanded [subst $x]
    # If not already in the list, add this file to the list
    if {[lsearch -exact $flist $expanded] < 0} {
      lappend flist $expanded
    }
  # If the item starts with +incdir+, directory files may need to be added
  } elseif {[string match "+incdir+*" $x]} {
      set trimchars "+incdir+"
      set temp [string trimleft $x $trimchars]
      set expanded [subst $temp]
      if {[string match "*top*" $expanded]} continue
      lappend dir_list $expanded
  }
}

# Add a top wrapper
set top "wrapper.sv"
lappend flist $top

set_part $::env(PART)
read_verilog -sv $flist
read_xdc design.xdc

synth_design -top wrapper -part $::env(PART) -include_dirs $dir_list
set filepath "BP_TOP_DIR"
report_utilization -file $::env($filepath)/syn/reports/vivado/hierarchical.rpt -hierarchical -hierarchical_percentages
