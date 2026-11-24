# list the flip-flops Vivado creates for the isolated controller under each FSM option
set here [file dirname [file normalize [info script]]]
foreach fsm {off sequential one_hot gray johnson} {
    read_verilog "$here/qd_ctrl.v"
    synth_design -top qd_ctrl -part xc7z010clg400-1 -mode out_of_context -fsm_extraction $fsm
    set ffs [get_cells -hier -filter {PRIMITIVE_GROUP == FLOP_LATCH}]
    puts "=== FF $fsm [llength $ffs]: [lsort $ffs]"
    close_design
}
