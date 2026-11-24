# Section 5 — Logic and FSM Optimisation: results (P17, VL401 report)

All files are in `report/work/fsm_logic/`. Nothing in the existing project was modified
(the RTL was copied). Python = project `.venv`; Vivado 2025.2 batch, part xc7z010clg400-1;
Yosys 0.71+59 / ABC from the YosysHQ OSS CAD Suite (2026-11-20 build).

## 5.1 State minimisation (DDD pacemaker controller)

**The specification-level STG.** Drawn the way a designer reads the pacemaker timing cycle, it
has one state per timing period:

- V–A interval:
  - **VRF**: VRP and PVARP both running
  - **PVA**: VRP over, PVARP running, so A is blanked
  - **VRO**: PVARP over, VRP running, so V is blanked (legal when PVARP < VRP)
  - **ALR**: both over; alert for an atrial sense, or AEI timeout gives AP
- A–V interval:
  - **AVD**: AV delay running
  - **URW**: AVI over, waiting for URI

It is a Mealy machine with one transition per 1 ms tick. The 7 inputs are a, v, r = t_v≥VRP,
b = t_v<PVARP, e = t_v≥AEI, m = t_av≥AVI, u = t_v≥URI; the 4 outputs are VS, VP, AS, AP. The
timers stay in the datapath; only their comparator outputs enter the FSM.

**Don't-cares.** Timers only grow inside an interval, so some inputs are impossible in some states
(r=0 in PVA/ALR, b=1 in VRO/ALR, m=0 in URW). That is 288 of the 768 table entries.

| Item | Value |
|---|---|
| Spec STG | 6 states, 7 inputs, 4 outputs; 240 KISS2 rows (complete) / 178 rows (don't-cares omitted) |
| Implication chart (incompletely specified, compatibility) | 15 pairs: 7 compatible, 8 incompatible in the first pass (outputs differ, e.g. input a v r b e m u = 0000011 gives AP in V-A states and VP in A-V states); no implied pairs, because the next state depends only on the current timer flags |
| Maximal compatibles | {VRF, PVA, VRO, ALR}, {AVD, URW}: they cover every state and the cover is closed |
| Partition method (complete machine) | P1 = P2 = {VRF,PVA,VRO,ALR} {AVD,URW}: stops after 2 passes |
| Professor's kit, `vl401.py` partition step (pure Python, run on Windows) | same 2 classes (`kit_partition_ddd_spec.txt`) |
| Minimised machine | **2 states, AEI and AVI = 1 flip-flop** (`ddd_min.kiss2`) |

The minimised machine is exactly the one phase bit of `rtl/ddd_pacemaker.v`.

**Equivalence checks.**
- **Product machine** with the RTL controller (phase bit plus its event logic), all 128 inputs:
  - 2-state result: equal outputs; the only reachable pairs are (AEI, phase 0) and (AVI, phase 1).
  - 6-state spec: equal on every care input; 6 reachable pairs.
- **Exhaustive exploration of the real timers** (phase, t_v, t_av, spec state; a and v free each
  tick), for 5 legal parameter sets from the `ddd_driver.c` range check: defaults; AEI < VRP;
  PVARP < VRP; URI = LRI; PVARP = VRP.
  - 249,822 reachable states in total; 999,288 transitions checked
  - **0 output mismatches, 0 don't-care violations**, so the don't-care assumptions are proven
    for these sets
- **Cross-check of the Python mirror** of `ddd_pacemaker.v` used above against
  `src/pacemaker.py`: 300,000 random ticks, 0 mismatches.

So the sub-states are redundant because the timer comparators already carry the blanking
information. The controller needs one flip-flop, and the RTL already uses exactly that.

The 8-phase `qrs_decision` controller is already minimal: the kit's partition step gives 8
classes for 8 states (`kit_partition_qrs_decision.txt`).

## 5.2 State encoding (8-phase FSM of `rtl/qrs_decision.v`)

**Exhaustive two-level cost of every 3-bit code** (IDLE = 000 fixed, 5,040 codes). Cost = exact
minimum SOP literals per output, from our own QM + branch-and-bound (`qm.py`,
`encoding_search.py`). All 8 codes are used, so there are no unused-code don't-cares.

| Encoding | Codes (IDL TRK CLS REG AVG LIM SBK END) | Next-state literals | Output literals | Total |
|---|---|---|---|---|
| Binary, as written | 000 001 010 011 100 101 110 111 | 21 | 25 | 46 |
| Gray chain | 000 001 011 010 110 111 101 100 | 26 | 25 | 51 |
| **Custom (exhaustive minimum)** | 000 001 010 100 011 110 111 101 | **17** | 25 | **42** |
| Worst of all 5,040 | 000 111 100 110 001 011 010 101 | 46 | 25 | 71 |

- Only 6 of the 5,040 codes reach 42.
- The output literals are fixed at 25: each phase enable is one full code.
- With the custom code, next-state bit n2 is just q1.
- The Gray chain is worse than binary because of the LIM branch and the SB → REG back-edge.

**On the FPGA (Vivado OOC, synth + place + route).** Vivado's `-fsm_extraction` re-encodes the
state register; `custom` and `as written` use `-fsm_extraction off`. The re-encoding was confirmed
from the synth log (see below).

Both tables report Slice LUTs from `report_utilization`; Fmax = 1/(T − WNS).

The 2,397 LUTs here are post-route, after `opt_design`. The 2,533 LUTs in
`results/stage8_zybo_resources_power.md` is the post-synthesis count from `vivado/ooc_blocks_zybo.tcl`.
All rows in these tables come from the same flow, so they compare with each other.

*(i) Whole `qrs_decision` (8-phase FSM + 40-bit datapath), clock target 10 ns.*

| Encoding (Vivado option) | State bits | Slice LUT | FF | WNS (ns) | Fmax (MHz) |
|---|---|---|---|---|---|
| Binary, as written (`off`) | 3 | 2,397 | 1,723 | +0.112 | 101.1 |
| auto (Vivado picks sequential) | 3 | 2,400 | 1,723 | −0.457 | 95.6 |
| sequential | 3 | 2,400 | 1,723 | −0.457 | 95.6 |
| gray | 3 | 2,413 | 1,723 | −0.130 | 98.7 |
| johnson | 4 | 2,506 | 1,726 | +0.158 | 101.6 |
| one-hot | 8 | 2,481 | 1,728 | +0.130 | 101.3 |
| custom (exhaustive minimum, `off`) | 3 | 2,401 | 1,725 | +0.015 | 100.2 |

*(ii) The 8-phase controller on its own (`vivado/qd_ctrl.v`), clock target 2.5 ns.*

| Encoding | State bits | Slice LUT (LUT cells) | FF | WNS (ns) | Fmax (MHz) |
|---|---|---|---|---|---|
| Binary, as written | 3 | 6 (11) | 3 | +0.820 | 595 |
| auto / sequential | 3 | 6 (11) | 3 | +0.822 | 596 |
| gray | 3 | 6 (11) | 3 | +0.754 | 573 |
| johnson | 4 | 9 (14) | 4 | +0.409 | 478 |
| one-hot | 8 | 5 (7) | 8 | −0.307 | 356 |
| custom (exhaustive minimum) | 3 | 6 (11) | 3 | +0.653 | 541 |

In (ii), Fmax above about 464 MHz is beyond the BUFG limit of a −1 part, so the 3-bit rows only
show the logic delay.

**Was the state register really re-encoded?** Yes. The synth log (`vivado_enc_qd.log`) prints
"encoded FSM with state register 'ph_reg' using encoding 'sequential' / 'gray' / 'johnson' /
'one-hot'" with the state table, for example one-hot P_IDLE = 00000001 … P_END = 10000000. The
flip-flop names confirm it (`FSM_onehot_ph_reg[7:0]`, `FSM_johnson_ph_reg[3:0]`, …). `auto`
chose `sequential`, which here keeps the written codes 000–111.

**What the numbers say:**
- **One-hot** costs 5 more FFs.
  - In the whole module it saves no LUTs: +84 Slice LUTs versus binary.
  - In the isolated controller it uses the fewest LUTs (5): the outputs come straight from the
    flip-flops.
  - It is the slowest there. Vivado builds it with a shared clock-enable: FF → LUT5 → LUT5 → CE,
    2 logic levels, fan-out 8. The binary-style codes need one LUT6/LUT5 per next-state bit
    (1 level).
- **Johnson** costs 1 more state FF and more decode LUTs.
- **On a 6-input-LUT FPGA, the two-level literal savings do not appear.** Every next-state bit is
  a function of 3 state bits + 3 inputs = 6 variables, which is always one LUT6. So binary, gray
  and the custom code all map to the same 6 Slice LUTs, even though the custom code has 17
  next-state literals versus 21 (binary) and 26 (gray).
- **In the whole module, the critical path is never the FSM.** It is the 40-bit THR1/NPKI
  arithmetic (15–22 logic levels, mostly CARRY4), ending at a register enable or data input. The
  encoding only changes the last decode LUT and the placement. That is why the whole-module Fmax
  spread is small (95.6–101.6 MHz) and not monotonic in the literal count. Even `sequential`,
  with the same codes as written, differs from `off` because the FSM flow re-synthesises the
  decode.
- **The FF counts above the state bits are synthesis fan-out replicas, not state bits**
  (`ff_names_*.txt`):
  - Johnson: `FSM_johnson_ph_reg[1]_rep` + `have_rr_reg_rep__6`
  - custom: `ph_reg[0]_rep` + `have_rr_reg_rep__6`

**The netlist matches the RTL for every encoding.** Each post-synthesis netlist of the isolated
controller was simulated (`sim_ctrl/run_net_all.bat`, unisims + glbl). Its 400-cycle trace,
driven by a pseudo-random LFSR input that reaches all 8 outputs, is **identical to the RTL trace
for all 7 encodings**. The RTL trace itself matches the Python model of the FSM (0 mismatches in
400 cycles).

**Lesson from a first attempt** (kept in `vivado/first_try_ctrl/`). The first `qd_ctrl.v` decoded
the outputs with `assign` statements outside the FSM `always` block. Vivado then:
- kept a second copy of the state register (6 FFs for sequential/gray, 7 for Johnson);
- refused to one-hot encode at all (3 FFs);
- printed a misleading "port … driven by constant 0" warning. The netlist simulation showed those
  ports toggling correctly.

The two-process style (register + one combinational next-state/output block) fixed all three.
`qrs_decision.v` uses `ph` only inside its own block, so it never had the problem.

**Functional check.** With the custom codes, the bit-exact detector testbench (`rtl/tb_qrs_detector.v`,
records 100 and 208) still passes: **814/814 detections match** the Python model
(`sim_custom/sim_custom.log`). The re-encoding changes no behaviour.

## 5.3 Two-level minimisation (event-priority block)

- The professor's kit (espresso, earlier Colab run) turned **148 ON rows into 9 products / 34
  literals**, and `-Dexact` gave the same cost.
- Our own QM (prime implicants from `src/event_priority.py`, imported) plus the covering table
  (`twolevel_qm.py`) gives:

| Output | ON minterms | Prime implicants | Essential | Covering table | After essentials | Cyclic core | Cover |
|---|---|---|---|---|---|---|---|
| VS | 64 | 1 | 1 | 64 × 1 | 0 × 0 | none | 1 product / 2 literals |
| VP | 24 | 2 | 2 | 24 × 2 | 0 × 0 | none | 2 / 8 |
| AS | 24 | 2 | 2 | 24 × 2 | 0 × 0 | none | 2 / 8 |
| AP | 36 | 4 | 4 | 36 × 4 | 0 × 0 | none | 4 / 16 |
| **Total** | 148 | 9 | 9 | | | | **9 products / 34 literals** |

- Every prime implicant is essential, so the covering table empties in one step. Row/column
  dominance and branch-and-bound are not needed (both are implemented in `qm.py`, and both were
  used in the encoding search).
- The cover is **identical, cube for cube, to espresso's** (`equals_espresso: true` for all 4
  outputs).
- No product is shared between outputs, so the multi-output minimum equals the sum of the
  single-output minima.

## 5.4 Multilevel optimisation

**Kernels and co-kernels** (own recursive kernel extraction, `kernels.py`; identical to the
kit/SIS list):

| Output | SOP (espresso) | Kernel (co-kernel) |
|---|---|---|
| VS | vr | none (single cube) |
| VP | pv'mu + pr'mu | v' + r' (pmu) |
| AS | p'av'b' + p'ar'b' | v' + r' (p'ab') |
| AP | p'a'v'e + p'a'r'e + p'v'eb + p'r'eb | v' + r' (p'a'e), v' + r' (p'eb), a' + b (p'v'e), a' + b (p'r'e), level-1: a'v' + a'r' + v'b + r'b (p'e) |

**Literal counts:**

| Network | Literals | Note |
|---|---|---|
| Two-level SOP (espresso) | 34 | 9 cubes; ABC `collapse; sop` gives the same 34 |
| Factored form | 18 | SIS and ABC `lit(fac)` |
| Common-kernel extraction (t4 = r'+v' shared by VP/AS/AP, t5 = a'+b in AP) | 18 | own extraction = kit `gkx` |
| **SIS `script.rugged`** | **14** | VP = VS'mpu, AS = VS'ab'p', AP = VS'AS'ep'. Boolean resubstitution sees that t4 = r'+v' = VS' and that, given p' VS', a'+b = AS'. Algebraic kernels cannot find this. |
| ABC `fx` (fast extract) | 16 | 7 nodes, 3 levels: n17 = vr, n18 = ab', n19 = p'n17', vp = n17'upm, as = n18 n19, ap = n19 e n18'. Same priority-chain structure. |
| ABC `resyn2; renode; sop` | 18 | 9 two-input nodes, 3 levels |

**Yosys + ABC mapping of `rtl/event_priority.v`:**

| Command | Result |
|---|---|
| `abc -g AND,OR` | 8 AND2 + 2 OR2 + 6 NOT |
| `abc -g cmos2` | 6 NAND2 + 3 NOR2 + 3 NOT |
| **`abc -lut 6`** | **4 LUTs**, the same as Vivado's 4 LUTs (OOC, +7.93 ns at 100 MHz) |

Each output has at most 8 inputs, and VP/AS/AP need only 5–7 of them, so on an FPGA one LUT6 per
output is the floor.

## Reproduce

```
.venv\Scripts\python report\work\fsm_logic\ddd_spec_stg.py       # 5.1 STG, chart, partition, checks, figures
.venv\Scripts\python report\work\fsm_logic\encoding_search.py    # 5.2 exhaustive two-level encoding cost
report\work\fsm_logic\vivado\run_enc.bat qd                      # 5.2 Vivado, whole qrs_decision (10 ns)
report\work\fsm_logic\vivado\run_enc.bat ctrl                    # 5.2 Vivado, isolated controller (2.5 ns)
report\work\fsm_logic\sim_custom\run_sim_custom.bat              # 5.2 custom code still bit-exact
report\work\fsm_logic\sim_ctrl\run_rtl.bat                       # 5.2 controller RTL trace (400 cycles)
report\work\fsm_logic\sim_ctrl\run_net_all.bat                   # 5.2 all 7 netlists == RTL trace
report\work\fsm_logic\vivado\run_ffdiff.bat                      # 5.2 which extra FFs (replicas)
.venv\Scripts\python report\work\fsm_logic\twolevel_qm.py        # 5.3 QM covering table
.venv\Scripts\python report\work\fsm_logic\kernels.py            # 5.4 kernels
report\work\fsm_logic\yosys\run_yosys.bat                        # 5.4 Yosys + ABC
```

Still to run in Colab with the kit's Linux binaries: STAMINA, NOVA, JEDI and the kit's espresso
encoding cost. The exact commands are in `COLAB_COMMANDS.md`.

## Figures

- `fig_ddd_stg_minimisation.pdf/.png`: the 6-state spec STG, grouped, and the minimised 2-state
  machine (= RTL phase bit). 6.3 × 2.35 in.
- `fig_ddd_implication_chart.pdf/.png`: implication chart, 6 states (OK / X). 3.1 × 2.5 in.

## Data files

- `ddd_spec_results.json`: every number in 5.1
- `encoding_search.json`
- `vivado/enc_results_{qd,ctrl}.txt` (their LUT column = LUT primitive cells, not Slice LUTs),
  `vivado/util_*.rpt`, `vivado/timing_*.rpt`, `vivado/vivado_enc_*.log`, `vivado/ff_names_*.txt`
- `vivado/first_try_ctrl/`: the first controller version's run (assign-decoded outputs, see the lesson above)
- `sim_ctrl/net/net_*.v` (netlists), `sim_ctrl/trace_rtl.txt`
- `sim_custom/sim_custom.log`
- `kit_partition_*.txt`
- `*.kiss2`, `*.fsm`
- `twolevel_qm.json`
- `kernels.json`
- `yosys/stat_*.txt`, `yosys/abc_ep.log`, `yosys/ep_abc_*.eqn`
