## P17 block-design build (p17_soc_wrapper) -- Zybo Z7-10 pins; the 125 MHz input clock is constrained by the Clocking Wizard IP
## Pin locations from Digilent's Zybo-Z7-Master.xdc (Rev. B); JB is Z7-20 only,
## so the Pmod VGA uses JC (J1) + JD (J2).

## 125 MHz system clock
set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 } [get_ports sysclk]

## Buttons (btn0 = reset, btn1 = next scenario, btn2 = rate, btn3 = bad-parameter test)
set_property -dict { PACKAGE_PIN K18 IOSTANDARD LVCMOS33 } [get_ports {btn[0]}]
set_property -dict { PACKAGE_PIN P16 IOSTANDARD LVCMOS33 } [get_ports {btn[1]}]
set_property -dict { PACKAGE_PIN K19 IOSTANDARD LVCMOS33 } [get_ports {btn[2]}]
set_property -dict { PACKAGE_PIN Y16 IOSTANDARD LVCMOS33 } [get_ports {btn[3]}]

## Switches (sw0 = pacing enable, sw1 = PMT guard ISR, sw2 = freeze screen)
set_property -dict { PACKAGE_PIN G15 IOSTANDARD LVCMOS33 } [get_ports {sw[0]}]
set_property -dict { PACKAGE_PIN P15 IOSTANDARD LVCMOS33 } [get_ports {sw[1]}]
set_property -dict { PACKAGE_PIN W13 IOSTANDARD LVCMOS33 } [get_ports {sw[2]}]
set_property -dict { PACKAGE_PIN T16 IOSTANDARD LVCMOS33 } [get_ports {sw[3]}]

## LEDs (LD0 = A-pace, LD1 = V-pace, LD2 = QRS detected, LD3 = arrhythmia IRQ)
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN M15 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN G14 IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN D18 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]

## RGB LED 6 (scenario colour)
set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports led6_r]
set_property -dict { PACKAGE_PIN F17 IOSTANDARD LVCMOS33 } [get_ports led6_g]
set_property -dict { PACKAGE_PIN M17 IOSTANDARD LVCMOS33 } [get_ports led6_b]

## HDMI TX (DVI 640x480 @ 60 Hz)
set_property -dict { PACKAGE_PIN H16 IOSTANDARD TMDS_33 } [get_ports hdmi_tx_clk_p]
set_property -dict { PACKAGE_PIN H17 IOSTANDARD TMDS_33 } [get_ports hdmi_tx_clk_n]
set_property -dict { PACKAGE_PIN D19 IOSTANDARD TMDS_33 } [get_ports {hdmi_tx_p[0]}]
set_property -dict { PACKAGE_PIN D20 IOSTANDARD TMDS_33 } [get_ports {hdmi_tx_n[0]}]
set_property -dict { PACKAGE_PIN C20 IOSTANDARD TMDS_33 } [get_ports {hdmi_tx_p[1]}]
set_property -dict { PACKAGE_PIN B20 IOSTANDARD TMDS_33 } [get_ports {hdmi_tx_n[1]}]
set_property -dict { PACKAGE_PIN B19 IOSTANDARD TMDS_33 } [get_ports {hdmi_tx_p[2]}]
set_property -dict { PACKAGE_PIN A20 IOSTANDARD TMDS_33 } [get_ports {hdmi_tx_n[2]}]

## Pmod VGA: J1 on JC (R0-3, B0-3), J2 on JD (G0-3, HS, VS)
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports {jc[0]}]
set_property -dict { PACKAGE_PIN W15 IOSTANDARD LVCMOS33 } [get_ports {jc[1]}]
set_property -dict { PACKAGE_PIN T11 IOSTANDARD LVCMOS33 } [get_ports {jc[2]}]
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports {jc[3]}]
set_property -dict { PACKAGE_PIN W14 IOSTANDARD LVCMOS33 } [get_ports {jc[4]}]
set_property -dict { PACKAGE_PIN Y14 IOSTANDARD LVCMOS33 } [get_ports {jc[5]}]
set_property -dict { PACKAGE_PIN T12 IOSTANDARD LVCMOS33 } [get_ports {jc[6]}]
set_property -dict { PACKAGE_PIN U12 IOSTANDARD LVCMOS33 } [get_ports {jc[7]}]
set_property -dict { PACKAGE_PIN T14 IOSTANDARD LVCMOS33 } [get_ports {jd[0]}]
set_property -dict { PACKAGE_PIN T15 IOSTANDARD LVCMOS33 } [get_ports {jd[1]}]
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports {jd[2]}]
set_property -dict { PACKAGE_PIN R14 IOSTANDARD LVCMOS33 } [get_ports {jd[3]}]
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports {jd[4]}]
set_property -dict { PACKAGE_PIN U15 IOSTANDARD LVCMOS33 } [get_ports {jd[5]}]
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports {jd[6]}]
set_property -dict { PACKAGE_PIN V18 IOSTANDARD LVCMOS33 } [get_ports {jd[7]}]

## Buttons/switches are synchronised + debounced; LEDs/Pmod are slow outputs
set_false_path -from [get_ports {btn[*] sw[*]}]
set_false_path -to   [get_ports {led[*] led6_r led6_g led6_b jc[*] jd[*]}]
