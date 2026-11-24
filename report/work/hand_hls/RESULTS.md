# Hand HLS of the per-sample Pan–Tompkins kernel (report Section 4)

Kernel: one 360 Hz sample of the filter chain in `hls/qrs_stream.cpp`. That is the low-pass,
the high-pass with a 32-tap running sum, the derivative, one squarer, and the 54-tap MWI running sum.
All numbers below are computed by `hand_hls.py` or measured with Vivado 2025.2 on
xc7z010clg400-1 (Zybo Z7-10), 20 Nov 2026. Nothing is estimated unless it says so.

## (a) CDFG and transformations

Figure `fig/cdfg.pdf`: (a) control flow of one call (IDLE → read state/buffer taps → DFG body →
write buffers/update state/pointers → DONE → next sample); (b) DFG of the final kernel, nodes placed
at their ASAP step, with the definition of every node.

Starting point: the original Pan–Tompkins equations written directly at 360 Hz:
- constant multiplications by 2, 1/8, 1/32 and 1/N;
- the high-pass as a direct 32-tap mean, hp = lp[n−16] − (1/32)·Σ₀³¹ lp[n−k];
- the MWI as a direct 54-term sum with 1/N.

The script builds each DFG and counts operations. The critical path is in control steps,
using the step rules of (b): add/sub = 1 step, multiply = 1 step, no chaining. The centring
subtraction x − baseline is included in every version. Each row of the table includes all
the transformations above it:

| Version | #Mult | #Add/Sub | Critical path (steps) |
|---|---|---|---|
| Original direct form | 8 | 93 | 98 |
| + strength reduction (×2, /8, /32 → shifts) | 2 | 93 | 94 |
| + constant folding (1/N folded into the thresholds) | 1 | 93 | 93 |
| + running-sum recurrence (HPF 31→2 adds, MWI 53→2 adds) | 1 | 13 | 14 |
| + tree-height reduction / reassociation (final kernel) | 1 | 13 | 8 |

The four transformations:

- **Strength reduction:** the five power-of-two constant multiplies become wiring.
- **Constant folding:** 1/N is dropped because the adaptive thresholds are learned from the
  same unnormalised MWI, so every decision is unchanged. `src/pan_tompkins_fixed.py` already works this way.
- **Recurrence:** Σ over a sliding window = previous Σ + newest − oldest. This is the largest saving:
  80 adders are removed and the path drops from 93 to 14 steps.
- **Tree-height reduction:** precompute everything that does not depend on the new sample,
  in parallel:
  - (2lp1 − lp2) and (x12 − 2x6);
  - (ms − lp32);
  - (h1 − h3 − 2h4), which is also the factored form of the derivative;
  - (mwi − sq54).

  The new sample then passes through only xc → lp → ms' → hp → dv → sq → mwi', 8 steps.

All arithmetic is modulo 2³² (2⁴⁰ for the MWI), so reassociation is bit-exact. The RTL in (e) proves it.
The running-sum row is exactly the left-to-right operation order written in `hls/qrs_stream.cpp`;
the final row is the same kernel re-associated.

## (b) Operator library (xc7z010clg400-1, measured)

Each operator sits between input and output registers, and was synthesised, placed and routed
out of context with a 10 ns clock (`oplib/`). FF counts include the test registers. Minimum
period = 10 ns − worst setup slack.

| Operator | LUT | FF (test regs) | DSP | CARRY4 | Min. period (ns) |
|---|---|---|---|---|---|
| 32-bit add | 32 | 96 | 0 | 8 | 2.96 |
| 40-bit add/sub (ALU) | 40 | 121 | 0 | 10 | 4.02 |
| 32×32→32 multiply (= the squarer, low 32 bits) | 15 | 17 | 3 | 4 | 5.69 * |
| 33×33→66 full multiply (reference) | 49 | 34 | 4 | 13 | 5.69 * |
| 64×32 LUT-RAM, async read (registered addr/out) | 44 (all LUTRAM) | 38 | 0 | 0 | 2.35 |
| 4:1 × 32-bit operand mux | 32 | 162 | 0 | 0 | 2.30 |

\* Stand-alone, Vivado moves the test registers into the DSP48E1 A/B/P registers, so the
5.69 ns is one DSP-to-DSP hop. Inside the FSMD the operand register (`dv_out`) also drives
an output port, so the whole product runs in one step: **9.05 ns, measured** (critical path of
the min-latency FSMD, DSP → fabric adder → R1).

Control-step rules adopted (10 ns step at 100 MHz):
- one add/sub per FU per step, including its operand mux and a LUT-RAM read
  (2.30 + 4.02 + 2.35 ≈ 8.7 ns);
- no chaining of two adders (> 10 ns);
- the squarer takes 1 step, with nothing chained after it.

The FSMD critical paths in (e) confirm these rules: 8.60 ns for an add step, 9.05 ns for the multiply step.

## (c) Scheduling of the final DFG (14 operations: 13 ALU + 1 MUL; latency bound L = 8)

| op | xc | u1 | u2 | u3 | lp | v1 | ms' | hp | w1 | w2 | dv | sq | m1 | mwi' |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ASAP | 1 | 1 | 1 | 2 | 3 | 1 | 4 | 5 | 1 | 2 | 6 | 7 | 1 | 8 |
| ALAP | 2 | 1 | 1 | 2 | 3 | 3 | 4 | 5 | 4 | 5 | 6 | 7 | 7 | 8 |
| Mobility | 1 | 0 | 0 | 0 | 0 | 2 | 0 | 0 | 3 | 3 | 0 | 0 | 6 | 0 |

- **Critical path** (mobility 0): u1/u2 → u3 → lp → ms' → hp → dv → sq → mwi'.
  ASAP needs 6 ALUs in step 1.
- **List scheduling** (priority = longest path to sink):
  - 1 ALU + 1 MUL: **13 steps**.
  - 3 ALU + 1 MUL: **8 steps**.
  - 2 ALU + 1 MUL: also **8 steps**.
- **ILP** (`scipy.optimize.milp`, time-indexed binary x[op,step]):
  - Time-constrained: the minimum number of ALUs is 2 for every L = 8…12, and 1 for L = 13.
  - Resource-constrained: the minimum latency is 13 with 1 ALU and 8 with 2 ALUs.

  So both list schedules are optimal, and the third ALU is never needed.

Figure `fig/schedule.pdf`: Gantt charts of the min-area (1 ALU, 13 steps) and min-latency
(2 ALU, 8 steps) schedules.

## (d) Allocation and binding

**Registers (left-edge).** The left-edge algorithm runs on value lifetimes [first step held, last
step read]. Results written straight into an architectural register at the end of their step need no
temporary: lp → lp1, ms' → ms, hp → hp_out, dv → dv_out, mwi' → mwi_out. The same holds for the
buffer writes. Running left-edge on all values gives the same counts.

- Min-area (13 steps): **3 temporaries**
  - R0 = {u1, u3, v1, w1, w2, sq}
  - R1 = {u2, m1} (40 bits)
  - R2 = {xc}
- Min-latency (8 steps): **2 temporaries**
  - R0 = {u1, xc, v1, w1, w2, m1} (40 bits)
  - R1 = {u2, u3, sq}

**Functional units (clique partitioning, Tseng–Siewiorek, networkx).** In the compatibility graph of
the 13 ALU operations, two operations are compatible if they run in different steps. The 2-ALU
schedule has 72 edges, and the partition gives **2 cliques**:

- ALU0 = {xc, u1, lp, ms', hp, dv}
- ALU1 = {u2, u3, v1, w1, w2, m1, mwi'}

A tie-break keeps the two 40-bit MWI operations on the same unit, so only ALU1 needs 40 bits
and ALU0 is 32 bits. The 1-ALU schedule gives a single clique, as expected.

Figure `fig/compat.pdf`: the compatibility graph, coloured by clique (= ALU instance).

## (e) FSMD and design points (RTL written by hand from the schedules above)

- `rtl/qrs_fsmd_area.v`: 1 × 40-bit ALU + 1 squarer, 13 control steps (+ IDLE). R0–R2 as bound
  above. The four circular buffers are LUT-RAM; shared read ports for lpbuf and hpbuf.
- `rtl/qrs_fsmd_lat.v`: ALU0 (32-bit) + ALU1 (40-bit) + 1 squarer, 8 control steps (+ IDLE),
  R0–R1 as bound above.

Interface for both: x, baseline and start in; done, hp, dv and mwi out. This is the same function as
the Vitis HLS `qrs_stream`.

**Verification (xsim, `sim/run_sim.bat`).** Both designs ran on 20,000 samples of MIT-BIH record 100
and were compared with the Python fixed-point golden model (`src/pan_tompkins_fixed.py`,
vectors from `hls/tb_data`):

- `qrs_fsmd_area`: 20,000 samples, **0 mismatches** (hp, dv, mwi), start→done 14 cycles: BIT-EXACT PASS.
- `qrs_fsmd_lat`: 20,000 samples, **0 mismatches**, start→done 9 cycles: BIT-EXACT PASS.

**Implementation (`impl/run_impl.bat`).** Out-of-context synthesis, place and route on
xc7z010clg400-1, `create_clock 10 ns`, 0 ns input/output delays so the port paths are timed too.
Fmax = 1000 / (10 − WNS).

| Design point | LUT (logic + LUTRAM) | FF | DSP | BRAM | WNS (ns) | F_max (MHz) | Latency (cycles) | Latency (ns) @100 MHz |
|---|---|---|---|---|---|---|---|---|
| Hand FSMD, min-latency (2 ALU + 1 MUL) | 643 (467 + 176) | 290 | 3 | 0 | +0.941 | 110.4 | 8 | 80 |
| Hand FSMD, min-area (1 ALU + 1 MUL) | 670 (494 + 176) | 345 | 3 | 0 | +0.735 | 107.9 | 13 | 130 |
| Vitis HLS `qrs_stream` (reference, board version) | 571 (409 + 162) | 563 | 3 | 0 | +2.311 (7.689 ns) | 130.1 | 7 (II 8) | 70 |

Latency counts the control steps. Start→done adds one handshake cycle (14 and 9, measured in xsim).
The HLS row is re-read from:

- `hls/qrs_stream_hls/sol1/impl/report/verilog/qrs_stream_export.rpt`: 571 LUT, 563 FF, 3 DSP, 7.689 ns post-route;
- the placed utilization report: 409 logic + 162 LUTRAM;
- `syn/report/qrs_stream_csynth.rpt`: latency 7, interval 8.

Notes for the discussion (all from the measured numbers):
- **The "min-area" schedule is not the smallest design on the FPGA.**
  - Sharing one 40-bit adder across 13 operations needs two 13-input × 40-bit operand
    multiplexers. On a LUT-based FPGA they cost more than a second adder: a 32-bit adder is 32 LUTs,
    while a 4:1 × 32 mux alone is 32 LUTs.
  - So the 1-ALU design uses **27 more logic LUTs** and **55 more FFs** than the 2-ALU one, and is
    5 cycles slower.
  - On this target the 2-ALU, 8-step schedule dominates in both area and latency. Minimising the number
    of FUs is the right cost model for ASICs or for expensive operators such as DSP multipliers;
    on an FPGA, interconnect has to be part of the binding cost.
  - Part of the FF difference is the extra temporary (R2, 32 FF) and the 40-bit R1. The
    remaining ~23 FF come from Vivado's register mapping and were not analysed further.
- Both designs use 3 DSP48E1 for the 32×32→32 squarer, the same as HLS. HLS narrowed the operand
  to 29 bits (`mul_29s_29s_32_2_1`, 2-cycle pipelined) but still needs 3 DSPs.
- The Vitis HLS core is faster in cycles (7) because it chains operations within a cycle and
  pipelines the multiplier. It is also smaller in logic LUTs (409 vs 467), but it uses about twice
  the FFs (563).
- Every design point needs at most 13 cycles per sample, against the ~69,000 clock cycles available
  between 360 Hz samples at 25 MHz on the board. The choice is about area, not throughput.

## Files

| File | What |
|---|---|
| `hand_hls.py` | DFG versions, op counts, critical paths, ASAP/ALAP, list scheduling, ILP, left-edge, clique partitioning, figures |
| `results.json`, `analysis_mul1.txt` | all computed tables (MUL_STEPS = 1) |
| `oplib/ops.v`, `oplib/oplib.tcl`, `oplib/oplib_results.txt`, `oplib/oplib_minperiod.txt`, `oplib/oplib_lutram.txt`, `oplib/timing_*.rpt` | operator library characterisation |
| `rtl/qrs_fsmd_area.v`, `rtl/qrs_fsmd_lat.v` | the two hand-written FSMDs |
| `sim/tb_fsmd.v`, `sim/tbA.v`, `sim/tbB.v`, `sim/run_sim.bat`, `sim/sim.log` | bit-exact testbench and log |
| `impl/impl.tcl`, `impl/impl_results.txt`, `impl/*_util.rpt`, `impl/*_timing.rpt`, `impl/*_paths.rpt` | P&R results |
| `fig/cdfg.pdf/.png`, `fig/schedule.pdf/.png`, `fig/compat.pdf/.png` | figures (DejaVu Serif, ≤ 6.2 in wide) |

## How to reproduce (from `report\work\hand_hls`)

```
..\..\..\.venv\Scripts\python hand_hls.py        # tables + figures (results.json)
oplib\run_oplib.bat                              # operator library (oplib_results.txt)
oplib\run_oplib_lutram.bat                       # LUT-RAM read with ram_style=distributed
sim\run_sim.bat                                  # xsim: both FSMDs bit-exact vs golden model
impl\run_impl.bat                                # OOC synth + P&R of both FSMDs (impl_results.txt)
```

Honesty notes:
- In `oplib_results.txt` the multiplier rows report data-path delay only; use
  `oplib_minperiod.txt`, which accounts for the DSP setup time.
- The first `op_lutram64` run in `oplib_results.txt` inferred a block RAM and is superseded by
  `oplib_lutram.txt`.
- WNS comes from out-of-context implementation with ideal 0 ns I/O delays, not from the full SoC.
