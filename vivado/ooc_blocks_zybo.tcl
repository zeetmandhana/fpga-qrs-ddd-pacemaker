# P17 -- out-of-context synthesis of each hand-written RTL block on the
# Zybo Z7-10 part (xc7z010clg400-1) at a 100 MHz constraint, for the
# per-block resource table. Writes vivado/zybo_reports/ooc_summary.txt
set root "C:/Vivadoproject/P17_QRS_Pacemaker"
set out  "$root/vivado/zybo_reports"
file mkdir $out
set part xc7z010clg400-1
set blocks {
    {ddd_pacemaker_apb {ddd_pacemaker.v ddd_pacemaker_apb.v}}
    {event_priority    {event_priority.v}}
    {qrs_decision      {qrs_decision.v}}
    {heart_model       {heart_model.v}}
    {xbus_apb_bridge   {xbus_apb_bridge.v}}
}
set fh [open $out/ooc_summary.txt w]
puts $fh [format "%-20s %6s %6s %5s %5s %9s" block LUT FF DSP BRAM WNS@100MHz]
foreach b $blocks {
    set name [lindex $b 0]
    foreach f [lindex $b 1] { read_verilog $root/rtl/$f }
    synth_design -top $name -part $part -mode out_of_context
    set cp [get_ports -quiet {clk PCLK}]
    if {[llength $cp]} {
        create_clock -period 10.0 -name clk $cp
    } else {
        # purely combinational block: constrain input-to-output delay to 10 ns
        set_max_delay 10.0 -from [all_inputs] -to [all_outputs]
    }
    report_utilization -file $out/ooc_${name}_util.rpt
    report_timing_summary -file $out/ooc_${name}_timing.rpt
    set lut  [llength [get_cells -hier -filter {PRIMITIVE_GROUP == LUT}]]
    set ff   [llength [get_cells -hier -filter {PRIMITIVE_GROUP == FLOP_LATCH}]]
    set dsp  [llength [get_cells -hier -filter {PRIMITIVE_GROUP == ARITHMETIC && REF_NAME =~ DSP*}]]
    set bram [llength [get_cells -hier -filter {PRIMITIVE_GROUP == BLOCKRAM}]]
    set paths [get_timing_paths -quiet -max_paths 1]
    set wns [expr {[llength $paths] ? [get_property SLACK $paths] : "n/a"}]
    puts $fh [format "%-20s %6d %6d %5d %5d %9s" $name $lut $ff $dsp $bram $wns]
    close_design
}
close $fh
puts "OOC_DONE"
