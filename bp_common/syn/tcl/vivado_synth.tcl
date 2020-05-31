
set f [split [string trim [read [open "flist.vcs"]]]]

set files [lmap x $f {expr {
    $x
}}]

puts $files
#add_files -norecurse $files
