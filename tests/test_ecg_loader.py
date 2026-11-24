"""
test_ecg_loader.py  --  P17 Phase 1 verification checks

Runnable two ways:
    python tests/test_ecg_loader.py        # prints a PASS/FAIL table, exit code
    pytest tests/test_ecg_loader.py         # standard pytest discovery

These checks confirm the Phase-1 requirements: the record loads, the sampling
frequency is 360 Hz, the MLII channel is selected, the reference annotations
load, and the first 10 seconds are extracted correctly.  No QRS detection is
asserted -- that algorithm does not exist yet.
"""

from __future__ import annotations

import hashlib
import os
import sys

import numpy as np

# Make 'src' importable whether run via pytest or directly.
_THIS_DIR = os.path.dirname(os.path.abspath(__file__))
_PROJECT_ROOT = os.path.dirname(_THIS_DIR)
_SRC = os.path.join(_PROJECT_ROOT, "src")
_DATA = os.path.join(_PROJECT_ROOT, "data")
if _SRC not in sys.path:
    sys.path.insert(0, _SRC)

from ecg_loader import (  # noqa: E402
    EXPECTED_FS_HZ,
    PREFERRED_CHANNEL,
    _expected_dat_bytes,
    extract_segment,
    load_ecg_record,
)

RECORD = "100"
SECONDS = 10.0


def _load():
    rec = load_ecg_record(RECORD, data_dir=_DATA)
    seg = extract_segment(rec, 0.0, SECONDS)
    return rec, seg


# --- pytest-style assertions ------------------------------------------------

def test_sampling_frequency_is_360():
    rec, _ = _load()
    assert rec.fs == EXPECTED_FS_HZ, f"fs={rec.fs}, expected {EXPECTED_FS_HZ}"


def test_mlii_channel_selected():
    rec, _ = _load()
    assert rec.channel_name == PREFERRED_CHANNEL, \
        f"selected '{rec.channel_name}', expected '{PREFERRED_CHANNEL}'"


def test_units_are_mv():
    rec, _ = _load()
    assert rec.units == "mV", f"units='{rec.units}', expected 'mV'"


def test_segment_sample_count():
    rec, seg = _load()
    expected = int(round(SECONDS * rec.fs))  # 10 s * 360 Hz = 3600
    assert seg.n_samples == expected, f"{seg.n_samples} samples, expected {expected}"


def test_annotations_loaded_and_in_range():
    rec, seg = _load()
    assert len(rec.ann_symbol) > 0, "no annotations loaded for the full record"
    assert seg.n_beats > 0, "no reference beats found in the first 10 s"
    assert ((seg.ann_sample_abs >= seg.start_sample) &
            (seg.ann_sample_abs < seg.end_sample)).all(), \
        "an annotation lies outside the extracted window"


def test_signal_preserved_as_float():
    rec, seg = _load()
    assert seg.signal.dtype.kind == "f", "ECG samples should stay floating point"
    assert seg.signal.shape[0] == seg.time_s.shape[0], "signal/time length mismatch"


# --- signal-CONTENT checks (not just metadata / array shapes) ---------------
# These validate the actual decoded samples, so a structurally-valid but
# corrupted file (e.g. one damaged by an interrupted/concurrent download) is
# caught -- the earlier metadata-only checks would pass on such a file.

def test_dat_size_matches_header():
    """File bytes must equal sig_len x n_sig x bits/8 -> catches truncation/overrun."""
    prefix = os.path.join(_DATA, RECORD)
    expected = _expected_dat_bytes(prefix)
    assert expected is not None, "could not derive expected .dat size from header"
    actual = os.path.getsize(prefix + ".dat")
    assert actual == expected, f"{RECORD}.dat is {actual} bytes, header implies {expected}"


def test_dat_sha256_matches_physionet():
    """.dat must match PhysioNet's AUTHORITATIVE published SHA256 (content check)."""
    sums = os.path.join(_DATA, "SHA256SUMS.txt")
    assert os.path.exists(sums), "SHA256SUMS.txt not present; cannot verify authoritatively"
    expected = None
    with open(sums, encoding="utf-8") as fh:
        for line in fh:
            parts = line.split()
            if len(parts) == 2 and parts[1] == f"{RECORD}.dat":
                expected = parts[0].lower()
                break
    assert expected is not None, f"no checksum line for {RECORD}.dat in SHA256SUMS.txt"
    h = hashlib.sha256()
    with open(os.path.join(_DATA, RECORD + ".dat"), "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    assert h.hexdigest().lower() == expected, f"{RECORD}.dat SHA256 != PhysioNet value"


def test_signal_samples_finite():
    rec, _ = _load()
    assert np.isfinite(rec.signal).all(), "signal contains NaN or Inf"


def test_signal_amplitude_and_variance_plausible():
    """Physiological ECG scale, and not a flat/constant trace."""
    rec, _ = _load()
    sig = rec.signal
    assert sig.min() > -10.0 and sig.max() < 10.0, \
        f"amplitude [{sig.min():.3f},{sig.max():.3f}] mV outside plausible range"
    assert 0.02 < sig.std() < 2.0, f"std {sig.std():.4f} mV implausible for ECG"


def test_signal_is_smooth_not_garbage():
    """Adjacent samples of a 360 Hz ECG are highly correlated; interleaved
    garbage would decorrelate them. Also flag absurd discontinuities."""
    rec, _ = _load()
    sig = rec.signal
    r1 = float(np.corrcoef(sig[:-1], sig[1:])[0, 1])
    assert r1 > 0.9, f"lag-1 autocorrelation {r1:.3f} too low (looks like garbage)"
    assert float(np.abs(np.diff(sig)).max()) < 5.0, "implausibly large sample jump"


# --- direct-run harness -----------------------------------------------------

def _run_all() -> int:
    checks = [
        # structural / metadata
        ("Sampling frequency is 360 Hz", test_sampling_frequency_is_360),
        ("MLII channel selected", test_mlii_channel_selected),
        ("Units are mV", test_units_are_mv),
        ("First 10 s = 3600 samples", test_segment_sample_count),
        ("Reference annotations load & in range", test_annotations_loaded_and_in_range),
        ("ECG samples preserved as float", test_signal_preserved_as_float),
        # signal content (catch a corrupt-but-structurally-valid file)
        (".dat size matches header", test_dat_size_matches_header),
        (".dat SHA256 matches PhysioNet (authoritative)", test_dat_sha256_matches_physionet),
        ("Signal samples all finite", test_signal_samples_finite),
        ("Signal amplitude & variance plausible", test_signal_amplitude_and_variance_plausible),
        ("Signal is smooth, not garbage", test_signal_is_smooth_not_garbage),
    ]
    failures = 0
    print(f"Running {len(checks)} Phase-1 checks on record {RECORD} ...\n")
    for name, fn in checks:
        try:
            fn()
            print(f"  [PASS] {name}")
        except AssertionError as exc:
            failures += 1
            print(f"  [FAIL] {name}: {exc}")
        except Exception as exc:  # loading/network errors etc.
            failures += 1
            print(f"  [ERROR] {name}: {exc!r}")
    print(f"\n{len(checks) - failures}/{len(checks)} checks passed.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(_run_all())
