# P17 QRS Detector + DDD Pacemaker -- IP-Integrator BLOCK DESIGN for Zybo Z7-10
#
#   source C:/Vivadoproject/P17_QRS_Pacemaker/vivado/create_zybo_bd.tcl
#
# Builds project vivado/p17_zybo_bd with block design "p17_soc":
#   Clocking Wizard (125 -> 25 / 125 MHz) + Processor System Reset
#   NEORV32 RISC-V IP (firmware in IMEM) --m_axi--> AXI SmartConnect
#     --> p17_axi_apb (AXI4-Lite -> APB) --> DDD pacemaker / demo control / screen text
#   Vitis-HLS IP qrs_stream (Pan-Tompkins filter chain) <-> RTL adaptive-threshold decision
#   heart model, ECG source (MIT-BIH BRAM), event router, time base, board I/O, HDMI TX
set root "C:/Vivadoproject/P17_QRS_Pacemaker"
set pdir "$root/vivado/p17_zybo_bd"

create_project p17_zybo_bd $pdir -part xc7z010clg400-1 -force
set_property target_language Verilog [current_project]
set_property ip_repo_paths [list \
    $root/neorv32_ip/rtl/system_integration/neorv32_vivado_ip_work/packaged_ip \
    $root/hls/qrs_stream_hls/sol1/impl/ip ] [current_project]
update_ip_catalog

# RTL used by the module-reference blocks
add_files -norecurse [list \
    $root/rtl/ddd_pacemaker.v $root/rtl/ddd_pacemaker_apb.v $root/rtl/demo_ctrl_apb.v \
    $root/rtl/vga_sync.v $root/rtl/ecg_display.v $root/rtl/qrs_decision.v \
    $root/rtl/heart_model.v $root/rtl/ecg_source.v $root/rtl/hdmi_tx.v \
    $root/rtl/p17_board_glue.v $root/rtl/bd/p17_axi_apb.v $root/rtl/bd/p17_bd_blocks.v ]
add_files -norecurse [glob $root/rtl/mem/*.mem]
update_compile_order -fileset sources_1

create_bd_design "p17_soc"

proc mk_const {name val width} {
    if {[catch {create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconstant:1.0 $name}]} {
        create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant $name
    }
    set_property -dict [list CONFIG.CONST_VAL $val CONFIG.CONST_WIDTH $width] [get_bd_cells $name]
}
proc mk_slice {name win from to} {
    if {[catch {create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilslice:1.0 $name}]} {
        create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice $name
    }
    set_property -dict [list CONFIG.DIN_WIDTH $win CONFIG.DIN_FROM $from CONFIG.DIN_TO $to] [get_bd_cells $name]
}
proc net {args} { connect_bd_net {*}[lmap p $args {get_bd_pins $p}] }
proc pnet {port args} { connect_bd_net [get_bd_ports $port] {*}[lmap p $args {get_bd_pins $p}] }

# ---------------- external ports ----------------
create_bd_port -dir I -type clk -freq_hz 125000000 sysclk
create_bd_port -dir I -from 3 -to 0 btn
create_bd_port -dir I -from 3 -to 0 sw
create_bd_port -dir O -from 3 -to 0 led
create_bd_port -dir O led6_r
create_bd_port -dir O led6_g
create_bd_port -dir O led6_b
create_bd_port -dir O hdmi_tx_clk_p
create_bd_port -dir O hdmi_tx_clk_n
create_bd_port -dir O -from 2 -to 0 hdmi_tx_p
create_bd_port -dir O -from 2 -to 0 hdmi_tx_n
create_bd_port -dir O -from 7 -to 0 jc
create_bd_port -dir O -from 7 -to 0 jd

# ---------------- clocking + reset ----------------
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz clk_wiz_0
set_property -dict [list CONFIG.PRIM_IN_FREQ {125.000} CONFIG.PRIM_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {25.000} CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {125.000} CONFIG.NUM_OUT_CLKS {2} \
    CONFIG.USE_RESET {false} CONFIG.USE_LOCKED {true}] [get_bd_cells clk_wiz_0]
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst_25M
set_property CONFIG.C_EXT_RESET_HIGH {1} [get_bd_cells rst_25M]
mk_slice btn0_slice 4 0 0
mk_const const_0 0 1

# ---------------- processor + interconnect ----------------
create_bd_cell -type ip -vlnv NEORV32:user:neorv32_vivado_ip:1.0 neorv32_top_0
set_property -dict [list CONFIG.CLOCK_FREQUENCY {25000000} CONFIG.BOOT_MODE_SELECT {2} \
    CONFIG.RISCV_ISA_Zicntr {true} CONFIG.IMEM_EN {true} CONFIG.IMEM_SIZE {16384} \
    CONFIG.DMEM_EN {true} CONFIG.DMEM_SIZE {8192} CONFIG.XBUS_EN {true} \
    CONFIG.IO_GPIO_EN {true} CONFIG.IO_GPIO_IN_NUM {8} CONFIG.IO_GPIO_OUT_NUM {3} \
    CONFIG.IO_CLINT_EN {true}] [get_bd_cells neorv32_top_0]
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect axi_smc
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] [get_bd_cells axi_smc]
create_bd_cell -type module -reference p17_axi_apb axi_apb_bridge_0

# ---------------- APB peripherals ----------------
create_bd_cell -type module -reference p17_ddd_slave  ddd_pacemaker_0
create_bd_cell -type module -reference p17_ctrl_slave demo_ctrl_0
create_bd_cell -type module -reference p17_display    ecg_display_0

# ---------------- detector: Vitis-HLS IP + RTL decision ----------------
create_bd_cell -type ip -vlnv xilinx.com:hls:qrs_stream:1.0 qrs_stream_0
create_bd_cell -type module -reference p17_qrs_hls_decision qrs_decision_0

# ---------------- closed loop + board ----------------
create_bd_cell -type module -reference heart_model      heart_model_0
create_bd_cell -type module -reference ecg_source       ecg_source_0
create_bd_cell -type module -reference p17_event_router event_router_0
create_bd_cell -type module -reference p17_timebase     timebase_0
create_bd_cell -type module -reference p17_board_io     board_io_0
create_bd_cell -type module -reference hdmi_tx          hdmi_tx_0

# ---------------- clocks / resets ----------------
pnet sysclk clk_wiz_0/clk_in1
pnet btn board_io_0/btn btn0_slice/Din
net btn0_slice/Dout rst_25M/ext_reset_in
net clk_wiz_0/locked rst_25M/dcm_locked
net clk_wiz_0/clk_out1 rst_25M/slowest_sync_clk neorv32_top_0/clk axi_smc/aclk \
    axi_apb_bridge_0/aclk ddd_pacemaker_0/clk demo_ctrl_0/clk ecg_display_0/clk \
    qrs_stream_0/ap_clk qrs_decision_0/clk heart_model_0/clk ecg_source_0/clk \
    event_router_0/clk timebase_0/clk board_io_0/clk hdmi_tx_0/pix_clk
net clk_wiz_0/clk_out2 hdmi_tx_0/ser_clk
net rst_25M/interconnect_aresetn axi_smc/aresetn
net rst_25M/peripheral_aresetn neorv32_top_0/resetn axi_apb_bridge_0/aresetn \
    ddd_pacemaker_0/rst_n demo_ctrl_0/rst_n ecg_display_0/rst_n qrs_decision_0/rst_n \
    event_router_0/rst_n timebase_0/rst_n board_io_0/rst_n
net rst_25M/peripheral_reset hdmi_tx_0/rst qrs_stream_0/ap_rst

# ---------------- buses ----------------
connect_bd_intf_net [get_bd_intf_pins neorv32_top_0/m_axi] [get_bd_intf_pins axi_smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] \
    [get_bd_intf_pins -of_objects [get_bd_cells axi_apb_bridge_0] -filter {VLNV =~ "*aximm*"}]
connect_bd_intf_net [get_bd_intf_pins axi_apb_bridge_0/APB_M0] [get_bd_intf_pins ddd_pacemaker_0/APB_S]
connect_bd_intf_net [get_bd_intf_pins axi_apb_bridge_0/APB_M1] [get_bd_intf_pins demo_ctrl_0/APB_S]
connect_bd_intf_net [get_bd_intf_pins axi_apb_bridge_0/APB_M2] [get_bd_intf_pins ecg_display_0/APB_S]
# HLS block-level handshake (ap_ctrl_hs): start / ready / done / idle
net qrs_decision_0/hls_ap_start qrs_stream_0/ap_start
net qrs_stream_0/ap_ready qrs_decision_0/hls_ap_ready
net qrs_stream_0/ap_done  qrs_decision_0/hls_ap_done
net qrs_stream_0/ap_idle  qrs_decision_0/hls_ap_idle

# ---------------- CPU I/O ----------------
net board_io_0/in_db neorv32_top_0/gpio_i
net neorv32_top_0/gpio_o board_io_0/rgb
net ddd_pacemaker_0/arrhythmia_irq neorv32_top_0/irq_mei_i board_io_0/arr_irq

# ---------------- pacemaker closed loop ----------------
net timebase_0/tick_ms ddd_pacemaker_0/tick_ms event_router_0/tick_ms
net timebase_0/tick_360 ecg_source_0/tick_360
net event_router_0/a_sense ddd_pacemaker_0/a_sense
net event_router_0/v_sense ddd_pacemaker_0/v_sense
net ddd_pacemaker_0/ap event_router_0/ap board_io_0/ap ecg_source_0/ap demo_ctrl_0/ap_evt ecg_display_0/ev_ap
net ddd_pacemaker_0/vp event_router_0/vp board_io_0/vp ecg_source_0/vp demo_ctrl_0/vp_evt ecg_display_0/ev_vp
net ddd_pacemaker_0/as_evt demo_ctrl_0/as_evt ecg_display_0/ev_as
net ddd_pacemaker_0/vs_evt demo_ctrl_0/vs_evt ecg_display_0/ev_vs
net demo_ctrl_0/mode event_router_0/mode heart_model_0/scen ecg_source_0/mode
net demo_ctrl_0/mode_wr event_router_0/mode_wr
net event_router_0/scen_rst_n heart_model_0/rst_n ecg_source_0/rst_n qrs_decision_0/relearn_n
net event_router_0/heart_update heart_model_0/update
net heart_model_0/a_in event_router_0/a_in
net heart_model_0/v_in event_router_0/v_in
net event_router_0/a_act heart_model_0/a_act
net event_router_0/v_act heart_model_0/v_act
net event_router_0/ecg_a_act ecg_source_0/a_act
net event_router_0/ecg_v_intr ecg_source_0/v_intr
net const_0/dout event_router_0/psel_txt event_router_0/penable event_router_0/pwrite

# ---------------- ECG -> HLS filter -> decision ----------------
net ecg_source_0/adc qrs_decision_0/adc ecg_display_0/smp_adc
net ecg_source_0/adc_valid qrs_decision_0/sample_valid ecg_display_0/smp_valid
net qrs_decision_0/hls_x qrs_stream_0/x
net qrs_decision_0/hls_baseline qrs_stream_0/baseline
net qrs_stream_0/hp_out qrs_decision_0/hls_hp
net qrs_stream_0/hp_out_ap_vld qrs_decision_0/hls_hp_vld
net qrs_stream_0/dv_out qrs_decision_0/hls_dv
net qrs_stream_0/dv_out_ap_vld qrs_decision_0/hls_dv_vld
net qrs_stream_0/mwi_out qrs_decision_0/hls_mwi
net qrs_stream_0/mwi_out_ap_vld qrs_decision_0/hls_mwi_vld
net qrs_decision_0/det ecg_display_0/qrs_det board_io_0/det demo_ctrl_0/qrs_evt event_router_0/det
net qrs_decision_0/det_r event_router_0/det_r
net qrs_decision_0/n_cnt event_router_0/n_cnt
net qrs_decision_0/learning demo_ctrl_0/learning
net qrs_decision_0/mwi_q ecg_display_0/smp_mwi
net qrs_decision_0/thr1 ecg_display_0/smp_thr
net qrs_decision_0/spki ecg_display_0/smp_spki
net event_router_0/last_rr demo_ctrl_0/last_rr
net event_router_0/qrs_delay ecg_display_0/qrs_delay

# ---------------- display + board outputs ----------------
net board_io_0/freeze ecg_display_0/freeze
net ecg_display_0/red hdmi_tx_0/red
net ecg_display_0/green hdmi_tx_0/green
net ecg_display_0/blue hdmi_tx_0/blue
net ecg_display_0/hsync hdmi_tx_0/hsync
net ecg_display_0/vsync hdmi_tx_0/vsync
net ecg_display_0/de hdmi_tx_0/de
pnet jc ecg_display_0/jc
pnet jd ecg_display_0/jd
pnet hdmi_tx_clk_p hdmi_tx_0/tmds_clk_p
pnet hdmi_tx_clk_n hdmi_tx_0/tmds_clk_n
pnet hdmi_tx_p hdmi_tx_0/tmds_p
pnet hdmi_tx_n hdmi_tx_0/tmds_n
pnet sw board_io_0/sw
pnet led board_io_0/led
pnet led6_r board_io_0/led6_r
pnet led6_g board_io_0/led6_g
pnet led6_b board_io_0/led6_b

# ---------------- address map (same as the firmware) ----------------
assign_bd_address
foreach seg [get_bd_addr_segs -of_objects [get_bd_addr_spaces -of_objects [get_bd_cells neorv32_top_0]]] {
    set_property range 64K $seg
    set_property offset 0x90000000 $seg
}

regenerate_bd_layout
validate_bd_design
save_bd_design

# ---------------- wrapper, constraints ----------------
make_wrapper -files [get_files p17_soc.bd] -top
add_files -norecurse $pdir/p17_zybo_bd.gen/sources_1/bd/p17_soc/hdl/p17_soc_wrapper.v
set_property top p17_soc_wrapper [current_fileset]
add_files -fileset constrs_1 -norecurse $root/vivado/p17_zybo_bd.xdc
update_compile_order -fileset sources_1
puts "P17 block design created: $pdir/p17_zybo_bd.xpr"
