# P17 -- automated on-board test of the Zybo Z7-10 over JTAG (VIO), no monitor needed.
#   source C:/Vivadoproject/P17_QRS_Pacemaker/vivado/vio_board_test.tcl
# Programs the debug bitstream, forces the switches through the VIO, presses
# virtual buttons to step through the six scenarios, and measures event rates
# from the hardware counters. Results -> results/stage8_board_test.txt
set root "C:/Vivadoproject/P17_QRS_Pacemaker"
set impl "$root/vivado/p17_zybo_bd/p17_zybo_bd.runs/impl_1"
set dev  [get_hw_devices xc7z010_1]
current_hw_device $dev
if {![info exists P17_BIT]} { set P17_BIT "$root/vivado/zybo_reports/p17_soc_vio_test" }
if {![info exists BTN_HOLD]} { set BTN_HOLD 1 }
set_property PROGRAM.FILE "$P17_BIT.bit" $dev
set_property PROBES.FILE  "$P17_BIT.ltx" $dev
set_property FULL_PROBES.FILE "$P17_BIT.ltx" $dev
program_hw_devices $dev
refresh_hw_device $dev
set vio [get_hw_vios -of_objects $dev]
puts "VIO: $vio"
foreach p [get_hw_probes -of_objects $vio] { puts "  probe: [get_property NAME $p] ([get_property TYPE $p])" }

proc probe {pat} {
    global vio
    set p [get_hw_probes -of_objects $vio -filter "NAME =~ *${pat}"]
    if {[llength $p] != 1} { error "probe pattern '$pat' matched: $p" }
    return $p
}
set P_led  [probe board_io_0_led]
set P_mode [probe demo_ctrl_0_mode]
set P_qrs  [probe cnt_qrs]
set P_ap   [probe cnt_ap]
set P_vp   [probe cnt_vp]
set P_as   [probe cnt_as]
set P_vs   [probe cnt_vs]
set P_irq  [probe cnt_irq]
set P_up   [probe uptime_ms]
set P_rr   [probe last_rr]
set P_rgb  [probe gpio_o]
set P_btn  [probe probe_out0]
set P_sw   [probe probe_out1]
set P_swen [probe probe_out2]
foreach p [list $P_qrs $P_ap $P_vp $P_as $P_vs $P_irq $P_up $P_rr $P_mode] {
    set_property INPUT_VALUE_RADIX UNSIGNED $p
}
set_property INPUT_VALUE_RADIX BINARY $P_led
set_property INPUT_VALUE_RADIX BINARY $P_rgb

proc rd {p} { return [get_property INPUT_VALUE $p] }
proc snap {} {
    global vio P_qrs P_ap P_vp P_as P_vs P_irq P_up P_rr P_mode P_led P_rgb
    refresh_hw_vio $vio
    return [list [rd $P_up] [rd $P_qrs] [rd $P_ap] [rd $P_vp] [rd $P_as] [rd $P_vs] [rd $P_irq] \
                 [rd $P_rr] [rd $P_mode] [rd $P_led] [rd $P_rgb]]
}
proc set_sw {bits} {
    global vio P_sw P_swen
    set_property OUTPUT_VALUE [format %X $bits] $P_sw
    set_property OUTPUT_VALUE 1 $P_swen
    commit_hw_vio [list $P_sw $P_swen]
    after 300
}
proc press {n} {
    global vio P_btn
    set_property OUTPUT_VALUE [format %X [expr {$::BTN_HOLD | (1 << $n)}]] $P_btn
    commit_hw_vio $P_btn
    after 600
    set_property OUTPUT_VALUE [format %X $::BTN_HOLD] $P_btn
    commit_hw_vio $P_btn
    after 600
}
proc mode_now {} {
    global vio P_mode
    refresh_hw_vio $vio
    return [get_property INPUT_VALUE $P_mode]
}
# press BTN1 until the scenario register (read back over JTAG) shows `target`
proc goto_mode {target} {
    global report
    for {set i 0} {$i < 10} {incr i} {
        if {[mode_now] == $target} {
            if {$i > 1} { lappend report "  (scenario $target reached after $i BTN1 presses)" }
            return
        }
        press 1
        after 800
    }
    error "could not reach scenario $target (now [mode_now])"
}
set report {}
proc measure {label secs} {
    # repeat a window whose JTAG read-back is implausible (any rate > 300/min)
    for {set try 0} {$try < 3} {incr try} {
        if {[measure_once $label $secs]} { return }
        puts "  (implausible JTAG read-back, repeating $label)"
    }
}
proc measure_once {label secs} {
    global report
    set a [snap]
    after [expr {$secs * 1000}]
    set b [snap]
    set dt [expr {([lindex $b 0] - [lindex $a 0]) / 60000.0}]
    if {$dt <= 0} {
        set line [format "%-34s NO PROGRESS: uptime counter stuck at %s (design held in reset?)" $label [lindex $b 0]]
        puts $line; return 0
    }
    set r {}
    foreach i {1 2 3 4 5} { lappend r [expr {round(([lindex $b $i] - [lindex $a $i]) / $dt)}] }
    foreach v $r { if {$v > 300 || $v < 0} { return 0 } }
    set rr [lindex $b 7]
    set hr [expr {$rr > 0 ? round(21600.0 / $rr) : 0}]
    set line [format "%-34s mode=%s  QRS/min=%3d  AP/min=%3d  VP/min=%3d  AS/min=%3d  VS/min=%3d  IRQ+=%d  HR(RR)=%3d  LED=%s RGB=%s" \
        $label [lindex $b 8] {*}$r [expr {[lindex $b 6] - [lindex $a 6]}] $hr [lindex $b 9] [lindex $b 10]]
    puts $line
    lappend report $line
    return 1
}

# ---------------- test sequence ----------------
# BTN_HOLD = 1 only for the first VIO build, whose reset input was active-LOW
# (block-design polarity bug); the corrected build uses BTN_HOLD = 0.
set_property OUTPUT_VALUE [format %X $BTN_HOLD] $P_btn; commit_hw_vio $P_btn
after 3000                      ;# firmware init + detector learning (2 s)
set_sw 1                        ;# SW0=1 pacing on, SW1=0 guard off
after 2500
if {[info exists P17_SEQ] && $P17_SEQ eq "part2"} {
    goto_mode 2; after 3000
    measure "3/6 sinus brady 40 (LRI 1000)"    15
    press 2; after 2500
    measure "3/6 brady, BTN2 -> LRI 857"       15
    press 2; after 2500
    measure "3/6 brady, BTN2 -> LRI 750"       15
    press 2; after 2500
    measure "3/6 brady, BTN2 -> LRI 1000"      15
    goto_mode 3; after 3000
    measure "4/6 complete AV block"            15
    goto_mode 4; after 3000
    measure "5/6 AV block + brady"             15
    goto_mode 0
    set_property OUTPUT_VALUE 0 $P_swen; commit_hw_vio $P_swen
    set fh [open "$root/results/stage8_board_test_part2.txt" w]
    puts $fh "P17 on Zybo Z7-10 -- on-board test part 2 ([clock format [clock seconds]]), bitstream $P17_BIT.bit"
    foreach l $report { puts $fh $l }
    close $fh
    puts "BOARD TEST PART2 DONE"
    return
}
measure "1/6 MIT-BIH rec 100 replay"       20
goto_mode 1; after 3000
measure "2/6 normal sinus 75 (LRI 1000)"   15
goto_mode 2; after 3000
measure "3/6 sinus brady 40 (LRI 1000)"    15
press 2; after 2500
measure "3/6 brady, BTN2 -> LRI 857"       15
press 2; after 2500
measure "3/6 brady, BTN2 -> LRI 750"       15
press 2; after 2500             ;# rate back to LRI 1000 (60 bpm)
measure "3/6 brady, BTN2 -> LRI 1000"      15
goto_mode 3; after 3000
measure "4/6 complete AV block"            15
goto_mode 4; after 3000
measure "5/6 AV block + brady"             15
goto_mode 5; after 3000
measure "6/6 PMT, PVARP 250, guard OFF"    15
set_sw 3                        ;# SW1=1 -> firmware arrhythmia ISR lengthens PVARP
after 3000
measure "6/6 PMT, guard ON (RV32 ISR)"     15
set_sw 2                        ;# SW0=0 pacing off (guard stays on)
after 2000
measure "6/6 PMT, pacing OFF (SW0=0)"      15
set_sw 1
goto_mode 0                     ;# back to scenario 1
set_property OUTPUT_VALUE 0 $P_swen; commit_hw_vio $P_swen   ;# hand the switches back to the board

set fh [open "$root/results/stage8_board_test.txt" w]
puts $fh "P17 on Zybo Z7-10 -- on-board test over JTAG/VIO ([clock format [clock seconds]]), bitstream $P17_BIT.bit"
puts $fh "rates measured from hardware event counters; HR(RR) from the detector's last R-R interval"
foreach l $report { puts $fh $l }
close $fh
puts "BOARD TEST DONE -> $root/results/stage8_board_test.txt"
