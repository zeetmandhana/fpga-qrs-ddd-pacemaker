"""
verify_record_integrity.py -- deep integrity check for a repaired MIT-BIH record.

Goes beyond the structural checks in test_ecg_loader.py. Everything here is read
FRESH from disk in this process (no cached arrays), so it reflects the file that
is actually on disk right now. It verifies:

  * the .dat size equals what the header implies (format x length x channels)
  * the .hea/.dat/.atr SHA256 match PhysioNet's published SHA256SUMS (authoritative)
  * the WFDB header and the data file are mutually consistent
  * the decoded ECG samples are finite, plausibly scaled, and SMOOTH
    (high adjacent-sample correlation) -- i.e. a real ECG, not interleaved garbage

Run:  python tests\verify_record_integrity.py
"""

from __future__ import annotations

import hashlib
import os
import sys

import numpy as np
import wfdb

_THIS = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.dirname(_THIS)
_DATA = os.path.join(_ROOT, "data")
sys.path.insert(0, os.path.join(_ROOT, "src"))

from ecg_loader import (  # noqa: E402
    _expected_dat_bytes,
    extract_segment,
    load_ecg_record,
)

RECORD = "100"


def sha256_of(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest().lower()


def published_sums() -> dict[str, str]:
    table: dict[str, str] = {}
    sums = os.path.join(_DATA, "SHA256SUMS.txt")
    if os.path.exists(sums):
        with open(sums, encoding="utf-8") as fh:
            for line in fh:
                parts = line.split()
                if len(parts) == 2:
                    table[parts[1]] = parts[0].lower()
    return table


def main() -> int:
    prefix = os.path.join(_DATA, RECORD)
    checks: list[tuple[str, bool, str]] = []

    # (2/4) size vs header-implied bytes
    expected_bytes = _expected_dat_bytes(prefix)
    actual_bytes = os.path.getsize(prefix + ".dat")
    checks.append((f"{RECORD}.dat size == header-implied bytes",
                   actual_bytes == expected_bytes,
                   f"{actual_bytes} vs {expected_bytes}"))

    # (3) authoritative SHA256 checksums
    sums = published_sums()
    have_sums = len(sums) > 0
    for ext in ("hea", "dat", "atr"):
        fname = f"{RECORD}.{ext}"
        exp = sums.get(fname)
        got = sha256_of(prefix + "." + ext)
        ok = exp is not None and got == exp
        detail = "match" if ok else (f"got {got[:12]}..., expected "
                                     f"{(exp[:12] + '...') if exp else 'N/A'}")
        checks.append((f"SHA256 {fname} == PhysioNet SHA256SUMS", ok, detail))

    # (4) header <-> data consistency (fresh read)
    rec = wfdb.rdrecord(prefix)
    checks.append(("header fs == 360 Hz", rec.fs == 360, f"fs={rec.fs}"))
    checks.append(("n_sig == data columns",
                   rec.n_sig == rec.p_signal.shape[1],
                   f"{rec.n_sig} vs {rec.p_signal.shape[1]}"))
    checks.append(("sig_len == data rows",
                   rec.sig_len == rec.p_signal.shape[0],
                   f"{rec.sig_len} vs {rec.p_signal.shape[0]}"))

    # (5) signal sanity on the MLII channel (full record)
    ch = rec.sig_name.index("MLII")
    sig = np.asarray(rec.p_signal[:, ch], dtype=float)
    finite = bool(np.isfinite(sig).all())
    smin, smax, smean, sstd = float(sig.min()), float(sig.max()), \
        float(sig.mean()), float(sig.std())
    diffs = np.abs(np.diff(sig))
    max_jump = float(diffs.max())
    autocorr1 = float(np.corrcoef(sig[:-1], sig[1:])[0, 1])

    checks.append(("all samples finite (no NaN/Inf)", finite, f"finite={finite}"))
    checks.append(("amplitude within +/-10 mV", (smin > -10 and smax < 10),
                   f"[{smin:.3f}, {smax:.3f}] mV"))
    checks.append(("std plausible for ECG (0.02-2 mV)", (0.02 < sstd < 2.0),
                   f"std={sstd:.4f} mV"))
    checks.append(("adjacent-sample corr > 0.9 (smooth, not garbage)",
                   autocorr1 > 0.9, f"r(lag1)={autocorr1:.4f}"))
    checks.append(("no absurd sample-to-sample jump (< 5 mV)",
                   max_jump < 5.0, f"max|dx|={max_jump:.3f} mV"))

    # fresh load via our own loader + first-10 s segment
    rec2 = load_ecg_record(RECORD, data_dir=_DATA)
    seg = extract_segment(rec2, 0.0, 10.0)
    checks.append(("ecg_loader first 10 s == 3600 samples",
                   seg.n_samples == 3600, f"{seg.n_samples} samples"))

    # ---- report ----
    print(f"Record {RECORD} integrity report (read fresh from {_DATA})")
    print(f"Authoritative SHA256SUMS available: {have_sums}\n")
    print(f"MLII full-record signal stats ({sig.size} samples @ {rec.fs} Hz):")
    print(f"  min={smin:.3f}  max={smax:.3f}  mean={smean:.4f}  std={sstd:.4f} mV")
    print(f"  max |sample-to-sample jump| = {max_jump:.3f} mV")
    print(f"  lag-1 autocorrelation       = {autocorr1:.5f}")
    print(f"\nFirst 10 s: {seg.n_samples} samples, {len(seg.ann_symbol)} annotations, "
          f"{seg.n_beats} reference beats, symbols={seg.symbol_counts()}")

    print("\n--- integrity checks ---")
    fails = 0
    for name, ok, detail in checks:
        print(f"  [{'PASS' if ok else 'FAIL'}] {name}  ({detail})")
        if not ok:
            fails += 1
    print(f"\n{len(checks) - fails}/{len(checks)} integrity checks passed.")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
