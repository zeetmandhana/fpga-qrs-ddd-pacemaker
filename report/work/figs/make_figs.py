"""
make_figs.py -- report figures owned by the main session (VL401 report)
  fig_paper_106.pdf : record 106 excerpt, B0 fixed threshold vs Pan-Tompkins
  fig_ila_board.pdf : ILA captures from the Zybo (replay, PMT guard off/on)
Run: .venv\\Scripts\\python report\\work\\figs\\make_figs.py
"""
from __future__ import annotations

import json
import os
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "src"))
sys.path.insert(0, os.path.join(ROOT, "tools"))
sys.path.insert(0, os.path.join(ROOT, "report", "work", "paper"))
from ecg_loader import BEAT_SYMBOLS, load_ecg_record          # noqa: E402
from pan_tompkins_fixed import fixed_filter_chain, load_record_digital  # noqa: E402
from qrs_hw_detector import HwQrsDecision                      # noqa: E402
from baseline_eval import crossings                            # noqa: E402
import plot_ila_ecg as ila                                     # noqa: E402

plt.rcParams.update({"font.family": "serif", "font.serif": ["DejaVu Serif"], "font.size": 8,
                     "axes.titlesize": 8, "legend.fontsize": 7, "axes.linewidth": 0.6,
                     "xtick.major.width": 0.6, "ytick.major.width": 0.6})
FS = 360
C_ECG, C_E, C_B0, C_AP, C_VP = "#1a7f37", "#d1242f", "#bf8700", "#bf8700", "#0969da"


def fig_paper_106():
    p = json.load(open(os.path.join(ROOT, "report", "work", "paper", "paper_results.json")))
    rec = load_ecg_record("106", data_dir=os.path.join(ROOT, "data"))
    ref = np.array([s for s, sym in zip(rec.ann_sample, rec.ann_symbol) if sym in BEAT_SYMBOLS])
    dig = load_record_digital("106", os.path.join(ROOT, "data"))
    x = dig["adc"] - dig["baseline"]
    st = fixed_filter_chain(dig["adc"], dig["baseline"])
    d0 = crossings(x, p["T0"])
    dec = HwQrsDecision()
    thr = np.zeros(len(x), dtype=np.int64)
    de = []
    for i in range(len(x)):
        d = dec.step(int(st["hp"][i]), int(st["dv"][i]), int(st["mwi"][i]))
        thr[i] = dec._thr1()
        if d is not None:
            de.append(d[0])
    de = np.array(de)
    # 6 s window with the most B0 false detections
    fp0 = np.array([n for n in d0 if np.min(np.abs(ref - n)) > 54])
    W = 6 * FS
    starts = np.arange(5 * FS, len(x) - W, FS)
    counts = [np.sum((fp0 >= s) & (fp0 < s + W)) for s in starts]
    s0 = int(starts[int(np.argmax(counts))])
    sl = slice(s0, s0 + W)
    t = np.arange(W) / FS
    mv = x[sl] / 200.0
    fig, (a1, a2) = plt.subplots(2, 1, figsize=(6.3, 2.5), sharex=True,
                                 gridspec_kw={"height_ratios": [1.5, 1]})
    a1.plot(t, mv, color=C_ECG, lw=0.7)
    inw = lambda arr: arr[(arr >= s0) & (arr < s0 + W)] - s0
    r = inw(ref)
    a1.plot(r / FS, np.full(r.size, mv.min() - 0.25), "^", color="k", ms=3.5, label="reference beat")
    b = inw(d0)
    a1.plot(b / FS, mv[b] + 0.25, "x", color=C_B0, ms=5, mew=1.2,
            label=f"B0 fixed threshold ({np.sum((fp0 >= s0) & (fp0 < s0 + W))} false here)")
    e = inw(de)
    a1.plot(e / FS, mv[e] + 0.5, "v", color=C_E, ms=4, label="E Pan-Tompkins (0 false)")
    a1.axhline(p["T0"] / 200.0, color=C_B0, lw=0.6, ls="--")
    a1.set_ylabel("ECG (mV)")
    a1.legend(loc="lower center", bbox_to_anchor=(0.5, 1.0), ncol=3, frameon=False, borderaxespad=0.1)
    a1.set_ylim(mv.min() - 0.45, mv.max() + 0.75)
    m = st["mwi"][sl] / 1e6
    a2.plot(t, m, color="#fb8500", lw=0.7, label="MWI")
    a2.axhline(p["T1"] / 1e6, color="#57606a", lw=0.7, ls="--", label="B1 fixed threshold")
    a2.plot(t, thr[sl] / 1e6, color="#c026d3", lw=0.9, label="E adaptive THR1")
    a2.set_ylabel(r"MWI ($\times10^6$)")
    a2.set_xlabel(f"time (s) from {s0 / FS:.0f} s in MIT-BIH record 106")
    a2.legend(loc="upper right", ncol=3, frameon=False, borderaxespad=0.1)
    for a in (a1, a2):
        a.grid(alpha=0.2, lw=0.4)
        a.spines[["top", "right"]].set_visible(False)
    fig.tight_layout(pad=0.3, h_pad=0.2)
    fig.savefig(os.path.join(HERE, "fig_paper_106.pdf"))
    fig.savefig(os.path.join(HERE, "fig_paper_106.png"), dpi=200)
    plt.close(fig)
    print("fig_paper_106: window start", s0 / FS, "s, B0 false in window", max(counts))


def fig_ila_board():
    caps = [("s1_mitbih_replay", "MIT-BIH record 100 replay: on-chip QRS detections (VS)"),
            ("s6_pmt_guard_off", "Retrograde VA, PMT guard off: VP tracks retrograde P at the URI (120 bpm)"),
            ("s6_pmt_guard_on", "PMT guard on: RV32 interrupt handler lengthens PVARP, rate back to 60 bpm")]
    fig, axs = plt.subplots(len(caps), 1, figsize=(6.3, 2.55), sharex=True)
    W = int(6 * FS)
    for ax, (tag, title) in zip(axs, caps):
        d = ila.load(os.path.join(ROOT, "results", "ila", tag + ".csv"))
        n = d["rec_ecg"].size
        s0 = 1024                                   # start at the ILA trigger
        sl = slice(s0, min(n, s0 + W))
        t = np.arange(sl.stop - sl.start) / FS
        mv = (d["rec_ecg"][sl] - 1024) / 200.0
        ax.plot(t, mv, color=C_ECG, lw=0.7)
        q = np.flatnonzero(d["rec_qrs"])                     # whole capture
        rf = q - 1 - d["rec_qrs_delay"][q]                    # R-peak sample (retroactive)
        rr = rf[(rf >= sl.start) & (rf < sl.stop)] - sl.start  # only peaks inside the window
        ax.plot(t[rr], mv[rr] + 0.2, "v", color=C_E, ms=3.5)
        for f, c in (("rec_ap", C_AP), ("rec_vp", C_VP)):
            for k in np.flatnonzero(d[f][sl]):
                ax.axvline(t[k], color=c, lw=0.9, alpha=0.75)
        ax.set_title(title, loc="left", pad=2)
        ax.set_ylabel("mV")
        ax.grid(alpha=0.2, lw=0.4)
        ax.spines[["top", "right"]].set_visible(False)
    axs[-1].set_xlabel("time (s) after the ILA trigger   [green ECG, red = QRS detected, "
                       "amber = A-pace, blue = V-pace]")
    fig.tight_layout(pad=0.3, h_pad=0.3)
    fig.savefig(os.path.join(HERE, "fig_ila_board.pdf"))
    fig.savefig(os.path.join(HERE, "fig_ila_board.png"), dpi=200)
    plt.close(fig)
    print("fig_ila_board done")


if __name__ == "__main__":
    fig_paper_106()
    fig_ila_board()
