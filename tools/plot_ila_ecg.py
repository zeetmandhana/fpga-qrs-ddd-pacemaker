"""
plot_ila_ecg.py  --  rebuild the ECG and the pacemaker events from Zybo ILA captures

Reads results/ila/<tag>.csv written by vivado/ila_capture.tcl (Vivado ILA CSV
export: one ILA entry per 360 Hz ECG sample thanks to capture control) and draws
  * the ECG exactly as the FPGA saw it (raw ADC -> mV, 200 ADU/mV, baseline 1024)
  * red triangles at the R peaks found by the on-chip Pan-Tompkins detector
    (placed retroactively with rec_qrs_delay, as on the HDMI screen)
  * AP / VP pace pulses and AS / VS senses as a marker channel
  * the detector's moving-window integral and adaptive threshold THR1
Writes results/ila/<tag>.png and a combined results/ila/ila_demo_all.png.

Run:  python tools/plot_ila_ecg.py
"""

from __future__ import annotations

import csv
import glob
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ILA_DIR = os.path.join(ROOT, "results", "ila")
FS = 360.0
SCEN = {0: "MIT-BIH record 100 replay (open loop)", 1: "Heart model: normal sinus 75 bpm",
        2: "Heart model: sinus bradycardia 40 bpm", 3: "Heart model: complete AV block",
        4: "Heart model: AV block + bradycardia", 5: "Heart model: retrograde VA (PMT)"}
FIELDS = ["rec_stb", "rec_ecg", "rec_qrs", "rec_ap", "rec_vp", "rec_as", "rec_vs",
          "rec_qrs_delay", "rec_mode", "rec_mwi", "rec_thr", "rec_n"]


def _val(s: str, radix: str) -> int:
    s = s.strip()
    if radix.upper().startswith("HEX") or radix.upper() == "H":
        return int(s, 16)
    if radix.upper().startswith("BIN") or radix.upper() == "B":
        return int(s, 2)
    return int(s)


def load(path: str) -> dict:
    with open(path, newline="") as fh:
        rows = list(csv.reader(fh))
    header, radix = rows[0], rows[1]
    cols = {}
    for f in FIELDS:
        idx = next(i for i, h in enumerate(header) if h.split("/")[-1].split("[")[0].endswith(f))
        cols[f] = idx
    data = {f: [] for f in FIELDS}
    trig = []
    tcol = next((i for i, h in enumerate(header) if h.strip().upper() == "TRIGGER"), None)
    for r in rows[2:]:
        if not r or not r[0].strip():
            continue
        for f, i in cols.items():
            data[f].append(_val(r[i], radix[i]))
        if tcol is not None:
            trig.append(int(r[tcol].strip() or 0))
    out = {f: np.array(v, dtype=np.int64) for f, v in data.items()}
    out["trigger"] = np.array(trig, dtype=np.int64)
    return out


def summarize(d: dict) -> dict:
    n = d["rec_ecg"].size
    dur = n / FS
    rr = np.diff(np.flatnonzero(d["rec_qrs"])) / FS
    cont = np.all(np.diff(d["rec_n"].astype(np.int64)) % 65536 == 1)
    return {"samples": n, "seconds": dur, "qrs": int(d["rec_qrs"].sum()),
            "ap": int(d["rec_ap"].sum()), "vp": int(d["rec_vp"].sum()),
            "as": int(d["rec_as"].sum()), "vs": int(d["rec_vs"].sum()),
            "hr": (60.0 / rr.mean()) if rr.size else 0.0, "contiguous": bool(cont),
            "mode": int(np.bincount(d["rec_mode"]).argmax())}


def draw(ax_ecg, ax_mk, ax_mwi, d: dict, s: dict, title: str) -> None:
    n = d["rec_ecg"].size
    t = np.arange(n) / FS
    mv = (d["rec_ecg"] - 1024) / 200.0
    ax_ecg.plot(t, mv, color="#1a7f37", lw=0.8, label="ECG on the FPGA")
    q = np.flatnonzero(d["rec_qrs"])
    r = np.clip(q - 1 - d["rec_qrs_delay"][q], 0, n - 1)
    ax_ecg.plot(t[r], mv[r] + 0.12, "v", color="#d1242f", ms=7,
                label=f"QRS detected on-chip ({s['qrs']})")
    for f, c, lab in (("rec_ap", "#bf8700", "A-pace"), ("rec_vp", "#0969da", "V-pace")):
        for k in np.flatnonzero(d[f]):
            ax_ecg.axvline(t[k], color=c, lw=1.0, alpha=0.6)
    trig = np.flatnonzero(d["trigger"]) if d["trigger"].size else []
    if len(trig):
        ax_ecg.axvline(t[trig[0]], color="k", ls="--", lw=0.8, label="ILA trigger")
    ax_ecg.set_ylabel("mV")
    ax_ecg.set_title(title, fontsize=10, loc="left")
    ax_ecg.legend(loc="upper right", fontsize=7, ncol=3)
    ax_ecg.grid(alpha=0.25)

    rows = (("rec_ap", 3, "#bf8700", "AP"), ("rec_as", 2, "#6e7781", "AS"),
            ("rec_vp", 1, "#0969da", "VP"), ("rec_vs", 0, "#6e7781", "VS"))
    for f, y, c, lab in rows:
        k = np.flatnonzero(d[f])
        ax_mk.vlines(t[k], y - 0.35, y + 0.35, color=c, lw=2)
    ax_mk.set_yticks([0, 1, 2, 3])
    ax_mk.set_yticklabels(["VS", "VP", "AS", "AP"], fontsize=8)
    ax_mk.set_ylim(-0.6, 3.6)
    ax_mk.grid(axis="x", alpha=0.25)

    ax_mwi.plot(t, d["rec_mwi"] * 16, color="#fb8500", lw=0.8, label="MWI (Pan-Tompkins)")
    ax_mwi.plot(t, d["rec_thr"] * 16, color="#c026d3", lw=1.0, label="adaptive THR1")
    ax_mwi.set_ylabel("MWI")
    ax_mwi.legend(loc="upper right", fontsize=7)
    ax_mwi.grid(alpha=0.25)
    ax_mwi.set_xlabel("time in capture (s)")


def main() -> None:
    files = sorted(glob.glob(os.path.join(ILA_DIR, "*.csv")))
    lines = ["Zybo Z7-10 ILA captures (one entry per 360 Hz ECG sample)", ""]
    figs = []
    for path in files:
        tag = os.path.splitext(os.path.basename(path))[0]
        d = load(path)
        s = summarize(d)
        title = (f"{tag}: {SCEN.get(s['mode'], '?')} | {s['seconds']:.1f} s on the Zybo | "
                 f"HR {s['hr']:.0f} bpm | QRS {s['qrs']}  AP {s['ap']}  VP {s['vp']}  "
                 f"AS {s['as']}  VS {s['vs']}")
        fig, axs = plt.subplots(3, 1, figsize=(13, 6.5), sharex=True,
                                gridspec_kw={"height_ratios": [3, 1, 1.4]})
        draw(axs[0], axs[1], axs[2], d, s, title)
        fig.tight_layout()
        fig.savefig(os.path.join(ILA_DIR, tag + ".png"), dpi=130)
        plt.close(fig)
        figs.append((tag, d, s, title))
        lines.append(f"{tag:22s} mode={s['mode']} samples={s['samples']} ({s['seconds']:.1f} s) "
                     f"contiguous={s['contiguous']} HR={s['hr']:.1f} bpm QRS={s['qrs']} "
                     f"AP={s['ap']} VP={s['vp']} AS={s['as']} VS={s['vs']}")
    if figs:
        fig, axs = plt.subplots(len(figs), 1, figsize=(13, 2.6 * len(figs)), squeeze=False)
        for ax, (tag, d, s, title) in zip(axs[:, 0], figs):
            n = d["rec_ecg"].size
            t = np.arange(n) / FS
            mv = (d["rec_ecg"] - 1024) / 200.0
            ax.plot(t, mv, color="#1a7f37", lw=0.7)
            q = np.flatnonzero(d["rec_qrs"])
            r = np.clip(q - 1 - d["rec_qrs_delay"][q], 0, n - 1)
            ax.plot(t[r], mv[r] + 0.12, "v", color="#d1242f", ms=5)
            for f, c in (("rec_ap", "#bf8700"), ("rec_vp", "#0969da")):
                for k in np.flatnonzero(d[f]):
                    ax.axvline(t[k], color=c, lw=0.9, alpha=0.6)
            ax.set_title(title, fontsize=8, loc="left")
            ax.set_ylabel("mV", fontsize=8)
            ax.grid(alpha=0.2)
        axs[-1, 0].set_xlabel("time in capture (s)   [green ECG, red = QRS detected, "
                              "yellow = A-pace, blue = V-pace]")
        fig.tight_layout()
        fig.savefig(os.path.join(ILA_DIR, "ila_demo_all.png"), dpi=120)
        plt.close(fig)
    text = "\n".join(lines)
    print(text)
    with open(os.path.join(ILA_DIR, "ila_summary.txt"), "w") as fh:
        fh.write(text + "\n")


if __name__ == "__main__":
    main()
