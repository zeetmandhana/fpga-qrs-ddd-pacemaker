# Batch: create the P17 project, run its three behavioral simulations as a
# check, and run synthesis so the reports are ready when it is opened in the GUI.
source [file join [file dirname [info script]] create_project.tcl]

foreach simset {sim_1 sim_event_priority sim_vga} {
    puts "=== behavioral simulation: $simset ==="
    launch_simulation -simset $simset -mode behavioral
    close_sim -force
}

launch_runs synth_1 -jobs 4
wait_on_run synth_1
puts "SYNTH_STATUS: [get_property STATUS [get_runs synth_1]]"
close_project
puts "BUILD_PROJECT_DONE"
