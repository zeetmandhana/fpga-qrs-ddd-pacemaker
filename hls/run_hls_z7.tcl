# P17 board phase -- Vitis HLS runs for the Zybo Z7-10 (xc7z010clg400-1).
#   qrs_stream_hls : streaming per-sample filter (goes into the board design)
#                    C-sim bit-exact, C-synth, export + Vivado impl (real P&R numbers)
#   qrs_filter_z7  : the Phase-4 array version re-synthesised for the new part
# Run with:  vitis-run --mode hls --tcl run_hls_z7.tcl

open_project qrs_stream_hls
set_top qrs_stream
add_files qrs_stream.cpp
add_files -tb qrs_stream_tb.cpp
open_solution "sol1" -flow_target vivado
set_part {xc7z010clg400-1}
create_clock -period 10 -name default   ;# 100 MHz target (board runs it at 25 MHz)
csim_design
csynth_design
export_design -flow impl -rtl verilog -format ip_catalog
close_project

open_project qrs_filter_z7
set_top qrs_filter
add_files qrs_filter.cpp
add_files -tb qrs_filter_tb.cpp
open_solution "sol1" -flow_target vivado
set_part {xc7z010clg400-1}
create_clock -period 10 -name default
csim_design
csynth_design
export_design -flow impl -rtl verilog -format ip_catalog
close_project
exit
