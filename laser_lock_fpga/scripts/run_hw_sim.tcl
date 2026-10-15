set root [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $root laser_lock_fpga.xpr]
foreach path [glob [file join $root sim *.v]] {
    if {[llength [get_files -quiet $path]]==0} { add_files -fileset sim_1 -norecurse [list $path] }
}
set_property xsim.simulate.runtime all [get_filesets sim_1]
set_property xsim.simulate.log_all_signals false [get_filesets sim_1]
set sim_dir [file join $root laser_lock_fpga.sim sim_1 behav xsim]
foreach {top result_name} {tb_hw_ad9643 ad9643_result.txt tb_hw_ad9122 hw_ad9122_result.txt tb_hw_startup hw_startup_result.txt tb_hw_clock_health clock_health_result.txt tb_hw_wrapper hw_wrapper_result.txt} {
    set_property top $top [get_filesets sim_1]
    set result [file join $sim_dir $result_name]
    if {[file exists $result]} { file delete $result }
    launch_simulation -simset sim_1 -mode behavioral
    close_sim
    if {![file exists $result]} { error "Hardware simulation missing result: $top" }
    set f [open $result r];set contents [read $f];close $f
    if {![string match "PASS*" $contents]} { error "Hardware simulation failed: $top" }
    set report_name $result_name
    if {$top eq "tb_hw_ad9643"} { set report_name hw_ad9643_result.txt }
    if {$top eq "tb_hw_clock_health"} { set report_name hw_clock_health_result.txt }
    file copy -force $result [file join $root reports $report_name]
    puts "${top}: $contents"
}
set_property top tb_hw_wrapper [get_filesets sim_1]
close_project


