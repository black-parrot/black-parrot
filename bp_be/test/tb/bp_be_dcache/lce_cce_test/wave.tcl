# Begin_DVE_Session_Save_Info
# DVE view(Wave.1 ) session
# Saved on Wed Nov 21 10:46:00 2018
# Toplevel windows open: 2
# 	TopLevel.1
# 	TopLevel.2
#   Wave.1: 64 signals
# End_DVE_Session_Save_Info

# DVE version: L-2016.06-SP2-15_Full64
# DVE build date: Mar 11 2018 22:07:39


#<Session mode="View" path="/home/dcjung/bp/bp_be/bp_dcache/testing/lce_cce_test/wave.tcl" type="Debug">

#<Database>

gui_set_time_units 1ps
#</Database>

# DVE View/pane content session: 

# Begin_DVE_Session_Save_Info (Wave.1)
# DVE wave signals session
# Saved on Wed Nov 21 10:46:00 2018
# 64 signals
# End_DVE_Session_Save_Info

# DVE version: L-2016.06-SP2-15_Full64
# DVE build date: Mar 11 2018 22:07:39


#Add ncecessay scopes

gui_set_time_units 1ps

set _wave_session_group_1 dcache
if {[gui_sg_is_group -name "$_wave_session_group_1"]} {
    set _wave_session_group_1 [gui_sg_generate_new_name]
}
set Group1 "$_wave_session_group_1"

gui_sg_addsignal -group "$_wave_session_group_1" { {V1:testbench.dcache_cce_mem.dcache.clk_i} {V1:testbench.dcache_cce_mem.dcache.reset_i} {V1:testbench.dcache_cce_mem.dcache.v_i} {V1:testbench.dcache_cce_mem.dcache.dcache_pkt.opcode} {V1:testbench.dcache_cce_mem.dcache.dcache_pkt.vaddr} {V1:testbench.dcache_cce_mem.dcache.dcache_pkt.data} {V1:testbench.dcache_cce_mem.dcache.ready_o} {V1:testbench.dcache_cce_mem.dcache.v_o} {V1:testbench.dcache_cce_mem.dcache.data_o} {V1:testbench.dcache_cce_mem.dcache.cache_miss_o} }

set _wave_session_group_2 lce_cce_req
if {[gui_sg_is_group -name "$_wave_session_group_2"]} {
    set _wave_session_group_2 [gui_sg_generate_new_name]
}
set Group2 "$_wave_session_group_2"

gui_sg_addsignal -group "$_wave_session_group_2" { {V1:testbench.dcache_cce_mem.dcache.lce.lce_cce_req_v_o} {V1:testbench.dcache_cce_mem.dcache.lce.lce_cce_req_ready_i} {V1:testbench.dcache_cce_mem.dcache.lce.lce_cce_req.dst_id} {V1:testbench.dcache_cce_mem.dcache.lce.lce_cce_req.src_id} {V1:testbench.dcache_cce_mem.dcache.lce.lce_cce_req.msg_type} {V1:testbench.dcache_cce_mem.dcache.lce.lce_cce_req.non_exclusive} {V1:testbench.dcache_cce_mem.dcache.lce.lce_cce_req.addr} {V1:testbench.dcache_cce_mem.dcache.lce.lce_cce_req.lru_way_id} {V1:testbench.dcache_cce_mem.dcache.lce.lce_cce_req.lru_dirty} }

set _wave_session_group_3 lce_cce_resp
if {[gui_sg_is_group -name "$_wave_session_group_3"]} {
    set _wave_session_group_3 [gui_sg_generate_new_name]
}
set Group3 "$_wave_session_group_3"

gui_sg_addsignal -group "$_wave_session_group_3" { {V1:testbench.dcache_cce_mem.dcache.lce.lce_cce_resp_v_o} {V1:testbench.dcache_cce_mem.dcache.lce.lce_cce_resp_ready_i} {V1:testbench.dcache_cce_mem.dcache.lce.lce_cce_resp.dst_id} {V1:testbench.dcache_cce_mem.dcache.lce.lce_cce_resp.src_id} {V1:testbench.dcache_cce_mem.dcache.lce.lce_cce_resp.msg_type} {V1:testbench.dcache_cce_mem.dcache.lce.lce_cce_resp.addr} }

set _wave_session_group_4 lce_cce_data_resp
if {[gui_sg_is_group -name "$_wave_session_group_4"]} {
    set _wave_session_group_4 [gui_sg_generate_new_name]
}
set Group4 "$_wave_session_group_4"

gui_sg_addsignal -group "$_wave_session_group_4" { {V1:testbench.dcache_cce_mem.dcache.lce.lce_cce_data_resp_v_o} {V1:testbench.dcache_cce_mem.dcache.lce.lce_cce_data_resp_ready_i} {V1:testbench.dcache_cce_mem.dcache.lce.lce_cce_data_resp.dst_id} {V1:testbench.dcache_cce_mem.dcache.lce.lce_cce_data_resp.src_id} {V1:testbench.dcache_cce_mem.dcache.lce.lce_cce_data_resp.msg_type} {V1:testbench.dcache_cce_mem.dcache.lce.lce_cce_data_resp.addr} {V1:testbench.dcache_cce_mem.dcache.lce.lce_cce_data_resp.data} }

set _wave_session_group_5 cce_lce_cmd
if {[gui_sg_is_group -name "$_wave_session_group_5"]} {
    set _wave_session_group_5 [gui_sg_generate_new_name]
}
set Group5 "$_wave_session_group_5"

gui_sg_addsignal -group "$_wave_session_group_5" { {V1:testbench.dcache_cce_mem.dcache.lce.cce_lce_cmd_v_i} {V1:testbench.dcache_cce_mem.dcache.lce.cce_lce_cmd_yumi_o} {V1:testbench.dcache_cce_mem.dcache.lce.cce_lce_cmd.dst_id} {V1:testbench.dcache_cce_mem.dcache.lce.cce_lce_cmd.src_id} {V1:testbench.dcache_cce_mem.dcache.lce.cce_lce_cmd.msg_type} {V1:testbench.dcache_cce_mem.dcache.lce.cce_lce_cmd.addr} {V1:testbench.dcache_cce_mem.dcache.lce.cce_lce_cmd.way_id} {V1:testbench.dcache_cce_mem.dcache.lce.cce_lce_cmd.state} {V1:testbench.dcache_cce_mem.dcache.lce.cce_lce_cmd.target} {V1:testbench.dcache_cce_mem.dcache.lce.cce_lce_cmd.target_way_id} }

set _wave_session_group_6 cce_lce_data_cmd
if {[gui_sg_is_group -name "$_wave_session_group_6"]} {
    set _wave_session_group_6 [gui_sg_generate_new_name]
}
set Group6 "$_wave_session_group_6"

gui_sg_addsignal -group "$_wave_session_group_6" { {V1:testbench.dcache_cce_mem.dcache.lce.cce_lce_data_cmd_v_i} {V1:testbench.dcache_cce_mem.dcache.lce.cce_lce_data_cmd_yumi_o} {V1:testbench.dcache_cce_mem.dcache.lce.cce_lce_data_cmd.dst_id} {V1:testbench.dcache_cce_mem.dcache.lce.cce_lce_data_cmd.src_id} {V1:testbench.dcache_cce_mem.dcache.lce.cce_lce_data_cmd.msg_type} {V1:testbench.dcache_cce_mem.dcache.lce.cce_lce_data_cmd.way_id} {V1:testbench.dcache_cce_mem.dcache.lce.cce_lce_data_cmd.addr} {V1:testbench.dcache_cce_mem.dcache.lce.cce_lce_data_cmd.data} }

set _wave_session_group_7 lce_lce_tr_resp_in
if {[gui_sg_is_group -name "$_wave_session_group_7"]} {
    set _wave_session_group_7 [gui_sg_generate_new_name]
}
set Group7 "$_wave_session_group_7"

gui_sg_addsignal -group "$_wave_session_group_7" { {V1:testbench.dcache_cce_mem.dcache.lce.lce_lce_tr_resp_v_i} {V1:testbench.dcache_cce_mem.dcache.lce.lce_lce_tr_resp_yumi_o} {V1:testbench.dcache_cce_mem.dcache.lce.lce_lce_tr_resp_in.dst_id} {V1:testbench.dcache_cce_mem.dcache.lce.lce_lce_tr_resp_in.src_id} {V1:testbench.dcache_cce_mem.dcache.lce.lce_lce_tr_resp_in.way_id} {V1:testbench.dcache_cce_mem.dcache.lce.lce_lce_tr_resp_in.addr} {V1:testbench.dcache_cce_mem.dcache.lce.lce_lce_tr_resp_in.data} }

set _wave_session_group_8 lce_lce_tr_resp_out
if {[gui_sg_is_group -name "$_wave_session_group_8"]} {
    set _wave_session_group_8 [gui_sg_generate_new_name]
}
set Group8 "$_wave_session_group_8"

gui_sg_addsignal -group "$_wave_session_group_8" { {V1:testbench.dcache_cce_mem.dcache.lce.lce_lce_tr_resp_v_o} {V1:testbench.dcache_cce_mem.dcache.lce.lce_lce_tr_resp_ready_i} {V1:testbench.dcache_cce_mem.dcache.lce.lce_lce_tr_resp_out.dst_id} {V1:testbench.dcache_cce_mem.dcache.lce.lce_lce_tr_resp_out.src_id} {V1:testbench.dcache_cce_mem.dcache.lce.lce_lce_tr_resp_out.way_id} {V1:testbench.dcache_cce_mem.dcache.lce.lce_lce_tr_resp_out.addr} {V1:testbench.dcache_cce_mem.dcache.lce.lce_lce_tr_resp_out.data} }
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
gui_wv_zoom_timerange -id ${Wave.1} 33799 35534
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group1}]
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group2}]
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group3}]
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group4}]
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group5}]
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group6}]
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group7}]
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group8}]
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
gui_list_set_insertion_bar  -id ${Wave.1} -group ${Group8}  -item testbench.dcache_cce_mem.dcache.lce.lce_lce_tr_resp_ready_i -position below

gui_marker_move -id ${Wave.1} {C1} 30551
gui_view_scroll -id ${Wave.1} -vertical -set 0
gui_show_grid -id ${Wave.1} -enable false
#</Session>

