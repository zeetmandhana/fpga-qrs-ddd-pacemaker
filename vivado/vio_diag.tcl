# P17 -- diagnosis: raw VIO read-back around one BTN2 (rate) press, no reprogramming.
set impl "C:/Vivadoproject/P17_QRS_Pacemaker/vivado/zybo_reports/p17_soc_final"
open_hw_manager
connect_hw_server -url localhost:3121 -allow_non_jtag
open_hw_target [lindex [get_hw_targets] 0]
set dev [get_hw_devices xc7z010_1]
current_hw_device $dev
set_property PROBES.FILE "$impl.ltx" $dev
set_property FULL_PROBES.FILE "$impl.ltx" $dev
refresh_hw_device $dev
set vio [get_hw_vios -of_objects $dev]
proc probe {pat} { global vio; return [get_hw_probes -of_objects $vio -filter "NAME =~ *${pat}"] }
set names {uptime_ms cnt_qrs cnt_ap cnt_vp cnt_as cnt_vs cnt_irq last_rr demo_ctrl_0_mode board_io_0_led gpio_o}
set P {}
foreach n $names { set p [probe $n]; lappend P $p; catch {set_property INPUT_VALUE_RADIX UNSIGNED $p} }
set P_btn [probe probe_out0]; set P_sw [probe probe_out1]; set P_swen [probe probe_out2]
proc dump {tag} {
    global vio P names
    refresh_hw_vio $vio
    set s "$tag:"
    foreach n $names p $P { append s " $n=[get_property INPUT_VALUE $p]" }
    puts $s
}
proc press {n} {
    global P_btn
    set_property OUTPUT_VALUE [format %X [expr {1 << $n}]] $P_btn; commit_hw_vio $P_btn
    after 600
    set_property OUTPUT_VALUE 0 $P_btn; commit_hw_vio $P_btn
    after 600
}
set_property OUTPUT_VALUE 1 $P_sw; set_property OUTPUT_VALUE 1 $P_swen; commit_hw_vio [list $P_sw $P_swen]
while {[get_property INPUT_VALUE [probe demo_ctrl_0_mode]] != 2} { press 1; after 800; refresh_hw_vio $vio }
after 3000
dump "BRADY t0"; after 2000; dump "BRADY t2"
press 2
for {set i 0} {$i < 6} {incr i} { after 1500; dump "AFTER_BTN2 [expr {$i*1.5+1.5}]s" }
press 1; after 1500
dump "AFTER_BTN1"
set_property OUTPUT_VALUE 0 $P_swen; commit_hw_vio $P_swen
puts "DIAG DONE"
