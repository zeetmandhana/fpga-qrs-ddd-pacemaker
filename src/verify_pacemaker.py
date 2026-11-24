"""
verify_pacemaker.py  --  P17 Phase 5: formal-verification report driver

Runs the CTL model checking of the DDD pacemaker (pacemaker_model.verify_all)
and writes a human-readable proof report plus a JSON summary:

    results/stage5_formal_report.txt
    results/stage5_formal.json

Run (venv active, from project root):  python src/verify_pacemaker.py
"""

from __future__ import annotations

import json
import os

from pacemaker_model import (
    AEI, AVI, LRI, PVARP, URI, VA, VRP,
    format_trace, verify_all,
)

_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESULTS = os.path.join(_ROOT, "results")


def build_report() -> tuple[str, dict]:
    r = verify_all()
    lines = []
    w = lines.append

    w("P17 Phase 5 -- Formal (CTL) verification of the DDD pacemaker")
    w("=" * 62)
    w("")
    w("Method: explicit-state CTL model checking (src/ctl.py) over a")
    w("counter-abstracted finite model (src/pacemaker_model.py). The engine")
    w("is validated against known Kripke structures in tests/test_formal.py.")
    w("")
    w(f"Abstract timing (ticks): AVI={AVI} VRP={VRP} PVARP={PVARP} URI={URI} "
      f"LRI={LRI} AEI={AEI} VA={VA}")
    w(f"Reachable states: over-approx={r['oa_states']}, "
      f"PMT-safe={r['pmt_safe_states']}, PMT-bug={r['pmt_bug_states']}")
    w("")
    w("Properties")
    w("-" * 62)
    w(f"  P1  AG !(AP & VP)   (safety: never pace both chambers)  : "
      f"{'PROVED' if r['safety_never_ap_and_vp'] else 'FAILED'}")
    w(f"  P2  AG AF Vbeat     (liveness: ventricle always beats)  : "
      f"{'PROVED' if r['liveness_v_always_beats'] else 'FAILED'}")
    w(f"  P3  AG AF normal-beat, correct PVARP blanking           : "
      f"{'PROVED' if r['pmt_safe_bounded_rate'] else 'FAILED'}")
    w(f"  P3  AG AF normal-beat, INJECTED PVARP bug               : "
      f"{'PROVED' if r['pmt_bug_bounded_rate'] else 'VIOLATED (PMT)'}")
    w("")

    ce = r["pmt_counterexample"]
    if ce is not None:
        stem, cycle = ce
        w("Pacemaker-mediated tachycardia (PMT) counterexample")
        w("-" * 62)
        w("Injected bug: the atrial channel senses retrograde P-waves inside")
        w("PVARP. The model checker returns a lasso (a stem then a cycle that")
        w("repeats forever) in which no normal-rate beat ever occurs again:")
        w("")
        w("  stem:")
        for ln in format_trace(stem):
            w("    " + ln)
        w("  cycle (repeats forever -- every ventricular beat at the upper rate):")
        for ln in format_trace(cycle):
            w("    " + ln)
        w("")
        w("With correct PVARP blanking (P3 safe) this cycle is unreachable, so")
        w("the property holds and no PMT can occur.")

    report = "\n".join(lines)

    summary = {k: v for k, v in r.items() if k != "pmt_counterexample"}
    summary["pmt_counterexample"] = {
        "stem": format_trace(ce[0]) if ce else None,
        "cycle": format_trace(ce[1]) if ce else None,
    }
    return report, summary


def main() -> None:
    report, summary = build_report()
    os.makedirs(RESULTS, exist_ok=True)
    with open(os.path.join(RESULTS, "stage5_formal_report.txt"), "w",
              encoding="utf-8") as fh:
        fh.write(report + "\n")
    with open(os.path.join(RESULTS, "stage5_formal.json"), "w",
              encoding="utf-8") as fh:
        json.dump(summary, fh, indent=2)
    print(report)
    print("\nSaved: results/stage5_formal_report.txt, results/stage5_formal.json")


if __name__ == "__main__":
    main()
