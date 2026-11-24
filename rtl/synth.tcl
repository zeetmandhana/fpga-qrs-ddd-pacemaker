# P17 Phase 6 -- out-of-context synthesis of the DDD pacemaker + APB slave.
read_verilog ddd_pacemaker.v
read_verilog ddd_pacemaker_apb.v
synth_design -top ddd_pacemaker_apb -part xc7a100tcsg324-1 -mode out_of_context
create_clock -period 10.000 -name pclk [get_ports PCLK]
report_utilization -file ddd_util.rpt
report_timing_summary -file ddd_timing.rpt -max_paths 1
puts "SYNTH_DONE"
