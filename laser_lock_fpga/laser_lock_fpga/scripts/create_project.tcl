# Run: vivado -mode batch -source scripts/create_project.tcl
set root [file normalize [file join [file dirname [info script]] ..]]
if {[regexp {[^ -~]} $root]} {
    error "Use an ASCII-only project directory. The local Vivado 2024.1 ILA generator fails in non-ASCII paths."
}
set project_file [file join $root laser_lock_fpga.xpr]
if {[file exists $project_file]} {
    error "Project already exists. Open laser_lock_fpga.xpr; this script does not overwrite it."
}
if {![string match "2024.1*" [version -short]]} {
    puts "WARNING: intended Vivado version is 2024.1; running [version -short]"
}
set part xcau15p-ffvb676-2-i
if {[llength [get_parts -quiet $part]] != 1} { error "Target part is not installed: $part" }
create_project laser_lock_fpga $root -part $part -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property target_simulator XSim [current_project]
add_files -norecurse [glob [file join $root rtl *.v]]
set_property top laser_lock_board_top [get_filesets sources_1]
set_property generic {ENABLE_ILA=1} [get_filesets sources_1]
add_files -fileset constrs_1 -norecurse [list [file join $root constr axau15_placeholder.xdc]]
add_files -fileset sim_1 -norecurse [glob [file join $root sim *.v]]
set_property top tb_laser_lock [get_filesets sim_1]
set_property xsim.simulate.runtime {all} [get_filesets sim_1]
set_property xsim.simulate.log_all_signals false [get_filesets sim_1]

# ILA is part of the installed Vivado IP catalog; control datapath is pure RTL.
file mkdir [file join $root ip]
create_ip -name ila -vendor xilinx.com -library ip -module_name laser_lock_ila -dir [file join $root ip]
set_property -dict [list CONFIG.C_NUM_OF_PROBES {6} CONFIG.C_DATA_DEPTH {1024} \
    CONFIG.C_PROBE0_WIDTH {16} CONFIG.C_PROBE1_WIDTH {16} \
    CONFIG.C_PROBE2_WIDTH {48} CONFIG.C_PROBE3_WIDTH {8} \
    CONFIG.C_PROBE4_WIDTH {1} CONFIG.C_PROBE5_WIDTH {1} \
    CONFIG.C_INPUT_PIPE_STAGES {1}] [get_ips laser_lock_ila]
generate_target all [get_ips laser_lock_ila]
export_ip_user_files -of_objects [get_ips laser_lock_ila] -no_script -sync -force -quiet
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "CREATED: $project_file"
close_project
