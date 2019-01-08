# Begin_DVE_Session_Save_Info
# DVE view(Wave.1 ) session
# Saved on Mon Dec 10 16:19:30 2018
# Toplevel windows open: 2
# 	TopLevel.1
# 	TopLevel.2
#   Wave.1: 49 signals
# End_DVE_Session_Save_Info

# DVE version: L-2016.06-SP2-15_Full64
# DVE build date: Mar 11 2018 22:07:39


#<Session mode="View" path="/home/dcjung/bp/bp_be/bp_dcache/testing/4dcache_axe_test/wave.tcl" type="Debug">

#<Database>

gui_set_time_units 1ps
#</Database>

# DVE View/pane content session: 

# Begin_DVE_Session_Save_Info (Wave.1)
# DVE wave signals session
# Saved on Mon Dec 10 16:19:30 2018
# 49 signals
# End_DVE_Session_Save_Info

# DVE version: L-2016.06-SP2-15_Full64
# DVE build date: Mar 11 2018 22:07:39


#Add ncecessay scopes

gui_set_time_units 1ps

set _wave_session_group_10 dcache0
if {[gui_sg_is_group -name "$_wave_session_group_10"]} {
    set _wave_session_group_10 [gui_sg_generate_new_name]
}
set Group1 "$_wave_session_group_10"

gui_sg_addsignal -group "$_wave_session_group_10" { {V1:testbench.dcache_cce_mem.genblk2[0].dcache.clk_i} {V1:testbench.dcache_cce_mem.genblk2[0].dcache.reset_i} {V1:testbench.dcache_cce_mem.genblk2[0].dcache.v_i} {V1:testbench.dcache_cce_mem.genblk2[0].dcache.dcache_pkt.opcode} {V1:testbench.dcache_cce_mem.genblk2[0].dcache.dcache_pkt.vaddr} {V1:testbench.dcache_cce_mem.genblk2[0].dcache.dcache_pkt.data} {V1:testbench.dcache_cce_mem.genblk2[0].dcache.ready_o} {V1:testbench.dcache_cce_mem.genblk2[0].dcache.data_o} {V1:testbench.dcache_cce_mem.genblk2[0].dcache.v_o} {V1:testbench.dcache_cce_mem.genblk2[0].dcache.addr_tv_r} {V1:testbench.dcache_cce_mem.genblk2[0].dcache.cache_miss_o} }
gui_set_radix -radix {decimal} -signals {{V1:testbench.dcache_cce_mem.genblk2[0].dcache.addr_tv_r}}
gui_set_radix -radix {unsigned} -signals {{V1:testbench.dcache_cce_mem.genblk2[0].dcache.addr_tv_r}}

set _wave_session_group_11 dcache1
if {[gui_sg_is_group -name "$_wave_session_group_11"]} {
    set _wave_session_group_11 [gui_sg_generate_new_name]
}
set Group2 "$_wave_session_group_11"

gui_sg_addsignal -group "$_wave_session_group_11" { {V1:testbench.dcache_cce_mem.genblk2[1].dcache.clk_i} {V1:testbench.dcache_cce_mem.genblk2[1].dcache.reset_i} {V1:testbench.dcache_cce_mem.genblk2[1].dcache.v_i} {V1:testbench.dcache_cce_mem.genblk2[1].dcache.dcache_pkt.opcode} {V1:testbench.dcache_cce_mem.genblk2[1].dcache.dcache_pkt.vaddr} {V1:testbench.dcache_cce_mem.genblk2[1].dcache.dcache_pkt.data} {V1:testbench.dcache_cce_mem.genblk2[1].dcache.ready_o} {V1:testbench.dcache_cce_mem.genblk2[1].dcache.data_o} {V1:testbench.dcache_cce_mem.genblk2[1].dcache.data_tv_r} {V1:testbench.dcache_cce_mem.genblk2[1].dcache.v_o} {V1:testbench.dcache_cce_mem.genblk2[1].dcache.addr_tv_r} {V1:testbench.dcache_cce_mem.genblk2[1].dcache.cache_miss_o} }
gui_set_radix -radix {decimal} -signals {{V1:testbench.dcache_cce_mem.genblk2[1].dcache.data_tv_r}}
gui_set_radix -radix {unsigned} -signals {{V1:testbench.dcache_cce_mem.genblk2[1].dcache.data_tv_r}}
gui_set_radix -radix {decimal} -signals {{V1:testbench.dcache_cce_mem.genblk2[1].dcache.addr_tv_r}}
gui_set_radix -radix {unsigned} -signals {{V1:testbench.dcache_cce_mem.genblk2[1].dcache.addr_tv_r}}

set _wave_session_group_12 dcache2
if {[gui_sg_is_group -name "$_wave_session_group_12"]} {
    set _wave_session_group_12 [gui_sg_generate_new_name]
}
set Group3 "$_wave_session_group_12"

gui_sg_addsignal -group "$_wave_session_group_12" { {V1:testbench.dcache_cce_mem.genblk2[2].dcache.clk_i} {V1:testbench.dcache_cce_mem.genblk2[2].dcache.reset_i} {V1:testbench.dcache_cce_mem.genblk2[2].dcache.v_i} {V1:testbench.dcache_cce_mem.genblk2[2].dcache.dcache_pkt.opcode} {V1:testbench.dcache_cce_mem.genblk2[2].dcache.dcache_pkt.vaddr} {V1:testbench.dcache_cce_mem.genblk2[2].dcache.dcache_pkt.data} {V1:testbench.dcache_cce_mem.genblk2[2].dcache.ready_o} {V1:testbench.dcache_cce_mem.genblk2[2].dcache.data_o} {V1:testbench.dcache_cce_mem.genblk2[2].dcache.v_o} {V1:testbench.dcache_cce_mem.genblk2[2].dcache.addr_tv_r} {V1:testbench.dcache_cce_mem.genblk2[2].dcache.cache_miss_o} }
gui_set_radix -radix {decimal} -signals {{V1:testbench.dcache_cce_mem.genblk2[2].dcache.addr_tv_r}}
gui_set_radix -radix {unsigned} -signals {{V1:testbench.dcache_cce_mem.genblk2[2].dcache.addr_tv_r}}

set _wave_session_group_13 {dcache1 lce_lce_tr_resp_in}
if {[gui_sg_is_group -name "$_wave_session_group_13"]} {
    set _wave_session_group_13 [gui_sg_generate_new_name]
}
set Group4 "$_wave_session_group_13"

gui_sg_addsignal -group "$_wave_session_group_13" { {V1:testbench.dcache_cce_mem.genblk2[1].dcache.lce.lce_lce_tr_resp_v_i} {V1:testbench.dcache_cce_mem.genblk2[1].dcache.lce.lce_lce_tr_resp_ready_o} {V1:testbench.dcache_cce_mem.genblk2[1].dcache.lce.lce_lce_tr_resp_in.dst_id} {V1:testbench.dcache_cce_mem.genblk2[1].dcache.lce.lce_lce_tr_resp_in.src_id} {V1:testbench.dcache_cce_mem.genblk2[1].dcache.lce.lce_lce_tr_resp_in.way_id} {V1:testbench.dcache_cce_mem.genblk2[1].dcache.lce.lce_lce_tr_resp_in.addr} {V1:testbench.dcache_cce_mem.genblk2[1].dcache.lce.lce_lce_tr_resp_in.data} }

set _wave_session_group_14 {dcache1 cce_lce_data_cmd}
if {[gui_sg_is_group -name "$_wave_session_group_14"]} {
    set _wave_session_group_14 [gui_sg_generate_new_name]
}
set Group5 "$_wave_session_group_14"

gui_sg_addsignal -group "$_wave_session_group_14" { {V1:testbench.dcache_cce_mem.genblk2[1].dcache.lce.cce_lce_data_cmd_v_i} {V1:testbench.dcache_cce_mem.genblk2[1].dcache.lce.cce_lce_data_cmd_ready_o} {V1:testbench.dcache_cce_mem.genblk2[1].dcache.lce.cce_lce_data_cmd.dst_id} {V1:testbench.dcache_cce_mem.genblk2[1].dcache.lce.cce_lce_data_cmd.src_id} {V1:testbench.dcache_cce_mem.genblk2[1].dcache.lce.cce_lce_data_cmd.msg_type} {V1:testbench.dcache_cce_mem.genblk2[1].dcache.lce.cce_lce_data_cmd.way_id} {V1:testbench.dcache_cce_mem.genblk2[1].dcache.lce.cce_lce_data_cmd.addr} {V1:testbench.dcache_cce_mem.genblk2[1].dcache.lce.cce_lce_data_cmd.data} }
gui_set_radix -radix {decimal} -signals {{V1:testbench.dcache_cce_mem.genblk2[1].dcache.lce.cce_lce_data_cmd.addr}}
gui_set_radix -radix {unsigned} -signals {{V1:testbench.dcache_cce_mem.genblk2[1].dcache.lce.cce_lce_data_cmd.addr}}
if {![info exists useOldWindow]} { 
	set useOldWindow true
}
if {$useOldWindow && [string first "Wave" [gui_get_current_window -view]]==0} { 
	set Wave.1 [gui_get_current_window -view] 
} else {
	set Wave.1 [lindex [gui_get_window_ids -type Wave] 0]
if {[string first "Wave" ${Wave.1}]!=0} {
gui_open_window Wave
set Wave.1 [ gui_get_current_window -view ]
}
}

set groupExD [gui_get_pref_value -category Wave -key exclusiveSG]
gui_set_pref_value -category Wave -key exclusiveSG -value {false}
set origWaveHeight [gui_get_pref_value -category Wave -key waveRowHeight]
gui_list_set_height -id Wave -height 25
set origGroupCreationState [gui_list_create_group_when_add -wave]
gui_list_create_group_when_add -wave -disable
gui_marker_create -id ${Wave.1} M1 44830
gui_marker_create -id ${Wave.1} M2 92580
gui_marker_create -id ${Wave.1} M3 172500
gui_marker_create -id ${Wave.1} M4 267580
gui_marker_set_ref -id ${Wave.1}  C1
gui_wv_zoom_timerange -id ${Wave.1} 267469 267630
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group1}]
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group2}]
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group3}]
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group4}]
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group5}]
gui_list_select -id ${Wave.1} {{testbench.dcache_cce_mem.genblk2[1].dcache.lce.cce_lce_data_cmd.data} }
gui_seek_criteria -id ${Wave.1} {Value...}


gui_set_pref_value -category Wave -key exclusiveSG -value $groupExD
gui_list_set_height -id Wave -height $origWaveHeight
if {$origGroupCreationState} {
	gui_list_create_group_when_add -wave -enable
}
if { $groupExD } {
 gui_msg_report -code DVWW028
}
gui_list_set_filter -id ${Wave.1} -list { {Buffer 1} {Input 1} {Others 1} {Linkage 1} {Output 1} {Parameter 1} {All 1} {Aggregate 1} {LibBaseMember 1} {Event 1} {Assertion 1} {Constant 1} {Interface 1} {BaseMembers 1} {Signal 1} {$unit 1} {Inout 1} {Variable 1} }
gui_list_set_filter -id ${Wave.1} -text {*}
gui_list_set_insertion_bar  -id ${Wave.1} -group ${Group5}  -item {testbench.dcache_cce_mem.genblk2[1].dcache.lce.cce_lce_data_cmd.data[511:0]} -position below

gui_marker_move -id ${Wave.1} {C1} 267530
gui_view_scroll -id ${Wave.1} -vertical -set 598
gui_show_grid -id ${Wave.1} -enable false
#</Session>

