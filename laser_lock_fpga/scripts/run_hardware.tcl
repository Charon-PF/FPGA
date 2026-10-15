set root [file normalize [file join [file dirname [info script]] ..]]
set mode [lindex $argv 0]
open_project [file join $root laser_lock_fpga.xpr]
set_param general.maxThreads 4
if {$mode ne "finish"} {
foreach rtl_file [glob [file join $root rtl *.v]] {
    if {[llength [get_files -quiet $rtl_file]] == 0} { add_files -norecurse [list $rtl_file] }
}
set_property top laser_lock_hw_top [get_filesets sources_1]
set_property generic {ENABLE_ILA=1 ENABLE_VIO=1} [get_filesets sources_1]
if {![string match "*Complete*" [get_property STATUS [get_runs synth_1]]] ||
    [get_property NEEDS_REFRESH [get_runs synth_1]]} {
    reset_run synth_1
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
}
if {![string match "*Complete*" [get_property STATUS [get_runs synth_1]]]} { error "Synthesis failed" }
open_run synth_1
file mkdir [file join $root reports]
report_utilization -file [file join $root reports hardware_synthesis_utilization.rpt]
close_design
# Reuse stable physical clock routing; all constraints and timing are rechecked.
# The seed is packaged with this project and has the identical target device.
set route_seed [file join $root hardware reference clock_route_seed.dcp]
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs impl_1]
if {[file exists $route_seed]} {
    set_property INCREMENTAL_CHECKPOINT $route_seed [get_runs impl_1]
} else {
    set_property INCREMENTAL_CHECKPOINT {} [get_runs impl_1]
}
# Fix short-path hold timing after incremental route, including vendor VIO logic.
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED 1 [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE Default [get_runs impl_1]
set_property -dict [list {STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.MORE OPTIONS} {-hold_fix -aggressive_hold_fix}] [get_runs impl_1]
set_property STEPS.OPT_DESIGN.TCL.PRE {} [get_runs impl_1]
reset_run impl_1
if {$::tcl_platform(platform) eq "windows"} {
    # Vivado's nested debug-core project failed in its default deep run path.
    # Use the supported Vivado -tempDir switch in the generated run launcher.
    set temp_root [file join [lindex [file split $root] 0] laser_lock_temp]
    if {[info exists ::env(LASER_LOCK_TEMP)]} { set temp_root $::env(LASER_LOCK_TEMP) }
    file mkdir $temp_root
    set temp_root [file normalize $temp_root]
    if {[regexp {[ "\\]} $temp_root]} { error "LASER_LOCK_TEMP must be an ASCII path without spaces" }
    launch_runs impl_1 -to_step write_bitstream -scripts_only
    set run_dir [get_property DIRECTORY [get_runs impl_1]]
    set launcher [file join $run_dir rundef.js]
    set f [open $launcher r]; set js [read $f]; close $f
    set js [string map [list {-mode batch} "-mode batch -tempDir $temp_root"] $js]
    set f [open $launcher w]; puts -nonewline $f $js; close $f
    puts "Prepared Windows implementation launcher: [file join $run_dir runme.bat]"
    close_project
    if {$mode ne "prepare"} { error "On Windows run run_checks.cmd, or execute runme.bat then this script with -tclargs finish." }
    exit 0
} else {
    launch_runs impl_1 -to_step write_bitstream -jobs 4
}
}
wait_on_run impl_1
if {![string match "*Complete*" [get_property STATUS [get_runs impl_1]]]} { error "Implementation failed" }
open_run impl_1
report_methodology -file [file join $root reports hardware_methodology.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $root reports hardware_timing_summary.rpt]
report_bus_skew -warn_on_violation -file [file join $root reports hardware_bus_skew.rpt]
report_clocks -file [file join $root reports hardware_clocks.rpt]
report_cdc -details -file [file join $root reports hardware_cdc.rpt]
report_utilization -file [file join $root reports hardware_utilization.rpt]
report_drc -file [file join $root reports hardware_drc.rpt]
report_route_status -file [file join $root reports hardware_route_status.rpt]
write_debug_probes -force [file join $root reports hardware_probes.ltx]
set setup_paths [get_timing_paths -delay_type max -max_paths 1]
set hold_paths [get_timing_paths -delay_type min -max_paths 1]
if {[llength $setup_paths] == 0 || [llength $hold_paths] == 0} { error "No timing paths found" }
set setup_slack [get_property SLACK $setup_paths]
set hold_slack [get_property SLACK $hold_paths]
set f [open [file join $root reports hardware_build_summary.txt] w]
puts $f "Vivado: [version -short]\nPart: [get_property PART [current_project]]"
puts $f "Synthesis: [get_property STATUS [get_runs synth_1]]"
puts $f "Implementation: [get_property STATUS [get_runs impl_1]]"
puts $f "Worst setup slack (ns): $setup_slack\nWorst hold slack (ns): $hold_slack"
puts $f "ILA: enabled, 6 probes, 1024 samples."
puts $f "Project top: laser_lock_hw_top. Debug buses are internal."
puts $f "E15 internal servo: signed lock calibration, optical slope polarity, 100 kHz default scheduler, scaled actuator anti-windup."
puts $f "78 AXAU15 physical ports assigned. Bitstream generated. External I/O envelope PROVISIONAL; card level translation and actual board skew pending."
close $f
if {$setup_slack < 0 || $hold_slack < 0} { error "Timing is not met; see reports/hardware_timing_summary.rpt" }
file mkdir [file join $root bitstream]
set bit_path [file join [get_property DIRECTORY [get_runs impl_1]] laser_lock_hw_top.bit]
if {![file exists $bit_path]} { error "Bitstream file missing" }
file copy -force $bit_path [file join $root bitstream laser_lock_hw_top.bit]
file copy -force [file join $root reports hardware_probes.ltx] [file join $root bitstream laser_lock_hw_top.ltx]
puts "HARDWARE BUILD: bitstream generated; constrained timing met under provisional I/O assumptions."
close_project







