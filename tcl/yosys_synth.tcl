# Based on https://yosyshq.net/yosys/
yosys -import

set techmap_dir $::env(TECHMAP_DIR)
source ${techmap_dir}/config.tcl

set design           wrapper
set lib_file         $::env(LIB_SYNTH)
set in_v_file        $::env(WRAPPER_SV2V)
set verilog_v_file   $::env(WRAPPER_VERILOG)
set elab_v_file      $::env(WRAPPER_ELAB)
set opt_v_file       $::env(WRAPPER_OPT)
set map_v_file       $::env(WRAPPER_MAP)
set synth_v_file     $::env(WRAPPER_SYNTH)
set without_mems     $::env(WITHOUT_MEMS)
set stat_file        stats.json
set check_file       checks.txt

set tiehi_cell       sky130_fd_sc_hd__conb
set tiehi_pin        HI
set tielo_cell       sky130_fd_sc_hd__conb
set tielo_pin        LO
set clkbuf_cell      sky130_fd_sc_hd__clkbuf
set clkbuf_pin       X
set buf_cell         sky130_fd_sc_hd__buf
set buf_ipin         A
set buf_opin         X


# read design
read_verilog $in_v_file

# blackbox memories
if {${without_mems}} {
    blackbox bsg_mem_1rw_sync*
    blackbox bsg_mem_1r1w_sync*
    blackbox bsg_mem_2r1w_sync*
    blackbox bsg_mem_3r1w_sync*
}

# write verilog design
write_verilog -nostr -noattr -noexpr -nohex -nodec ${verilog_v_file}
#write_blif ${verilog_v_file}.blif

# elaborate design hierarchy
hierarchy -check -top ${design}

# write elab design
write_verilog -nostr -noattr -noexpr -nohex -nodec ${elab_v_file}
#write_blif ${elab_v_file}.blif

# the high-level stuff
yosys proc; opt; fsm; opt; yosys memory; opt

# write opt design
write_verilog -nostr -noattr -noexpr -nohex -nodec ${opt_v_file}
write_blif ${opt_v_file}.blif

# mapping to internal cell library
techmap; opt
techmap -map ${techmap_dir}/csa_map.v
techmap -map ${techmap_dir}/fa_map.v
techmap -map ${techmap_dir}/latch_map.v
techmap -map ${techmap_dir}/mux2_map.v
techmap -map ${techmap_dir}/mux4_map.v
techmap -map ${techmap_dir}/rca_map.v
techmap -map ${techmap_dir}/tribuff_map.v

# mapping to cell lib
dfflibmap -liberty ${lib_file}

# write mapped design
write_verilog -nostr -noattr -noexpr -nohex -nodec ${map_v_file}
write_blif ${map_v_file}.blif

# mapping logic to cell lib
abc -liberty ${lib_file}

# Set X to zero
setundef -zero

# mapping constants and clock buffers to cell lib
hilomap -hicell ${tiehi_cell} ${tiehi_pin} -locell ${tielo_cell} ${tielo_pin}
clkbufmap -buf ${clkbuf_cell} ${clkbuf_pin}

# Split nets to single bits and map to buffers
splitnets
insbuf -buf ${buf_cell} ${buf_ipin} ${buf_opin}

# Clean up the design
opt_clean -purge

# Check and print statistics
tee -o ${check_file} check -mapped -noinit
tee -o ${stat_file} stat -top ${design} -liberty ${lib_file} -tech cmos -width -json

# write synthesized design
write_verilog -nostr -noattr -noexpr -nohex -nodec ${synth_v_file}
write_blif ${synth_v_file}.blif

