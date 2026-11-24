read_verilog C:/Vivadoproject/P17_QRS_Pacemaker/rtl/event_priority.v
synth_design -top event_priority -part xc7z010clg400-1 -mode out_of_context
set_max_delay 10.0 -from [all_inputs] -to [all_outputs]
report_utilization -file zybo_reports/ooc_event_priority_espresso_util.rpt
report_timing_summary -file zybo_reports/ooc_event_priority_espresso_timing.rpt
puts "EP_LUT=[llength [get_cells -hier -filter {PRIMITIVE_GROUP == LUT}]] WNS=[get_property SLACK [get_timing_paths -max_paths 1]]"
