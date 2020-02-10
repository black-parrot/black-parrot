
create_clock -name sys_clk -period 10 [get_ports sys_clk_p]

set_property IOSTANDARD LVCMOS33 [get_ports sys_rst_n]
set_property PULLUP true [get_ports sys_rst_n]
set_property LOC M20 [get_ports sys_rst_n]

set_property LOC IBUFDS_GTE2_X0Y2 [get_cells refclk_ibuf]
set_false_path -from [get_ports sys_rst_n]

set_clock_groups -name async_mig_pcie -asynchronous -group [get_clocks -include_generated_clocks userclk2] -group [get_clocks -include_generated_clocks mmcm_clkout1]
#set_clock_uncertainty -setup 2.0 [get_clocks mmcm_clkout1]

set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]

set_property PACKAGE_PIN M26 [get_ports {led[0]}]
set_property PACKAGE_PIN T24 [get_ports {led[1]}]
set_property PACKAGE_PIN T25 [get_ports {led[2]}]
set_property PACKAGE_PIN R26 [get_ports {led[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]

set_property SLEW SLOW [get_ports {led[3]}]
set_property SLEW SLOW [get_ports {led[2]}]
set_property SLEW SLOW [get_ports {led[1]}]
set_property SLEW SLOW [get_ports {led[0]}]

set_property DRIVE 12 [get_ports {led[3]}]
set_property DRIVE 12 [get_ports {led[2]}]
set_property DRIVE 12 [get_ports {led[1]}]
set_property DRIVE 12 [get_ports {led[0]}]
