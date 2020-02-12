
sed -i '/set file .*\/.*\.prj/,+2d' ./bp_fpga.tcl
sed -i '/\/.*\.prj/d' ./bp_fpga.tcl

sed -i 's/imported_files/added_files/g' ./bp_fpga.tcl
sed -i 's/file_imported/file_added/g' ./bp_fpga.tcl
sed -i 's/import_files/add_files/g' ./bp_fpga.tcl
