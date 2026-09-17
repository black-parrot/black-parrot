clear -all
if {![info exists ::env(BP_DIR)]} {
    error "Set BP_DIR to the patched BlackParrot checkout."
}
set bp_dir [file normalize $::env(BP_DIR)]
set includes [list \
    bp_common/src/include \
    bp_be/src/include \
    external/basejump_stl/bsg_misc \
    external/basejump_stl/bsg_noc \
    external/basejump_stl/bsg_cache \
    external/HardFloat/source \
    external/HardFloat/source/RISCV]
set analyze_args [list -sv12]
foreach directory $includes {
    lappend analyze_args +incdir+$bp_dir/$directory
}
foreach source [list \
    bp_common/src/include/bp_common_pkg.sv \
    bp_be/src/include/bp_be_pkg.sv \
    external/basejump_stl/bsg_misc/bsg_dff.sv \
    external/basejump_stl/bsg_misc/bsg_dff_reset.sv \
    external/basejump_stl/bsg_misc/bsg_dff_reset_en.sv \
    external/basejump_stl/bsg_misc/bsg_dff_reset_set_clear.sv \
    external/basejump_stl/bsg_misc/bsg_encode_one_hot.sv \
    external/basejump_stl/bsg_misc/bsg_scan.sv \
    external/basejump_stl/bsg_misc/bsg_priority_encode_one_hot_out.sv \
    external/basejump_stl/bsg_misc/bsg_priority_encode.sv \
    bp_be/src/v/bp_be_calculator/bp_be_csr.sv \
    bp_be/test/formal/bp_be_nonsynth_satp_checker.sv] {
    lappend analyze_args $bp_dir/$source
}
analyze {*}$analyze_args
elaborate -top bp_be_csr
clock clk_i
reset -expression reset_i
set_prove_time_limit 60s
prove -all
report -summary
foreach {kind expected names} {
    assert proven {reject_preserves_next reject_preserves_register idle_preserves_register accept_forwards_write accept_updates_register}
    cover covered {reject_from_bare reject_from_sv39 bare_update sv39_update}
} {
    foreach name $names {
        set matches [get_property_list -include [list type $kind name *satp_checker.$name]]
        if {[llength $matches] != 1} {
            error "Expected exactly one property for $name; found $matches"
        }
        set status [get_property_info -list status [lindex $matches 0]]
        if {$status ne $expected} {
            error "$name: expected $expected, got $status"
        }
        puts "PASS $name: $status"
    }
}
exit
