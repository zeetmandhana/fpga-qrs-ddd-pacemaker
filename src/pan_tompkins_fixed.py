"""
pan_tompkins_fixed.py  --  P17 Phase 4: fixed-point (integer) filter chain

A bit-accurate integer model of the Pan-Tompkins filter chain that the HLS
hardware implements. It operates on the RAW ADC samples (what the FPGA would
receive) and uses only adds, shifts and ONE multiplier (the squarer); the
moving-window integrator emits a running SUM, not a mean, so no divider is
needed. QRS detection is scale-invariant, so a running sum works identically to
a mean for the adaptive-threshold decision.

This module is the GOLDEN REFERENCE for the hand-written HLS in hls/: the C++
filter must reproduce these integer stage outputs bit-for-bit. The decision
stage (adaptive thresholds) is shared with the float detector via
pan_tompkins.decide_qrs -- it only compares magnitudes, so it runs on the
integer stages directly.

All intermediate values stay well inside 32 bits (filters) / 64 bits
(square, MWI sum), which is what the HLS data types are sized for.
"""

from __future__ import annotations

import numpy as np
import wfdb

from ecg_loader import PREFERRED_CHANNEL, ensure_record_local
from pan_tompkins import decide_qrs

MWI_WINDOW = 54          # 150 ms at 360 Hz (running sum width)
HP_DIV_SHIFT = 5         # divide by 32  -> arithmetic right shift 5
DERIV_SHIFT = 3          # divide by 8   -> arithmetic right shift 3


def load_record_digital(record: str, data_dir: str,
                        preferred: str = PREFERRED_CHANNEL) -> dict:
    """Load the RAW integer ADC samples (plus baseline/gain) for one record."""
    prefix = ensure_record_local(record, data_dir)
    rec = wfdb.rdrecord(prefix, physical=False)      # d_signal = raw ADC codes
    names = list(rec.sig_name)
    ch = names.index(preferred) if preferred in names else 0
    adc = np.asarray(rec.d_signal[:, ch], dtype=np.int64)
    baseline = int(rec.baseline[ch])
    gain = float(rec.adc_gain[ch])
    return {
        "adc": adc,
        "baseline": baseline,
        "gain": gain,
        "fs": float(rec.fs),
        "channel": names[ch],
        "physical": (adc - baseline) / gain,         # mV, only for R-peak localisation
    }


def fixed_filter_chain(adc: np.ndarray, baseline: int,
                       mwi_window: int = MWI_WINDOW) -> dict:
    """Integer Pan-Tompkins filter chain, per-sample form (mirrors the HLS).

    Returns the integer outputs of every stage. All shifts are arithmetic
    (floor) so they match ap_int<>::operator>> in the C++ exactly.
    """
    n = adc.size
    x = (adc.astype(np.int64) - baseline)            # centre the ADC input

    lp = np.zeros(n, dtype=np.int64)                 # low-pass
    hp = np.zeros(n, dtype=np.int64)                 # high-pass (band-pass out)
    dv = np.zeros(n, dtype=np.int64)                 # derivative
    sq = np.zeros(n, dtype=np.int64)                 # squared
    mwi = np.zeros(n, dtype=np.int64)                # moving-window running sum

    moving_sum = 0                                   # 32-tap running sum (HPF)
    mwi_sum = 0                                      # 54-tap running sum (MWI)

    for i in range(n):
        # --- low-pass: y = 2y[-1] - y[-2] + x - 2x[-6] + x[-12] ---
        v = x[i]
        if i >= 6:
            v -= 2 * x[i - 6]
        if i >= 12:
            v += x[i - 12]
        if i >= 1:
            v += 2 * lp[i - 1]
        if i >= 2:
            v -= lp[i - 2]
        lp[i] = v

        # --- high-pass: ms = ms + lp - lp[-32]; hp = lp[-16] - (ms >> 5) ---
        moving_sum += int(lp[i])
        if i >= 32:
            moving_sum -= int(lp[i - 32])
        d16 = int(lp[i - 16]) if i >= 16 else 0
        hp[i] = d16 - (moving_sum >> HP_DIV_SHIFT)

        # --- derivative: (2hp + hp[-1] - hp[-3] - 2hp[-4]) >> 3 ---
        d = 2 * int(hp[i])
        if i >= 1:
            d += int(hp[i - 1])
        if i >= 3:
            d -= int(hp[i - 3])
        if i >= 4:
            d -= 2 * int(hp[i - 4])
        dv[i] = d >> DERIV_SHIFT

        # --- square: THE one multiplier ---
        sq[i] = int(dv[i]) * int(dv[i])

        # --- moving-window integration: running sum over 54 samples ---
        mwi_sum += int(sq[i])
        if i >= mwi_window:
            mwi_sum -= int(sq[i - mwi_window])
        mwi[i] = mwi_sum

    return {"lp": lp, "hp": hp, "dv": dv, "sq": sq, "mwi": mwi,
            "mwi_window": mwi_window}


def detect_qrs_fixed(rec_dig: dict) -> tuple[np.ndarray, dict]:
    """Full fixed-point detector: integer filter chain + shared decision stage."""
    stages = fixed_filter_chain(rec_dig["adc"], rec_dig["baseline"])
    qrs, cand = decide_qrs(rec_dig["physical"], stages["hp"], stages["dv"],
                           stages["mwi"], rec_dig["fs"], stages["mwi_window"])
    stages["candidate_peaks"] = cand
    return qrs, stages


# ---------------------------------------------------------------------------
# Compare fixed-point vs float detector on record 100:  python src/pan_tompkins_fixed.py
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    import os
    import sys

    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from ecg_loader import BEAT_SYMBOLS, load_ecg_record
    from pan_tompkins import detect_qrs
    from qrs_eval import match_detections

    data_dir = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data")
    record = "100"

    rec = load_ecg_record(record, data_dir=data_dir)
    ref = np.array([s for s, sym in zip(rec.ann_sample, rec.ann_symbol)
                    if sym in BEAT_SYMBOLS], dtype=np.int64)
    tol = int(round(0.150 * rec.fs))

    # float detector
    fres = detect_qrs(rec.signal, rec.fs)
    fm = match_detections(ref, fres.qrs_indices, tol)

    # fixed-point detector
    dig = load_record_digital(record, data_dir)
    fx_qrs, _ = detect_qrs_fixed(dig)
    xm = match_detections(ref, fx_qrs, tol)

    print(f"Record {record}: {ref.size} reference beats")
    print(f"  FLOAT  detector: Se={100*fm.sensitivity:.3f}%  "
          f"+P={100*fm.positive_predictivity:.3f}%  (TP={fm.tp} FP={fm.fp} FN={fm.fn})")
    print(f"  FIXED  detector: Se={100*xm.sensitivity:.3f}%  "
          f"+P={100*xm.positive_predictivity:.3f}%  (TP={xm.tp} FP={xm.fp} FN={xm.fn})")
