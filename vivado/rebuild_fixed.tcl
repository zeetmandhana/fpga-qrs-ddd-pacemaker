# Rebuild the IP-Integrator SoC (debug build with ILA + VIO) after the 2026-11-20 ddd_pacemaker.v fixes.
set root C:/Vivadoproject/P17_QRS_Pacemaker
open_project $root/vivado/p17_zybo_bd/p17_zybo_bd.xpr
set bd [get_files p17_soc.bd]
open_bd_design $bd
report_ip_status -file $root/vivado/zybo_reports/ip_status_before_rebuild.txt
foreach ip [get_ips] {
    if {[catch {update_module_reference $ip} msg] == 0} { puts "REFRESHED module reference: $ip" }
}
validate_bd_design
save_bd_design
generate_target all $bd
foreach r [get_runs -filter {IS_SYNTHESIS == 1}] { if {[string match *ddd_pacemaker* $r]} { reset_run $r; puts "RESET $r" } }
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
puts "IMPL STATUS: [get_property STATUS [get_runs impl_1]]"
open_run impl_1
report_utilization    -file $root/vivado/zybo_reports/p17_soc_ila_fixed_util.rpt
report_timing_summary -file $root/vivado/zybo_reports/p17_soc_ila_fixed_timing.rpt
report_power          -file $root/vivado/zybo_reports/p17_soc_ila_fixed_power.rpt
puts "REBUILD_DONE"
