## P17 -- timing constraint for the demo top (100 MHz board clock).
## Pin LOC / IOSTANDARD constraints for the Arty A7 + Pmod VGA are NOT added
## yet (pending board bring-up), so this project synthesizes but cannot yet
## generate a bitstream.
create_clock -period 10.000 -name clk100 [get_ports clk100]
