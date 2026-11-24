"""
evaluate_detector.py  --  P17 Phase 2: evaluate the Pan-Tompkins golden model.

Runs the detector on several MIT-BIH records, scores the detections against the
reference beat annotations (sensitivity / positive predictivity), writes a
metrics table, and renders:

    results/stage2_pipeline_stages.png    the 5 filter stages on one window
    results/stage2_detection_overlay.png  raw ECG with TP / FP / FN marked
    results/stage2_detector_metrics.csv    per-record + gross metrics
    results/stage2_detector_metrics.json   same, machine-readable

Reference annotations are MIT-BIH GROUND TRUTH; the detections are our algorithm.
Only beat symbols count as reference beats (non-beat markers are excluded).

Usage (venv active, from project root):
    python src/evaluate_detector.py
    python src/evaluate_detector.py --records 100 101 106 208 234
"""

from __future__ import annotations

import argparse
import json
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from ecg_loader import BEAT_SYMBOLS, load_ecg_record
from pan_tompkins import detect_qrs
from qrs_eval import match_detections

SRC_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SRC_DIR)
DATA_DIR = os.path.join(PROJECT_ROOT, "data")
RESULTS_DIR = os.path.join(PROJECT_ROOT, "results")

DEFAULT_RECORDS = ["100", "101", "106", "208", "234"]
TOLERANCE_S = 0.150   # +/- 150 ms match window (standard for QRS scoring)


def reference_beats(rec) -> np.ndarray:
    """Sample indices of the MIT-BIH *beat* annotations (ground truth)."""
    return np.array(
        [s for s, sym in zip(rec.ann_sample, rec.ann_symbol) if sym in BEAT_SYMBOLS],
        dtype=np.int64,
    )


def evaluate_record(record: str) -> dict:
    rec = load_ecg_record(record, data_dir=DATA_DIR)
    ref = reference_beats(rec)
    res = detect_qrs(rec.signal, rec.fs)
    tol = int(round(TOLERANCE_S * rec.fs))
    m = match_detections(ref, res.qrs_indices, tol)
    return {
        "record": record,
        "channel": rec.channel_name,
        "n_ref_beats": int(ref.size),
        "n_detected": int(res.qrs_indices.size),
        "TP": m.tp, "FP": m.fp, "FN": m.fn,
        "sensitivity_%": round(100.0 * m.sensitivity, 3),
        "pos_predictivity_%": round(100.0 * m.positive_predictivity, 3),
    }


def plot_pipeline_stages(record: str, t0: float, t1: float, out_png: str) -> None:
    """Show the 5 Pan-Tompkins stages over a time window of one record."""
    rec = load_ecg_record(record, data_dir=DATA_DIR)
    res = detect_qrs(rec.signal, rec.fs)
    fs = rec.fs
    a, b = int(t0 * fs), int(t1 * fs)
    t = np.arange(a, b) / fs

    stages = [
        (rec.signal[a:b], f"1. Raw ECG ({rec.channel_name}, mV)"),
        (res.bandpass[a:b], "2. Band-pass (integer LPF+HPF)"),
        (res.derivative[a:b], "3. Derivative"),
        (res.squared[a:b], "4. Squared"),
        (res.integrated[a:b], f"5. Moving-window integration ({res.mwi_window} samp)"),
    ]
    qrs = res.qrs_indices[(res.qrs_indices >= a) & (res.qrs_indices < b)]

    fig, axes = plt.subplots(len(stages), 1, figsize=(13, 10), sharex=True)
    for ax, (sig, title) in zip(axes, stages):
        ax.plot(t, sig, color="#1f4e79", linewidth=0.9)
        ax.set_ylabel(title, fontsize=8)
        ax.grid(True, alpha=0.3)
        for q in qrs:
            ax.axvline(q / fs, color="#c00000", alpha=0.35, linewidth=0.8)
    axes[0].set_title(f"Pan-Tompkins pipeline stages - record {record} "
                      f"({t0:.0f}-{t1:.0f} s); red lines = detected QRS")
    axes[-1].set_xlabel("Time (s)")
    fig.tight_layout()
    os.makedirs(os.path.dirname(out_png), exist_ok=True)
    fig.savefig(out_png, dpi=150)
    plt.close(fig)


def plot_detection_overlay(record: str, t0: float, t1: float, out_png: str) -> None:
    """Raw ECG with reference beats and detections (TP / FP / FN) marked."""
    rec = load_ecg_record(record, data_dir=DATA_DIR)
    ref = reference_beats(rec)
    res = detect_qrs(rec.signal, rec.fs)
    fs = rec.fs
    tol = int(round(TOLERANCE_S * fs))
    m = match_detections(ref, res.qrs_indices, tol)

    a, b = int(t0 * fs), int(t1 * fs)
    t = np.arange(a, b) / fs

    def inwin(x):
        return x[(x >= a) & (x < b)]

    tp = inwin(m.matched_det)
    fp = inwin(m.extra_det)
    fn = inwin(m.missed_ref)

    fig, ax = plt.subplots(figsize=(13, 5))
    ax.plot(t, rec.signal[a:b], color="#1f4e79", linewidth=0.9, label="ECG")
    ax.plot(tp / fs, rec.signal[tp], "o", mfc="none", mec="#1a9850",
            mew=1.6, ms=11, label=f"True positive ({m.tp})")
    if fp.size:
        ax.plot(fp / fs, rec.signal[fp], "x", color="#d73027", mew=2,
                ms=10, label=f"False positive ({m.fp})")
    if fn.size:
        ax.plot(fn / fs, rec.signal[fn], "s", mfc="none", mec="#f46d43",
                mew=1.8, ms=12, label=f"False negative ({m.fn})")
    ax.set_title(f"QRS detection vs reference - record {record} ({t0:.0f}-{t1:.0f} s) "
                 f"| Se={100*m.sensitivity:.2f}%  +P={100*m.positive_predictivity:.2f}% "
                 f"(whole record)")
    ax.set_xlabel("Time (s)")
    ax.set_ylabel(f"ECG amplitude ({rec.units})")
    ax.set_xlim(t0, t1)
    ax.grid(True, alpha=0.3)
    ax.legend(loc="upper right", framealpha=0.9)
    fig.tight_layout()
    os.makedirs(os.path.dirname(out_png), exist_ok=True)
    fig.savefig(out_png, dpi=150)
    plt.close(fig)


def main() -> None:
    parser = argparse.ArgumentParser(description="Phase 2: evaluate Pan-Tompkins detector.")
    parser.add_argument("--records", nargs="+", default=DEFAULT_RECORDS)
    parser.add_argument("--plot-record", default="100")
    args = parser.parse_args()

    rows = []
    print(f"Scoring Pan-Tompkins detector (match tolerance +/-{TOLERANCE_S*1000:.0f} ms)\n")
    print(f"{'rec':>4} {'ref':>6} {'det':>6} {'TP':>6} {'FP':>5} {'FN':>5} "
          f"{'Se%':>8} {'+P%':>8}")
    for record in args.records:
        r = evaluate_record(record)
        rows.append(r)
        print(f"{r['record']:>4} {r['n_ref_beats']:>6} {r['n_detected']:>6} "
              f"{r['TP']:>6} {r['FP']:>5} {r['FN']:>5} "
              f"{r['sensitivity_%']:>8.3f} {r['pos_predictivity_%']:>8.3f}")

    tot_tp = sum(r["TP"] for r in rows)
    tot_fp = sum(r["FP"] for r in rows)
    tot_fn = sum(r["FN"] for r in rows)
    gross_se = 100.0 * tot_tp / (tot_tp + tot_fn) if (tot_tp + tot_fn) else 0.0
    gross_pp = 100.0 * tot_tp / (tot_tp + tot_fp) if (tot_tp + tot_fp) else 0.0
    print(f"\nGROSS  TP={tot_tp} FP={tot_fp} FN={tot_fn}  "
          f"Se={gross_se:.3f}%  +P={gross_pp:.3f}%")

    summary = {
        "match_tolerance_ms": TOLERANCE_S * 1000,
        "records": rows,
        "gross": {"TP": tot_tp, "FP": tot_fp, "FN": tot_fn,
                  "sensitivity_%": round(gross_se, 3),
                  "pos_predictivity_%": round(gross_pp, 3)},
        "note": ("Reference beats are MIT-BIH ground-truth beat annotations; "
                 "detections are the Pan-Tompkins golden model. Non-beat symbols "
                 "are excluded from the reference beat set."),
    }
    os.makedirs(RESULTS_DIR, exist_ok=True)
    with open(os.path.join(RESULTS_DIR, "stage2_detector_metrics.json"), "w") as fh:
        json.dump(summary, fh, indent=2)
    pd.DataFrame(rows).to_csv(
        os.path.join(RESULTS_DIR, "stage2_detector_metrics.csv"), index=False)

    stages_png = os.path.join(RESULTS_DIR, "stage2_pipeline_stages.png")
    overlay_png = os.path.join(RESULTS_DIR, "stage2_detection_overlay.png")
    print(f"\nPlotting pipeline stages -> {stages_png}")
    plot_pipeline_stages(args.plot_record, 0.0, 6.0, stages_png)
    print(f"Plotting detection overlay -> {overlay_png}")
    plot_detection_overlay(args.plot_record, 0.0, 10.0, overlay_png)
    print("\nDone.")


if __name__ == "__main__":
    main()
