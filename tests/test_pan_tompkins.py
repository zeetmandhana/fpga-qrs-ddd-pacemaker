"""
test_pan_tompkins.py  --  P17 Phase 2 tests (Pan-Tompkins detector)

Runnable two ways:
    python tests/test_pan_tompkins.py     # PASS/FAIL table, exit code
    pytest tests/test_pan_tompkins.py

Covers: the filter stages (impulse/band shape), the match scorer on synthetic
data, and the detector's sensitivity / positive predictivity on real record 100.
"""

from __future__ import annotations

import os
import sys

import numpy as np

_THIS = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.dirname(_THIS)
_DATA = os.path.join(_ROOT, "data")
sys.path.insert(0, os.path.join(_ROOT, "src"))

from ecg_loader import BEAT_SYMBOLS, load_ecg_record          # noqa: E402
from pan_tompkins import (                                     # noqa: E402
    bandpass_filter,
    derivative_filter,
    detect_qrs,
    moving_window_integration,
)
from qrs_eval import match_detections                          # noqa: E402

FS = 360.0


# --- filter stages ----------------------------------------------------------

def test_mwi_window_is_150ms():
    _, n = moving_window_integration(np.zeros(100), FS)
    assert n == 54, f"MWI window {n}, expected 54 (=0.150*360)"


def test_derivative_impulse_response():
    impulse = np.zeros(16); impulse[0] = 1.0
    y = derivative_filter(impulse)
    expected = np.array([2, 1, 0, -1, -2]) / 8.0
    assert np.allclose(y[:5], expected), f"derivative taps {y[:5]} != {expected}"


def test_bandpass_removes_dc():
    y = bandpass_filter(np.ones(2000))
    assert abs(np.mean(y[500:])) < 1e-6, "band-pass should reject a DC input"


def test_bandpass_favours_qrs_band():
    """A ~15 Hz tone (QRS band) should pass more than 0.5 Hz or 50 Hz tones."""
    t = np.arange(int(4 * FS)) / FS
    amp = {}
    for f in (0.5, 15.0, 50.0):
        y = bandpass_filter(np.sin(2 * np.pi * f * t))
        amp[f] = float(np.std(y[int(FS):]))   # skip startup transient
    assert amp[15.0] > amp[0.5], "15 Hz should pass more than 0.5 Hz"
    assert amp[15.0] > amp[50.0], "15 Hz should pass more than 50 Hz"


# --- scorer -----------------------------------------------------------------

def test_match_detections_counts():
    ref = np.array([100, 200, 300, 400])
    det = np.array([102, 205, 500])        # 2 hits, 1 extra (FP), 2 misses (FN)
    m = match_detections(ref, det, tolerance=10)
    assert (m.tp, m.fp, m.fn) == (2, 1, 2), (m.tp, m.fp, m.fn)
    assert abs(m.sensitivity - 0.5) < 1e-9
    assert abs(m.positive_predictivity - 2 / 3) < 1e-9


def test_match_is_one_to_one():
    ref = np.array([100])
    det = np.array([98, 103])              # two detections, one real beat
    m = match_detections(ref, det, tolerance=10)
    assert m.tp == 1 and m.fp == 1 and m.fn == 0


# --- end-to-end on real data ------------------------------------------------

def _score_record(record: str):
    rec = load_ecg_record(record, data_dir=_DATA)
    ref = np.array([s for s, sym in zip(rec.ann_sample, rec.ann_symbol)
                    if sym in BEAT_SYMBOLS], dtype=np.int64)
    res = detect_qrs(rec.signal, rec.fs)
    tol = int(round(0.150 * rec.fs))
    return match_detections(ref, res.qrs_indices, tol)


def test_detector_record100_accuracy():
    m = _score_record("100")
    assert m.sensitivity > 0.99, f"Se={m.sensitivity:.4f} on record 100"
    assert m.positive_predictivity > 0.99, f"+P={m.positive_predictivity:.4f} on record 100"


# --- direct-run harness -----------------------------------------------------

def _run_all() -> int:
    checks = [
        ("MWI window = 150 ms (54 samples)", test_mwi_window_is_150ms),
        ("Derivative impulse response", test_derivative_impulse_response),
        ("Band-pass rejects DC", test_bandpass_removes_dc),
        ("Band-pass favours QRS band (~15 Hz)", test_bandpass_favours_qrs_band),
        ("Scorer TP/FP/FN counts", test_match_detections_counts),
        ("Scorer is one-to-one", test_match_is_one_to_one),
        ("Record 100 Se>99% and +P>99%", test_detector_record100_accuracy),
    ]
    fails = 0
    print(f"Running {len(checks)} Phase-2 checks ...\n")
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
