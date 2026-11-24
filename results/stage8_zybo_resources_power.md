# P17 on Zybo Z7-10 (xc7z010clg400-1): resources, timing, power

All numbers are from Vivado 2025.2 / Vitis HLS 2025.2 on 2026-11-11, part
xc7z010clg400-1 (17,600 LUT, 35,200 FF, 60 BRAM36, 80 DSP).

## Whole board design (p17_zybo_top), post-route

| Resource | Used | Available | % |
|---|---|---|---|
| Slice LUTs | 6,048 | 17,600 | 34.4 |
| of which LUT as memory | 408 | 6,000 | 6.8 |
| Flip-flops | 4,780 | 35,200 | 13.6 |
| Block RAM (36 Kb tiles) | 20.5 | 60 | 34.2 |
| DSP48E1 | 3 | 80 | 3.8 |
| Bonded IOB | 40 | 100 | 40 |
| MMCM / BUFG / OSERDES | 1 / 3 / 8 | | |

Timing: system/pixel clock 25 MHz (40 ns), WNS +23.398 ns, WHS +0.032 ns,
all constraints met. Bitstream: `vivado/p17_zybo/p17_zybo.runs/impl_1/p17_zybo_top.bit`
(GUI project) and `vivado/zybo_reports/p17_zybo_top.bit` (batch run).

### Same system as an IP-Integrator block design (p17_soc, post-route)

`vivado/p17_zybo_bd/p17_zybo_bd.xpr`: Clocking Wizard + Processor System
Reset + NEORV32 IP (m_axi) + AXI SmartConnect + AXI4-Lite->APB bridge + the
Vitis-HLS qrs_stream IP + the RTL blocks. The AXI path (SmartConnect + bridge)
costs a little more logic than the direct XBUS bridge of the RTL top.

| Resource | Used | % |
|---|---|---|
| Slice LUTs | 6,772 | 38.5 |
| Flip-flops | 5,360 | 15.2 |
| Block RAM (36 Kb) | 19.5 | 32.5 |
| DSP48E1 | 3 | 3.8 |

Timing at 25 MHz: WNS +23.598 ns, WHS +0.040 ns, all constraints met.
Power: 0.355 W total (0.258 W dynamic + 0.097 W static).
Bitstream: `vivado/p17_zybo_bd/p17_zybo_bd.runs/impl_1/p17_soc_wrapper.bit`.

### Measured on the Zybo Z7-10 (2026-11-11, after programming p17_soc_wrapper.bit)

Read over JTAG from the on-chip XADC (System Monitor) in Vivado Hardware
Manager, with the design running: die temperature **38.0 C**, VCCINT
**0.998 V**, VCCAUX **1.786 V**, VCCBRAM **0.997 V** (nominal 1.0 / 1.8 / 1.0 V).
The XADC measures temperature and voltage, not current, so it confirms the
chip runs cool and the rails are nominal; it is not a power measurement.

## Per block inside the implemented design (post-route, hierarchical)

| Block | LUT | LUTRAM | FF | BRAM36 / 18 | DSP |
|---|---|---|---|---|---|
| NEORV32 RV32I CPU (16 KB IMEM, 8 KB DMEM) | 1,483 | 24 | 1,204 | 5 / 4 | 0 |
| QRS detector total | 3,190 | 162 | 2,384 | 0 | 3 |
| - HLS filter chain (qrs_stream, one multiplier) | 459 | 162 | 563 | 0 | 3 |
| - RTL adaptive-threshold decision (qrs_decision) | 2,730 | 0 | 1,704 | 0 | 0 |
| DDD pacemaker + APB regs | 236 | 0 | 120 | 0 | 0 |
| Heart model (closed loop) | 57 | 0 | 167 | 0 | 0 |
| ECG source (MIT-BIH 100 replay BRAM + templates) | 131 | 0 | 51 | 10 / 0 | 0 |
| ECG display (sweep, markers, text) | 736 | 220 | 352 | 2 / 1 | 0 |
| XBUS->APB bridge | 77 | 0 | 70 | 0 | 0 |
| Demo control APB (scenario, counters) | 114 | 0 | 164 | 0 | 0 |

## Stand-alone blocks, out-of-context synthesis at 100 MHz

| Block | LUT | FF | DSP | BRAM | WNS @ 100 MHz |
|---|---|---|---|---|---|
| ddd_pacemaker_apb | 197 | 120 | 0 | 0 | +1.570 ns |
| event_priority (professor-kit ESPRESSO SOP: 9 products / 34 literals, combinational) | 4 | 0 | 0 | 0 | +7.930 ns (in->out) |
| qrs_decision | 2,533 | 1,723 | 0 | 0 | +0.189 ns |
| heart_model | 109 | 167 | 0 | 0 | +5.207 ns |
| xbus_apb_bridge | 44 | 90 | 0 | 0 | +6.963 ns |

HLS blocks, Vitis export + Vivado place-and-route on xc7z010 (10 ns target):

| HLS block | LUT | FF | DSP | BRAM | Achieved clock |
|---|---|---|---|---|---|
| qrs_stream (per-sample, used on the board) | 571 | 563 | 3 | 0 | 7.689 ns (130 MHz) |
| qrs_filter (Phase-4 array version) | 852 | 1,054 (+191 SRL) | 4 | 0 | 8.598 ns (116 MHz) |

(Vitis HLS C-synthesis estimates were 144 MHz and 96.8 MHz; the
place-and-route numbers above are the real ones. The board only needs 25 MHz:
at 360 samples/s there are ~69,444 clocks per sample.)

## Power (Vivado report_power, post-route)

| Item | Power |
|---|---|
| **Total on-chip** | **0.360 W** |
| Dynamic | 0.262 W |
| - MMCM (125 -> 25/125 MHz) | 0.106 W |
| - I/O (mostly HDMI TMDS outputs) | 0.136 W |
| - logic + signals + clocks + BRAM + DSP | ~0.021 W |
| Device static | 0.097 W |
| Junction temperature | 29.1 C |

By hierarchy (dynamic): HDMI TX 0.132 W, detector 0.008 W, display 0.004 W,
ECG source 0.004 W, NEORV32 0.002 W.

How measured: this is Vivado's post-implementation power analysis with
default (vectorless) switching activity, so Vivado rates its confidence
"Low". It is not a measurement with a meter: the Zybo has no PL supply
current sensor. The pacemaker/detector logic itself is a tiny part
(~0.02 W); the clocking (MMCM) and HDMI I/O dominate, and those do not
depend much on switching activity.
