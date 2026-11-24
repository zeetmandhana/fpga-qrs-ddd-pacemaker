# Characterise each operator: OOC synth + place + route on xc7z010clg400-1, 10 ns clock.
set here [file dirname [file normalize [info script]]]
set part xc7z010clg400-1
set ops {op_lutram64}
set fh [open $here/oplib_lutram.txt w]
puts $fh [format "%-16s %5s %6s %4s %4s %4s %9s %9s %9s %7s" op LUT LUTRAM FF DSP CARRY datapath_ns logic_ns route_ns levels]
foreach op $ops {
    read_verilog $here/ops.v
    synth_design -top $op -part $part -mode out_of_context
    create_clock -period 10.0 -name clk [get_ports clk]
    opt_design; place_design; route_design
    set u [report_utilization -return_string]
    regexp {Slice LUTs\*?\s*\|\s*(\d+)} $u -> lut
    set lutram 0; regexp {LUT as Memory\s*\|\s*(\d+)} $u -> lutram
    regexp {Slice Registers\s*\|\s*(\d+)} $u -> ff
    set dsp 0; regexp {DSPs\s*\|\s*(\d+)} $u -> dsp
    set carry [llength [get_cells -hier -filter {REF_NAME == CARRY4}]]
    # worst register-to-register path inside the operator
    set p [get_timing_paths -max_paths 1 -setup -from [all_registers] -to [all_registers]]
    set dp  [get_property DATAPATH_DELAY $p]
    set ld  [get_property DATAPATH_LOGIC_DELAY $p]
    set rd  [get_property DATAPATH_NET_DELAY $p]
    set lv  [get_property LOGIC_LEVELS $p]
    puts $fh [format "%-16s %5s %6s %4s %4s %4s %9.3f %9.3f %9.3f %7s" $op $lut $lutram $ff $dsp $carry $dp $ld $rd $lv]
    report_timing -from [all_registers] -to [all_registers] -max_paths 1 -file $here/timing_$op.rpt
    close_design
}
close $fh
puts "OPLIB_DONE"
