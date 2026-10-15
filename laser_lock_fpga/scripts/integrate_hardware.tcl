# Modify the existing XPR only. The servo RTL and old placeholder are retained.
set root [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $root laser_lock_fpga.xpr]
foreach path [glob [file join $root rtl *.v]] {
    if {[llength [get_files -quiet $path]]==0} { add_files -norecurse [list $path] }
}
foreach path [glob [file join $root sim *.v]] {
    if {[llength [get_files -quiet $path]]==0} { add_files -fileset sim_1 -norecurse [list $path] }
}
set old_xdc [get_files -quiet [file join $root constr axau15_placeholder.xdc]]
if {[llength $old_xdc]} { set_property IS_ENABLED false $old_xdc }
foreach relative {constr/axau15_fl4322_pins.xdc constr/hardware_timing.tcl} {
    set path [file join $root $relative]
    if {[llength [get_files -quiet $path]]==0} { add_files -fileset constrs_1 -norecurse [list $path] }
}
set timing_file [get_files [file join $root constr hardware_timing.tcl]]
set_property FILE_TYPE Tcl $timing_file
set_property USED_IN_SYNTHESIS false $timing_file
set_property USED_IN_IMPLEMENTATION true $timing_file
set_property PROCESSING_ORDER LATE $timing_file
if {[llength [get_ips -quiet laser_lock_hw_vio]]==0} {
    create_ip -name vio -vendor xilinx.com -library ip -module_name laser_lock_hw_vio -dir [file join $root ip]
    set_property -dict [list CONFIG.C_NUM_PROBE_IN {7} CONFIG.C_NUM_PROBE_OUT {4} \
        CONFIG.C_PROBE_IN0_WIDTH {32} CONFIG.C_PROBE_IN1_WIDTH {8} CONFIG.C_PROBE_IN2_WIDTH {8} \
        CONFIG.C_PROBE_IN3_WIDTH {14} CONFIG.C_PROBE_IN4_WIDTH {16} CONFIG.C_PROBE_IN5_WIDTH {4} \
        CONFIG.C_PROBE_IN6_WIDTH {32} CONFIG.C_PROBE_OUT0_WIDTH {1} CONFIG.C_PROBE_OUT1_WIDTH {8} \
        CONFIG.C_PROBE_OUT2_WIDTH {32} CONFIG.C_PROBE_OUT3_WIDTH {2}] [get_ips laser_lock_hw_vio]
    generate_target all [get_ips laser_lock_hw_vio]
    export_ip_user_files -of_objects [get_ips laser_lock_hw_vio] -no_script -sync -force -quiet
}
set_property top laser_lock_hw_top [get_filesets sources_1]
set_property generic {ENABLE_ILA=1 ENABLE_VIO=1} [get_filesets sources_1]
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
set_property INCREMENTAL_CHECKPOINT {} [get_runs synth_1]
set_property top tb_laser_lock [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
reset_run synth_1
launch_runs synth_1 -jobs 4
puts "Existing XPR now targets AXAU15 FL4322 physical wrapper; synthesis launched."
close_project
