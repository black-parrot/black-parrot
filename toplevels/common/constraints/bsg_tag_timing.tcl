#-------------------------------------------------------------------------------
# bsg_tag timing constraints
#
#-------------------------------------------------------------------------------

#
# "bsg_tag" (aka bsg tag)
#
# bsg_tag connects to the two oscillators, and two ds's
#
# note: if the bsg_tag clock is 10 ns, then 5 percent uncertainty is 0.5 ns, which
# is a lot of uncertainty and will result in many extraneous gates being added to satisfy
# hold times, and this creates havoc on CDCs etc.
#

proc bsg_tag_clock_create { bsg_tag_clk_name bsg_tag_port bsg_tag_data bsg_tag_attach bsg_tag_period uncertainty_percent } {
    # this is the scan chain
    create_clock -period $bsg_tag_period -name $bsg_tag_clk_name $bsg_tag_port
    set_clock_uncertainty  [expr ($uncertainty_percent * $bsg_tag_period)    / 100.0] [get_clocks $bsg_tag_clk_name]

    # we set the input delay of these pins to be half the bsg_tag clock period; we launch on the negative edge and clock and
    # data travel in parallel, so should be about right

    set_input_delay [expr $bsg_tag_period  / 2.0] -clock $bsg_tag_clk_name $bsg_tag_data

    # this signal is relative to the bsg_tag_clk, but is used in the bsg_tag_client in a CDC kind of way
    set_input_delay [expr $bsg_tag_period  / 2.0] -clock $bsg_tag_clk_name $bsg_tag_attach
}

#
# invoked by clients of bsg_tag to set up CDC
#

proc bsg_tag_add_client_cdc_timing_constraints { bsg_tag_clk_name other_clk_name } {

    # declare BSG_TAG and the other domain asynchronous to each other
    set_clock_groups -asynchronous -group $bsg_tag_clk_name -group $other_clk_name

    # CDC crossing assertions
    #

    set suffix "_cdc"

    set bsg_tag_clk_name_cdc $bsg_tag_clk_name$suffix
    set other_clk_name_cdc $other_clk_name$suffix

    set bsg_tag_period  [get_attribute [get_clocks $bsg_tag_clk_name] period]
    set other_period [get_attribute [get_clocks $other_clk_name] period]

    # CDC delay corresponds to skew between bits in the sender. we need to make sure
    # that the skew is not greater than the cycle time; but an easier way to ensure
    # this is to just ensure that it takes less than one sender clock cycle
    # conservatively, we set it to one half of the sender cycle time
    set bsg_tag_cdc_delay [expr $bsg_tag_period / 2.0]

    # create bsg_tag cdc clock if it is not already created
    if {[sizeof_collection [get_clocks $bsg_tag_clk_name_cdc]]==0} {
        echo "BSG: Ignore above warning about not finding clock."
        create_clock -name $bsg_tag_clk_name_cdc \
            -period $bsg_tag_period \
            -add  [get_attribute $bsg_tag_clk_name sources]
    }

    create_clock -name $other_clk_name_cdc \
        -period $other_period \
        -add  [get_attribute  $other_clk_name sources]

    remove_propagated_clock $bsg_tag_clk_name_cdc
    remove_propagated_clock $other_clk_name_cdc

    set_false_path -from $bsg_tag_clk_name_cdc  -to $bsg_tag_clk_name_cdc
    set_false_path -from $other_clk_name_cdc -to $other_clk_name_cdc

    # make cdc clocks physically exclusive from all others
    set_clock_groups -physically_exclusive \
        -group [remove_from_collection [get_clocks *] [list $bsg_tag_clk_name_cdc $other_clk_name_cdc ]]\
        -group [list $bsg_tag_clk_name_cdc $other_clk_name_cdc ]

    # ensure bounded skew between bits that cross over the CDC.

    set_max_delay $bsg_tag_cdc_delay  -from $bsg_tag_clk_name_cdc -to $other_clk_name_cdc
    set_max_delay $bsg_tag_cdc_delay  -from $other_clk_name_cdc -to $bsg_tag_clk_name_cdc

    set_min_delay 0 -from $bsg_tag_clk_name_cdc -to $other_clk_name_cdc
    set_min_delay 0 -from $other_clk_name_cdc   -to $bsg_tag_clk_name_cdc
}


