"""
test_event_priority.py  --  P17 Phase 6 tests (event-priority logic block)

Runnable two ways:
    python tests/test_event_priority.py     # PASS/FAIL table, exit code
    pytest tests/test_event_priority.py

Checks: the two-level (ESPRESSO-style) minimisation and the BDD are each
equivalent to the block's truth table, the minimisation actually reduces the
logic, and the block matches src/pacemaker.py's decision at the timer boundaries.
"""

from __future__ import annotations

import os
import sys

_THIS = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.dirname(_THIS)
sys.path.insert(0, os.path.join(_ROOT, "src"))

from event_priority import (                                    # noqa: E402
    N, OUTPUTS, assignment, build_bdd, decide, minimise, minterms,
)
from pacemaker import DDDPacemaker, DDDParameters               # noqa: E402


def _sop_eval(cubes, bits):
    return 1 if any(all(c == "-" or c == str(bits[i]) for i, c in enumerate(cube))
                    for cube in cubes) else 0


def test_sop_equivalent_to_truth_table():
    for oi in range(len(OUTPUTS)):
        cubes = minimise(minterms(oi))
        for idx in range(1 << N):
            bits = assignment(idx)
            assert _sop_eval(cubes, bits) == decide(*bits)[oi], \
                f"{OUTPUTS[oi]} SOP mismatch at {bits}"


def test_minimisation_reduces_logic():
    total_minterms = sum(len(minterms(oi)) for oi in range(len(OUTPUTS)))
    total_terms = sum(len(minimise(minterms(oi))) for oi in range(len(OUTPUTS)))
    assert total_terms < total_minterms, "minimisation should reduce term count"
    assert total_terms <= 12, f"expected a compact cover, got {total_terms}"


def test_bdd_equivalent_to_truth_table():
    bdd, roots, stats = build_bdd()
    for idx in range(1 << N):
        bits = assignment(idx)
        exp = decide(*bits)
        for oi, name in enumerate(OUTPUTS):
            assert bdd.eval(roots[name], bits) == exp[oi], f"BDD {name} at {bits}"
    assert stats["shared_internal_nodes"] > 0


def test_block_matches_pacemaker_at_boundaries():
    p = DDDParameters()
    lri, avi, uri, pvarp, vrp, aei = (p.lri_ms, p.avi_ms, p.uri_ms,
                                      p.pvarp_ms, p.vrp_ms, p.aei_ms)
    # all threshold boundaries for every timer predicate
    tvs = sorted({0, vrp-1, vrp, uri-1, uri, aei-1, aei, pvarp-1, pvarp, lri})
    tavs = sorted({0, avi-1, avi, avi+1})
    for phase in (DDDPacemaker.AEI, DDDPacemaker.AVI):
        for t_v in tvs:
            for t_av in tavs:
                for a_in in (0, 1):
                    for v_in in (0, 1):
                        pm = DDDPacemaker(p)
                        pm.phase = phase; pm.t_v = t_v; pm.t_av = t_av
                        out = pm.step(bool(a_in), bool(v_in))
                        tv = min(t_v + 1, lri)
                        tav = (t_av + 1) if phase == DDDPacemaker.AVI else 0
                        bits = (1 if phase == DDDPacemaker.AVI else 0, a_in, v_in,
                                int(tv >= vrp), int(tav >= avi), int(tv >= uri),
                                int(tv >= aei), int(tv < pvarp))
                        assert (int(out.v_sense), int(out.v_pace),
                                int(out.a_sense), int(out.a_pace)) == decide(*bits), \
                            f"mismatch phase={phase} t_v={t_v} t_av={t_av} a={a_in} v={v_in}"


def test_professor_kit_espresso_and_sis():
    """Professor's A2DSL kit: espresso (9 products, 34 literals) and SIS
    script.rugged results == golden decision on all 256 inputs."""
    from verify_espresso_kit import ESPRESSO_PLA, espresso_eqs, eval_pla, rugged_eqs
    assert len(ESPRESSO_PLA) == 9
    assert sum(sum(c != "-" for c in cube) for cube, _ in ESPRESSO_PLA) == 34
    for i in range(256):
        bits = [(i >> (7 - k)) & 1 for k in range(8)]
        ref = tuple(int(x) for x in decide(*bits))
        assert eval_pla(bits) == ref, bits
        assert espresso_eqs(*bits) == ref, bits
        assert rugged_eqs(*bits) == ref, bits


def _run_all() -> int:
    checks = [
        ("Minimised SOP == truth table", test_sop_equivalent_to_truth_table),
        ("Minimisation reduces logic", test_minimisation_reduces_logic),
        ("BDD == truth table", test_bdd_equivalent_to_truth_table),
        ("Block == pacemaker.py at boundaries", test_block_matches_pacemaker_at_boundaries),
        ("Professor-kit espresso + SIS == truth table", test_professor_kit_espresso_and_sis),
    ]
    fails = 0
    print(f"Running {len(checks)} Phase-6 event-priority checks ...\n")
    for name, fn in checks:
        try:
            fn()
            print(f"  [PASS] {name}")
        except AssertionError as exc:
            fails += 1
            print(f"  [FAIL] {name}: {exc}")
        except Exception as exc:
            fails += 1
            print(f"  [ERROR] {name}: {exc!r}")
    print(f"\n{len(checks) - fails}/{len(checks)} checks passed.")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(_run_all())
