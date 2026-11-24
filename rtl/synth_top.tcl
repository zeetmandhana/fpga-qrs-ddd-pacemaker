# P17 Phase 6 -- synthesis of the full board demo top.
read_verilog ddd_pacemaker.v
read_verilog ddd_pacemaker_apb.v
read_verilog vga_sync.v
read_verilog ecg_vga.v
read_verilog pacemaker_demo_top.v
synth_design -top pacemaker_demo_top -part xc7a100tcsg324-1
create_clock -period 10.000 -name clk100 [get_ports clk100]
report_utilization -file top_util.rpt
report_timing_summary -file top_timing.rpt -max_paths 1
puts "SYNTH_TOP_DONE"
