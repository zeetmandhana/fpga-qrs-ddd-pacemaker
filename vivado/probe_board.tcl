open_hw_manager
connect_hw_server -url localhost:3121 -allow_non_jtag
puts "TARGETS: [get_hw_targets]"
foreach t [get_hw_targets] { current_hw_target $t; set_property PARAM.FREQUENCY 5000000 $t; open_hw_target; puts "DEVICES on $t: [get_hw_devices]"; close_hw_target }
disconnect_hw_server
