"""
verify_event_priority.py  --  P17 Phase 6: minimise, BDD, verify, report

For the event-priority / timer-expiry block (src/event_priority.py):
  1. two-level (ESPRESSO-style) minimisation of each output + a .pla file,
  2. a reduced ordered BDD (a distinct, canonical representation),
  3. exhaustive checks: minimised SOP == truth table, BDD == truth table, and
     the block == the actual src/pacemaker.py decision over all timer values,
  4. writes results/stage6b_event_priority.txt / .pla / .dot.

Run (venv active, from project root):  python src/verify_event_priority.py
"""

from __future__ import annotations

import os

from event_priority import (
    N, OUTPUTS, VARS, VAR_DESC, assignment, build_bdd, cube_to_str, decide,
    literal_count, minimise, minterms, sop_to_str, to_pla,
)

_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESULTS = os.path.join(_ROOT, "results")


def _sop_eval(cubes, bits) -> int:
    for cube in cubes:
        if all(c == "-" or c == str(bits[i]) for i, c in enumerate(cube)):
            return 1
    return 0


def check_sop(out_idx):
    mts = minterms(out_idx)
    cubes = minimise(mts)
    # exhaustive equivalence: SOP == original function
    for idx in range(1 << N):
        bits = assignment(idx)
        if _sop_eval(cubes, bits) != decide(*bits)[out_idx]:
            raise AssertionError(f"SOP mismatch for {OUTPUTS[out_idx]} at {bits}")
    return cubes, len(mts)


def check_bdd():
    bdd, roots, stats = build_bdd()
    for idx in range(1 << N):
        bits = assignment(idx)
        exp = decide(*bits)
        for oi, name in enumerate(OUTPUTS):
            if bdd.eval(roots[name], bits) != exp[oi]:
                raise AssertionError(f"BDD mismatch for {name} at {bits}")
    return bdd, roots, stats


def check_vs_pacemaker():
    """The extracted block must equal src/pacemaker.py's per-tick decision."""
    import sys
    sys.path.insert(0, os.path.join(_ROOT, "src"))
    from pacemaker import DDDPacemaker, DDDParameters

    p = DDDParameters()
    lri, avi, uri, pvarp, vrp = p.lri_ms, p.avi_ms, p.uri_ms, p.pvarp_ms, p.vrp_ms
    aei = p.aei_ms
    checked = 0
    for phase in (DDDPacemaker.AEI, DDDPacemaker.AVI):
        for t_v in range(0, lri + 2):
            for t_av in range(0, avi + 2):
                for a_in in (0, 1):
                    for v_in in (0, 1):
                        pm = DDDPacemaker(p)
                        pm.phase = phase
                        pm.t_v = t_v
                        pm.t_av = t_av
                        out = pm.step(bool(a_in), bool(v_in))
                        tv = min(t_v + 1, lri)
                        tav = (t_av + 1) if phase == DDDPacemaker.AVI else 0
                        bits = (1 if phase == DDDPacemaker.AVI else 0, a_in, v_in,
                                int(tv >= vrp), int(tav >= avi), int(tv >= uri),
                                int(tv >= aei), int(tv < pvarp))
                        vs, vp, as_, ap = decide(*bits)
                        got = (int(out.v_sense), int(out.v_pace),
                               int(out.a_sense), int(out.a_pace))
                        if got != (vs, vp, as_, ap):
                            raise AssertionError(
                                f"block != pacemaker.py at phase={phase} "
                                f"t_v={t_v} t_av={t_av} a={a_in} v={v_in}: "
                                f"{got} vs {(vs,vp,as_,ap)}")
                        checked += 1
    return checked


def build_report() -> str:
    lines = []
    w = lines.append
    w("P17 Phase 6 -- Event-priority / timer-expiry logic block")
    w("=" * 60)
    w("")
    w("Inputs:")
    for v in VARS:
        w(f"  {v} = {VAR_DESC[v]}")
    w("Outputs: " + ", ".join(OUTPUTS) + "   (priority VS > VP > AS > AP)")
    w("")
    w("Two-level (ESPRESSO-style) minimisation -- sum-of-products per output")
    w("-" * 60)
    total_before = total_after = 0
    for oi, name in enumerate(OUTPUTS):
        cubes, nmin = check_sop(oi)
        total_before += nmin
        total_after += len(cubes)
        w(f"  {name}: {nmin} minterms -> {len(cubes)} product term(s), "
          f"{literal_count(cubes)} literals")
        w(f"       {name} = {sop_to_str(cubes)}")
    w("")
    w(f"  minterms total {total_before} -> {total_after} product terms "
      f"(two-level minimised).")
    w("")
    w("BDD representation (reduced ordered BDD; order: " + " ".join(VARS) + ")")
    w("-" * 60)
    bdd, roots, stats = check_bdd()
    w(f"  shared BDD internal nodes (4 outputs): {stats['shared_internal_nodes']}")
    for name in OUTPUTS:
        w(f"    {name}: {stats['per_output'][name]} nodes")
    w("  (ESPRESSO minimises two-level logic; a BDD is a canonical decision-")
    w("   diagram representation -- different tools, both derived here.)")
    w("")
    checked = check_vs_pacemaker()
    w("Equivalence")
    w("-" * 60)
    w(f"  minimised SOP  == truth table : PASS (all {1<<N} input combinations)")
    w(f"  BDD            == truth table : PASS (all {1<<N} input combinations)")
    w(f"  block          == pacemaker.py: PASS ({checked} timer/input states)")
    return "\n".join(lines) + "\n", bdd, roots


def main() -> None:
    report, bdd, roots = build_report()
    os.makedirs(RESULTS, exist_ok=True)
    with open(os.path.join(RESULTS, "stage6b_event_priority.txt"), "w",
              encoding="utf-8") as fh:
        fh.write(report)
    with open(os.path.join(RESULTS, "stage6b_event_priority.pla"), "w",
              encoding="utf-8") as fh:
        fh.write(to_pla())
    with open(os.path.join(RESULTS, "stage6b_event_priority_bdd.dot"), "w",
              encoding="utf-8") as fh:
        fh.write(bdd.to_dot(roots))
    print(report)
    print("Saved: results/stage6b_event_priority.txt, .pla, _bdd.dot")


if __name__ == "__main__":
    main()
