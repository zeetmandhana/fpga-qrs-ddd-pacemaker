# Batch wrapper: program the ILA bitstream and capture all scenarios.
#   vivado -mode batch -source ila_capture_batch.tcl
set P17_ILA_AUTO 1
open_hw_manager
connect_hw_server -url localhost:3121 -allow_non_jtag
# debug hub runs at 25 MHz -> JTAG clock must be <= 25/2.5 = 10 MHz (Digilent default is faster)
current_hw_target [lindex [get_hw_targets] 0]
set_property PARAM.FREQUENCY 5000000 [current_hw_target]
open_hw_target
source C:/Vivadoproject/P17_QRS_Pacemaker/vivado/ila_capture.tcl
close_hw_target
disconnect_hw_server
