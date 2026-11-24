set here [file dirname [file normalize [info script]]]
foreach fsm {off sequential one_hot} {
  read_verilog "$here/qd_ctrl.v"
  synth_design -top qd_ctrl -part xc7z010clg400-1 -mode out_of_context -fsm_extraction $fsm
  write_verilog -force -mode funcsim "$here/../sim_ctrl/qd_ctrl_net_$fsm.v"
  close_design
}
