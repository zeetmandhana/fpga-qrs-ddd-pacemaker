# P17 TA demo -- connect to the Zybo, program the debug bitstream (ILA + VIO), ready for live captures.
# In the Vivado Tcl console:
#   source C:/Vivadoproject/P17_QRS_Pacemaker/vivado/ta_demo.tcl
# Afterwards:
#   ila_capture live_replay qrs     capture 22.8 s of ECG + events (trigger on a detected QRS)
#   ila_capture live_brady  ap      ... trigger on an atrial pace (use vp for a ventricular pace)
#   goto_mode M                     jump to scenario M (0 = replay ... 5 = PMT) with the virtual BTN1
# Then in a terminal:  .venv\Scripts\python tools\plot_ila_ecg.py   -> results\ila\<tag>.png

unset -nocomplain P17_ILA_AUTO          ;# never re-run the full automatic capture sequence here
catch { open_hw_manager }
if {[llength [get_hw_servers -quiet]] == 0} {
    connect_hw_server -url localhost:3121 -allow_non_jtag
}
catch { close_hw_target }
current_hw_target [lindex [get_hw_targets] 0]
# the debug hub runs at 25 MHz, so the JTAG clock must be <= 10 MHz (the default is faster
# and gives corrupted VIO/ILA readings)
set_property PARAM.FREQUENCY 5000000 [current_hw_target]
open_hw_target

source C:/Vivadoproject/P17_QRS_Pacemaker/vivado/ila_capture.tcl
ila_prog
set_btn 0          ;# virtual buttons released
release_sw         ;# the physical switches control the design
puts ""
puts "P17 READY: board programmed with p17_soc_ila.bit (JTAG 5 MHz)."
puts "  Physical: BTN0 reset, BTN1 next scenario, BTN2 lower rate 60/70/80, BTN3 bad LRI (rejected)"
puts "            SW0 pacing on, SW1 PMT guard (RV32 interrupt), SW2 freeze HDMI screen"
puts "  LEDs:     LD0 A-pace, LD1 V-pace, LD2 QRS detected, LD3 arrhythmia IRQ, LD6 colour = scenario"
puts "  Capture:  ila_capture <name> qrs|ap|vp   then run tools/plot_ila_ecg.py"
