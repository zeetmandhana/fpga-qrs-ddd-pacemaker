# P17 -- batch (non-project) synthesis + implementation + power for Zybo Z7-10.
# Produces the real post-route numbers for the resource & power table:
#   vivado/zybo_reports/*.rpt  and  vivado/zybo_reports/p17_zybo_top.bit
# Run:  vivado -mode batch -source impl_zybo.tcl
source [file join [file dirname [info script]] zybo_sources.tcl]
set out "$root/vivado/zybo_reports"
file mkdir $out

read_vhdl -library neorv32 $neo_files
read_vhdl [lindex $rtl_files 0]
read_verilog $hls_files
read_verilog [lrange $rtl_files 1 end]
read_xdc $xdc_file

synth_design -top $top -part $part
report_utilization -file $out/synth_util.rpt
opt_design
place_design
phys_opt_design
route_design
write_checkpoint -force $out/p17_zybo_routed.dcp
report_utilization -file $out/impl_util.rpt
report_utilization -hierarchical -hierarchical_depth 2 -file $out/impl_util_hier.rpt
report_timing_summary -max_paths 10 -file $out/impl_timing.rpt
report_power -file $out/impl_power.rpt
report_power -hierarchical_depth 2 -file $out/impl_power_hier.rpt -format text
report_drc -file $out/impl_drc.rpt
write_bitstream -force $out/p17_zybo_top.bit
puts "IMPL_ZYBO_DONE"
