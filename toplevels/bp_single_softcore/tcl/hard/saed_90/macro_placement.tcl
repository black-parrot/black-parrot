
set suffix "0"
set tile_height [get_attribute [get_core_area] tile_height]
set k $tile_height

# KEEPOUT
set_keepout_margin -type hard -outer [list $k $k $k $k] [all_macro]

# ICACHE DATA
set macros [sort_collection -dictionary [get_fp_cells -filter "is_hard_macro&&full_name=~*icache*data_mem*"] name]
set icache_data_mem_list ""
for {set row 0} {$row < 2} {incr row} { 
    set macro_row [list]
    for {set col 0} {$col < 4} {incr col} { 
        set idx [expr $row*4 + $col]
        set macro [index_collection $macros $idx]
        lappend macro_row [get_object_name $macro]
        set_fp_macro_options $macro -legal_orientations W
    }
    lappend icache_data_mem_list [get_cells $macro_row]
}
set_fp_macro_array -name icache_data_mem_array_$suffix -elements $icache_data_mem_list -use_keepout_margin
set_fp_relative_location -name icache_data_mem_array_rl_$suffix -target_cell icache_data_mem_array_$suffix -target_corner bl -anchor_corner bl

# DCACHE DATA
set macros [sort_collection -dictionary [get_fp_cells -filter "is_hard_macro&&full_name=~*dcache*data_mem*"] name]
set dcache_data_mem_list ""
for {set row 0} {$row < 2} {incr row} { 
    set macro_row [list]
    for {set col 0} {$col < 4} {incr col} { 
        set idx [expr $row*4 + $col]
        set macro [index_collection $macros $idx]
        lappend macro_row [get_object_name $macro]
        set_fp_macro_options $macro -legal_orientations FW
    }
    lappend dcache_data_mem_list [get_cells $macro_row]
}
set_fp_macro_array -name dcache_data_mem_array_$suffix -elements $dcache_data_mem_list -use_keepout_margin
set_fp_relative_location -name dcache_data_mem_array_rl_$suffix -target_cell dcache_data_mem_array_$suffix -target_corner br -anchor_corner br

# ICACHE TAG + STAT
set icache_tag_stat_mem_list [get_object_name [get_fp_cells -filter "is_hard_macro&&full_name=~*icache*tag_mem*"]]
lappend icache_tag_stat_mem_list [get_object_name [get_fp_cells -filter "is_hard_macro&&full_name=~*icache*stat_mem*"]]
set_fp_macro_options [get_cells $icache_tag_stat_mem_list] -legal_orientations W
set_fp_macro_array -name icache_tag_stat_mem_array_$suffix -elements [get_cells $icache_tag_stat_mem_list] -use_keepout_margin -vertical -align_edge left
set_fp_relative_location -name icache_stat_tag_mem_array_rl_$suffix -target_cell icache_tag_stat_mem_array_$suffix -target_corner bl -anchor_corner br -anchor_object icache_data_mem_array_$suffix

# DCACHE TAG + STAT
set dcache_tag_stat_mem_list [get_object_name [get_fp_cells -filter "is_hard_macro&&full_name=~*dcache*tag_mem*"]]
lappend dcache_tag_stat_mem_list [get_object_name [get_fp_cells -filter "is_hard_macro&&full_name=~*dcache*stat_mem*"]]
set_fp_macro_options [get_cells $dcache_tag_stat_mem_list] -legal_orientations FW
set_fp_macro_array -name dcache_tag_stat_mem_array_$suffix -elements [get_cells $dcache_tag_stat_mem_list] -use_keepout_margin -vertical -align_edge right
set_fp_relative_location -name dcache_stat_tag_mem_array_rl_$suffix -target_cell dcache_tag_stat_mem_array_$suffix -target_corner br -anchor_corner bl -anchor_object dcache_data_mem_array_$suffix

# REGISTER FILE
set int_rf_mem_list [get_object_name [get_fp_cells -filter "is_hard_macro&&full_name=~*int_regfile*"]]
set_fp_macro_options [get_cells $int_rf_mem_list] -legal_orientations FW
set_fp_macro_array -name int_rf_array_$suffix -elements [get_cells $int_rf_mem_list] -use_keepout_margin -vertical
set_fp_relative_location -name int_rf_array_rl_$suffix -target_cell int_rf_array_$suffix -target_corner br -anchor_corner bl -anchor_object dcache_tag_stat_mem_array_$suffix

