"""
evaluate_hw_detector.py  --  score the hardware (streaming, integer) detector

Runs the bit-accurate hardware detector (fixed-point filter chain +
qrs_hw_detector.HwQrsDecision) on whole MIT-BIH records and scores it against
the reference beat annotations (+/-150 ms), next to the Phase-2 float
detector. Also reports the detection latency (decision time - R peak), which
is what the pacemaker's ventricular-sense input sees on the board.

Usage (venv active, project root):
    python src/evaluate_hw_detector.py [records...]
Writes results/stage7_hw_detector.json and .txt
"""

from __future__ import annotations

import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ecg_loader import BEAT_SYMBOLS, load_ecg_record          # noqa: E402
from pan_tompkins import detect_qrs                            # noqa: E402
from pan_tompkins_fixed import fixed_filter_chain, load_record_digital  # noqa: E402
from qrs_eval import match_detections                          # noqa: E402
from qrs_hw_detector import detect_stream                      # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")
RESULTS = os.path.join(ROOT, "results")


def evaluate(record: str, with_float: bool = True) -> dict:
    rec = load_ecg_record(record, data_dir=DATA)
    ref = np.array([s for s, sym in zip(rec.ann_sample, rec.ann_symbol)
                    if sym in BEAT_SYMBOLS], dtype=np.int64)
    tol = int(round(0.150 * rec.fs))

    dig = load_record_digital(record, DATA)
    st = fixed_filter_chain(dig["adc"], dig["baseline"])
    hw_r, events = detect_stream(st["hp"], st["dv"], st["mwi"])
    hm = match_detections(ref, hw_r, tol)
    lat = np.array([e[0] - e[1] for e in events], dtype=np.int64)
    out = {
        "record": record, "ref_beats": int(ref.size),
        "hw": {"tp": hm.tp, "fp": hm.fp, "fn": hm.fn,
               "se": 100 * hm.sensitivity, "ppv": 100 * hm.positive_predictivity,
               "searchback": int(sum(1 for e in events if e[2]))},
        "latency_ms": {"mean": float(lat.mean() * 1000 / rec.fs),
                       "max": float(lat.max() * 1000 / rec.fs),
                       "min": float(lat.min() * 1000 / rec.fs)},
    }
    if with_float:
        fr = detect_qrs(rec.signal, rec.fs)
        fm = match_detections(ref, fr.qrs_indices, tol)
        out["float"] = {"tp": fm.tp, "fp": fm.fp, "fn": fm.fn,
                        "se": 100 * fm.sensitivity,
                        "ppv": 100 * fm.positive_predictivity}
    return out


def main() -> None:
    records = sys.argv[1:] or ["100", "101", "106", "208", "234"]
    rows = [evaluate(r) for r in records]
    lines = ["Hardware (streaming integer) QRS detector vs Phase-2 float detector",
             "match tolerance +/-150 ms, whole records (30 min each)", "",
             f"{'rec':>4} {'beats':>6} | {'HW Se%':>7} {'HW +P%':>7} {'TP':>5} {'FP':>4} {'FN':>4}"
             f" {'sb':>3} | {'FL Se%':>7} {'FL +P%':>7} | lat ms mean/max"]
    tot = {"hw": [0, 0, 0], "float": [0, 0, 0]}
    for o in rows:
        h, f = o["hw"], o["float"]
        lines.append(f"{o['record']:>4} {o['ref_beats']:>6} | {h['se']:7.2f} {h['ppv']:7.2f} "
                     f"{h['tp']:5d} {h['fp']:4d} {h['fn']:4d} {h['searchback']:3d} | "
                     f"{f['se']:7.2f} {f['ppv']:7.2f} | "
                     f"{o['latency_ms']['mean']:.0f}/{o['latency_ms']['max']:.0f}")
        for k in ("hw", "float"):
            tot[k][0] += o[k]["tp"]; tot[k][1] += o[k]["fp"]; tot[k][2] += o[k]["fn"]
    gross = {}
    for k, (tp, fp, fn) in tot.items():
        gross[k] = {"tp": tp, "fp": fp, "fn": fn,
                    "se": 100 * tp / (tp + fn), "ppv": 100 * tp / (tp + fp)}
    lines.append("")
    lines.append(f"GROSS  HW   : Se {gross['hw']['se']:.2f}%  +P {gross['hw']['ppv']:.2f}%  "
                 f"(TP {tot['hw'][0]} FP {tot['hw'][1]} FN {tot['hw'][2]})")
    lines.append(f"GROSS  FLOAT: Se {gross['float']['se']:.2f}%  +P {gross['float']['ppv']:.2f}%  "
                 f"(TP {tot['float'][0]} FP {tot['float'][1]} FN {tot['float'][2]})")
    text = "\n".join(lines)
    print(text)
    os.makedirs(RESULTS, exist_ok=True)
    with open(os.path.join(RESULTS, "stage7_hw_detector.txt"), "w") as fh:
        fh.write(text + "\n")
    with open(os.path.join(RESULTS, "stage7_hw_detector.json"), "w") as fh:
        json.dump({"records": rows, "gross": gross}, fh, indent=2)


if __name__ == "__main__":
    main()
