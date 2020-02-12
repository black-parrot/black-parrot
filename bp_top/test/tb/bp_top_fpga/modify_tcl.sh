# Ignore .prj files, later added automatically during DB generation
# (Resolving bug in Vivado tcl generation)
sed -i '/set file .*\/.*\.prj/,+2d' ./bp_fpga.tcl
sed -i '/\/.*\.prj/d' ./bp_fpga.tcl

# Add files to project instead of importing (copying) to project directory
sed -i 's/imported_files/added_files/g' ./bp_fpga.tcl
sed -i 's/file_imported/file_added/g' ./bp_fpga.tcl
sed -i 's/import_files/add_files/g' ./bp_fpga.tcl
