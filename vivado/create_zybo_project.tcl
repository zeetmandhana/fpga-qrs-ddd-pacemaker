# P17 QRS Detector + DDD Pacemaker -- Vivado GUI project for the Zybo Z7-10
#
# In the Vivado Tcl console:
#   source C:/Vivadoproject/P17_QRS_Pacemaker/vivado/create_zybo_project.tcl
#
# Top: p17_zybo_top (xc7z010clg400-1). Simulation sets:
#   sim_1            tb_closed_loop    heart model + DDD closed loop vs Python (72k ticks)
#   sim_detector     tb_qrs_detector   HLS filter + RTL decision vs Python (814 QRS)
#   sim_ddd          tb_ddd_pacemaker  DDD + APB replay vs Python (18k ticks)
#   sim_event_prio   tb_event_priority event-priority block (256 combos)
#   sim_top          tb_p17_zybo_top   whole board incl. NEORV32 firmware (frames to results/)
source [file join [file dirname [info script]] zybo_sources.tcl]
set pdir "$root/vivado/p17_zybo"

create_project p17_zybo $pdir -part $part -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

add_files -norecurse $neo_files
set_property library neorv32 [get_files $neo_files]
add_files -norecurse $hls_files
add_files -norecurse $rtl_files
add_files -norecurse $mem_files
set_property top $top [get_filesets sources_1]
add_files -fileset constrs_1 -norecurse $xdc_file

proc p17_simset {name tb} {
    global root
    if {$name ne "sim_1"} { create_fileset -simset $name }
    add_files -fileset $name -norecurse $root/rtl/$tb.v
    set_property top $tb [get_filesets $name]
    set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets $name]
}
p17_simset sim_1          tb_closed_loop
p17_simset sim_detector   tb_qrs_detector
p17_simset sim_ddd        tb_ddd_pacemaker
p17_simset sim_event_prio tb_event_priority
p17_simset sim_top        tb_p17_zybo_top

current_fileset -simset [get_filesets sim_1]
update_compile_order -fileset sources_1
puts "P17 Zybo project created: $pdir/p17_zybo.xpr"
