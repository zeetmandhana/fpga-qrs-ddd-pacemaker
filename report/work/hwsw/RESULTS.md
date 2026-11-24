# HW/SW comparison on the board's RV32 core (template Section 6.3)

All numbers are **measured in RTL simulation (xsim, Vivado 2025.2)** of the real
designs, in clock cycles at the board clock (25 MHz). Nothing is estimated except
where marked.

- **SW:** the detector in C, run on the board's NEORV32 v1.13.2 configuration
  (`rtl/neorv32_p17.vhd`: rv32i + Zicsr + Zifencei + Zicntr, **no M extension**,
  16 KB IMEM, 8 KB DMEM, XBUS). Compiled with the same gcc 15.2 flags as the
  board firmware (`-march=rv32i_zicsr_zifencei -mabi=ilp32 -Os`). Timed with
  `mcycle`/`minstret` around each function.
- **HW:** the same detector RTL that runs on the Zybo: the Vitis-HLS
  `qrs_stream` IP plus the RTL `qrs_decision` FSM (`rtl/qrs_detector.v`).

## Result

| Path (per 360 Hz sample) | Cycles mean | min | max | Time at 25 MHz (mean / max) | Speed-up (mean) |
|---|---|---|---|---|---|
| SW filter chain (C port of `qrs_stream.cpp`, squarer = libgcc `__mulsi3`) | 898.8 | 526 | 1,195 | 35.9 µs / 47.8 µs | – |
| HW filter chain (HLS `qrs_stream` + input register + output capture) | 10 | 10 | 10 | 0.40 µs | **89.9×** |
| – of which the HLS core, `ap_start` → `ap_done` | 7 | 7 | 7 | 0.28 µs | (Vitis report: latency 7, II 8) |
| SW decision (C port of `HwQrsDecision.step`) | 484.6 | 368 | 2,531 | 19.4 µs / 101.2 µs | – |
| HW decision (`qrs_decision` FSM, 7 phases, or 8 with the search-back phase) | 8.0 | 7 | 8 | 0.32 µs | **60.6×** |
| **SW total** | **1,383.4** | 902 | 3,712 | **55.3 µs** / 148.5 µs | – |
| **HW total** (sample accepted → decision FSM idle) | **18.0** | 17 | 18 | **0.72 µs** | **76.9×** (worst case 3,712/18 = **206×**) |
| One CPU read over XBUS → APB bridge → APB register | 7 | 7 | 7 | 0.28 µs | – |

The table rounds 17.997 to 18.0 and 7.997 to 8.0 (exact means over 100,000 samples).

**Instructions and CPI (SW).**

| Stage | Instructions mean | Range | CPI |
|---|---|---|---|
| Filter | 247.9 | 144–331 | 3.63 |
| Decision | 96.0 | 73–587 | 5.05 |
| Overall | – | – | 4.02 |

The NEORV32 is a multi-cycle core.

**CPU load at 360 samples/s and 25 MHz** (69,444 clocks per sample):

| Configuration | CPU load |
|---|---|
| Software only, mean | 1,383.4 × 360 / 25 MHz = **1.99 %** |
| Software only, if every sample hit the worst case | 5.35 % |
| With the hardware detector, if the CPU fetched each result (one APB read) | 0.010 % |
| With the hardware detector, as on the board | **0** |

On the board the CPU does no per-sample work: the detector drives the pacemaker's
V-sense directly.

**Amdahl's law** for a per-sample loop that still moves one word over the bus
(7 cycles, not accelerated):

| Quantity | Value |
|---|---|
| Software loop | 7 + 1,383.4 = 1,390.4 cycles |
| Hardware-assisted loop, CPU waits for the result | 7 + 18.0 = 25.0 cycles |
| Accelerated fraction f | 1,383.4 / 1,390.4 = **99.5 %** |
| Kernel speed-up S | 76.9× |
| Overall speed-up 1 / ((1 − f) + f/S) | **55.6×** |
| Upper bound, even with a zero-cycle accelerator | 1,390.4 / 7 = **199×** |

The bus access is what limits the whole-loop gain.

## Correctness check (apples to apples)

- **Filter outputs:** the SW `hp`, `dv` and `mwi` outputs equal the golden
  bit-exact model for all 2,048 samples (0 mismatches). The golden model is
  `src/pan_tompkins_fixed.py::fixed_filter_chain`, which matches the HLS C-sim
  and RTL.
- **Detections:** SW detections equal the golden `src/qrs_hw_detector.py`
  events exactly. There are 5 detections (sample, R index): (738, 662),
  (1022, 946), (1306, 1231), (1590, 1515), (1884, 1809), none from search-back.
- **HW run:** 100,000 samples of record 100, 341 detections. RTL = golden,
  0 mismatches, so the counted cycles come from a correct run.
- **APB read:** the timed read returned the demo-control ID 0x5017_0001 every
  time.

## Notes

- **Different block lengths.** SW was measured on the first 2,048 samples of
  record 100 (5.7 s, including the 720-sample learning phase and 5 detections).
  HW was measured on 100,000 samples. HW cycles are data-independent (filter
  always 10, decision 7 or 8), so the block length does not matter for HW. The
  SW mean depends on the data mix.
- **Why the SW filter cost varies with the data.** With no M extension, the
  single multiply becomes a libgcc `__mulsi3` shift-add loop that runs once per
  bit of the unsigned multiplier. A negative derivative gives `(uint32)d` 32
  bits, so 32 iterations, while a small positive one needs only a few. That is
  the whole 526–1,195-cycle spread. The hardware squarer (DSP) takes fixed time.
- **Where the SW decision peaks.** The worst case (2,531 cycles) is on samples
  where a QRS is registered: shifting and summing the two 8-deep RR buffers and
  doing 64-bit arithmetic on a 32-bit core. Once, at sample 719, gcc `-Os` turned
  the shift-add `91·lsum` into a `__muldi3` call (1,301 cycles on that sample).
- **Measurement overhead.** An empty timed window costs 6 cycles and 2
  instructions (mailbox calibration records). This is subtracted from every SW
  number.
- **Timed windows exclude the mailbox writes.** IMEM and DMEM have no wait
  states, so cycle counts do not depend on the clock frequency.
- **Not measured:** a core with the M extension (would cut the filter cost),
  `-O2`/`-O3` builds, and power or energy per sample.
- **Honest takeaway.** At 360 Hz the plain software would also meet real time
  (about 2 % CPU). The hardware's value is:
  - a deterministic 18-cycle latency instead of 902–3,712 data-dependent cycles;
  - freeing the CPU completely (0 per-sample work on the board);
  - roughly 77× on the per-sample kernel.
- **Out of scope, for the parent agent.** `rtl/firmware/build_p17_fw.bat` and
  `rtl/run_top_sim.bat` point at `C:\fpga\neorv32`, which no longer exists on
  this machine. The same NEORV32 v1.13.2 tree is now at `C:\NEORV32\neorv32`
  (hw_version 0x01130200), and this benchmark uses that path. The project files
  were left unchanged.

## How to reproduce (from `report/work/hwsw`)

```
..\..\..\.venv\Scripts\python gen_vectors.py 2048     # fw\samples.h + golden_filter.txt + golden_events.txt
fw\build_bench.bat                                    # firmware -> fw\build\neorv32_imem_image.vhd
python make_sim_bat.py                                # writes run_sw_sim.bat (NEORV32 compile order)
run_sw_sim.bat                                        # NEORV32 xsim, ~3 min -> sw_sim\sw_dump.txt
run_hw_sim.bat                                        # detector xsim, ~1 min -> HWCYC lines
..\..\..\.venv\Scripts\python analyze.py              # -> results.json + summary
```

(The `run_hw_sim.bat` console output was saved as `run_hw_sim.log`, which `analyze.py` reads.)

## Files

| File | Purpose |
|---|---|
| `gen_vectors.py` | inputs and golden outputs from the project's bit-exact models |
| `fw/hwsw_bench.c` | C ports of `qrs_stream.cpp` and `HwQrsDecision.step`, plus the mcycle/minstret harness |
| `fw/samples.h` | generated input samples |
| `fw/build_bench.bat` | firmware build, same flags as `build_p17_fw.bat`; produces `fw/build/main.asm` |
| `tb_sw_bench.v` | NEORV32 + board XBUS→APB bridge + `demo_ctrl_apb` + mailbox |
| `neorv32_p17.vhd` | unchanged copy of the board wrapper |
| `make_sim_bat.py`, `run_sw_sim.bat` | software-side simulation |
| `sw_sim/sw_dump.txt` | raw mailbox words from the software run |
| `tb_hw_cycles.v`, `run_hw_sim.bat`, `run_hw_sim.log` | hardware-side cycle counting with a bit-exact check |
| `analyze.py`, `results.json` | final numbers |
