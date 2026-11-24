"""fig_replay.py -- figure of the BUG-1 (PVARP disabled) counterexample replayed on the RTL."""
import re
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
ROW = re.compile(r"^\s*(\d+)\s+(\d)\s+(\d)\s+(\d)\s+\|\s+(\d)\s+(\d+)\s+(\d+)\s+\|\s+(\d)\s+(\d)\s+(\d)\s+(\d)\s+(\d)\s+\|")


def load(log):
    rows = []
    for line in (HERE / log).read_text().splitlines():
        m = ROW.match(line)
        if m:
            rows.append([int(g) for g in m.groups()])
    return rows


def panel(ax, rows, title):
    # rows: cyc tick a v | phase t_v t_av | AP VP AS VS arr ; outputs appear one cycle after the tick
    cyc = [r[0] for r in rows]
    tv = [r[5] for r in rows]
    ax.step(cyc, tv, where="post", color="0.45", lw=0.9, label="$t_v$ register (ticks since V)")
    ax.axhspan(0, 4, color="#e8e8e8", lw=0, zorder=0)
    ax.text(cyc[-1] + 0.4, 2, "PVARP", fontsize=6.5, va="center", color="0.4")
    ax.axhline(5, color="#b3261e", lw=0.6, ls="--")
    ax.text(cyc[-1] + 0.4, 5, "URI", fontsize=6.5, va="center", color="#b3261e")
    for r in rows:
        c, a = r[0], r[2]
        if a:
            ax.plot(c, -1.2, "^", color="#6e40aa", ms=4)
        for j, (name, col, y) in enumerate((("AP", "#bf8700", 12.2), ("VP", "#0969da", 12.2),
                                            ("AS", "#1a7f37", 12.2), ("VS", "k", 12.2))):
            if r[7 + j]:
                ax.annotate(name, (c, y), ha="center", fontsize=6.5, color=col, weight="bold")
                ax.axvline(c, color=col, lw=0.6, alpha=0.5)
    ax.set_ylim(-2.2, 13.5)
    ax.set_xlim(-0.5, cyc[-1] + 2.2)
    ax.set_ylabel("ticks", fontsize=7)
    ax.set_title(title, fontsize=7.5, loc="left")
    ax.tick_params(labelsize=6.5)


def main():
    plt.rcParams.update({"font.family": "serif", "font.size": 7.5})
    fig, axs = plt.subplots(2, 1, figsize=(6.3, 2.7), sharex=True)
    panel(axs[0], load("closed_pmt_bug1.log"),
          "(a) BUG 1 RTL (no PVARP blanking): retrograde P ($\\blacktriangle$) sensed, "
          "VP at URI every cycle = PMT (7/8 upper-rate)")
    panel(axs[1], load("closed_pmt_original.log"),
          "(b) correct RTL, same heart: retrograde P blanked by PVARP, AP-VP at the lower rate "
          "(0 upper-rate beats)")
    axs[1].set_xlabel("tick (one 1 ms tick per clock); heart: AV block + retrograde conduction VA = 3 ticks",
                      fontsize=7)
    fig.tight_layout(pad=0.2, h_pad=0.4)
    out = HERE.parent / "fig_replay"
    fig.savefig(out.with_suffix(".pdf"))
    fig.savefig(out.with_suffix(".png"), dpi=200)
    print("wrote", out)


if __name__ == "__main__":
    main()
