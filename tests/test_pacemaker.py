"""
test_pacemaker.py  --  P17 Phase 3 tests (DDD pacemaker timing controller)

Runnable two ways:
    python tests/test_pacemaker.py     # PASS/FAIL table, exit code
    pytest tests/test_pacemaker.py

Covers: parameter range-checking, the base pacing behaviour, the per-scenario
safety / liveness properties, and the PMT counterexample.
"""

from __future__ import annotations

import os
import sys

_THIS = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.dirname(_THIS)
sys.path.insert(0, os.path.join(_ROOT, "src"))

from heart_model import SCENARIOS, HeartParams              # noqa: E402
from pacemaker import DDDParameters                          # noqa: E402
from pacemaker_sim import check_safety, run_closed_loop      # noqa: E402

PARAMS = DDDParameters()
DUR = 12000


# --- parameter range-checking -----------------------------------------------

def test_default_params_valid():
    DDDParameters().validate()   # must not raise


def test_reject_uri_above_lri():
    try:
        DDDParameters(lri_ms=600, uri_ms=800).validate()
    except ValueError:
        return
    raise AssertionError("URI > LRI should be rejected")


def test_reject_avi_out_of_range():
    try:
        DDDParameters(avi_ms=500).validate()
    except ValueError:
        return
    raise AssertionError("AVI 500 ms should be rejected")


# --- base behaviour ---------------------------------------------------------

def test_no_intrinsic_paces_both_at_lower_rate():
    empty = HeartParams("empty", "no intrinsic activity", None, None, None, None)
    sim = run_closed_loop(PARAMS, empty, 10000)
    rep = check_safety(PARAMS, sim)
    assert 9 <= rep["n_AP"] <= 11, f"AP={rep['n_AP']} (expect ~10 at 60 bpm)"
    assert 9 <= rep["n_VP"] <= 11, f"VP={rep['n_VP']} (expect ~10)"
    assert 55 <= rep["vent_rate_bpm"] <= 62, rep["vent_rate_bpm"]


# --- scenario safety --------------------------------------------------------

def _run(name, enforce_pvarp=True):
    sim = run_closed_loop(PARAMS, SCENARIOS[name], DUR, enforce_pvarp=enforce_pvarp)
    return sim, check_safety(PARAMS, sim)


def test_all_scenarios_safe():
    for name in ("normal", "brady", "block", "dual"):
        _, rep = _run(name)
        assert rep["all_passed"], f"{name} failed: {rep['checks']}"


def test_never_ap_and_vp_together():
    for name in ("normal", "brady", "block", "dual", "pmt"):
        sim, _ = _run(name)
        assert len(sim["both_pace"]) == 0, f"{name}: AP&VP coincided"


def test_normal_inhibits_pacing():
    _, rep = _run("normal")
    assert rep["n_VP"] == 0 and rep["n_VS"] > 0, rep


def test_block_is_atrial_tracking():
    _, rep = _run("block")
    assert rep["n_VP"] > 0 and rep["n_AS"] > 0 and rep["n_VS"] == 0, rep


def test_dual_is_av_sequential():
    _, rep = _run("dual")
    assert rep["n_AP"] > 0 and rep["n_VP"] > 0, rep


# --- PMT counterexample -----------------------------------------------------

def test_pmt_bug_drives_upper_rate_but_safe_does_not():
    _, safe = _run("pmt", enforce_pvarp=True)
    _, bug = _run("pmt", enforce_pvarp=False)
    assert safe["vent_rate_bpm"] < 90, f"safe V-rate {safe['vent_rate_bpm']}"
    assert bug["vent_rate_bpm"] > 110, f"bug V-rate {bug['vent_rate_bpm']}"
    # even during PMT the URI is still respected (rate pinned AT the ceiling)
    assert bug["min_vv_ms"] >= PARAMS.uri_ms, f"min V-V {bug['min_vv_ms']} < URI"


# --- direct-run harness -----------------------------------------------------

def _run_all() -> int:
    checks = [
        ("Default parameters valid", test_default_params_valid),
        ("Reject URI > LRI", test_reject_uri_above_lri),
        ("Reject AVI out of range", test_reject_avi_out_of_range),
        ("No intrinsic -> AP+VP at lower rate", test_no_intrinsic_paces_both_at_lower_rate),
        ("All base scenarios SAFE", test_all_scenarios_safe),
        ("Never AP and VP on same tick", test_never_ap_and_vp_together),
        ("Normal rhythm inhibits pacing", test_normal_inhibits_pacing),
        ("AV block -> atrial tracking (AS->VP)", test_block_is_atrial_tracking),
        ("AV block + brady -> AV-sequential", test_dual_is_av_sequential),
        ("PMT bug drives upper rate; safe does not", test_pmt_bug_drives_upper_rate_but_safe_does_not),
    ]
    fails = 0
    print(f"Running {len(checks)} Phase-3 checks ...\n")
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
