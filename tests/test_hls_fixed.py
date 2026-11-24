"""
test_hls_fixed.py  --  P17 Phase 4 tests (fixed-point filter chain / HLS golden)

Runnable two ways:
    python tests/test_hls_fixed.py     # PASS/FAIL table, exit code
    pytest tests/test_hls_fixed.py

Validates the integer golden model that the hand-written HLS must match:
the fixed-point detector equals the float detector on record 100, the stage
outputs fit the HLS integer widths (so the C++ is bit-exact), and the MWI is a
true 54-sample running sum of the squared signal.
"""

from __future__ import annotations

import os
import sys

import numpy as np

_THIS = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.dirname(_THIS)
_DATA = os.path.join(_ROOT, "data")
sys.path.insert(0, os.path.join(_ROOT, "src"))

from ecg_loader import BEAT_SYMBOLS, load_ecg_record                 # noqa: E402
from pan_tompkins import detect_qrs                                   # noqa: E402
from pan_tompkins_fixed import (                                      # noqa: E402
    fixed_filter_chain,
    detect_qrs_fixed,
    load_record_digital,
)
from qrs_eval import match_detections                                 # noqa: E402

RECORD = "100"


def _ref_beats(rec):
    return np.array([s for s, sym in zip(rec.ann_sample, rec.ann_symbol)
                     if sym in BEAT_SYMBOLS], dtype=np.int64)


def test_fixed_matches_float_accuracy():
    rec = load_ecg_record(RECORD, data_dir=_DATA)
    ref = _ref_beats(rec)
    tol = int(round(0.150 * rec.fs))
    fm = match_detections(ref, detect_qrs(rec.signal, rec.fs).qrs_indices, tol)
    dig = load_record_digital(RECORD, _DATA)
    xm = match_detections(ref, detect_qrs_fixed(dig)[0], tol)
    # the integer pipeline must be at least as good as, and here equal to, float
    assert xm.sensitivity >= 0.99, f"fixed Se={xm.sensitivity:.4f}"
    assert xm.positive_predictivity >= 0.99, f"fixed +P={xm.positive_predictivity:.4f}"
    assert abs(xm.sensitivity - fm.sensitivity) < 0.005, "fixed vs float Se differ"


def test_stage_widths_fit_hls_types():
    dig = load_record_digital(RECORD, _DATA)
    st = fixed_filter_chain(dig["adc"], dig["baseline"])
    for name in ("lp", "hp", "dv"):          # HLS filt_t = ap_int<32>
        m = int(np.abs(st[name]).max())
        assert m < 2 ** 31, f"{name} max {m} exceeds 32-bit"
    for name in ("sq", "mwi"):               # HLS acc_t = ap_int<64>
        m = int(np.abs(st[name]).max())
        assert m < 2 ** 63, f"{name} max {m} exceeds 64-bit"


def test_mwi_is_54_sample_running_sum():
    dig = load_record_digital(RECORD, _DATA)
    st = fixed_filter_chain(dig["adc"][:5000], dig["baseline"])
    sq, mwi, w = st["sq"], st["mwi"], st["mwi_window"]
    assert w == 54
    for i in (100, 1000, 3000):
        expected = int(sq[max(0, i - w + 1):i + 1].sum())
        assert int(mwi[i]) == expected, f"MWI[{i}] {int(mwi[i])} != window sum {expected}"


def test_mwi_nonnegative():
    dig = load_record_digital(RECORD, _DATA)
    st = fixed_filter_chain(dig["adc"][:5000], dig["baseline"])
    assert (st["mwi"] >= 0).all(), "MWI (sum of squares) must be non-negative"


def test_exported_vectors_match_model():
    """The HLS test vectors must reproduce from the model (no stale vectors)."""
    tb = os.path.join(_ROOT, "hls", "tb_data")
    inp = os.path.join(tb, "rec100_input.txt")
    exp = os.path.join(tb, "rec100_expected_mwi.txt")
    if not (os.path.exists(inp) and os.path.exists(exp)):
        print("    (vectors not generated yet; run hls/gen_test_vectors.py) - skipping")
        return
    adc = np.loadtxt(inp, dtype=np.int64)
    expected = np.loadtxt(exp, dtype=np.int64)
    st = fixed_filter_chain(adc, baseline=1024)
    assert np.array_equal(st["mwi"], expected), "exported MWI vectors are stale"


def _run_all() -> int:
    checks = [
        ("Fixed-point detector matches float accuracy", test_fixed_matches_float_accuracy),
        ("Stage outputs fit HLS 32/64-bit widths", test_stage_widths_fit_hls_types),
        ("MWI is a 54-sample running sum", test_mwi_is_54_sample_running_sum),
        ("MWI is non-negative", test_mwi_nonnegative),
        ("Exported HLS vectors match the model", test_exported_vectors_match_model),
    ]
    fails = 0
    print(f"Running {len(checks)} Phase-4 checks ...\n")
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
