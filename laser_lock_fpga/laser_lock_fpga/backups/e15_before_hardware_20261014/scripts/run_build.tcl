set root [file normalize [file join [file dirname [info script]] ..]]
set mode [lindex $argv 0]
open_project [file join $root laser_lock_fpga.xpr]
set_param general.maxThreads 4
if {$mode ne "finish"} {
foreach rtl_file [glob [file join $root rtl *.v]] {
    if {[llength [get_files -quiet $rtl_file]] == 0} { add_files -norecurse [list $rtl_file] }
}
set_property top laser_lock_board_top [get_filesets sources_1]
set_property generic {ENABLE_ILA=1} [get_filesets sources_1]
if {![string match "*Complete*" [get_property STATUS [get_runs synth_1]]] ||
    [get_property NEEDS_REFRESH [get_runs synth_1]]} {
    reset_run synth_1
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
}
if {![string match "*Complete*" [get_property STATUS [get_runs synth_1]]]} { error "Synthesis failed" }
open_run synth_1
file mkdir [file join $root reports]
report_utilization -file [file join $root reports synthesis_utilization.rpt]
close_design
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
    launch_runs impl_1 -to_step route_design -scripts_only
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
    launch_runs impl_1 -to_step route_design -jobs 4
}
}
wait_on_run impl_1
if {![string match "*Complete*" [get_property STATUS [get_runs impl_1]]]} { error "Implementation failed" }
open_run impl_1
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $root reports timing_summary.rpt]
report_bus_skew -warn_on_violation -file [file join $root reports bus_skew.rpt]
report_utilization -file [file join $root reports implementation_utilization.rpt]
report_drc -file [file join $root reports drc.rpt]
report_route_status -file [file join $root reports route_status.rpt]
write_debug_probes -force [file join $root reports laser_lock_fpga.ltx]
set setup_paths [get_timing_paths -delay_type max -max_paths 1]
set hold_paths [get_timing_paths -delay_type min -max_paths 1]
if {[llength $setup_paths] == 0 || [llength $hold_paths] == 0} { error "No timing paths found" }
set setup_slack [get_property SLACK $setup_paths]
set hold_slack [get_property SLACK $hold_paths]
set f [open [file join $root reports build_summary.txt] w]
puts $f "Vivado: [version -short]\nPart: [get_property PART [current_project]]"
puts $f "Synthesis: [get_property STATUS [get_runs synth_1]]"
puts $f "Implementation: [get_property STATUS [get_runs impl_1]]"
puts $f "Worst setup slack (ns): $setup_slack\nWorst hold slack (ns): $hold_slack"
puts $f "ILA: enabled, 6 probes, 1024 samples."
puts $f "Project top: laser_lock_board_top. Debug buses are internal."
puts $f "E15 internal servo: signed lock calibration, optical slope polarity, 100 kHz default scheduler, scaled actuator anti-windup."
puts $f "Pins/voltages: placeholders. No bitstream generated. UCIO-1/NSTD-1 not waived."
close $f
if {$setup_slack < 0 || $hold_slack < 0} { error "Timing is not met; see reports/timing_summary.rpt" }
puts "BUILD PASS: synthesis and route, setup/hold timing met."
close_project
