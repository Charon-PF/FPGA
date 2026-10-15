# Update the existing project in place; never calls create_project.
set root [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $root laser_lock_fpga.xpr]
foreach path [glob [file join $root rtl *.v]] {
    if {[llength [get_files -quiet $path]]==0} { add_files -norecurse [list $path] }
}
set_property top laser_lock_board_top [get_filesets sources_1]
set_property generic {ENABLE_ILA=1} [get_filesets sources_1]
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
set_property INCREMENTAL_CHECKPOINT {} [get_runs synth_1]
update_compile_order -fileset sources_1
reset_run synth_1
launch_runs synth_1 -jobs 4
puts "Updated existing XPR; synthesis launched."
close_project
