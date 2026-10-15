set root [file normalize [file join [file dirname [info script]] ..]]
open_checkpoint [file join $root laser_lock_fpga.runs impl_1 laser_lock_hw_top_physopt.dcp]
report_timing -delay_type max -max_paths 12 -file [file join $root reports hardware_diagnostic_timing.rpt]
foreach path [get_timing_paths -delay_type max -max_paths 8] {
 puts "PATH [get_property SLACK $path] [get_property STARTPOINT_PIN $path] -> [get_property ENDPOINT_PIN $path]"
}
