# Register helper files as utilities and check that the delivered project is current.
set root [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $root laser_lock_fpga.xpr]
if {[get_property TOP [get_filesets sources_1]] ne "laser_lock_board_top"} { error "Wrong project top" }
foreach run {synth_1 impl_1} {
    if {![string match "*Complete*" [get_property STATUS [get_runs $run]]]} { error "$run is not complete" }
    if {[get_property NEEDS_REFRESH [get_runs $run]]} { error "$run is out of date" }
}
foreach relative {README.md open_project.cmd run_checks.cmd scripts/create_project.tcl scripts/run_sim.tcl scripts/run_build.tcl scripts/package_project.py} {
    set path [file join $root $relative]
    if {[llength [get_files -quiet $path]] == 0} { add_files -fileset utils_1 -norecurse [list $path] }
}
file mkdir [file join $root laser_lock_fpga.gen sources_1]
puts "DELIVERY VERIFIED: Vivado [version -short], [get_property PART [current_project]], laser_lock_board_top, current synthesis and routed implementation."
close_project
