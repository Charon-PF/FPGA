# Register helper files as utilities and check that the delivered project is current.
set root [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $root laser_lock_fpga.xpr]
foreach path [glob [file join $root sim *.v]] {
    if {[llength [get_files -quiet $path]] == 0} { add_files -fileset sim_1 -norecurse [list $path] }
}
set_property top tb_hw_wrapper [get_filesets sim_1]
set_property xsim.simulate.log_all_signals false [get_filesets sim_1]
set legacy_test [get_files -quiet [file join $root sim tb_laser_lock_top.v]]
if {[llength $legacy_test]} { set_property USED_IN_SIMULATION false $legacy_test }
update_compile_order -fileset sim_1
if {[get_property TOP [get_filesets sources_1]] ne "laser_lock_hw_top"} { error "Wrong hardware project top" }
foreach run {synth_1 impl_1} {
    if {![string match "*Complete*" [get_property STATUS [get_runs $run]]]} { error "$run is not complete" }
    if {[get_property NEEDS_REFRESH [get_runs $run]]} { error "$run is out of date" }
}
foreach relative {README.md hardware/INTEGRATION.md constr/hw_pins.csv open_project.cmd run_checks.cmd scripts/run_sim.tcl scripts/run_hw_sim.tcl scripts/run_hardware.tcl scripts/integrate_hardware.tcl scripts/finalize_project.tcl scripts/package_project.py} {
    set path [file join $root $relative]
    if {[llength [get_files -quiet $path]] == 0} { add_files -fileset utils_1 -norecurse [list $path] }
}
file mkdir [file join $root laser_lock_fpga.gen sources_1]
if {![file exists [file join $root bitstream laser_lock_hw_top.bit]]} { error "Hardware bitstream missing" }
puts "DELIVERY VERIFIED: Vivado [version -short], [get_property PART [current_project]], laser_lock_hw_top, current synthesis and bitstream. External electrical/timing qualification pending."
close_project
