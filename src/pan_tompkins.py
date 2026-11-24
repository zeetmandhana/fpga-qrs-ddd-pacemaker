"""
pan_tompkins.py  --  P17 QRS Detector (Phase 2 golden model)

A software golden model of the Pan-Tompkins QRS detector, written to mirror the
hardware data path that will be built later. The filter chain uses the classic
INTEGER difference equations (hardware-friendly: adds, shifts, one squarer), and
the decision stage is the adaptive dual-threshold scheme from

    J. Pan and W. J. Tompkins, "A Real-Time QRS Detection Algorithm,"
    IEEE Trans. Biomed. Eng., BME-32(3):230-236, 1985.

Pipeline:
    raw ECG --> band-pass (integer LPF then HPF) --> derivative --> square
            --> 150 ms moving-window integration --> adaptive thresholds
            --> QRS fiducial (R-peak) locations

This is a MODEL ONLY. No RTL/HLS, no pacemaker logic. The detector output is a
list of detected R-peak sample indices; Phase-2 evaluation scores these against
the MIT-BIH reference annotations (sensitivity / positive predictivity).

NOTE on sampling rate: the MIT-BIH records are 360 Hz (the original Pan-Tompkins
constants were for 200 Hz). We keep the integer filters as-is and size the
moving-window integrator to 150 ms = round(0.150 * fs) = 54 samples at 360 Hz,
as the project specification states. The adaptive thresholds self-scale, so the
detector tracks the signal regardless of the exact passband.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
from scipy.signal import find_peaks, lfilter

# ---------------------------------------------------------------------------
# Stage 1-5: the filter chain (integer difference equations)
# ---------------------------------------------------------------------------

def lowpass_filter(x: np.ndarray) -> np.ndarray:
    """Integer low-pass:  y[n] = 2y[n-1] - y[n-2] + x[n] - 2x[n-6] + x[n-12].

    H(z) = (1 - z^-6)^2 / (1 - z^-1)^2.  Gain 36, group delay 6 samples.
    """
    b = np.zeros(13)
    b[0], b[6], b[12] = 1.0, -2.0, 1.0
    a = np.array([1.0, -2.0, 1.0])
    return lfilter(b, a, x)


def highpass_filter(x: np.ndarray) -> np.ndarray:
    """Integer high-pass:  y[n] = x[n-16] - (1/32) * sum_{k=0}^{31} x[n-k].

    Implemented as (delay-16 all-pass) minus (32-tap moving average). The moving
    sum s[n] = s[n-1] + x[n] - x[n-32] is recursive but the overall filter is
    FIR and stable. Group delay ~16 samples.
    """
    b_ms = np.zeros(33)
    b_ms[0], b_ms[32] = 1.0, -1.0
    moving_sum = lfilter(b_ms, np.array([1.0, -1.0]), x)   # 32-sample running sum
    delayed_16 = np.concatenate([np.zeros(16), x[:-16]])
    return delayed_16 - moving_sum / 32.0


def bandpass_filter(x: np.ndarray) -> np.ndarray:
    """Band-pass = integer LPF cascaded with integer HPF (~QRS energy band)."""
    return highpass_filter(lowpass_filter(x))


def derivative_filter(x: np.ndarray) -> np.ndarray:
    """5-point derivative:  y[n] = (1/8)(2x[n] + x[n-1] - x[n-3] - 2x[n-4]).

    Emphasises the steep QRS slope. Group delay 2 samples.
    """
    b = np.array([2.0, 1.0, 0.0, -1.0, -2.0]) / 8.0
    return lfilter(b, np.array([1.0]), x)


def square_signal(x: np.ndarray) -> np.ndarray:
    """Point-by-point squaring: makes everything positive, boosts large slopes."""
    return x * x


def moving_window_integration(x: np.ndarray, fs: float) -> tuple[np.ndarray, int]:
    """150 ms moving-window integration. Returns (integrated signal, window N)."""
    n = int(round(0.150 * fs))              # 54 samples at 360 Hz
    b = np.ones(n) / n
    return lfilter(b, np.array([1.0]), x), n


# ---------------------------------------------------------------------------
# Result container
# ---------------------------------------------------------------------------

@dataclass
class DetectionResult:
    fs: float
    qrs_indices: np.ndarray       # detected R-peak sample indices (on input signal)
    bandpass: np.ndarray          # stage outputs, for plotting / inspection
    derivative: np.ndarray
    squared: np.ndarray
    integrated: np.ndarray
    mwi_window: int
    candidate_peaks: np.ndarray   # all MWI local maxima considered

    @property
    def n_detected(self) -> int:
        return int(self.qrs_indices.size)


# ---------------------------------------------------------------------------
# Stage 6: adaptive thresholding + decision (Pan-Tompkins)
# ---------------------------------------------------------------------------

def detect_qrs(signal: np.ndarray, fs: float) -> DetectionResult:
    """Detect QRS complexes in a single-channel ECG using Pan-Tompkins.

    Returns a DetectionResult whose `qrs_indices` are R-peak sample positions in
    the ORIGINAL `signal` (fiducials are refined back onto the band-passed wave).
    """
    signal = np.asarray(signal, dtype=float)
    n_total = signal.size

    # ---- filter chain --------------------------------------------------
    bp = bandpass_filter(signal)
    deriv = derivative_filter(bp)
    squared = square_signal(deriv)
    mwi, win = moving_window_integration(squared, fs)

    qrs_sorted, cand = decide_qrs(signal, bp, deriv, mwi, fs, win)
    return DetectionResult(
        fs=fs,
        qrs_indices=qrs_sorted,
        bandpass=bp,
        derivative=deriv,
        squared=squared,
        integrated=mwi,
        mwi_window=win,
        candidate_peaks=cand,
    )


def decide_qrs(signal: np.ndarray, bp: np.ndarray, deriv: np.ndarray,
               mwi: np.ndarray, fs: float, win: int):
    """Adaptive-threshold QRS decision on precomputed filter-chain stages.

    Shared by the float detector and the fixed-point (hardware) model; it only
    compares magnitudes, so it runs on float OR integer stage arrays. Returns
    (R-peak indices on `signal`, candidate MWI peak indices).
    """
    signal = np.asarray(signal, dtype=float)
    n_total = signal.size

    refractory = int(round(0.200 * fs))     # 200 ms physiological QRS refractory
    twave_rr = 0.360                         # RR below this (s) triggers T-wave test
    half_search = int(round(0.075 * fs))     # +/- window for R-peak localisation
    # Group delay from raw ECG to the MWI peak (lpf 6 + hpf 16 + deriv 2 + half window)
    group_delay = 6 + 16 + 2 + win // 2

    # ---- candidate peaks on the integrated signal ----------------------
    # All local maxima; the decision loop enforces the refractory period and
    # performs search-back among sub-threshold peaks.
    cand, _ = find_peaks(mwi, distance=max(1, int(round(0.05 * fs))))

    # ---- learning phase: initialise running estimates from first 2 s ----
    learn = slice(0, min(n_total, int(round(2.0 * fs))))
    spki = 0.25 * float(np.max(mwi[learn])) if mwi[learn].size else 0.0   # signal peak (MWI)
    npki = 0.5 * float(np.mean(mwi[learn])) if mwi[learn].size else 0.0   # noise  peak (MWI)
    spkf = 0.25 * float(np.max(bp[learn])) if bp[learn].size else 0.0     # signal peak (band-pass)
    npkf = 0.5 * float(np.mean(np.abs(bp[learn]))) if bp[learn].size else 0.0

    qrs: list[int] = []            # detected R-peak indices (on raw signal)
    qrs_mwi: list[int] = []        # corresponding MWI peak indices
    rr_recent: list[int] = []      # last 8 RR intervals (samples)
    rr_ok: list[int] = []          # last 8 RR intervals within normal limits
    rr_avg1 = rr_avg2 = 0.0        # mean of last 8 (all) / last 8 (normal) RR
    rr_low = rr_high = rr_missed = 0.0
    irregular = False              # rhythm irregular -> halve thresholds (PT rule)
    last_qrs_mwi = -refractory     # MWI index of last accepted QRS
    last_slope = 0.0               # slope (max |deriv|) of last accepted QRS
    # buffer of sub-threshold peaks since the last QRS, for search-back
    pending: list[tuple[int, float, float, float]] = []  # (idx, peaki, peakf, slope)

    def localise_rpeak(mwi_idx: int) -> int:
        """Map an MWI peak back to the true R-peak on the raw signal."""
        center = mwi_idx - group_delay
        lo = max(0, center - half_search)
        hi = min(n_total, center + half_search + 1)
        if hi <= lo:
            return int(min(max(center, 0), n_total - 1))
        window = signal[lo:hi]
        return int(lo + np.argmax(np.abs(window - np.median(window))))

    def bandpass_peak_and_slope(mwi_idx: int) -> tuple[float, float]:
        """Peak of the band-passed wave and the QRS slope near this MWI peak."""
        lo = max(0, mwi_idx - win)
        hi = min(n_total, mwi_idx + 1)
        peakf = float(np.max(np.abs(bp[lo:hi]))) if hi > lo else 0.0
        slope = float(np.max(np.abs(deriv[lo:hi]))) if hi > lo else 0.0
        return peakf, slope

    def register_qrs(mwi_idx: int, peaki: float, peakf: float, slope: float,
                     searchback: bool) -> None:
        nonlocal spki, spkf, last_qrs_mwi, last_slope
        nonlocal rr_low, rr_high, rr_missed, rr_avg1, rr_avg2, irregular
        # update signal-peak estimates (lighter weight on a search-back find)
        if searchback:
            spki = 0.25 * peaki + 0.75 * spki
            spkf = 0.25 * peakf + 0.75 * spkf
        else:
            spki = 0.125 * peaki + 0.875 * spki
            spkf = 0.125 * peakf + 0.875 * spkf
        # RR bookkeeping: maintain both the all-beat and normal-only averages.
        if qrs_mwi:
            rr = mwi_idx - qrs_mwi[-1]
            if rr > 0:
                rr_recent.append(rr)
                if len(rr_recent) > 8:
                    rr_recent.pop(0)
                # classify as "normal" against the limits in force BEFORE update
                if rr_low == 0.0 or (rr_low <= rr <= rr_high):
                    rr_ok.append(rr)
                    if len(rr_ok) > 8:
                        rr_ok.pop(0)
                rr_avg1 = float(np.mean(rr_recent))
                rr_avg2 = float(np.mean(rr_ok)) if rr_ok else rr_avg1
                # irregular rhythm when the all-beat and normal averages diverge
                irregular = bool(rr_ok) and abs(rr_avg1 - rr_avg2) > 0.10 * rr_avg2
                rr_low, rr_high = 0.92 * rr_avg2, 1.16 * rr_avg2
                rr_missed = 1.66 * rr_avg2
        qrs_mwi.append(mwi_idx)
        qrs.append(localise_rpeak(mwi_idx))
        last_qrs_mwi = mwi_idx
        last_slope = slope

    for idx in cand:
        peaki = float(mwi[idx])
        peakf, slope = bandpass_peak_and_slope(int(idx))
        thr_i1 = npki + 0.25 * (spki - npki)
        thr_f1 = npkf + 0.25 * (spkf - npkf)
        # Pan-Tompkins: when the rhythm is irregular, halve the thresholds so
        # smaller beats among large ectopics (e.g. bigeminy) are not missed.
        if irregular:
            thr_i1 *= 0.5
            thr_f1 *= 0.5

        is_qrs = False
        if (idx - last_qrs_mwi) > refractory:
            if peaki > thr_i1 and peakf > thr_f1:
                # T-wave discrimination for short RR intervals
                if qrs_mwi and (idx - qrs_mwi[-1]) < int(round(twave_rr * fs)):
                    if slope > 0.5 * last_slope:
                        is_qrs = True            # steep enough -> genuine QRS
                    # else: identified as a T-wave, fall through to noise update
                else:
                    is_qrs = True

        if is_qrs:
            register_qrs(int(idx), peaki, peakf, slope, searchback=False)
            pending.clear()
        else:
            # noise peak: update noise estimates and keep for possible search-back
            npki = 0.125 * peaki + 0.875 * npki
            npkf = 0.125 * peakf + 0.875 * npkf
            pending.append((int(idx), peaki, peakf, slope))

        # ---- search-back: too long since last QRS? re-examine pending peaks ----
        if rr_missed > 0 and (idx - last_qrs_mwi) > rr_missed:
            thr_i2 = 0.5 * thr_i1
            thr_f2 = 0.5 * thr_f1
            best = None
            for (pidx, ppi, ppf, psl) in pending:
                if (pidx - last_qrs_mwi) > refractory and ppi > thr_i2 and ppf > thr_f2:
                    if best is None or ppi > best[1]:
                        best = (pidx, ppi, ppf, psl)
            if best is not None:
                register_qrs(best[0], best[1], best[2], best[3], searchback=True)
                pending = [p for p in pending if p[0] > best[0]]

    qrs_sorted = np.array(sorted(set(qrs)), dtype=np.int64)
    return qrs_sorted, cand


# ---------------------------------------------------------------------------
# Manual smoke test:  python src/pan_tompkins.py
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    import os
    import sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from ecg_loader import load_ecg_record

    data_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data")
    rec = load_ecg_record("100", data_dir=data_dir)
    res = detect_qrs(rec.signal, rec.fs)
    dur_min = rec.duration_s / 60.0
    print(f"Record {rec.record_name}: detected {res.n_detected} QRS "
          f"in {rec.duration_s:.0f} s ({res.n_detected / dur_min:.1f} bpm avg), "
          f"MWI window = {res.mwi_window} samples")
    first10 = res.qrs_indices[res.qrs_indices < int(10 * rec.fs)]
    print(f"First 10 s: {first10.size} beats at t(s) = "
          f"{np.round(first10 / rec.fs, 2).tolist()}")
