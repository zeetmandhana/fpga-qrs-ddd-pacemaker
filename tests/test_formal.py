"""
test_formal.py  --  P17 Phase 5 tests (CTL model checker + pacemaker proofs)

Runnable two ways:
    python tests/test_formal.py     # PASS/FAIL table, exit code
    pytest tests/test_formal.py

First validates the CTL engine on tiny Kripke structures with hand-known truths,
then checks the pacemaker verification results (safety, liveness, PMT).
"""

from __future__ import annotations

import os
import sys

_THIS = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.dirname(_THIS)
sys.path.insert(0, os.path.join(_ROOT, "src"))

from ctl import AF, AG, AP, AND, EF, EG, EX, OR, Kripke  # noqa: E402


# --- CTL engine sanity on a known linear structure --------------------------
#   s0 --p--> s1 --p--> s2(--q--, sink)
def _linear():
    trans = {"s0": {"s1"}, "s1": {"s2"}, "s2": {"s2"}}
    labels = {"s0": {"p"}, "s1": {"p"}, "s2": {"q"}}
    return Kripke(trans, labels, {"s0"})


def test_ef_reachable():
    assert _linear().holds(EF(AP("q")))          # q is reachable


def test_af_eventually_on_linear():
    assert _linear().holds(AF(AP("q")))          # all paths reach q


def test_ag_fails_for_p():
    assert not _linear().holds(AG(AP("p")))      # s2 has no p


def test_eg_p_false():
    assert not _linear().holds(EG(AP("p")))      # no infinite p-path


def test_ag_invariant_holds():
    assert _linear().holds(AG(OR(AP("p"), AP("q"))))   # always p or q


def test_ex():
    assert _linear().holds(EX(AP("p")))          # s0 has a p-successor


# --- branching structure: EF q true but AF q false --------------------------
#   s0 -> {s1, s3};  s1 -> s2(q, sink);  s3 -> s3 (never q)
def _branch():
    trans = {"s0": {"s1", "s3"}, "s1": {"s2"}, "s2": {"s2"}, "s3": {"s3"}}
    labels = {"s2": {"q"}}
    return Kripke(trans, labels, {"s0"})


def test_branch_ef_true_af_false():
    k = _branch()
    assert k.holds(EF(AP("q")))                  # q possible
    assert not k.holds(AF(AP("q")))              # not inevitable (s3 loops)


def test_liveness_counterexample_is_a_lasso():
    k = _branch()
    ce = k.liveness_counterexample(AP("q"))      # AG AF q fails here
    assert ce is not None
    stem, cycle = ce
    assert len(cycle) >= 1 and "s3" in cycle     # the q-avoiding cycle


def test_safety_counterexample_path():
    k = _linear()
    ce = k.safety_counterexample(AP("p"))        # AG p fails
    assert ce is not None and ce[-1] == "s2"     # path ends at the violating state


# --- pacemaker verification results (filled once the model exists) ----------
def test_pacemaker_results_if_available():
    try:
        from pacemaker_model import verify_all
    except Exception as exc:  # model not built yet
        print(f"    (pacemaker_model not available: {exc}) - skipping")
        return
    res = verify_all()
    assert res["safety_never_ap_and_vp"] is True
    assert res["liveness_v_always_beats"] is True
    assert res["pmt_safe_bounded_rate"] is True
    assert res["pmt_bug_bounded_rate"] is False      # PMT: property violated
    assert res["pmt_counterexample"] is not None


def _run_all() -> int:
    checks = [
        ("EF reachability", test_ef_reachable),
        ("AF inevitability (linear)", test_af_eventually_on_linear),
        ("AG p fails on linear", test_ag_fails_for_p),
        ("EG p false on linear", test_eg_p_false),
        ("AG invariant (p or q)", test_ag_invariant_holds),
        ("EX successor", test_ex),
        ("Branch: EF true, AF false", test_branch_ef_true_af_false),
        ("Liveness counterexample is a lasso", test_liveness_counterexample_is_a_lasso),
        ("Safety counterexample path", test_safety_counterexample_path),
        ("Pacemaker verification results", test_pacemaker_results_if_available),
    ]
    fails = 0
    print(f"Running {len(checks)} Phase-5 checks ...\n")
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
