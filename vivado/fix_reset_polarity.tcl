# P17 -- block design reset fix. IP Integrator propagated an ACTIVE-LOW polarity onto
# rst_25M/ext_reset_in (C_EXT_RESET_HIGH = 0), but BTN0 is active-high, so the
# design was held in reset while the button was NOT pressed. Insert an inverter
# so "BTN0 pressed" = reset, and check the resulting polarity.
open_bd_design [get_files p17_soc.bd]
delete_bd_objs [get_bd_nets -of_objects [get_bd_pins rst_25M/ext_reset_in]]
if {[catch {create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilvector_logic:1.0 btn0_inv}]} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic btn0_inv
}
set_property -dict [list CONFIG.C_OPERATION {not} CONFIG.C_SIZE {1}] [get_bd_cells btn0_inv]
connect_bd_net [get_bd_pins btn0_slice/Dout] [get_bd_pins btn0_inv/Op1]
connect_bd_net [get_bd_pins btn0_inv/Res] [get_bd_pins rst_25M/ext_reset_in]
validate_bd_design
puts "RESET CHECK: C_EXT_RESET_HIGH = [get_property CONFIG.C_EXT_RESET_HIGH [get_bd_cells rst_25M]] (0 = active-low input, correct with the inverter)"
regenerate_bd_layout
save_bd_design
