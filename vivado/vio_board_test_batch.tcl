# Batch wrapper: run the on-board VIO test in its own Vivado session.
#   vivado -mode batch -source vio_board_test_batch.tcl
set P17_BIT  "C:/Vivadoproject/P17_QRS_Pacemaker/vivado/zybo_reports/p17_soc_final"
set BTN_HOLD 0
if {[info exists ::env(P17_SEQ)]} { set P17_SEQ $::env(P17_SEQ) }
open_hw_manager
connect_hw_server -url localhost:3121 -allow_non_jtag
# debug hub runs at 25 MHz -> JTAG clock must be <= 25/2.5 = 10 MHz (Digilent default is faster)
current_hw_target [lindex [get_hw_targets] 0]
set_property PARAM.FREQUENCY 5000000 [current_hw_target]
open_hw_target
source C:/Vivadoproject/P17_QRS_Pacemaker/vivado/vio_board_test.tcl
close_hw_target
disconnect_hw_server
