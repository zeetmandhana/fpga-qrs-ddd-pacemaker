# P17 -- add a JTAG debug path (VIO) to the p17_soc block design, so the board
# can be tested from the laptop without a monitor: read event counters / LEDs /
# scenario, and press virtual buttons / switches.
#   source C:/Vivadoproject/P17_QRS_Pacemaker/vivado/add_debug_vio.tcl
set root "C:/Vivadoproject/P17_QRS_Pacemaker"
add_files -norecurse $root/rtl/bd/p17_jtag_debug.v
update_compile_order -fileset sources_1
open_bd_design [get_files p17_soc.bd]

proc net {args} { connect_bd_net {*}[lmap p $args {get_bd_pins $p}] }
# connect dst pin onto the existing net of src pin
proc tap {src dst} { connect_bd_net -net [get_bd_nets -of_objects [get_bd_pins $src]] [get_bd_pins $dst] }

# re-route the board buttons / switches through the debug block
delete_bd_objs [get_bd_nets -of_objects [get_bd_ports btn]]
delete_bd_objs [get_bd_nets -of_objects [get_bd_ports sw]]
create_bd_cell -type module -reference p17_jtag_debug jtag_debug_0
connect_bd_net [get_bd_ports btn] [get_bd_pins jtag_debug_0/btn_in]
connect_bd_net [get_bd_ports sw]  [get_bd_pins jtag_debug_0/sw_in]
net jtag_debug_0/btn_out board_io_0/btn btn0_slice/Din
net jtag_debug_0/sw_out board_io_0/sw

create_bd_cell -type ip -vlnv xilinx.com:ip:vio vio_0
set_property -dict [list CONFIG.C_NUM_PROBE_IN {11} CONFIG.C_NUM_PROBE_OUT {3} \
    CONFIG.C_PROBE_IN0_WIDTH {4}  CONFIG.C_PROBE_IN1_WIDTH {3}  CONFIG.C_PROBE_IN2_WIDTH {32} \
    CONFIG.C_PROBE_IN3_WIDTH {32} CONFIG.C_PROBE_IN4_WIDTH {32} CONFIG.C_PROBE_IN5_WIDTH {32} \
    CONFIG.C_PROBE_IN6_WIDTH {32} CONFIG.C_PROBE_IN7_WIDTH {16} CONFIG.C_PROBE_IN8_WIDTH {32} \
    CONFIG.C_PROBE_IN9_WIDTH {32} CONFIG.C_PROBE_IN10_WIDTH {3} \
    CONFIG.C_PROBE_OUT0_WIDTH {4} CONFIG.C_PROBE_OUT1_WIDTH {4} CONFIG.C_PROBE_OUT2_WIDTH {1}] [get_bd_cells vio_0]

# clocks / reset
tap clk_wiz_0/clk_out1 jtag_debug_0/clk
tap clk_wiz_0/clk_out1 vio_0/clk
tap rst_25M/peripheral_aresetn jtag_debug_0/rst_n
# virtual buttons / switches
net vio_0/probe_out0 jtag_debug_0/vio_btn
net vio_0/probe_out1 jtag_debug_0/vio_sw
net vio_0/probe_out2 jtag_debug_0/vio_sw_en
# events into the counters
tap ddd_pacemaker_0/tick_ms jtag_debug_0/tick_ms
tap qrs_decision_0/det      jtag_debug_0/det
tap ddd_pacemaker_0/ap      jtag_debug_0/ap
tap ddd_pacemaker_0/vp      jtag_debug_0/vp
tap ddd_pacemaker_0/as_evt  jtag_debug_0/as_evt
tap ddd_pacemaker_0/vs_evt  jtag_debug_0/vs_evt
tap ddd_pacemaker_0/arrhythmia_irq jtag_debug_0/arr_irq
# what the laptop reads
tap board_io_0/led       vio_0/probe_in0
tap demo_ctrl_0/mode     vio_0/probe_in1
net jtag_debug_0/cnt_qrs vio_0/probe_in2
net jtag_debug_0/cnt_ap  vio_0/probe_in3
net jtag_debug_0/cnt_vp  vio_0/probe_in4
net jtag_debug_0/cnt_as  vio_0/probe_in5
net jtag_debug_0/cnt_vs  vio_0/probe_in6
net jtag_debug_0/cnt_irq vio_0/probe_in7
net jtag_debug_0/uptime_ms vio_0/probe_in8
tap demo_ctrl_0/last_rr  vio_0/probe_in9
tap neorv32_top_0/gpio_o vio_0/probe_in10

regenerate_bd_layout
validate_bd_design
save_bd_design
puts "P17 debug VIO added"
