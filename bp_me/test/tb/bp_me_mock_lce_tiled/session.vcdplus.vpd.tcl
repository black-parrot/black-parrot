# Begin_DVE_Session_Save_Info
# DVE full session
# Saved on Thu May 16 11:39:26 2019
# Designs open: 1
#   V1: vcdplus.vpd
# Toplevel windows open: 2
# 	TopLevel.1
# 	TopLevel.2
#   Source.1: testbench
#   Wave.1: 71 signals
#   Group count = 5
#   Group Request signal count = 5
#   Group PC signal count = 3
#   Group Directory signal count = 21
#   Group Registers signal count = 18
#   Group Decode signal count = 24
# End_DVE_Session_Save_Info

# DVE version: L-2016.06-SP2-15_Full64
# DVE build date: Mar 11 2018 22:07:39


#<Session mode="Full" path="/mnt/bsg/diskbits/wysem/blackparrot/pre-alpha-release/bp_me/test/tb/bp_me_mock_lce_tiled/session.vcdplus.vpd.tcl" type="Debug">

gui_set_loading_session_type Post
gui_continuetime_set

# Close design
if { [gui_sim_state -check active] } {
    gui_sim_terminate
}
gui_close_db -all
gui_expr_clear_all

# Close all windows
gui_close_window -type Console
gui_close_window -type Wave
gui_close_window -type Source
gui_close_window -type Schematic
gui_close_window -type Data
gui_close_window -type DriverLoad
gui_close_window -type List
gui_close_window -type Memory
gui_close_window -type HSPane
gui_close_window -type DLPane
gui_close_window -type Assertion
gui_close_window -type CovHier
gui_close_window -type CoverageTable
gui_close_window -type CoverageMap
gui_close_window -type CovDetail
gui_close_window -type Local
gui_close_window -type Stack
gui_close_window -type Watch
gui_close_window -type Group
gui_close_window -type Transaction



# Application preferences
gui_set_pref_value -key app_default_font -value {Helvetica,10,-1,5,50,0,0,0,0,0}
gui_src_preferences -tabstop 8 -maxbits 24 -windownumber 1
#<WindowLayout>

# DVE top-level session


# Create and position top-level window: TopLevel.1

if {![gui_exist_window -window TopLevel.1]} {
    set TopLevel.1 [ gui_create_window -type TopLevel \
       -icon $::env(DVE)/auxx/gui/images/toolbars/dvewin.xpm] 
} else { 
    set TopLevel.1 TopLevel.1
}
gui_show_window -window ${TopLevel.1} -show_state normal -rect {{189 56} {1875 1044}}

# ToolBar settings
gui_set_toolbar_attributes -toolbar {TimeOperations} -dock_state top
gui_set_toolbar_attributes -toolbar {TimeOperations} -offset 0
gui_show_toolbar -toolbar {TimeOperations}
gui_hide_toolbar -toolbar {&File}
gui_set_toolbar_attributes -toolbar {&Edit} -dock_state top
gui_set_toolbar_attributes -toolbar {&Edit} -offset 0
gui_show_toolbar -toolbar {&Edit}
gui_hide_toolbar -toolbar {CopyPaste}
gui_set_toolbar_attributes -toolbar {&Trace} -dock_state top
gui_set_toolbar_attributes -toolbar {&Trace} -offset 0
gui_show_toolbar -toolbar {&Trace}
gui_hide_toolbar -toolbar {TraceInstance}
gui_hide_toolbar -toolbar {BackTrace}
gui_set_toolbar_attributes -toolbar {&Scope} -dock_state top
gui_set_toolbar_attributes -toolbar {&Scope} -offset 0
gui_show_toolbar -toolbar {&Scope}
gui_set_toolbar_attributes -toolbar {&Window} -dock_state top
gui_set_toolbar_attributes -toolbar {&Window} -offset 0
gui_show_toolbar -toolbar {&Window}
gui_set_toolbar_attributes -toolbar {Signal} -dock_state top
gui_set_toolbar_attributes -toolbar {Signal} -offset 0
gui_show_toolbar -toolbar {Signal}
gui_set_toolbar_attributes -toolbar {Zoom} -dock_state top
gui_set_toolbar_attributes -toolbar {Zoom} -offset 0
gui_show_toolbar -toolbar {Zoom}
gui_set_toolbar_attributes -toolbar {Zoom And Pan History} -dock_state top
gui_set_toolbar_attributes -toolbar {Zoom And Pan History} -offset 0
gui_show_toolbar -toolbar {Zoom And Pan History}
gui_set_toolbar_attributes -toolbar {Grid} -dock_state top
gui_set_toolbar_attributes -toolbar {Grid} -offset 0
gui_show_toolbar -toolbar {Grid}
gui_hide_toolbar -toolbar {Simulator}
gui_hide_toolbar -toolbar {Interactive Rewind}
gui_hide_toolbar -toolbar {Testbench}

# End ToolBar settings

# Docked window settings
set HSPane.1 [gui_create_window -type HSPane -parent ${TopLevel.1} -dock_state left -dock_on_new_line true -dock_extent 419]
catch { set Hier.1 [gui_share_window -id ${HSPane.1} -type Hier] }
gui_set_window_pref_key -window ${HSPane.1} -key dock_width -value_type integer -value 419
gui_set_window_pref_key -window ${HSPane.1} -key dock_height -value_type integer -value -1
gui_set_window_pref_key -window ${HSPane.1} -key dock_offset -value_type integer -value 0
gui_update_layout -id ${HSPane.1} {{left 0} {top 0} {width 418} {height 715} {dock_state left} {dock_on_new_line true} {child_hier_colhier 341} {child_hier_coltype 126} {child_hier_colpd 0} {child_hier_col1 0} {child_hier_col2 1} {child_hier_col3 -1}}
set DLPane.1 [gui_create_window -type DLPane -parent ${TopLevel.1} -dock_state left -dock_on_new_line true -dock_extent 772]
catch { set Data.1 [gui_share_window -id ${DLPane.1} -type Data] }
gui_set_window_pref_key -window ${DLPane.1} -key dock_width -value_type integer -value 772
gui_set_window_pref_key -window ${DLPane.1} -key dock_height -value_type integer -value 715
gui_set_window_pref_key -window ${DLPane.1} -key dock_offset -value_type integer -value 0
gui_update_layout -id ${DLPane.1} {{left 0} {top 0} {width 771} {height 715} {dock_state left} {dock_on_new_line true} {child_data_colvariable 271} {child_data_colvalue 402} {child_data_coltype 116} {child_data_col1 0} {child_data_col2 1} {child_data_col3 2}}
set Console.1 [gui_create_window -type Console -parent ${TopLevel.1} -dock_state bottom -dock_on_new_line true -dock_extent 202]
gui_set_window_pref_key -window ${Console.1} -key dock_width -value_type integer -value 1688
gui_set_window_pref_key -window ${Console.1} -key dock_height -value_type integer -value 202
gui_set_window_pref_key -window ${Console.1} -key dock_offset -value_type integer -value 0
gui_update_layout -id ${Console.1} {{left 0} {top 0} {width 1686} {height 201} {dock_state bottom} {dock_on_new_line true}}
#### Start - Readjusting docked view's offset / size
set dockAreaList { top left right bottom }
foreach dockArea $dockAreaList {
  set viewList [gui_ekki_get_window_ids -active_parent -dock_area $dockArea]
  foreach view $viewList {
      if {[lsearch -exact [gui_get_window_pref_keys -window $view] dock_width] != -1} {
        set dockWidth [gui_get_window_pref_value -window $view -key dock_width]
        set dockHeight [gui_get_window_pref_value -window $view -key dock_height]
        set offset [gui_get_window_pref_value -window $view -key dock_offset]
        if { [string equal "top" $dockArea] || [string equal "bottom" $dockArea]} {
          gui_set_window_attributes -window $view -dock_offset $offset -width $dockWidth
        } else {
          gui_set_window_attributes -window $view -dock_offset $offset -height $dockHeight
        }
      }
  }
}
#### End - Readjusting docked view's offset / size
gui_sync_global -id ${TopLevel.1} -option true

# MDI window settings
set Source.1 [gui_create_window -type {Source}  -parent ${TopLevel.1}]
gui_show_window -window ${Source.1} -show_state maximized
gui_update_layout -id ${Source.1} {{show_state maximized} {dock_state undocked} {dock_on_new_line false}}

# End MDI window settings


# Create and position top-level window: TopLevel.2

if {![gui_exist_window -window TopLevel.2]} {
    set TopLevel.2 [ gui_create_window -type TopLevel \
       -icon $::env(DVE)/auxx/gui/images/toolbars/dvewin.xpm] 
} else { 
    set TopLevel.2 TopLevel.2
}
gui_show_window -window ${TopLevel.2} -show_state normal -rect {{89 40} {1721 1013}}

# ToolBar settings
gui_set_toolbar_attributes -toolbar {TimeOperations} -dock_state top
gui_set_toolbar_attributes -toolbar {TimeOperations} -offset 0
gui_show_toolbar -toolbar {TimeOperations}
gui_hide_toolbar -toolbar {&File}
gui_set_toolbar_attributes -toolbar {&Edit} -dock_state top
gui_set_toolbar_attributes -toolbar {&Edit} -offset 0
gui_show_toolbar -toolbar {&Edit}
gui_hide_toolbar -toolbar {CopyPaste}
gui_set_toolbar_attributes -toolbar {&Trace} -dock_state top
gui_set_toolbar_attributes -toolbar {&Trace} -offset 0
gui_show_toolbar -toolbar {&Trace}
gui_hide_toolbar -toolbar {TraceInstance}
gui_hide_toolbar -toolbar {BackTrace}
gui_set_toolbar_attributes -toolbar {&Scope} -dock_state top
gui_set_toolbar_attributes -toolbar {&Scope} -offset 0
gui_show_toolbar -toolbar {&Scope}
gui_set_toolbar_attributes -toolbar {&Window} -dock_state top
gui_set_toolbar_attributes -toolbar {&Window} -offset 0
gui_show_toolbar -toolbar {&Window}
gui_set_toolbar_attributes -toolbar {Signal} -dock_state top
gui_set_toolbar_attributes -toolbar {Signal} -offset 0
gui_show_toolbar -toolbar {Signal}
gui_set_toolbar_attributes -toolbar {Zoom} -dock_state top
gui_set_toolbar_attributes -toolbar {Zoom} -offset 0
gui_show_toolbar -toolbar {Zoom}
gui_set_toolbar_attributes -toolbar {Zoom And Pan History} -dock_state top
gui_set_toolbar_attributes -toolbar {Zoom And Pan History} -offset 0
gui_show_toolbar -toolbar {Zoom And Pan History}
gui_set_toolbar_attributes -toolbar {Grid} -dock_state top
gui_set_toolbar_attributes -toolbar {Grid} -offset 0
gui_show_toolbar -toolbar {Grid}
gui_hide_toolbar -toolbar {Simulator}
gui_hide_toolbar -toolbar {Interactive Rewind}
gui_set_toolbar_attributes -toolbar {Testbench} -dock_state top
gui_set_toolbar_attributes -toolbar {Testbench} -offset 0
gui_show_toolbar -toolbar {Testbench}

# End ToolBar settings

# Docked window settings
gui_sync_global -id ${TopLevel.2} -option true

# MDI window settings
set Wave.1 [gui_create_window -type {Wave}  -parent ${TopLevel.2}]
gui_show_window -window ${Wave.1} -show_state maximized
gui_update_layout -id ${Wave.1} {{show_state maximized} {dock_state undocked} {dock_on_new_line false} {child_wave_left 473} {child_wave_right 1154} {child_wave_colname 234} {child_wave_colvalue 235} {child_wave_col1 0} {child_wave_col2 1}}

# End MDI window settings

gui_set_env TOPLEVELS::TARGET_FRAME(Source) ${TopLevel.1}
gui_set_env TOPLEVELS::TARGET_FRAME(Schematic) ${TopLevel.1}
gui_set_env TOPLEVELS::TARGET_FRAME(PathSchematic) ${TopLevel.1}
gui_set_env TOPLEVELS::TARGET_FRAME(Wave) none
gui_set_env TOPLEVELS::TARGET_FRAME(List) none
gui_set_env TOPLEVELS::TARGET_FRAME(Memory) ${TopLevel.1}
gui_set_env TOPLEVELS::TARGET_FRAME(DriverLoad) none
gui_update_statusbar_target_frame ${TopLevel.1}
gui_update_statusbar_target_frame ${TopLevel.2}

#</WindowLayout>

#<Database>

# DVE Open design session: 

if { ![gui_is_db_opened -db {vcdplus.vpd}] } {
	gui_open_db -design V1 -file vcdplus.vpd -nosource
}
gui_set_precision 1ps
gui_set_time_units 1ps
#</Database>

# DVE Global setting session: 


# Global: Bus

# Global: Expressions

# Global: Signal Time Shift

# Global: Signal Compare

# Global: Signal Groups


set _session_group_6 Request
gui_sg_create "$_session_group_6"
set Request "$_session_group_6"

gui_sg_addsignal -group "$_session_group_6" { testbench.clk testbench.reset {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.lce_req_v_i} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.lce_req_yumi_o} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.registers.lce_req_s_i} }

set _session_group_7 PC
gui_sg_create "$_session_group_7"
set PC "$_session_group_7"

gui_sg_addsignal -group "$_session_group_7" { {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_ram.dir_busy_i} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_ram.inst_v_o} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_ram.ex_pc_r} }

set _session_group_8 Directory
gui_sg_create "$_session_group_8"
set Directory "$_session_group_8"

gui_sg_addsignal -group "$_session_group_8" { {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.directory.way_group_i} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.directory.lce_i} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.directory.way_i} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.directory.lru_way_i} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.directory.r_cmd_i} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.directory.r_v_i} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.directory.tag_i} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.directory.coh_state_i} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.directory.pending_i} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.directory.w_cmd_i} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.directory.w_v_i} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.directory.busy_o} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.directory.pending_o} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.directory.pending_v_o} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.directory.sharers_v_o} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.directory.sharers_hits_o} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.directory.sharers_ways_o} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.directory.sharers_coh_states_o} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.directory.lru_v_o} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.directory.lru_cached_excl_o} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.directory.lru_tag_o} }

set _session_group_9 Registers
gui_sg_create "$_session_group_9"
set Registers "$_session_group_9"

gui_sg_addsignal -group "$_session_group_9" { {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.req_lce_r_lo} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.req_addr_r_lo} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.req_tag_r_lo} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.req_addr_way_r_lo} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.lru_way_r_lo} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.lru_addr_r_lo} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.transfer_lce_r_lo} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.transfer_lce_way_r_lo} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.next_coh_state_r_lo} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.flags_r_lo} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.gpr_r_lo} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.ack_type_r_lo} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.sharers_hits_r_lo} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.sharers_ways_r_lo} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.sharers_coh_states_r_lo} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.nc_req_size_r_lo} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.nc_data_r_lo} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.lru_cached_excl_r_lo} }

set _session_group_10 Decode
gui_sg_create "$_session_group_10"
set Decode "$_session_group_10"

gui_sg_addsignal -group "$_session_group_10" { {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode.inst_i} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode.inst_v_i} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode.lce_req_v_i} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode.lce_resp_v_i} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode.lce_data_resp_v_i} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode.mem_resp_v_i} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode.mem_data_resp_v_i} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode.pending_v_i} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode.lce_cmd_ready_i} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode.lce_data_cmd_ready_i} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode.mem_cmd_ready_i} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode.mem_data_cmd_ready_i} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode.decoded_inst_v_o} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode.pc_stall_o} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode.pc_branch_target_o} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode.op} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode.pushq_op} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode.popq_op} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode.poph_op} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode.pushq_qsel} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode.popq_qsel} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode.rd_dir_op} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode.decoded_inst_o} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode.read_dir_op_s} }

# Global: Highlighting

# Global: Stack
gui_change_stack_mode -mode list

# Post database loading setting...

# Restore C1 time
gui_set_time -C1_only 68230



# Save global setting...

# Wave/List view global setting
gui_list_create_group_when_add -wave -enable
gui_cov_show_value -switch false

# Close all empty TopLevel windows
foreach __top [gui_ekki_get_window_ids -type TopLevel] {
    if { [llength [gui_ekki_get_window_ids -parent $__top]] == 0} {
        gui_close_window -window $__top
    }
}
gui_set_loading_session_type noSession
# DVE View/pane content session: 


# Hier 'Hier.1'
gui_show_window -window ${Hier.1}
gui_list_set_filter -id ${Hier.1} -list { {Package 1} {All 0} {Process 1} {VirtPowSwitch 0} {UnnamedProcess 1} {UDP 0} {Function 1} {Block 1} {SrsnAndSpaCell 0} {OVA Unit 1} {LeafScCell 1} {LeafVlgCell 1} {Interface 1} {LeafVhdCell 1} {$unit 1} {NamedBlock 1} {Task 1} {VlgPackage 1} {ClassDef 1} {VirtIsoCell 0} }
gui_list_set_filter -id ${Hier.1} -text {*}
gui_hier_list_init -id ${Hier.1}
gui_change_design -id ${Hier.1} -design V1
catch {gui_list_expand -id ${Hier.1} testbench}
catch {gui_list_expand -id ${Hier.1} testbench.me_top_test}
catch {gui_list_expand -id ${Hier.1} testbench.me_top_test.me_top}
catch {gui_list_expand -id ${Hier.1} {testbench.me_top_test.me_top.rof1[0].tile}}
catch {gui_list_expand -id ${Hier.1} {testbench.me_top_test.me_top.rof1[0].tile.cce}}
catch {gui_list_expand -id ${Hier.1} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce}}
catch {gui_list_select -id ${Hier.1} {{testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode}}}
gui_view_scroll -id ${Hier.1} -vertical -set 60
gui_view_scroll -id ${Hier.1} -horizontal -set 0

# Data 'Data.1'
gui_list_set_filter -id ${Data.1} -list { {Buffer 1} {Input 1} {Others 1} {Linkage 1} {Output 1} {LowPower 1} {Parameter 1} {All 1} {Aggregate 1} {LibBaseMember 1} {Event 1} {Assertion 1} {Constant 1} {Interface 1} {BaseMembers 1} {Signal 1} {$unit 1} {Inout 1} {Variable 1} }
gui_list_set_filter -id ${Data.1} -text {*}
gui_list_show_data -id ${Data.1} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode}
gui_show_window -window ${Data.1}
catch { gui_list_select -id ${Data.1} {{testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode.stall_op} }}
gui_view_scroll -id ${Data.1} -vertical -set 89
gui_view_scroll -id ${Data.1} -horizontal -set 0
gui_view_scroll -id ${Hier.1} -vertical -set 60
gui_view_scroll -id ${Hier.1} -horizontal -set 0

# Source 'Source.1'
gui_src_value_annotate -id ${Source.1} -switch false
gui_set_env TOGGLE::VALUEANNOTATE 0
gui_open_source -id ${Source.1}  -replace -active testbench
gui_view_scroll -id ${Source.1} -vertical -set 72
gui_src_set_reusable -id ${Source.1}

# View 'Wave.1'
gui_wv_sync -id ${Wave.1} -switch false
set groupExD [gui_get_pref_value -category Wave -key exclusiveSG]
gui_set_pref_value -category Wave -key exclusiveSG -value {false}
set origWaveHeight [gui_get_pref_value -category Wave -key waveRowHeight]
gui_list_set_height -id Wave -height 25
set origGroupCreationState [gui_list_create_group_when_add -wave]
gui_list_create_group_when_add -wave -disable
gui_marker_set_ref -id ${Wave.1}  C1
gui_wv_zoom_timerange -id ${Wave.1} 68101 68442
gui_list_add_group -id ${Wave.1} -after {New Group} {Request}
gui_list_add_group -id ${Wave.1} -after {New Group} {PC}
gui_list_add_group -id ${Wave.1} -after {New Group} {Directory}
gui_list_add_group -id ${Wave.1} -after {New Group} {Registers}
gui_list_add_group -id ${Wave.1} -after {New Group} {Decode}
gui_list_expand -id ${Wave.1} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.registers.lce_req_s_i}
gui_list_expand -id ${Wave.1} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.gpr_r_lo}
gui_list_expand -id ${Wave.1} {testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.inst_decode.decoded_inst_o}
gui_list_select -id ${Wave.1} {{testbench.me_top_test.me_top.rof1[0].tile.cce.bp_cce.directory.lce_i} }
gui_seek_criteria -id ${Wave.1} {Any Edge}



gui_set_env TOGGLE::DEFAULT_WAVE_WINDOW ${Wave.1}
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
gui_list_set_insertion_bar  -id ${Wave.1} -group Decode  -position in

gui_marker_move -id ${Wave.1} {C1} 68230
gui_view_scroll -id ${Wave.1} -vertical -set 225
gui_show_grid -id ${Wave.1} -enable false
# Restore toplevel window zorder
# The toplevel window could be closed if it has no view/pane
if {[gui_exist_window -window ${TopLevel.1}]} {
	gui_set_active_window -window ${TopLevel.1}
	gui_set_active_window -window ${Source.1}
	gui_set_active_window -window ${DLPane.1}
}
if {[gui_exist_window -window ${TopLevel.2}]} {
	gui_set_active_window -window ${TopLevel.2}
	gui_set_active_window -window ${Wave.1}
}
#</Session>

