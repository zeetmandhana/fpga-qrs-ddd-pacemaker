# Board test of the rebuilt bitstream (pacemaker fixes, 2026-11-20): program it and capture all
# seven scenarios into results/ila_fixed (last week's captures in results/ila stay untouched).
set P17_ILA_AUTO 1
set P17_ILA_BIT C:/Vivadoproject/P17_QRS_Pacemaker/vivado/zybo_reports/p17_soc_ila_fixed
set P17_ILA_OUT C:/Vivadoproject/P17_QRS_Pacemaker/results/ila_fixed
open_hw_manager
connect_hw_server -url localhost:3121 -allow_non_jtag
current_hw_target [lindex [get_hw_targets] 0]
set_property PARAM.FREQUENCY 5000000 [current_hw_target]   ;# debug hub at 25 MHz -> JTAG <= 10 MHz
open_hw_target
source C:/Vivadoproject/P17_QRS_Pacemaker/vivado/ila_capture.tcl
close_hw_target
disconnect_hw_server
