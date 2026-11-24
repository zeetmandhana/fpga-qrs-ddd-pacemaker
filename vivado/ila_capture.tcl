# P17 -- capture ECG + detected QRS + pace events from the running Zybo with the ILA.
# Needs an open hw target (Hardware Manager connected). Defines procs and, when
# P17_ILA_AUTO is set, programs the board and captures every scenario.
#   ila_prog                      program the ILA bitstream (+ probes file)
#   ila_capture TAG ?TRIGS?       capture 8192 ECG samples (22.7 s), trigger = OR of
#                                 the listed flags (default: qrs ap), write
#                                 results/ila/TAG.csv and TAG.ila, show the waveform
#   goto_mode M                   press virtual BTN1 until the scenario register = M
#   set_sw BITS                   drive the switches from the VIO (SW0 pacing, SW1 PMT guard)
set root "C:/Vivadoproject/P17_QRS_Pacemaker"
if {![info exists P17_ILA_BIT]} { set P17_ILA_BIT "$root/vivado/zybo_reports/p17_soc_ila" }
if {![info exists P17_ILA_OUT]} { set P17_ILA_OUT "$root/results/ila" }   ;# capture output folder
file mkdir $P17_ILA_OUT
set dev [get_hw_devices xc7z010_1]
current_hw_device $dev

proc ila_prog {} {
    global dev P17_ILA_BIT
    set_property PROGRAM.FILE "$P17_ILA_BIT.bit" $dev
    set_property PROBES.FILE "$P17_ILA_BIT.ltx" $dev
    set_property FULL_PROBES.FILE "$P17_ILA_BIT.ltx" $dev
    program_hw_devices $dev
    refresh_hw_device $dev
}
proc vio {} { return [get_hw_vios -of_objects [get_hw_devices xc7z010_1]] }
proc ila {} { return [get_hw_ilas -of_objects [get_hw_devices xc7z010_1]] }
proc vprobe {pat} { return [get_hw_probes -of_objects [vio] -filter "NAME =~ *${pat}"] }
proc iprobe {pat} { return [get_hw_probes -of_objects [ila] -filter "NAME =~ *${pat}"] }

proc set_btn {val} {
    set p [vprobe probe_out0]
    set_property OUTPUT_VALUE [format %X $val] $p
    commit_hw_vio $p
}
proc press {n} { set_btn [expr {1 << $n}]; after 600; set_btn 0; after 600 }
proc set_sw {bits} {
    set_property OUTPUT_VALUE [format %X $bits] [vprobe probe_out1]
    set_property OUTPUT_VALUE 1 [vprobe probe_out2]
    commit_hw_vio [list [vprobe probe_out1] [vprobe probe_out2]]
    after 300
}
proc release_sw {} {
    set_property OUTPUT_VALUE 0 [vprobe probe_out2]; commit_hw_vio [vprobe probe_out2]
}
proc mode_now {} {
    set p [vprobe demo_ctrl_0_mode]
    set_property INPUT_VALUE_RADIX UNSIGNED $p
    refresh_hw_vio [vio]
    return [get_property INPUT_VALUE $p]
}
proc goto_mode {m} {
    for {set i 0} {$i < 10} {incr i} {
        if {[mode_now] == $m} { return }
        press 1; after 800
    }
    error "could not reach scenario $m"
}

proc ila_capture {tag {trig qrs}} {
    # trigger = (rec_stb AND rec_<trig>): the trigger lands exactly on a stored
    # ECG sample (the event flags are held between samples, so triggering on
    # the flag alone gives "multiple trigger marks" with capture control).
    global root P17_ILA_OUT
    set ila [ila]
    set_property CONTROL.DATA_DEPTH 8192 $ila
    set_property CONTROL.TRIGGER_POSITION 1024 $ila
    set_property CONTROL.CAPTURE_MODE BASIC $ila
    set_property CONTROL.TRIGGER_CONDITION AND $ila
    # store only one entry per ECG sample
    set_property CAPTURE_COMPARE_VALUE eq1'b1 [iprobe rec_stb]
    set_property TRIGGER_COMPARE_VALUE eq1'b1 [iprobe rec_stb]
    foreach f {qrs ap vp as vs} {
        set_property TRIGGER_COMPARE_VALUE eq1'bX [iprobe rec_$f]
    }
    set_property TRIGGER_COMPARE_VALUE eq1'b1 [iprobe rec_$trig]
    set trigs $trig
    run_hw_ila $ila
    wait_on_hw_ila -timeout 2 $ila
    set d [upload_hw_ila_data $ila]
    write_hw_ila_data -force -csv_file "$P17_ILA_OUT/$tag.csv" $d
    write_hw_ila_data -force "$P17_ILA_OUT/$tag.ila" $d
    catch { display_hw_ila_data $d }
    puts "ILA CAPTURE DONE: $tag (trigger: $trigs)"
}

if {[info exists P17_ILA_AUTO]} {
    ila_prog
    set_btn 0
    after 3000                    ;# firmware init + 2 s detector learning
    set_sw 1                      ;# SW0 = pacing on, SW1 = PMT guard off
    after 2000
    ila_capture s1_mitbih_replay qrs
    goto_mode 1; after 3000; ila_capture s2_normal_sinus qrs
    goto_mode 2; after 3000; ila_capture s3_sinus_brady ap
    goto_mode 3; after 3000; ila_capture s4_av_block vp
    goto_mode 4; after 3000; ila_capture s5_av_block_brady ap
    goto_mode 5; after 3000; ila_capture s6_pmt_guard_off vp
    set_sw 3; after 3000;     ila_capture s6_pmt_guard_on ap
    set_sw 1; goto_mode 0; release_sw
    puts "ALL ILA CAPTURES DONE"
}
