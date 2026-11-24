# P17 -- add an ILA (Integrated Logic Analyzer) to the p17_soc block design so the
# ECG, detected QRS and pace events can be captured from the board and shown on
# the laptop without a monitor.
#   source C:/Vivadoproject/P17_QRS_Pacemaker/vivado/add_ila.tcl
set root "C:/Vivadoproject/P17_QRS_Pacemaker"
add_files -norecurse $root/rtl/bd/p17_ila_tap.v
update_compile_order -fileset sources_1
open_bd_design [get_files p17_soc.bd]

proc net {args} { connect_bd_net {*}[lmap p $args {get_bd_pins $p}] }
proc tap {src dst} { connect_bd_net -net [get_bd_nets -of_objects [get_bd_pins $src]] [get_bd_pins $dst] }

create_bd_cell -type module -reference p17_ila_tap ila_tap_0
tap clk_wiz_0/clk_out1          ila_tap_0/clk
tap rst_25M/peripheral_aresetn  ila_tap_0/rst_n
tap ecg_source_0/adc_valid      ila_tap_0/adc_valid
tap ecg_source_0/adc            ila_tap_0/adc
tap qrs_decision_0/det          ila_tap_0/det
tap ecg_display_0/qrs_delay     ila_tap_0/qrs_delay
tap ddd_pacemaker_0/ap          ila_tap_0/ap
tap ddd_pacemaker_0/vp          ila_tap_0/vp
tap ddd_pacemaker_0/as_evt      ila_tap_0/as_evt
tap ddd_pacemaker_0/vs_evt      ila_tap_0/vs_evt
tap demo_ctrl_0/mode            ila_tap_0/mode
tap qrs_decision_0/mwi_q        ila_tap_0/mwi_q
tap qrs_decision_0/thr1         ila_tap_0/thr1

# ILA: 12 native probes, 8192 entries, capture qualifier = rec_stb
create_bd_cell -type ip -vlnv xilinx.com:ip:ila ila_0
set_property -dict [list CONFIG.C_MONITOR_TYPE {Native} CONFIG.C_NUM_OF_PROBES {12} \
    CONFIG.C_DATA_DEPTH {8192} CONFIG.C_EN_STRG_QUAL {1} CONFIG.ALL_PROBE_SAME_MU_CNT {2} \
    CONFIG.C_PROBE0_WIDTH {1}  CONFIG.C_PROBE1_WIDTH {11} CONFIG.C_PROBE2_WIDTH {1} \
    CONFIG.C_PROBE3_WIDTH {1}  CONFIG.C_PROBE4_WIDTH {1}  CONFIG.C_PROBE5_WIDTH {1} \
    CONFIG.C_PROBE6_WIDTH {1}  CONFIG.C_PROBE7_WIDTH {12} CONFIG.C_PROBE8_WIDTH {3} \
    CONFIG.C_PROBE9_WIDTH {24} CONFIG.C_PROBE10_WIDTH {24} CONFIG.C_PROBE11_WIDTH {16}] [get_bd_cells ila_0]
tap clk_wiz_0/clk_out1 ila_0/clk
net ila_tap_0/rec_stb       ila_0/probe0
net ila_tap_0/rec_ecg       ila_0/probe1
net ila_tap_0/rec_qrs       ila_0/probe2
net ila_tap_0/rec_ap        ila_0/probe3
net ila_tap_0/rec_vp        ila_0/probe4
net ila_tap_0/rec_as        ila_0/probe5
net ila_tap_0/rec_vs        ila_0/probe6
net ila_tap_0/rec_qrs_delay ila_0/probe7
net ila_tap_0/rec_mode      ila_0/probe8
net ila_tap_0/rec_mwi       ila_0/probe9
net ila_tap_0/rec_thr       ila_0/probe10
net ila_tap_0/rec_n         ila_0/probe11

regenerate_bd_layout
validate_bd_design
save_bd_design
puts "P17 ILA added"
