
##
##
##
proc bsg_chip_ucsd_bsg_332_timing_constraint {bsg_reset_port \
                                              bsg_core_clk_name \
                                              bsg_core_clk \
                                              bsg_core_clk_port \
                                              bsg_core_clk_period \
                                              bsg_master_io_clk_name \
                                              bsg_master_io_clk \
                                              bsg_master_io_clk_port \
                                              bsg_master_io_clk_period \
                                              bsg_manycore_clk_name \
                                              bsg_manycore_clk \
                                              bsg_manycore_clk_port \
                                              bsg_manycore_clk_period \
                                              bsg_src_sync_in_clk_period \
                                              bsg_src_sync_out_clk_period \
                                              bsg_input_cell_rise_fall_difference \
                                              bsg_output_cell_rise_fall_difference_A \
                                              bsg_output_cell_rise_fall_difference_B \
                                              bsg_output_cell_rise_fall_difference_C \
                                              bsg_output_cell_rise_fall_difference_D \
                                              } {

  puts "INFO\[BSG\]: begin bsg_chip_ucsd_bsg_332_timing_constraint function in script [info script]\n"

  ## according to design compiler, we need this option to support the -add flag of create_clock
  #
  set_app_var timing_enable_multiple_clocks_per_reg true

  # aka io master frequency
  set out_io_clk_period $bsg_src_sync_out_clk_period

  # because of DDR, the input clocks are half the frequency and the corresponding
  # logic runs at half the frequency but there is nothing to say that we would
  # not run the input clocks a bit faster. so for now at least, we will make sure
  # the logic times at the same clock period
  set in_io_clk_period $bsg_src_sync_in_clk_period

  # tecnically the token clock period should be a fraction, like 1/8 of this
  # period. but resets or bugs could make these signals to glitch faster than
  # that.  so we keep it at IO_IN_CLK_PERIOD fixme: add assertion into verilog to
  # detect this glitching
  set in_token_clk_period [expr $bsg_src_sync_in_clk_period]

  set max_in_io_skew_percent 2.5
  set max_in_io_skew_time [expr ($max_in_io_skew_percent * $bsg_src_sync_in_clk_period) / 100.0]

  set max_out_io_skew_percent 2.5
  set max_out_io_skew_time [expr ($max_out_io_skew_percent * $bsg_src_sync_out_clk_period) / 100.0]

  # say that reset gets 50% of the clock cycle to propagate inside the chip.
  set max_async_reset_percent 50
  set max_async_reset_delay [expr ((100-$max_async_reset_percent) * $bsg_core_clk_period) / 100.0]

  # clock uncertainty
  set clock_uncertainty_percent 5
  set core_clk_uncertainty      [expr ($clock_uncertainty_percent * $bsg_core_clk_period) / 100.0]
  set out_io_clk_uncertainty    [expr ($clock_uncertainty_percent * $bsg_src_sync_out_clk_period) / 100.0]
  set in_io_clk_uncertainty     [expr ($clock_uncertainty_percent * $bsg_src_sync_in_clk_period) / 100.0]
  set master_io_clk_uncertainty [expr ($clock_uncertainty_percent * $bsg_master_io_clk_period) / 100.0]
  set manycore_clk_uncertainty  [expr ($clock_uncertainty_percent * $bsg_manycore_clk_period) / 100.0]
  set token_clk_uncertainty     [expr ($clock_uncertainty_percent * $in_token_clk_period) / 100.0]

  # input channel clock
  set sdi_A_sclk_port [get_ports p_sdi_sclk_i[0]]
  set sdi_B_sclk_port [get_ports p_sdi_sclk_i[1]]
  set sdi_C_sclk_port [get_ports p_sdi_sclk_i[2]]
  set sdi_D_sclk_port [get_ports p_sdi_sclk_i[3]]

  # output channel clock
  set sdo_A_sclk_port [get_ports p_sdo_sclk_o[0]]
  set sdo_B_sclk_port [get_ports p_sdo_sclk_o[1]]
  set sdo_C_sclk_port [get_ports p_sdo_sclk_o[2]]
  set sdo_D_sclk_port [get_ports p_sdo_sclk_o[3]]

  # input token
  set sdo_A_token_clk_port [get_ports p_sdo_token_i[0]]
  set sdo_B_token_clk_port [get_ports p_sdo_token_i[1]]
  set sdo_C_token_clk_port [get_ports p_sdo_token_i[2]]
  set sdo_D_token_clk_port [get_ports p_sdo_token_i[3]]

  # print parameters
  puts "\nConstrain design [get_attribute [current_design] full_name] timing with the following settings:\n"
  puts "Parameter                             Value"
  puts "-----------------------               -------------------"
  puts "Core main clock period                $bsg_core_clk_period ns"
  puts "Out IO clock period                   $bsg_src_sync_out_clk_period ns"
  puts "In IO clock period                    $bsg_src_sync_in_clk_period ns"
  puts "Max allowed on-chip in  IO skew (%)   $max_in_io_skew_percent %"
  puts "Max allowed on-chip in  IO skew       $max_in_io_skew_time ns"
  puts "Max allowed on-chip out IO skew (%)   $max_out_io_skew_percent %"
  puts "Max allowed on-chip out IO skew       $max_out_io_skew_time ns"
  puts "Core main clock uncertainty           $core_clk_uncertainty ns"
  puts "Out IO clock uncertainty              $out_io_clk_uncertainty ns"
  puts "In  IO clock uncertainty              $in_io_clk_uncertainty ns"
  puts "Manycore main clock period            $bsg_manycore_clk_period ns"
  puts "manycore main clock uncertainty       $manycore_clk_uncertainty ns"
  puts "-----------------------               -------------------\n"


  ## sdi_A_sclk
  create_clock -period $bsg_src_sync_in_clk_period -name sdi_A_sclk $sdi_A_sclk_port
  set_clock_uncertainty $in_io_clk_uncertainty [get_clocks sdi_A_sclk]
  set_propagated_clock [get_clocks sdi_A_sclk]

  ## sdi_B_sclk
  create_clock -period $bsg_src_sync_in_clk_period -name sdi_B_sclk $sdi_B_sclk_port
  set_clock_uncertainty $in_io_clk_uncertainty [get_clocks sdi_B_sclk]
  set_propagated_clock [get_clocks sdi_B_sclk]

  ## sdi_C_sclk
  create_clock -period $bsg_src_sync_in_clk_period -name sdi_C_sclk $sdi_C_sclk_port
  set_clock_uncertainty $in_io_clk_uncertainty [get_clocks sdi_C_sclk]
  set_propagated_clock [get_clocks sdi_C_sclk]

  ## sdi_D_sclk
  create_clock -period $bsg_src_sync_in_clk_period -name sdi_D_sclk $sdi_D_sclk_port
  set_clock_uncertainty $in_io_clk_uncertainty [get_clocks sdi_D_sclk]
  set_propagated_clock [get_clocks sdi_D_sclk]

  ## sdo_A_token_clk
  create_clock -period $in_token_clk_period -name sdo_A_token_clk $sdo_A_token_clk_port
  set_clock_uncertainty $token_clk_uncertainty [get_clocks sdo_A_token_clk]

  ## sdo_B_token_clk
  create_clock -period $in_token_clk_period -name sdo_B_token_clk $sdo_B_token_clk_port
  set_clock_uncertainty $token_clk_uncertainty [get_clocks sdo_B_token_clk]

  ## sdo_C_token_clk
  create_clock -period $in_token_clk_period -name sdo_C_token_clk $sdo_C_token_clk_port
  set_clock_uncertainty $token_clk_uncertainty [get_clocks sdo_C_token_clk]

  ## sdo_D_token_clk
  create_clock -period $in_token_clk_period -name sdo_D_token_clk $sdo_D_token_clk_port
  set_clock_uncertainty $token_clk_uncertainty [get_clocks sdo_D_token_clk]

  # we declare these clocks as being asynchronous
  # note this disables all timing checks between groups
  # so you really need to be sure this is what you want!
  set_clock_groups -asynchronous  \
    -group $bsg_core_clk_name \
    -group $bsg_master_io_clk_name \
    -group $bsg_manycore_clk_name \
    -group {sdi_A_sclk} \
    -group {sdi_B_sclk} \
    -group {sdi_C_sclk} \
    -group {sdi_D_sclk} \
    -group {sdo_A_token_clk} \
    -group {sdo_B_token_clk} \
    -group {sdo_C_token_clk} \
    -group {sdo_D_token_clk}


  #----------------------------------------------------------------------------
  # CDC checks
  #
  # we follow the advice www.zimmerdesignservices.com/no_mans_land_20130328.pdf
  #
  # oddly, for this to work, we need to clone all of the clocks involved.
  #
  # we tried instead of doing this, just adding a max_delay path between paths
  # but it causes a lot of warnings to be issued. this approach nicely groups
  # these paths together.
  #
  # we set the cdc delay to be the minimimum of the clock periods involved, to
  # be conservative. Alternatively, we could try to hunt down all of the paths
  # and explicitly label all of them but that adds a greater risk of error.
  # none of these paths should be particularly critical.
  #
  # we care about:
  #   1. the sending clock domain for gray code bit skew and
  #   2. the receiving clock domain for delay through 2-port rams.
  #
  # we care less about:
  #   1. path from reset signal in master_io_clk domain wired to token_reset
  #      going into token ctr, since this signal is supposed to be asserted
  #      for many cycles before and after the strobe of the token clock.
  #      nonetheless, we restrict the timing of this path.
  #
  # namespace: we have added BSG_CHIP as a prefix to _cdc to prevent
  # accidental conflicts between scripts
  #----------------------------------------------------------------------------

  set all_clk_period  [list $bsg_core_clk_period \
                            $bsg_master_io_clk_period \
                            $bsg_manycore_clk_period \
                            $bsg_src_sync_in_clk_period \
                            $in_token_clk_period]
  set cdc_delay [lindex [lsort -real $all_clk_period] 0]

  puts "INFO\[BSG\]: Constraining clock crossing paths to $cdc_delay (ns)."

  ## core_clk_BSG_CHIP_cdc
  create_clock -name core_clk_BSG_CHIP_cdc \
               -period $bsg_core_clk_period \
               -add $bsg_core_clk_port

  ## master_io_clk_BSG_CHIP_cdc
  create_clock -name master_io_clk_BSG_CHIP_cdc \
               -period $bsg_master_io_clk_period \
               -add $bsg_master_io_clk_port

  ## manycore_clk_BSG_CHIP_cdc
  create_clock -name manycore_clk_BSG_CHIP_cdc \
               -period $bsg_manycore_clk_period \
               -add $bsg_manycore_clk_port

  ## sdi_A_sclk_BSG_CHIP_cdc
  create_clock -name sdi_A_sclk_BSG_CHIP_cdc \
               -period [get_attribute [get_clocks sdi_A_sclk] period] \
               -add $sdi_A_sclk_port

  ## sdi_B_sclk_BSG_CHIP_cdc
  create_clock -name sdi_B_sclk_BSG_CHIP_cdc \
               -period [get_attribute [get_clocks sdi_B_sclk] period] \
               -add $sdi_B_sclk_port

  ## sdi_C_sclk_BSG_CHIP_cdc
  create_clock -name sdi_C_sclk_BSG_CHIP_cdc \
               -period [get_attribute [get_clocks sdi_C_sclk] period] \
               -add $sdi_C_sclk_port

  ## sdi_D_sclk_BSG_CHIP_cdc
  create_clock -name sdi_D_sclk_BSG_CHIP_cdc \
               -period [get_attribute [get_clocks sdi_D_sclk] period] \
               -add $sdi_D_sclk_port

  ## sdo_A_token_clk_BSG_CHIP_cdc
  create_clock -name sdo_A_token_clk_BSG_CHIP_cdc \
               -period [get_attribute [get_clocks sdo_A_token_clk] period] \
               -add $sdo_A_token_clk_port

  ## sdo_B_token_clk_BSG_CHIP_cdc
  create_clock -name sdo_B_token_clk_BSG_CHIP_cdc \
               -period [get_attribute [get_clocks sdo_B_token_clk] period] \
               -add $sdo_B_token_clk_port

  ## sdo_C_token_clk_BSG_CHIP_cdc
  create_clock -name sdo_C_token_clk_BSG_CHIP_cdc \
               -period [get_attribute [get_clocks sdo_C_token_clk] period] \
               -add $sdo_C_token_clk_port

  ## sdo_D_token_clk_BSG_CHIP_cdc
  create_clock -name sdo_D_token_clk_BSG_CHIP_cdc \
               -period [get_attribute [get_clocks sdo_D_token_clk] period] \
               -add $sdo_D_token_clk_port

  # these are redundant, I guess
  remove_propagated_clock [get_clocks *_BSG_CHIP_cdc]

  # remove all internal paths from concern; these should already be timed
  foreach_in_collection cdc_clk [get_clocks *_BSG_CHIP_cdc] {
    set_false_path -from [get_clock $cdc_clk] -to [get_clock $cdc_clk]
  }

  # make cdc clocks physically exclusive from all others
  set_clock_groups -physically_exclusive \
                   -group [remove_from_collection [get_clocks *] [get_clocks *_BSG_CHIP_cdc]] \
                   -group [get_clocks *_BSG_CHIP_cdc]

  # impose a delay of one cycle delay for paths from sdi clocks to core
  foreach_in_collection cdc_clk [get_clocks *_BSG_CHIP_cdc] {
    set_max_delay $cdc_delay -from $cdc_clk -to [remove_from_collection [get_clocks *_BSG_CHIP_cdc] $cdc_clk]
    set_min_delay 0          -from $cdc_clk -to [remove_from_collection [get_clocks *_BSG_CHIP_cdc] $cdc_clk]
  }

  puts "INFO\[BSG\]: Library setup information:"
  list_libs

  # get channel ports
  set sdi_A_input_ports [add_to_collection [get_ports "p_sdi_A_data_i*"] [get_ports "p_sdi_ncmd_i*[0]"]]
  set sdi_B_input_ports [add_to_collection [get_ports "p_sdi_B_data_i*"] [get_ports "p_sdi_ncmd_i*[1]"]]
  set sdi_C_input_ports [add_to_collection [get_ports "p_sdi_C_data_i*"] [get_ports "p_sdi_ncmd_i*[2]"]]
  set sdi_D_input_ports [add_to_collection [get_ports "p_sdi_D_data_i*"] [get_ports "p_sdi_ncmd_i*[3]"]]

  set sdo_A_output_ports [add_to_collection [get_ports "p_sdo_A_data_o*"] [get_ports "p_sdo_ncmd_o[0]"]]
  set sdo_B_output_ports [add_to_collection [get_ports "p_sdo_B_data_o*"] [get_ports "p_sdo_ncmd_o[1]"]]
  set sdo_C_output_ports [add_to_collection [get_ports "p_sdo_C_data_o*"] [get_ports "p_sdo_ncmd_o[2]"]]
  set sdo_D_output_ports [add_to_collection [get_ports "p_sdo_D_data_o*"] [get_ports "p_sdo_ncmd_o[3]"]]

  # bound the delay on the reset signal to something reasonable
  set_input_delay -clock $bsg_core_clk_name $max_async_reset_delay $bsg_reset_port

  # TODO: token ports need special constraints.

  # sets input delay on pins or input ports relative to a clock signal.
  # note, since our inputs are ddr, we have to define min and max
  # for both edges of the clock.
  #
  # See p. 14 of this document:
  # http://www.zimmerdesignservices.com/working-with-ddrs-in-primetime.pdf

  set min_input_delay [expr [expr $max_in_io_skew_time + $in_io_clk_uncertainty + $bsg_input_cell_rise_fall_difference/2]]
  set max_input_delay [expr ($in_io_clk_period / 2) - $min_input_delay]

  set_input_delay                        -clock sdi_A_sclk -min $min_input_delay $sdi_A_input_ports
  set_input_delay -add_delay             -clock sdi_A_sclk -max $max_input_delay $sdi_A_input_ports
  set_input_delay -add_delay -clock_fall -clock sdi_A_sclk -min $min_input_delay $sdi_A_input_ports
  set_input_delay -add_delay -clock_fall -clock sdi_A_sclk -max $max_input_delay $sdi_A_input_ports

  set_input_delay                        -clock sdi_B_sclk -min $min_input_delay $sdi_B_input_ports
  set_input_delay -add_delay             -clock sdi_B_sclk -max $max_input_delay $sdi_B_input_ports
  set_input_delay -add_delay -clock_fall -clock sdi_B_sclk -min $min_input_delay $sdi_B_input_ports
  set_input_delay -add_delay -clock_fall -clock sdi_B_sclk -max $max_input_delay $sdi_B_input_ports

  set_input_delay                        -clock sdi_C_sclk -min $min_input_delay $sdi_C_input_ports
  set_input_delay -add_delay             -clock sdi_C_sclk -max $max_input_delay $sdi_C_input_ports
  set_input_delay -add_delay -clock_fall -clock sdi_C_sclk -min $min_input_delay $sdi_C_input_ports
  set_input_delay -add_delay -clock_fall -clock sdi_C_sclk -max $max_input_delay $sdi_C_input_ports

  set_input_delay                        -clock sdi_D_sclk -min $min_input_delay $sdi_D_input_ports
  set_input_delay -add_delay             -clock sdi_D_sclk -max $max_input_delay $sdi_D_input_ports
  set_input_delay -add_delay -clock_fall -clock sdi_D_sclk -min $min_input_delay $sdi_D_input_ports
  set_input_delay -add_delay -clock_fall -clock sdi_D_sclk -max $max_input_delay $sdi_D_input_ports

  report_clocks [get_clocks *]

  # set_multicycle_path is used according to the following synopsys document
  # called "Overcoming the Default Behavior of the set_data_check Command"
  # the document ID is 024664

  # this article suggests that the set_data_check command does have a problem
  # in that you cannot remove clock uncertainty unless the tool supports path-based
  # uncertainties which synopsys does not seem to.
  # http://www.analog-eetimes.com/content/modeling-skew-requirements-interfacing-protocol-signals-soc/page/0/4
  # we nullify this problem by also subtracting the uncertainty from the data check.

  foreach_in_collection obj $sdo_A_output_ports {
    set setup [expr (($out_io_clk_period/2) - $max_out_io_skew_time - $master_io_clk_uncertainty - $bsg_output_cell_rise_fall_difference_A/2)]
    set hold  [expr (($out_io_clk_period/2) - $max_out_io_skew_time - $master_io_clk_uncertainty - $bsg_output_cell_rise_fall_difference_A/2)]
    set_data_check -from [get_ports "p_sdo_sclk_o[0]"] -to $obj -setup $setup
    set_data_check -from [get_ports "p_sdo_sclk_o[0]"] -to $obj -hold  $hold
    set_multicycle_path -end   -setup 1 -to $obj
    set_multicycle_path -start -hold  0 -to $obj
  }

  foreach_in_collection obj $sdo_B_output_ports {
    set setup [expr (($out_io_clk_period/2) - $max_out_io_skew_time - $master_io_clk_uncertainty - $bsg_output_cell_rise_fall_difference_B/2)]
    set hold  [expr (($out_io_clk_period/2) - $max_out_io_skew_time - $master_io_clk_uncertainty - $bsg_output_cell_rise_fall_difference_B/2)]
    set_data_check -from [get_ports "p_sdo_sclk_o[1]"] -to $obj -setup $setup
    set_data_check -from [get_ports "p_sdo_sclk_o[1]"] -to $obj -hold  $hold
    set_multicycle_path -end   -setup 1 -to $obj
    set_multicycle_path -start -hold  0 -to $obj
  }

  foreach_in_collection obj $sdo_C_output_ports {
    set setup [expr (($out_io_clk_period/2) - $max_out_io_skew_time - $master_io_clk_uncertainty - $bsg_output_cell_rise_fall_difference_C/2)]
    set hold  [expr (($out_io_clk_period/2) - $max_out_io_skew_time - $master_io_clk_uncertainty - $bsg_output_cell_rise_fall_difference_C/2)]
    set_data_check -from [get_ports "p_sdo_sclk_o[2]"] -to $obj -setup $setup
    set_data_check -from [get_ports "p_sdo_sclk_o[2]"] -to $obj -hold  $hold
    set_multicycle_path -end   -setup 1 -to $obj
    set_multicycle_path -start -hold  0 -to $obj
  }

  foreach_in_collection obj $sdo_D_output_ports {
    set setup [expr (($out_io_clk_period/2) - $max_out_io_skew_time - $master_io_clk_uncertainty - $bsg_output_cell_rise_fall_difference_D/2)]
    set hold  [expr (($out_io_clk_period/2) - $max_out_io_skew_time - $master_io_clk_uncertainty - $bsg_output_cell_rise_fall_difference_D/2)]
    set_data_check -from [get_ports "p_sdo_sclk_o[3]"] -to $obj -setup $setup
    set_data_check -from [get_ports "p_sdo_sclk_o[3]"] -to $obj -hold  $hold
    set_multicycle_path -end   -setup 1 -to $obj
    set_multicycle_path -start -hold  0 -to $obj
  }

  # ouput ports p_sdo_sclk_o and p_sdi_token_o will be reported as unconstrained endpoint
  # if no constraints are set on these ports. these signals are input clocks of downstream
  # devices. we want to set a max_delay on these ports, but it's hard to predict the delay
  # from the driving clocks to the ports before cts. and it will cause violations if the
  # value is set too small. actually we don't care too much about these delays. i think it
  # could be acceptable if these ports are unconstrained

  #set_max_delay $bsg_master_io_clk_period -from [get_clocks $bsg_master_io_clk_name] -to [get_ports p_sdo_sclk_o*]
  #set_min_delay 0 -from [get_clocks $bsg_master_io_clk_name] -to [get_ports p_sdo_sclk_o*]

  #set_max_delay $in_io_clk_period -from [get_clocks sdi_*_sclk] -to [get_ports p_sdi_token_o*]
  #set_min_delay 0 -from [get_clocks sdi_*_sclk] -to [get_ports p_sdi_token_o*]

  # set driving cell and load
  set_driving_cell -lib_cell [get_attribute [get_cells -h sdo_A_sclk_o] ref_name] [all_inputs]
  set_load 15 [all_outputs]

  # create path groups
  #
  # separating these paths can help improve optimization in each group independently.
  #
  # during compile each timing path is placed into a path group associated with
  # that path's "capturing" clock. DC then optimizes each path group in turn,
  # starting with the critical path in each group.
  #
  # Reg_to_reg path groups are automatically created, named the same as their
  # related (end-point) clock object names, by default.

  set ports_clock_root [filter_collection [get_attribute [get_clocks] sources] object_class==port]
  group_path -name input_to_reg -from [remove_from_collection [all_inputs] ${ports_clock_root}]
  group_path -name reg_to_output -to [all_outputs]
  group_path -name feedthrough -from [remove_from_collection [all_inputs] ${ports_clock_root}] -to [all_outputs]

  # it is much easier for the physical design tool to fix a small number of
  # violations through savvy placement, compared to having to handle a large
  # number of violations.

  puts "INFO\[BSG\]: end bsg_chip_ucsd_bsg_332_timing_constraint function in script [info script]\n"

}

##
##
##
proc bsg_chip_timing_constraint {args} {

  parse_proc_arguments -args $args pargs

  set bsg_package                            $pargs(-package)
  set bsg_reset_port                         $pargs(-reset_port)
  set bsg_core_clk_name                      $pargs(-core_clk_name)
  set bsg_core_clk                           $pargs(-core_clk)
  set bsg_core_clk_port                      $pargs(-core_clk_port)
  set bsg_core_clk_period                    $pargs(-core_clk_period)
  set bsg_master_io_clk_name                 $pargs(-master_io_clk_name)
  set bsg_master_io_clk                      $pargs(-master_io_clk)
  set bsg_master_io_clk_port                 $pargs(-master_io_clk_port)
  set bsg_master_io_clk_period               $pargs(-master_io_clk_period)
  set bsg_manycore_clk_name                  $pargs(-manycore_clk_name)
  set bsg_manycore_clk                       $pargs(-manycore_clk)
  set bsg_manycore_clk_port                  $pargs(-manycore_clk_port)
  set bsg_manycore_clk_period                $pargs(-manycore_clk_period)
  set bsg_src_sync_in_clk_period             $pargs(-src_sync_in_clk_period)
  set bsg_src_sync_out_clk_period            $pargs(-src_sync_out_clk_period)
  set bsg_input_cell_rise_fall_difference    $pargs(-input_cell_rise_fall_difference)
  set bsg_output_cell_rise_fall_difference_A $pargs(-output_cell_rise_fall_difference_A)
  set bsg_output_cell_rise_fall_difference_B $pargs(-output_cell_rise_fall_difference_B)
  set bsg_output_cell_rise_fall_difference_C $pargs(-output_cell_rise_fall_difference_C)
  set bsg_output_cell_rise_fall_difference_D $pargs(-output_cell_rise_fall_difference_D)

  if {$bsg_package != "ucsd_bsg_332" || $bsg_core_clk_period <= 0 || $bsg_master_io_clk_period <= 0 || $bsg_manycore_clk_period <= 0} {
    puts "ERROR\[BSG\]: Either you have the wrong package or one clock period is less or equal to zero"
  } else {
    bsg_chip_ucsd_bsg_332_timing_constraint \
      $bsg_reset_port \
      $bsg_core_clk_name \
      $bsg_core_clk \
      $bsg_core_clk_port \
      $bsg_core_clk_period \
      $bsg_master_io_clk_name \
      $bsg_master_io_clk \
      $bsg_master_io_clk_port \
      $bsg_master_io_clk_period \
      $bsg_manycore_clk_name \
      $bsg_manycore_clk \
      $bsg_manycore_clk_port \
      $bsg_manycore_clk_period \
      $bsg_src_sync_in_clk_period \
      $bsg_src_sync_out_clk_period \
      $bsg_input_cell_rise_fall_difference \
      $bsg_output_cell_rise_fall_difference_A \
      $bsg_output_cell_rise_fall_difference_B \
      $bsg_output_cell_rise_fall_difference_C \
      $bsg_output_cell_rise_fall_difference_D
  }

}

##
##
##
define_proc_attributes bsg_chip_timing_constraint \
  -info "bsg_chip timing constraint" \
  -define_args {
    {-package "bsg package used, i.e. ucsd_bsg_332" package string required}
    {-reset_port "reset port, i.e \[get_ports p_reset_i\]" reset_port string required}
    {-core_clk_name "core clock name, i.e core_clk" core_clk_name string required}
    {-core_clk "core clock, i.e \[get_clocks core_clk\] or \[get_generated_clocks core_clk\]" core_clk string required}
    {-core_clk_port "core clock port, i.e \[get_ports p_misc_L_i\[4\]\]" core_clk_port string required}
    {-core_clk_period "core clock period in tech-time-unit, i.e 3.5" core_clk_period float required}
    {-master_io_clk_name "master io clock name, i.e master_io_clk" master_io_clk_name string required}
    {-master_io_clk "master io clock, i.e. \[get_clocks master_io_clk\] or \[get_generated_clocks master_io_clk\]" master_io_clk string required}
    {-master_io_clk_port "master io clock port, i.e. \[get_ports p_PLL_CLK_i\]" master_io_clk_port string required}
    {-master_io_clk_period "master io clock period in tech-time-unit, i.e. 2.35" master_io_clk_period float required}
    {-manycore_clk_name "manycore clock name, i.e manycore_clk" manycore_clk_name string required}
    {-manycore_clk "manycore clock, i.e \[get_clocks manycore_clk\] or \[get_generated_clock manycore_clk\]" manycore_clk string required}
    {-manycore_clk_port "manycore clock port, i.e \[get_ports p_misc_L_i\[5\]\]" manycore_clk_port string required}
    {-manycore_clk_period "core clock period in tech-time-unit, i.e 3.5" manycore_clk_period float required}
    {-src_sync_in_clk_period "source synchronous input clock period in tech-time-unit, i.e 3.5" src_sync_in_clk_period float required}
    {-src_sync_out_clk_period "source synchronous output clock period in tech-time-unit, i.e 3.5" src_sync_out_clk_period float required}
    {-input_cell_rise_fall_difference "difference between rising and falling delay of input cell" input_cell_rise_fall_difference float required}
    {-output_cell_rise_fall_difference_A "difference between rising and falling delay of output cell" output_cell_rise_fall_difference_A float required}
    {-output_cell_rise_fall_difference_B "difference between rising and falling delay of output cell" output_cell_rise_fall_difference_B float required}
    {-output_cell_rise_fall_difference_C "difference between rising and falling delay of output cell" output_cell_rise_fall_difference_C float required}
    {-output_cell_rise_fall_difference_D "difference between rising and falling delay of output cell" output_cell_rise_fall_difference_D float required}
  }

