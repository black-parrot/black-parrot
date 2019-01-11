# Begin_DVE_Session_Save_Info
# DVE view(Wave.1 ) session
# Saved on Thu Jan 10 18:09:07 2019
# Toplevel windows open: 2
# 	TopLevel.1
# 	TopLevel.2
#   Wave.1: 32 signals
# End_DVE_Session_Save_Info

# DVE version: L-2016.06-SP2-15_Full64
# DVE build date: Mar 11 2018 22:07:39


#<Session mode="View" path="/home/wysem/posh/session.inter.vpd.tcl" type="Debug">

#<Database>

gui_set_time_units 1ps
#</Database>

# DVE View/pane content session: 

# Begin_DVE_Session_Save_Info (Wave.1)
# DVE wave signals session
# Saved on Thu Jan 10 18:09:07 2019
# 32 signals
# End_DVE_Session_Save_Info

# DVE version: L-2016.06-SP2-15_Full64
# DVE build date: Mar 11 2018 22:07:39


#Add ncecessay scopes
gui_load_child_values {cmp_top.system.chip.tile0.g_core.core.transducer}

gui_set_time_units 1ps

set _wave_session_group_2 Group1
if {[gui_sg_is_group -name "$_wave_session_group_2"]} {
    set _wave_session_group_2 [gui_sg_generate_new_name]
}
set Group1 "$_wave_session_group_2"

gui_sg_addsignal -group "$_wave_session_group_2" { {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.clk_i} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.reset_i} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.trans_state} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.set_count_r} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.sync_count_r} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.sync_ack_count_r} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.dcache_lce_req_yumi_from_tr} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.dcache_lce_resp_yumi_from_tr} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.dcache_lce_data_resp_yumi_from_tr} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.icache_lce_req_yumi_from_tr} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.icache_lce_resp_yumi_from_tr} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.icache_lce_data_resp_yumi_from_tr} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.lce_req_r} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.lce_resp_r} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.dcache_lce_cmd_r} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.icache_lce_cmd_r} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.icache_req_r} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.l15_noc1buffer_req_val} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.l15_noc1buffer_req_type} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.l15_noc1buffer_req_threadid} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.l15_noc1buffer_req_mshrid} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.l15_noc1buffer_req_address} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.l15_noc1buffer_req_non_cacheable} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.l15_noc1buffer_req_size} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.l15_noc1buffer_req_prefetch} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.l15_noc1buffer_req_data_0} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.l15_noc1buffer_req_data_1} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.l15_noc1buffer_req_csm_data} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.l15_noc1buffer_req_csm_ticket} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.l15_noc1buffer_req_homeid} {Sim:cmp_top.system.chip.tile0.g_core.core.transducer.l15_noc1buffer_req_homeid_val} {Sim:cmp_top.system.chip.tile0.g_core.core.fe.bp_fe_pc_gen_1.pc} }
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
gui_marker_set_ref -id ${Wave.1}  C1
gui_wv_zoom_timerange -id ${Wave.1} 290093 390958
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group1}]
gui_list_expand -id ${Wave.1} cmp_top.system.chip.tile0.g_core.core.transducer.lce_req_r
gui_list_select -id ${Wave.1} {cmp_top.system.chip.tile0.g_core.core.transducer.l15_noc1buffer_req_val }
gui_seek_criteria -id ${Wave.1} {Any Edge}


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
gui_list_set_insertion_bar  -id ${Wave.1} -group ${Group1}  -position in

gui_marker_move -id ${Wave.1} {C1} 335253
gui_view_scroll -id ${Wave.1} -vertical -set 211
gui_show_grid -id ${Wave.1} -enable false
#</Session>

