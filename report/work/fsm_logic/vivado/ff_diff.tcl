# which flip-flops differ between encodings of the whole qrs_decision (synthesis only)
set here [file dirname [file normalize [info script]]]
foreach v {{as_written off qrs_decision qrs_decision.v} {johnson johnson qrs_decision qrs_decision.v} {custom_min off qrs_decision_custom qrs_decision_custom.v}} {
    lassign $v name fsm top src
    read_verilog "$here/$src"
    synth_design -top $top -part xc7z010clg400-1 -mode out_of_context -fsm_extraction $fsm
    set f [open "$here/ff_names_$name.txt" w]
    foreach c [lsort [get_cells -hier -filter {PRIMITIVE_GROUP == FLOP_LATCH}]] { puts $f $c }
    close $f
    close_design
}
puts FFDIFF_DONE
