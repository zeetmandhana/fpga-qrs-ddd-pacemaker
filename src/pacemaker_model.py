"""
pacemaker_model.py  --  P17 Phase 5: finite-state DDD pacemaker for model checking

A COUNTER-ABSTRACTED model of the DDD timing controller (src/pacemaker.py) built
as a finite Kripke structure so CTL properties can be checked exhaustively with
src/ctl.py. Time is in abstract "ticks" whose values preserve the orderings that
matter (the exact milliseconds do not change the logic or the proofs):

    AVI=2  VRP=3  PVARP=4  URI=5  LRI=10  ->  AEI = LRI-AVI = 8
    VA (retrograde conduction) = 3   (VA < PVARP: a retrograde P falls inside
                                      PVARP and is correctly blanked)

Two heart environments:
  * "oa"  over-approximation: each tick the heart may present ANY intrinsic
          atrial and/or ventricular event -> proofs hold for ALL heart behaviours.
  * "pmt" AV block + retrograde VA conduction: the substrate for pacemaker-
          mediated tachycardia. With the correct PVARP blanking the retrograde P
          is ignored; with the injected bug (enforce_pvarp=False) it is tracked.

Verified properties (see verify_all):
  P1 SAFETY    AG !(AP & VP)        never pace both chambers on one tick
  P2 LIVENESS  AG AF Vbeat          the ventricle always eventually beats
  P3 PMT       AG AF !upper         the ventricle is not pinned at the upper rate
               (holds with correct PVARP; FAILS -> counterexample with the bug)
"""

from __future__ import annotations

from collections import namedtuple

from ctl import AF, AG, AND, AP, EF, EG, NOT, OR, Kripke

# abstract tick parameters
AVI, VRP, PVARP, URI, LRI = 2, 3, 4, 5, 10
AEI = LRI - AVI            # 8
VA = 3                     # retrograde conduction delay

AEI_PH, AVI_PH = 0, 1      # controller phase encodings

# State carries the timers/flags AND the device events that produced it (so the
# atomic propositions are just a function of the state).
State = namedtuple("State", "phase t_v t_av armed ap vp as_ vs upper")


def initial_state() -> State:
    return State(AEI_PH, 0, 0, False, False, False, False, False, False)


def labels_of(s: State) -> set:
    L = set()
    if s.ap:
        L.add("AP")
    if s.vp:
        L.add("VP")
    if s.as_:
        L.add("AS")
    if s.vs:
        L.add("VS")
    if s.vp or s.vs:
        L.add("Vbeat")
    if s.upper:
        L.add("upper")
    if (s.vp or s.vs) and not s.upper:
        L.add("slow_vbeat")        # a ventricular beat NOT at the upper-rate limit
    if s.ap and s.vp:
        L.add("pace_both")
    return L


def step(s: State, env_mode: str, enforce_pvarp: bool) -> set:
    """One tick. Returns the SET of successor states (nondeterministic for 'oa')."""
    t_v = min(s.t_v + 1, LRI)
    t_av = min(s.t_av + 1, LRI) if s.phase == AVI_PH else 0
    armed = s.armed

    # retrograde atrial depolarisation (PMT heart): fires VA ticks after a V event
    retro_a = (env_mode == "pmt" and armed and t_v == VA)
    if retro_a:
        armed = False

    if env_mode == "oa":
        env_choices = [(a, v) for a in (False, True) for v in (False, True)]
    else:  # pmt: AV block -> no antegrade intrinsic V; atrial events are retrograde
        env_choices = [(retro_a, False)]

    out = set()
    for (a_in, v_in) in env_choices:
        ap = vp = as_ = vs = False
        n_phase, n_tv, n_tav, n_armed, upper = s.phase, t_v, t_av, armed, False

        # (1) ventricular sensing -- blanked during VRP
        if v_in and t_v >= VRP:
            vs = True
        if vs:
            upper = (t_v == URI)
            n_phase, n_tv, n_tav = AEI_PH, 0, 0
            n_armed = (env_mode == "pmt")
        else:
            # (2) ventricular pacing -- AVI elapsed and URI satisfied
            if s.phase == AVI_PH and t_av >= AVI and t_v >= URI:
                vp = True
                upper = (t_v == URI)
                n_phase, n_tv, n_tav = AEI_PH, 0, 0
                n_armed = (env_mode == "pmt")
            # (3) atrial side -- only while awaiting an atrial event
            if not vp and s.phase == AEI_PH:
                blanked = enforce_pvarp and t_v < PVARP
                if a_in and not blanked:
                    as_ = True
                    n_phase, n_tav = AVI_PH, 0
                elif t_v >= AEI:
                    ap = True
                    n_phase, n_tav = AVI_PH, 0

        out.add(State(n_phase, n_tv, n_tav, n_armed, ap, vp, as_, vs, upper))
    return out


def build_kripke(env_mode: str, enforce_pvarp: bool) -> Kripke:
    """Breadth-first construction of the reachable Kripke structure."""
    init = initial_state()
    trans, labels, seen, frontier = {}, {}, {init}, [init]
    while frontier:
        s = frontier.pop()
        succ = step(s, env_mode, enforce_pvarp)
        trans[s] = succ
        labels[s] = labels_of(s)
        for t in succ:
            if t not in seen:
                seen.add(t)
                frontier.append(t)
    return Kripke(trans, labels, {init})


def format_trace(states) -> list:
    """Readable per-tick lines for a counterexample path/cycle."""
    phase_name = {AEI_PH: "AEI", AVI_PH: "AVI"}
    lines = []
    for s in states:
        evs = [e for e in ("AP", "VP", "AS", "VS") if e in labels_of(s)]
        tag = "+".join(evs) if evs else "-"
        up = " [UPPER-RATE]" if s.upper else ""
        lines.append(f"phase={phase_name[s.phase]:3} t_v={s.t_v:<2} t_av={s.t_av:<2} "
                     f"event={tag:<5}{up}")
    return lines


# CTL property formulas
SAFETY = AG(NOT(AND(AP("AP"), AP("VP"))))        # P1
LIVENESS = AG(AF(AP("Vbeat")))                   # P2
SLOW_VBEAT = AP("slow_vbeat")
PMT_FREE = AG(AF(SLOW_VBEAT))                    # P3: a normal-rate beat always recurs
                                                 # (fails => ventricle pinned at upper rate = PMT)


def verify_all() -> dict:
    oa = build_kripke("oa", enforce_pvarp=True)
    pmt_safe = build_kripke("pmt", enforce_pvarp=True)
    pmt_bug = build_kripke("pmt", enforce_pvarp=False)

    res = {
        "oa_states": len(oa.states),
        "pmt_safe_states": len(pmt_safe.states),
        "pmt_bug_states": len(pmt_bug.states),
        "safety_never_ap_and_vp": oa.holds(SAFETY),
        "liveness_v_always_beats": oa.holds(LIVENESS),
        "pmt_safe_bounded_rate": pmt_safe.holds(PMT_FREE),
        "pmt_bug_bounded_rate": pmt_bug.holds(PMT_FREE),
    }
    # counterexample for the buggy model (lasso: no normal-rate beat ever again)
    ce = pmt_bug.liveness_counterexample(SLOW_VBEAT)
    res["pmt_counterexample"] = ce
    return res


if __name__ == "__main__":
    r = verify_all()
    print("DDD pacemaker -- CTL verification (counter-abstracted model)\n")
    print(f"  over-approx model : {r['oa_states']} reachable states")
    print(f"  PMT-safe model    : {r['pmt_safe_states']} states")
    print(f"  PMT-bug model     : {r['pmt_bug_states']} states\n")
    print(f"  P1  AG !(AP & VP)        [safety]   : "
          f"{'PROVED' if r['safety_never_ap_and_vp'] else 'FAILED'}")
    print(f"  P2  AG AF Vbeat          [liveness] : "
          f"{'PROVED' if r['liveness_v_always_beats'] else 'FAILED'}")
    print(f"  P3  AG AF normal-rate-beat (safe)   : "
          f"{'PROVED' if r['pmt_safe_bounded_rate'] else 'FAILED'}")
    print(f"  P3  AG AF normal-rate-beat (bug)    : "
          f"{'PROVED' if r['pmt_bug_bounded_rate'] else 'VIOLATED (PMT)'}")

    if r["pmt_counterexample"] is not None:
        stem, cycle = r["pmt_counterexample"]
        print("\n  PMT counterexample (lasso): stem then a cycle repeated forever")
        print("  --- stem ---")
        for ln in format_trace(stem):
            print("   ", ln)
        print("  --- cycle (repeats forever: every beat at the upper rate) ---")
        for ln in format_trace(cycle):
            print("   ", ln)
