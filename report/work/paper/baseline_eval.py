"""
baseline_eval.py  --  VL401 report Section 9: baseline vs Pan-Tompkins (paper) detector

Three streaming, integer, hardware-style detectors on the SAME MIT-BIH input
(MLII, 360 Hz, raw 11-bit ADC codes), scored with the SAME matcher (+/-150 ms):

  B0  fixed threshold on the raw ECG (our Phase-6 demo detector): a beat is
      declared when x = adc - baseline rises above T, then 200 ms refractory.
  B1  ablation: the Pan-Tompkins filter chain (bit-exact HLS outputs) but a
      FIXED threshold on the moving-window integral instead of the paper's
      adaptive dual thresholds; fiducial = crossing - D (D fitted on rec 100).
  E   full Pan-Tompkins as implemented on the board (src/qrs_hw_detector.py,
      bit-exact with rtl/qrs_decision.v).

T (and D) are tuned on record 100 only (best F1), then frozen for all records,
like a fixed hardware constant. Writes paper_results.json / .txt here.

Run: .venv\\Scripts\\python report\\work\\paper\\baseline_eval.py
"""

from __future__ import annotations

import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "src"))
from ecg_loader import BEAT_SYMBOLS, load_ecg_record          # noqa: E402
from pan_tompkins_fixed import fixed_filter_chain, load_record_digital  # noqa: E402
from qrs_eval import match_detections                          # noqa: E402
from qrs_hw_detector import detect_stream                      # noqa: E402

DATA = os.path.join(ROOT, "data")
RECORDS = ["100", "101", "106", "208", "234"]
FS = 360
TOL = 54            # 150 ms
REFRACT = 72        # 200 ms, same as the Pan-Tompkins refractory period


def crossings(sig: np.ndarray, thr: int) -> np.ndarray:
    """Rising crossings of `thr` with a 200 ms refractory period (streaming rule)."""
    above = sig > thr
    rise = np.flatnonzero(above[1:] & ~above[:-1]) + 1
    out, last = [], -10 * REFRACT
    for n in rise:
        if n - last >= REFRACT:
            out.append(n)
            last = n
    return np.asarray(out, dtype=np.int64)


def score(ref, det):
    m = match_detections(ref, det, TOL)
    return m.tp, m.fp, m.fn


def f1(tp, fp, fn):
    return 2 * tp / (2 * tp + fp + fn) if tp else 0.0


def load(rec_name):
    rec = load_ecg_record(rec_name, data_dir=DATA)
    ref = np.array([s for s, sym in zip(rec.ann_sample, rec.ann_symbol)
                    if sym in BEAT_SYMBOLS], dtype=np.int64)
    dig = load_record_digital(rec_name, DATA)
    x = dig["adc"] - dig["baseline"]
    st = fixed_filter_chain(dig["adc"], dig["baseline"])
    return ref, x, st


def latency_ms(ref, det, delay):
    """decision time - matched R peak (ms), for detections that match a beat."""
    m = match_detections(ref, det - delay, TOL)
    if not m.tp:
        return float("nan")
    # matched_ref / matched_det are aligned pairs (TP)
    return float(np.mean((np.asarray(m.matched_det) + delay - np.asarray(m.matched_ref)) * 1000 / FS))


def main() -> None:
    data = {r: load(r) for r in RECORDS}

    # ---- tune B0 threshold on record 100 ----
    ref, x, st = data["100"]
    best0 = max(((f1(*score(ref, crossings(x, T))), T) for T in range(20, 800, 5)))
    T0 = best0[1]

    # ---- tune B1 threshold (log grid) and fiducial delay D on record 100 ----
    mwi = st["mwi"]
    grid = np.unique(np.round(np.geomspace(max(1, np.percentile(mwi, 50)), mwi.max(), 400))).astype(np.int64)
    best1 = (-1, 0, 0)
    for T in grid:
        c = crossings(mwi, int(T))
        if c.size == 0:
            continue
        # D = median distance from crossing back to the nearest reference beat
        idx = np.searchsorted(ref, c)
        idx = np.clip(idx, 1, ref.size - 1)
        near = np.where(np.abs(ref[idx] - c) < np.abs(ref[idx - 1] - c), ref[idx], ref[idx - 1])
        D = int(np.median(c - near))
        s = f1(*score(ref, c - D))
        if s > best1[0]:
            best1 = (s, int(T), D)
    _, T1, D1 = best1

    rows = []
    tot = {k: [0, 0, 0] for k in ("B0", "B1", "E")}
    lat = {k: [] for k in ("B0", "B1", "E")}
    for r in RECORDS:
        ref, x, st = data[r]
        d0 = crossings(x, T0)
        d1 = crossings(st["mwi"], T1) - D1
        de, events = detect_stream(st["hp"], st["dv"], st["mwi"])
        row = {"record": r, "beats": int(ref.size)}
        for k, det in (("B0", d0), ("B1", d1), ("E", np.asarray(de))):
            tp, fp, fn = score(ref, det)
            row[k] = {"tp": tp, "fp": fp, "fn": fn,
                      "se": 100 * tp / (tp + fn), "ppv": 100 * tp / (tp + fp) if tp + fp else 0.0}
            for i, v in enumerate((tp, fp, fn)):
                tot[k][i] += v
        lat["B0"].append(latency_ms(ref, d0, 0))
        lat["B1"].append(latency_ms(ref, d1 + D1, D1))
        lat["E"].append(float(np.mean([(e[0] - e[1]) * 1000 / FS for e in events])))
        rows.append(row)

    gross = {k: {"tp": t[0], "fp": t[1], "fn": t[2],
                 "se": 100 * t[0] / (t[0] + t[2]), "ppv": 100 * t[0] / (t[0] + t[1]),
                 "latency_ms": float(np.nanmean(lat[k]))} for k, t in tot.items()}

    lines = ["Baseline vs Pan-Tompkins (same input, same +/-150 ms matcher, whole records)",
             f"B0 raw fixed threshold T0 = {T0} ADC codes ({T0/200:.2f} mV) tuned on rec 100",
             f"B1 PT filters + fixed MWI threshold T1 = {T1}, fiducial delay D = {D1} samples, tuned on rec 100",
             "E  full Pan-Tompkins (adaptive dual thresholds, search-back, T-wave test)", "",
             f"{'rec':>4} {'beats':>6} | {'B0 Se':>6} {'B0 +P':>6} | {'B1 Se':>6} {'B1 +P':>6} | {'E Se':>6} {'E +P':>6}"]
    for o in rows:
        lines.append(f"{o['record']:>4} {o['beats']:>6} | {o['B0']['se']:6.2f} {o['B0']['ppv']:6.2f} | "
                     f"{o['B1']['se']:6.2f} {o['B1']['ppv']:6.2f} | {o['E']['se']:6.2f} {o['E']['ppv']:6.2f}")
    lines.append("")
    for k in ("B0", "B1", "E"):
        g = gross[k]
        lines.append(f"GROSS {k:2s}: Se {g['se']:.2f}%  +P {g['ppv']:.2f}%  TP {g['tp']} FP {g['fp']} FN {g['fn']}"
                     f"  mean latency {g['latency_ms']:.0f} ms (decision - R peak)")
    text = "\n".join(lines)
    print(text)
    with open(os.path.join(HERE, "paper_results.txt"), "w") as fh:
        fh.write(text + "\n")
    with open(os.path.join(HERE, "paper_results.json"), "w") as fh:
        json.dump({"T0": T0, "T1": T1, "D1": D1, "records": rows, "gross": gross}, fh, indent=2)


if __name__ == "__main__":
    main()
