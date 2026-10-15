set root [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $root laser_lock_fpga.xpr]
foreach rtl_file [glob [file join $root rtl *.v]] {
    if {[llength [get_files -quiet $rtl_file]] == 0} { add_files -norecurse [list $rtl_file] }
}
set_property top tb_laser_lock_top [get_filesets sim_1]
set_property xsim.simulate.runtime {all} [get_filesets sim_1]
set sim_dir [file join $root laser_lock_fpga.sim sim_1 behav xsim]
set result [file join $sim_dir simulation_result.txt]
if {[file exists $result]} { file delete $result }
launch_simulation -simset sim_1 -mode behavioral
close_sim
if {![file exists $result]} { error "Simulation did not produce a PASS result" }
set f [open $result r]
set contents [read $f]
close $f
if {![string match "PASS*" $contents]} { error "Simulation failed: $contents" }
file mkdir [file join $root reports]
file copy -force $result [file join $root reports simulation_result.txt]
file copy -force [file join $sim_dir closed_loop.csv] [file join $root reports closed_loop.csv]
puts $contents
set_property top tb_pi2d_controller [get_filesets sim_1]
set core_result [file join $sim_dir controller_result.txt]
if {[file exists $core_result]} { file delete $core_result }
launch_simulation -simset sim_1 -mode behavioral
close_sim
if {![file exists $core_result]} { error "Controller test did not produce a PASS result" }
set f [open $core_result r]
set contents [read $f]
close $f
if {![string match "PASS*" $contents]} { error "Controller test failed: $contents" }
file copy -force $core_result [file join $root reports controller_result.txt]
puts $contents
set_property top tb_laser_lock_top [get_filesets sim_1]
close_project
