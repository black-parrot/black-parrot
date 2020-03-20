proc print_regout_title {} {
  echo [format "  %-50s %-10s %-20s %-10s %-10s %-10s %-s" "From" "Rise/Fall" "To" "Rise/Fall" "Arriaval" "Skew(rise)" "Skew(fall)"]
}

proc print_cdc_title {} {
}

proc print_divider {} {
  echo "  ----------------------------------------------------------------------------------------------------------------------------------"
}

proc report_reg_to_output_path {start end to_option clock_rise_arrival clock_fall_arrival type} {
  if { $to_option == "rise_to" } {
    set path [get_timing_paths -from $start -rise_to $end -delay_type $type]
  } elseif { $to_option == "fall_to" } {
    set path [get_timing_paths -from $start -fall_to $end -delay_type $type]
  } else {
    error "fatal error: to_option should be one of { rise_to, fall_to }"
    exit
  }

  set startpoint [get_attribute $path startpoint]
  set endpoint [get_attribute $path endpoint]
  set arrival [get_attribute $path arrival]
  set skew_to_clock_rise [expr ($arrival - $clock_rise_arrival)]
  set skew_to_clock_fall [expr ($arrival - $clock_fall_arrival)]
  set startpoint_name [get_attribute $startpoint full_name]
  set endpoint_name [get_attribute $endpoint full_name]
  foreach_in_collection point [get_attribute $path points] {
    set point_name [get_attribute [get_attribute $point object] full_name]
    if { $point_name == $startpoint_name } {
      set startpoint_edge [get_attribute $point rise_fall]
    }
    if { $point_name == $endpoint_name } {
      set endpoint_edge [get_attribute $point rise_fall]
    }
  }
  echo [format "  %-50s %-10s %-20s %-10s %-10s %-10s %-s" $startpoint_name $startpoint_edge $endpoint_name $endpoint_edge $arrival $skew_to_clock_rise $skew_to_clock_fall]
}

proc report_output_channel {channel_name type} {
  if { $channel_name < "A" || $channel_name > "D" } {
    error "fatal error: channel_name should be one of { A, B, C, D }"
    exit
  }
  set channel_number [expr ([scan $channel_name %c] - 65)]
  set clock_rise_path [get_timing_paths -from [get_clocks *] -rise_to [get_ports p_sdo_sclk_o[${channel_number}]] -delay_type $type]
  set clock_rise_arrival [get_attribute $clock_rise_path arrival]
  set clock_fall_path [get_timing_paths -from [get_clocks *] -fall_to [get_ports p_sdo_sclk_o[${channel_number}]] -delay_type $type]
  set clock_fall_arrival [get_attribute $clock_fall_path arrival]
  print_regout_title
  print_divider
  report_reg_to_output_path [get_clocks *] [get_ports p_sdo_sclk_o[${channel_number}]] "rise_to" $clock_rise_arrival $clock_fall_arrival $type
  report_reg_to_output_path [get_clocks *] [get_ports p_sdo_sclk_o[${channel_number}]] "fall_to" $clock_rise_arrival $clock_fall_arrival $type
  print_divider
  foreach_in_collection output_data_ports [get_ports p_sdo_${channel_name}_data_o*] {
    report_reg_to_output_path [get_clocks *] $output_data_ports "rise_to" $clock_rise_arrival $clock_fall_arrival $type
    report_reg_to_output_path [get_clocks *] $output_data_ports "fall_to" $clock_rise_arrival $clock_fall_arrival $type
  }
  report_reg_to_output_path [get_clocks *] [get_ports p_sdo_ncmd_o[${channel_number}]] "rise_to" $clock_rise_arrival $clock_fall_arrival $type
  report_reg_to_output_path [get_clocks *] [get_ports p_sdo_ncmd_o[${channel_number}]] "fall_to" $clock_rise_arrival $clock_fall_arrival $type
}

proc report_cdc_paths {type} {
  print_divider
  foreach_in_collection cdc_clk [get_clocks *_cdc] {
    foreach_in_collection path [get_timing_paths -from [get_clocks $cdc_clk] -to [remove_from_collection [get_clocks *_cdc] $cdc_clk] -delay_type $type] {
      set startreg [get_cells -of_objects [get_attribute $path startpoint]]
      set endreg [get_cells -of_objects [get_attribute $path endpoint]]
      set arrival [get_attribute $path arrival]
      echo [format "  From: %-100s %s" [get_attribute $startreg full_name] [get_attribute [get_attribute $path startpoint_clock] full_name]]
      echo [format "  To:   %-100s %s" [get_attribute $endreg full_name] [get_attribute [get_attribute $path endpoint_clock] full_name]]
      echo "  Arrival:   $arrival"
      print_divider
    }
  }
}

proc custom_report {} {
  foreach type [list max min] {
    echo ""
    echo "CDC Paths"
    echo "Path Type: $type"
    echo ""
    report_cdc_paths $type
  }

  echo ""

  foreach channel [list A B C D] {
    echo ""
    foreach type [list max min] {
      echo ""
      echo "Output Channel: $channel"
      echo "Path Type: $type"
      echo ""
      report_output_channel $channel $type
    }
  }
}
