# P17 QRS Detector + DDD Pacemaker -- Vivado project for the Phase-6 RTL.
#
# In the Vivado Tcl console (or batch):
#   source C:/Vivadoproject/P17_QRS_Pacemaker/vivado/create_project.tcl
#
# Simulation sets (choose one, then Flow Navigator > Run Simulation):
#   sim_1               tb_ddd_pacemaker   DDD + APB, bit-exact vs Python model
#   sim_event_priority  tb_event_priority  event-priority block, 256 combos
#   sim_vga             tb_vga_sync        VGA 640x480 @ 60 Hz timing

set root "C:/Vivadoproject/P17_QRS_Pacemaker"
set pdir "$root/vivado/p17_pacemaker"

create_project p17_pacemaker $pdir -part xc7a100tcsg324-1 -force
set_property target_language Verilog [current_project]
set_property simulator_language Verilog [current_project]

# --- design sources ---
add_files -norecurse [list \
    $root/rtl/ddd_pacemaker.v \
    $root/rtl/ddd_pacemaker_apb.v \
    $root/rtl/event_priority.v \
    $root/rtl/vga_sync.v \
    $root/rtl/ecg_vga.v \
    $root/rtl/pacemaker_demo_top.v \
    $root/rtl/ecg_samples.mem ]
set_property top pacemaker_demo_top [get_filesets sources_1]

# --- constraints (timing only; board pins pending) ---
add_files -fileset constrs_1 -norecurse $root/vivado/p17_timing.xdc

# --- simulation sets ---
add_files -fileset sim_1 -norecurse $root/rtl/tb_ddd_pacemaker.v
set_property top tb_ddd_pacemaker [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]

create_fileset -simset sim_event_priority
add_files -fileset sim_event_priority -norecurse $root/rtl/tb_event_priority.v
set_property top tb_event_priority [get_filesets sim_event_priority]
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_event_priority]

create_fileset -simset sim_vga
add_files -fileset sim_vga -norecurse $root/rtl/tb_vga_sync.v
set_property top tb_vga_sync [get_filesets sim_vga]
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_vga]

current_fileset -simset [get_filesets sim_1]
update_compile_order -fileset sources_1
puts "P17 project created: $pdir/p17_pacemaker.xpr"
