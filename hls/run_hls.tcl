# P17 Phase 4 -- Vitis HLS flow for the Pan-Tompkins filter chain.
#   C-sim  : bit-exact check vs the Python golden model (qrs_filter_tb.cpp)
#   C-synth: resource / timing for the resource & power table
# Run with:  vitis-run --mode hls --tcl run_hls.tcl

open_project qrs_filter_hls
set_top qrs_filter
add_files qrs_filter.cpp
add_files -tb qrs_filter_tb.cpp

open_solution "sol1" -flow_target vivado
set_part {xc7a100tcsg324-1}
create_clock -period 10 -name default   ;# 100 MHz

csim_design
csynth_design

exit
