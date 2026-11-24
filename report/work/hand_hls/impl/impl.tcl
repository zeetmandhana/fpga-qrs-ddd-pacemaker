# OOC synth + place + route of the two hand-written FSMDs, xc7z010clg400-1, 10 ns clock.
# Inputs/outputs get 0 ns delays so the port paths are timed as register paths.
set here [file dirname [file normalize [info script]]]
set part xc7z010clg400-1
set fh [open $here/impl_results.txt w]
puts $fh [format "%-15s %6s %7s %7s %5s %4s %5s %8s %8s %9s" top LUT LUTlog LUTmem FF DSP BRAM WNS_ns TNS_ns Fmax_MHz]
foreach top {qrs_fsmd_area qrs_fsmd_lat} {
    read_verilog $here/../rtl/$top.v
    synth_design -top $top -part $part -mode out_of_context
    create_clock -period 10.0 -name clk [get_ports clk]
    set_input_delay  0 -clock clk [get_ports -filter {DIRECTION == IN && NAME != clk}]
    set_output_delay 0 -clock clk [all_outputs]
    opt_design; place_design; route_design
    set u [report_utilization -return_string]
    regexp {Slice LUTs\*?\s*\|\s*(\d+)} $u -> lut
    regexp {LUT as Logic\s*\|\s*(\d+)} $u -> lutl
    regexp {LUT as Memory\s*\|\s*(\d+)} $u -> lutm
    regexp {Slice Registers\s*\|\s*(\d+)} $u -> ff
    regexp {DSPs\s*\|\s*(\d+)} $u -> dsp
    regexp {Block RAM Tile\s*\|\s*([0-9.]+)} $u -> bram
    set wns [get_property SLACK [get_timing_paths -max_paths 1 -setup]]
    set tns 0.0
    regexp {TNS\(ns\).*?\n.*?\n\s*([-0-9.]+)\s+([-0-9.]+)} [report_timing_summary -return_string -no_detailed_paths] -> wns_s tns
    set fmax [expr {1000.0 / (10.0 - $wns)}]
    puts $fh [format "%-15s %6s %7s %7s %5s %4s %5s %8.3f %8s %9.1f" $top $lut $lutl $lutm $ff $dsp $bram $wns $tns $fmax]
    report_utilization -file $here/${top}_util.rpt
    report_utilization -hierarchical -file $here/${top}_util_hier.rpt
    report_timing_summary -file $here/${top}_timing.rpt
    report_timing -max_paths 3 -file $here/${top}_paths.rpt
    close_design
}
close $fh
puts "IMPL_DONE"
