# State-encoding study, OOC synth + place + route on xc7z010clg400-1.
#   vivado -mode batch -source run_enc.tcl -tclargs qd|ctrl
# qd   : whole rtl/qrs_decision.v (8-phase FSM + datapath), clock 10 ns
# ctrl : the isolated 8-phase controller qd_ctrl.v,          clock 2.5 ns
set which [lindex $argv 0]
set here [file dirname [file normalize [info script]]]
set part xc7z010clg400-1
set out [open "$here/enc_results_$which.txt" w]
puts $out "variant|fsm_extraction|LUT|FF|WNS_ns|period_ns|Fmax_MHz"

if {$which eq "qd"} {
    set period 10.0
    set variants {
        {as_written   off        qrs_decision        qrs_decision.v        {}}
        {auto         auto       qrs_decision        qrs_decision.v        {}}
        {sequential   sequential qrs_decision        qrs_decision.v        {}}
        {gray         gray       qrs_decision        qrs_decision.v        {}}
        {johnson      johnson    qrs_decision        qrs_decision.v        {}}
        {one_hot      one_hot    qrs_decision        qrs_decision.v        {}}
        {custom_min   off        qrs_decision_custom qrs_decision_custom.v {}}
    }
} else {
    set period 2.5
    set cust {C_IDL=3'b000 C_TRK=3'b001 C_CLS=3'b010 C_REG=3'b100 C_AVG=3'b011 C_LIM=3'b110 C_SBK=3'b111 C_END=3'b101}
    set variants [list \
        [list as_written off        qd_ctrl qd_ctrl.v {}] \
        [list auto       auto       qd_ctrl qd_ctrl.v {}] \
        [list sequential sequential qd_ctrl qd_ctrl.v {}] \
        [list gray       gray       qd_ctrl qd_ctrl.v {}] \
        [list johnson    johnson    qd_ctrl qd_ctrl.v {}] \
        [list one_hot    one_hot    qd_ctrl qd_ctrl.v {}] \
        [list custom_min off        qd_ctrl qd_ctrl.v $cust] ]
}

foreach v $variants {
    lassign $v name fsm top src gens
    puts "=== VARIANT $which $name (fsm_extraction $fsm) ==="
    read_verilog "$here/$src"
    set gargs {}
    foreach g $gens { lappend gargs -generic $g }
    synth_design -top $top -part $part -mode out_of_context -fsm_extraction $fsm {*}$gargs
    if {$which eq "ctrl"} {
        file mkdir "$here/../sim_ctrl/net"
        write_verilog -force -mode funcsim "$here/../sim_ctrl/net/net_$name.v"
        set sff [get_cells -hier -filter {PRIMITIVE_GROUP == FLOP_LATCH}]
        puts "=== SYNTH_FF $which $name [llength $sff]: [lsort $sff]"
    }
    create_clock -period $period -name clk [get_ports clk]
    opt_design
    place_design
    route_design
    set lut [llength [get_cells -hier -filter {PRIMITIVE_GROUP == LUT}]]
    set ff  [llength [get_cells -hier -filter {PRIMITIVE_GROUP == FLOP_LATCH}]]
    set wns [get_property SLACK [get_timing_paths -setup -max_paths 1 -nworst 1]]
    set fmax [format %.1f [expr {1000.0 / ($period - $wns)}]]
    report_utilization -file "$here/util_${which}_$name.rpt"
    report_timing_summary -file "$here/timing_${which}_$name.rpt"
    puts $out "$name|$fsm|$lut|$ff|$wns|$period|$fmax"
    flush $out
    puts "=== RESULT $which $name LUT=$lut FF=$ff WNS=$wns Fmax=$fmax ==="
    close_design
}
close $out
puts "ENC_DONE $which"
