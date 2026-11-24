# Section 9: B0 / B1 / E on the same device and clock (OOC, post-route)
set root C:/Vivadoproject/P17_QRS_Pacemaker
set H $root/rtl/hls_qrs_stream
set hls [list $H/qrs_stream.v $H/qrs_stream_hpbuf_RAM_2P_LUTRAM_1R1W.v $H/qrs_stream_lpbuf_RAM_2P_LUTRAM_1R1W.v \
              $H/qrs_stream_sqbuf_RAM_2P_LUTRAM_1R1W.v $H/qrs_stream_xbuf_RAM_2P_LUTRAM_1R1W.v $H/qrs_stream_mul_29s_29s_32_2_1.v]
set out $root/report/work/paper/impl
set f [open $out/ooc_summary.txt w]
puts $f "top LUT LUTRAM FF DSP BRAM WNS_ns Fmax_MHz"
foreach {top srcs} [list \
    qrs_base_thr [list $root/report/work/paper/rtl/qrs_baselines.v] \
    qrs_base_mwi [concat $hls [list $root/report/work/paper/rtl/qrs_baselines.v]] \
    qrs_detector [concat $hls [list $root/rtl/qrs_decision.v $root/rtl/qrs_detector.v]]] {
    create_project -in_memory -part xc7z010clg400-1
    read_verilog $srcs
    synth_design -top $top -mode out_of_context -part xc7z010clg400-1
    create_clock -period 10.000 -name clk [get_ports clk]
    opt_design; place_design; route_design
    report_utilization -file $out/${top}_util.rpt
    report_timing_summary -file $out/${top}_timing.rpt
    set lut  [llength [get_cells -hier -filter {PRIMITIVE_GROUP == LUT}]]
    set lutram [llength [get_cells -hier -filter {PRIMITIVE_GROUP == DMEM || PRIMITIVE_TYPE =~ DMEM.*}]]
    set ff   [llength [get_cells -hier -filter {PRIMITIVE_GROUP == FLOP_LATCH}]]
    set dsp  [llength [get_cells -hier -filter {PRIMITIVE_GROUP == ARITHMETIC}]]
    set bram [llength [get_cells -hier -filter {PRIMITIVE_GROUP == BLOCKRAM}]]
    set wns  [get_property SLACK [get_timing_paths -max_paths 1 -setup]]
    set fmax [format %.1f [expr {1000.0 / (10.0 - $wns)}]]
    puts $f "$top $lut $lutram $ff $dsp $bram $wns $fmax"
    flush $f
    close_project
}
close $f
puts "OOC_THREE_DONE"
