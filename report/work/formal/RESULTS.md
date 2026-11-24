# Section 8 Formal Verification: results (all runs real, 2026-11-20)

The RTL used is the current `rtl/ddd_pacemaker.v` (sha256 prefix `c9fcecaf1b2f2514`). That version includes the two fixes made by the main session after constrained-random simulation:

- the controller is held in its start state while disabled;
- `t_v` saturates at LRI+1.

The NuSMV model, the mutants and the SBY copies were all regenerated from this version.

**Tools:**
- NuSMV 2.7.1 (win64, from nusmv.fbk.eu, sha256 checked).
- OSS CAD Suite 2026-11-20: Yosys 0.71+59, SymbiYosys, Yices / Boolector / Bitwuzla / ABC.
- Python `dd` 0.6.0.
- Vivado 2025.2 xsim.

---

## (a) Kripke structure and hand-run CTL labelling (`kripke/`, fig_kripke.pdf)

**The structure.** The DDD controller is abstracted with the same tick values as the NuSMV model (AVI 2, VRP 3, PVARP 4, URI 5, LRI 10, AEI 8), with one tick per Kripke step. The heart has complete AV block, plus a retrograde P wave at VA = 3 that may or may not conduct (one nondeterministic branch). Bug 1 is active (PVARP blanking off), so the retrograde P can be sensed.

The result is 16 states and 17 edges:

- an entry path s0→s1(AP)→s2→s3(VP, slow);
- a fork at s5:
  - the PMT loop: s7(AS) → s9 → s11(VP at URI, upper) → s4;
  - the normal loop: s6 → … → s14(AP) → s15 → s3.

**Labels:**
- `upper` = V beat with tv ≤ URI (s11);
- `slow_vbeat` = V beat that is not upper (s3);
- `AS` holds in s7.

**φ1 = E[ ¬upper U AS ]** (least fixpoint: Z0 = [AS], then Z(k+1) = Z(k) ∪ ([¬upper] ∩ pre∃(Z(k)))):

```
Z0 = {s7}
Z1 = Z0 + {s5}       Z2 = Z1 + {s4}        Z3 = Z2 + {s3}
Z4 = Z3 + {s2,s15}   Z5 = Z4 + {s1,s14}    Z6 = Z5 + {s0,s13}
Z7 = Z6 + {s12}      Z8 = Z7 + {s10}       Z9 = Z8 + {s8}     Z10 = Z9 + {s6}
fixpoint: all 14 states except {s9, s11}; holds at s0 (the PMT entry is reachable from reset)
```

**φ2 = EG ¬slow_vbeat** (greatest fixpoint: Z0 = [¬slow], then Z(k+1) = Z(k) ∩ pre∃(Z(k))):

```
Z0 = all except {s3}
Z1 = Z0 - {s2,s15}   Z2 = Z1 - {s1,s14}   Z3 = Z2 - {s0,s13}
Z4 = Z3 - {s12}      Z5 = Z4 - {s10}      Z6 = Z5 - {s8}     Z7 = Z6 - {s6}
fixpoint: {s4, s5, s7, s9, s11}, which is exactly the PMT loop. It fails at s0.
```

**NuSMV check.** NuSMV ran on an explicit copy of the graph (`kripke_hand.smv`), with every state initial and one spec `s = k -> φ` per state. **Both sets match the hand labelling exactly** (`kripke_hand.txt`).

**Why this matters.** EF EG ¬slow_vbeat holds at s0, which is exactly why AG AF slow_vbeat (P11) fails under bug 1.

---

## (b) NuSMV model and CTL properties (`gen_smv.py`, `ddd_*.smv`, `nusmv_*.out`)

**The model.** It is register-level and mirrors `rtl/ddd_pacemaker.v`:

- **State variables:** the RTL registers `phase`, `t_v` (0..11, saturating at LRI+1) and `t_av`.
- **Free inputs** (modelled as state variables): `tick` (the 1 ms strobe), `a` and `v` (intrinsic heart events).
- **Per-tick decision:** the event priority VS > VP > AS > AP, written as DEFINEs exactly like the RTL's blocking assignments. Because of this, NuSMV traces replay on the RTL cycle for cycle.
- **Over-approximating heart:** `a` and `v` are free on every tick, so the proofs cover every possible heart behaviour.
- **Size:** 168 reachable states out of 2,112, diameter 11. Each run takes about 50 ms.

| # | Type | CTL formula | no fairness | FAIRNESS tick |
|---|---|---|---|---|
| P0 | Abstraction check | AG t_av ≤ 4 | true | true |
| P1 | Safety | AG ¬(AP ∧ VP) | true | true |
| P2 | Safety (upper rate) | AG (VP → tv ≥ URI) | true | true |
| P3 | Safety (PVARP) | AG (AS → tv ≥ PVARP) | true | true |
| P4 | Safety (VRP) | AG (VS → tv ≥ VRP) | true | true |
| P5 | Safety (AV delay) | AG (VP → tav ≥ AVI) | true | true |
| P6 | Safety (escape) | AG (AP → tv ≥ AEI) | true | true |
| P7 | Reachability | EF AP ∧ EF VP ∧ EF AS ∧ EF VS | true | true |
| P8 | Non-blocking | AG EF phase = AEI | true | true |
| P9 | Liveness | AG AF (VS ∨ VP) | **false** | true |
| P10 | Until | AG ((AS ∨ AP) → AX A[ ¬(AS ∨ AP) U (VS ∨ VP) ]) | **false** | true |
| P11 | PMT freedom (AV block + retrograde VA = 3 heart) | AG AF slow_vbeat | — | true (correct PVARP) / **false** (bug 1) |

**Why fairness is needed.** `tick` is a free input, so the 1 ms timebase may stop.

- **P9 without fairness:** NuSMV returns a lasso that loops at the reset state with tick = FALSE forever.
- **P10 without fairness:** AP happens, then tick = FALSE forever in the AVI phase.

`FAIRNESS tick` models a working timebase (the hardware divider always produces the 1 ms tick), and both properties then hold.

**Why the abstraction is safe.** P0 shows that bounding `t_av` to 0..10 never cuts a reachable behaviour (the maximum is 4).

**An observation.** P2 holds even with bug 1. With these parameters PVARP + AVI ≥ URI, so the URI check is also implied by the blanking.

---

## (c) Bug injection, counterexamples, replay in simulation (`cex/`, `replay/`, fig_replay.pdf)

The mutants are one-line edits of COPIES of `rtl/ddd_pacemaker.v`:

- **Bug 1:** `blanked = (tv < pvarp)` becomes `blanked = 1'b0` (PVARP blanking removed).
- **Bug 2:** `if (v_sense_in && (tv >= vrp))` becomes `if (v_sense_in)` (VRP blanking removed).

### NuSMV verdicts

| Bug | Property | Verdict |
|---|---|---|
| Bug 1, over-approximating heart | P3 | false |
| Bug 1, PMT heart | P11 | false |
| Bug 2, over-approximating heart | P4 | false |

All other properties stay true.

### Bug 1 / P11: the PMT lasso (11 states, loop back to state 5)

```
 1 tick=0              AEI t_v=10
 2 tick=1              AEI t_v=10  tv=11  AP
 3 tick=1              AVI t_v=11
 4 tick=1              AVI t_v=11  t_av=1 VP          (slow beat)
 5 <loop tick=0        AEI t_v=0
 6 tick=1              AEI t_v=0
 7 tick=1              AEI t_v=1
 8 tick=1 a=1          AEI t_v=2   tv=3   AS          (retrograde P sensed inside PVARP)
 9 tick=1              AVI t_v=3
10 tick=1              AVI t_v=4   tv=5   VP upper    (paced at URI)
11 tick=0              AEI t_v=0   -> back to 5: every beat at the upper rate forever
```

### Bug 2 / P4 (3 states)

The trace is VS at tick 1, then `v` again on the next tick, which gives VS with tv = 1 < VRP = 3. The arrhythmia flag is also raised.

### Replay in xsim

`replay/run_replay.bat` with `tb_replay.v` drives one NuSMV state per clock (tick, a, v → tick_en, a_sense_in, v_sense_in). Before each edge it checks the RTL registers (phase, t_v, t_av); after the edge it checks the outputs (ap, vp, as_evt, vs_evt).

| Trace | RTL | Cycles | Output / register mismatches | Monitors |
|---|---|---|---|---|
| bug1_pmt_P11 (loop unrolled 4×) | bug-1 mutant | 34 | **0 / 0** | AS inside PVARP: 5; upper-rate V beats: 5 of 6 |
| bug1_pmt_P11 | correct RTL | 34 | diverges at cycle 7 (AS rejected, t_v = 3 < PVARP) | 0 violations |
| bug1_oa_P3 | bug-1 mutant | 3 | **0 / 0** | AS inside PVARP: 1 |
| bug1_oa_P3 | correct RTL | 3 | diverges at cycle 2 | 0 violations |
| bug2_oa_P4 | bug-2 mutant | 3 | **0 / 0** | VS inside VRP: 1 |
| bug2_oa_P4 | correct RTL | 3 | diverges at cycle 2 | 0 violations |

**Closed loop** (`tb_pmt_closed.v`, same heart as the NuSMV PMT model, 40 ticks; this is fig_replay.pdf):

| RTL | V beats | at the upper rate | Behaviour |
|---|---|---|---|
| Bug-1 mutant | 8 | 7 | PMT |
| Correct RTL | 4 | 0 | retrograde P blanked; AP–VP at the lower rate |

### Bug 3 (a real bug, found by the main session's constrained-random simulation)

The start-up LRI bug: the old RTL loaded `t_v` from the reset-time LRI.

- SymbiYosys property A8 FAILS on the saved pre-fix copy (`report/work/sim/ddd_pacemaker_before_fix.v`) at step 3.
- The counterexample: reset with LRI = 27, then the CPU writes LRI = 19 while disabled, then enables. The old RTL starts with t_v = 27 instead of 19.
- A8 PASSES (unbounded) on the fixed RTL.

---

## (d) BDD study (`bdd/`)

The block is the event-priority block: 8 inputs (p, a, v, r, m, u, e, b) and 4 outputs (VS, VP, AS, AP), stored as one shared ROBDD.

Node counts are given two ways:

- **classical:** textbook ROBDD, no complement edges, internal nodes + 2 terminals. The natural order gives 21 internal nodes, which equals the own BDD in `src/event_priority.py`.
- **dd:** the dd package, which uses complement edges and a single terminal.

Run with `PYTHONHASHSEED=0`. dd's sifting visits variables in hash order, so without a fixed seed the sifting result varies from run to run.

| Variable ordering | classical | dd |
|---|---|---|
| natural p,a,v,r,m,u,e,b | 23 | 21 |
| reversed b,e,u,m,r,v,a,p | 22 | 20 |
| timers first e,b,u,m,r,p,a,v | 26 | 22 |
| worst of all 8! orders (v,a,p,m,u,e,r,b) | 32 | 29 |
| after dynamic sifting, from natural (order p,a,b,e,r,v,u,m) | 18 | 15 |
| after dynamic sifting, from worst (order u,v,r,a,b,m,e,p) | 19 | 17 |
| **exhaustive optimum** over 40,320 orders (e.g. a,m,u,b,e,p,v,r) | **15** | **12** |

**Ordering.** Only 240 of the 40,320 orders (0.6 %) reach the optimum. The spread is 15–32 nodes, so ordering more than doubles the size. Sifting improves the natural order by 22 % (classical 23 → 18) but stays 3 nodes above the optimum, as expected of a local heuristic. The exhaustive search takes about 45 s.

**Equivalence.** Every implementation was built in one manager. Equal functions give the identical canonical node, and all 4 outputs are **EQUAL** for:

- the truth table (`src/event_priority.py`);
- the espresso SOP (9 products);
- the kit's factored form;
- the SIS gkx kernel form (t4 = v'+r', t5 = b+a');
- the SIS script.rugged (14 literals);
- the RTL `rtl/event_priority.v` (parsed);
- the Yosys 0.71 `synth; abc` netlist (10 gates: 4 AND, 2 NAND, 3 NOR, 1 NOT; BLIF parsed).

**Symbolic reachability** (`reach/reach_bdd.py`):

- **Method:** the transition relation T(x, x') is built as a BDD from the model's next-state function over the full encoded domain, with x = phase, 4-bit t_v, 4-bit t_av, [armed], tick, [a, v]. Then R(k+1) = R(k) ∨ (∃x. R(k) ∧ T)[x'→x] is iterated to a fixpoint.
- **Cross-check:** NuSMV `print_reachable_states`. NuSMV's diameter equals image steps + 1, because it counts levels.

| Model | dd: reachable / image steps | NuSMV: reachable / diameter |
|---|---|---|
| ddd_oa (correct) | 168 / 10 | 168 / 11 |
| ddd_pmt (correct) | 26 / 12 | 26 / 13 |
| ddd_pmt_bug1 | 16 / 7 | 16 / 8 |
| ddd_oa_bug1 | 240 / 10 | 240 / 11 |
| ddd_oa_bug2 | 168 / 10 | 168 / 11 |

All counts match.

---

## (e) SymbiYosys on the RTL (`sby/`)

**Harness.** `ddd_formal.sv` is the top. All inputs are free, with these assumptions:

- reset in step 0;
- a legal parameter set mirroring `ddd_driver.c` (avi < lri, avi ≤ uri ≤ lri);
- parameters change only while the controller is disabled.

**Properties.** `ddd_props.vh` is `` `include ``d at the end of a COPY of `rtl/ddd_pacemaker.v`. That is the only line added (diff = 1 line), and it is active only under `` `ifdef FORMAL ``. The properties live inside the module because Yosys does not resolve hierarchical references (`dut.t_v`): it silently creates free wires, which my first harness hit. An independent monitor `f_since` counts the ticks since the last V event, using only the module's registered outputs.

**Assertions:**

| ID | Property |
|---|---|
| A1 | ¬(ap ∧ vp) |
| A2 | vp → f_since ≥ URI |
| A3 | as_evt → f_since ≥ PVARP |
| A4 | vs_evt → f_since ≥ VRP |
| A5 | f_since ≤ LRI (the ventricle is never left longer than LRI) |
| A6 | t_v ≤ LRI+1 while running |
| A7 | phase = AEI → t_av = 0; phase = AVI → t_av ≤ t_v |
| A8 | the first cycle after enable has t_v = programmed LRI |

**Strengthening invariants** (each is itself proven):

| ID | Invariant |
|---|---|
| I1 | f_since = t_v |
| I2 | a registered output event matches the state it produced |
| I3 | AEI after the first V event → t_v < AEI |
| I4 | AVI → t_v ≤ AEI + t_av |
| I5 | a stored AVI state never has both AVI and URI elapsed |

Without I2–I5, k-induction failed even at k = 30. The counterexample-to-induction is an unreachable state with ap = 1 while phase = AEI. Also, because ticks may be absent for arbitrarily many cycles, no k alone can close the proof.

| Task | Design | Engine | Result | Depth / k | Time |
|---|---|---|---|---|---|
| bmc | fixed RTL, W = 8, LRI ≤ 60 | smtbmc bitwuzla (first of yices / boolector / bitwuzla / abc bmc3) | **PASS** | 40 steps | 20 s |
| prove | fixed RTL, W = 8 | smtbmc yices, k-induction | **PASS** (proof) | k = 3 is the minimum (k = 1, 2 → UNKNOWN) | 1 s |
| prove16 | fixed RTL, **W = 16, firmware ranges in ms** (LRI 400–2000, AVI 30–350, URI 300–LRI, PVARP 150–500, VRP 150–400) | smtbmc yices, k-induction | **PASS** (proof) | depth 12 | 2 s |
| before_fix | pre-fix copy | smtbmc yices | **FAIL A8** (start-up LRI) | step 3 | 1 s |
| bug1 | PVARP-blanking mutant | smtbmc yices | **FAIL A3** | step 4 | 1 s |
| bug2 | VRP-blanking mutant | smtbmc yices | **FAIL A4** | step 4 | 1 s |
| pdr | fixed RTL, W = 8 | abc pdr (IC3) | 12 of 15 assertions proved individually; 3 still open at the time limit | frame 34 | 20 min limit |

PDR (IC3) is an independent unbounded engine. It needs no hand-written invariants, but it did not close all properties within 20 minutes, so it is a supporting result only. The complete proof is the k-induction with the invariants I1–I5.

**Earlier harness mistakes** (both were in my harness, not the design):

- hierarchical references became free wires;
- A6 must only hold while running, because LRI may be legally rewritten while disabled.

The run times above are wall clock on Windows; sby cannot report process time there.

---

## Appendix excerpt: NuSMV model (ddd_oa.smv, 40 lines)

```
MODULE main
DEFINE
  LRI := 10;  AVI_T := 2;  URI := 5;  PVARP := 4;  VRP := 3;
  AEI := LRI - AVI_T;
VAR
  phase : {PH_AEI, PH_AVI};   -- RTL register 'phase'
  t_v   : 0..11;              -- ticks since last V event (saturates at LRI+1)
  t_av  : 0..10;              -- ticks since the atrial event
  tick  : boolean;            -- 1 ms timebase strobe (free)
  a     : boolean;            -- intrinsic atrial event (free)
  v     : boolean;            -- intrinsic ventricular event (free)
DEFINE
  tv  := min(t_v + 1, LRI + 1);                     -- RTL: (t_v>=lri) ? lri+1 : t_v+1
  tav := (phase = PH_AVI) ? min(t_av + 1, 10) : 0;
  VS := tick & v & tv >= VRP;                        -- priority VS > VP > AS > AP
  VP := tick & !VS & phase = PH_AVI & tav >= AVI_T & tv >= URI;
  AS := tick & !VS & !VP & phase = PH_AEI & a & !(tv < PVARP);
  AP := tick & !VS & !VP & phase = PH_AEI & !AS & tv >= AEI;
  Vbeat := VS | VP;
ASSIGN
  init(phase) := PH_AEI;  init(t_v) := LRI;  init(t_av) := 0;
  next(phase) := case !tick : phase; VS | VP : PH_AEI; AS | AP : PH_AVI; TRUE : phase; esac;
  next(t_v)   := case !tick : t_v;   VS | VP : 0;      TRUE : tv;  esac;
  next(t_av)  := case !tick : t_av;  VS | VP | AS | AP : 0;   TRUE : tav; esac;
FAIRNESS tick
CTLSPEC NAME P1  := AG !(AP & VP);
CTLSPEC NAME P2  := AG (VP -> tv >= URI);
CTLSPEC NAME P3  := AG (AS -> tv >= PVARP);
CTLSPEC NAME P4  := AG (VS -> tv >= VRP);
CTLSPEC NAME P5  := AG (VP -> tav >= AVI_T);
CTLSPEC NAME P6  := AG (AP -> tv >= AEI);
CTLSPEC NAME P7  := EF AP & EF VP & EF AS & EF VS;
CTLSPEC NAME P8  := AG EF phase = PH_AEI;
CTLSPEC NAME P9  := AG AF Vbeat;
CTLSPEC NAME P10 := AG ((AS | AP) -> AX A[ !(AS | AP) U Vbeat ]);
```

(The full file adds P0, the bug switches ENFORCE_PVARP / CHECK_VRP, and the upper / slow_vbeat labels. The PMT model replaces `a, v` with the AV-block + retrograde heart and checks `P11 := AG AF slow_vbeat`.)

## Reproduction commands (from `report/work/formal`)

```
..\..\..\.venv\Scripts\python gen_smv.py
..\..\..\tools\nusmv\NuSMV-2.7.1-win64\bin\NuSMV.exe -dcx ddd_oa.smv            (also ddd_oa_nofair, ddd_pmt, ddd_pmt_bug1, ddd_oa_bug1, ddd_oa_bug2)
NuSMV.exe -source cex\bug1_pmt_P11.cmd                                          (counterexample traces -> cex\*.xml / *.txt)
..\..\..\.venv\Scripts\python cex_to_stim.py cex\bug1_pmt_P11.xml replay\stim_bug1_pmt_P11.txt 4
replay\run_replay.bat                                                           (xsim replays + closed loop -> replay\*.log)
..\..\..\.venv\Scripts\python replay\fig_replay.py
..\..\..\.venv\Scripts\python kripke\kripke_hand.py                              (hand labelling + NuSMV check + fig_kripke)
set PYTHONHASHSEED=0 & ..\..\..\.venv\Scripts\python bdd\bdd_study.py
NuSMV.exe -source reach\ddd_oa.cmd  &  ..\..\..\.venv\Scripts\python reach\reach_bdd.py
cd sby & ..\..\..\..\tools\oss-cad-suite\environment.bat & sby -f ddd.sby bmc prove prove16 before_fix bug1 bug2 pdr
yosys -p "read_verilog rtl/event_priority.v; synth -top event_priority; abc -g AND,OR,XOR,NAND,NOR; opt_clean; stat; write_blif bdd/event_priority_abc.blif"
```

## Figures

- `fig_kripke.pdf` / `.png` (6.3 × 2.35 in): the 16-state Kripke structure. Fill colour shows whether EG ¬slow holds; the slow / upper-rate V beats are ringed. E[¬upper U AS] holds everywhere except s9 and s11 (say this in the caption).
- `fig_replay.pdf` / `.png` (6.3 × 2.7 in): the PMT closed loop on the RTL.
  - (a) Bug-1 RTL: the retrograde P is sensed and VP lands at URI every cycle.
  - (b) Correct RTL: the retrograde P is blanked and pacing stays at the lower rate.
