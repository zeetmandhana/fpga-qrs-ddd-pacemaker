# P17 -- source list of the Zybo Z7-10 board design (shared by the GUI
# project script and the batch implementation/power script).
set root "C:/Vivadoproject/P17_QRS_Pacemaker"
set neo  "C:/NEORV32/neorv32/rtl/core"

# NEORV32 core (VHDL library neorv32); the IMEM image is the P17 firmware build
set neo_files {}
foreach f {neorv32_package neorv32_sys neorv32_cpu_decompressor neorv32_cpu_frontend
           neorv32_cpu_control neorv32_cpu_hwtrig neorv32_prim neorv32_cpu_counters
           neorv32_cpu_regfile neorv32_cpu_alu_shifter neorv32_cpu_alu_muldiv
           neorv32_cpu_alu_bitmanip neorv32_cpu_alu_fpu neorv32_cpu_alu_cfu
           neorv32_cpu_alu_cond neorv32_cpu_alu_crypto neorv32_cpu_alu neorv32_cpu_lsu
           neorv32_cpu_pmp neorv32_cpu_trace neorv32_cpu neorv32_cache neorv32_bus
           neorv32_dma neorv32_imem neorv32_dmem neorv32_xbus neorv32_bootrom neorv32_cfs
           neorv32_sdi neorv32_gpio neorv32_wdt neorv32_clint neorv32_uart neorv32_spi
           neorv32_twi neorv32_twd neorv32_pwm neorv32_trng neorv32_neoled neorv32_gptmr
           neorv32_onewire neorv32_slink neorv32_tracer neorv32_sysinfo neorv32_debug_dtm
           neorv32_debug_auth neorv32_debug_dm neorv32_top neorv32_cache_ram
           neorv32_imem_rom neorv32_imem_ram neorv32_dmem_ram neorv32_bootrom_image
           neorv32_bootrom_rom} {
    lappend neo_files "$neo/$f.vhd"
}
lappend neo_files "$root/rtl/firmware/build/neorv32_imem_image.vhd"

set hls_files [glob $root/rtl/hls_qrs_stream/*.v]

set rtl_files [list \
    $root/rtl/neorv32_p17.vhd \
    $root/rtl/qrs_decision.v \
    $root/rtl/qrs_detector.v \
    $root/rtl/ddd_pacemaker.v \
    $root/rtl/ddd_pacemaker_apb.v \
    $root/rtl/event_priority.v \
    $root/rtl/heart_model.v \
    $root/rtl/ecg_source.v \
    $root/rtl/vga_sync.v \
    $root/rtl/ecg_display.v \
    $root/rtl/hdmi_tx.v \
    $root/rtl/xbus_apb_bridge.v \
    $root/rtl/demo_ctrl_apb.v \
    $root/rtl/p17_board_glue.v \
    $root/rtl/p17_zybo_top.v ]

set mem_files [glob $root/rtl/mem/*.mem]
set xdc_file  "$root/vivado/p17_zybo.xdc"
set part      "xc7z010clg400-1"
set top       "p17_zybo_top"
