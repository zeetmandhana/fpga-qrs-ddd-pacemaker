"""
hand_hls.py -- hand high-level synthesis of the per-sample Pan-Tompkins kernel
(VL401 report, Section 4).  Everything below is computed, nothing is typed in.

  (a) DFGs of five versions (original direct form -> our kernel), op counts and
      critical path in control steps
  (b) control-step rules from the measured operator library (oplib/)
  (c) ASAP / ALAP / mobility, list scheduling under two resource sets,
      ILP (scipy.optimize.milp) for the time- and resource-constrained cases
  (d) left-edge register binding, clique-partitioning FU binding
  figures: fig/cdfg.pdf, fig/schedule.pdf, fig/compat.pdf
  tables : results.json + printed markdown

Run:  ..\\..\\..\\.venv\\Scripts\\python hand_hls.py   (from report/work/hand_hls)
"""

from __future__ import annotations

import json
import os
from collections import OrderedDict

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
import networkx as nx
import numpy as np
from scipy.optimize import LinearConstraint, Bounds, milp

HERE = os.path.dirname(os.path.abspath(__file__))
FIG = os.path.join(HERE, "fig")
os.makedirs(FIG, exist_ok=True)

plt.rcParams.update({"font.family": "DejaVu Serif", "font.size": 8,
                     "axes.titlesize": 8.5, "axes.labelsize": 8,
                     "pdf.fonttype": 42})

# Control-step rule (from oplib/oplib_results.txt, 10 ns step at 100 MHz):
#   add/sub (32 or 40 bit) incl. operand mux + LUTRAM read = 1 step, no chaining
#   of two adders in one step; the 32x32->32 squarer (3 DSP48E1) = MUL_STEPS steps.
MUL_STEPS = int(os.environ.get("MUL_STEPS", "1"))


# ---------------------------------------------------------------------------
# DFG helper
# ---------------------------------------------------------------------------
class DFG:
    def __init__(self, name):
        self.name = name
        self.ops = OrderedDict()          # op -> dict(kind, ins, label)

    def op(self, name, kind, ins, label=""):
        assert name not in self.ops, name
        self.ops[name] = {"kind": kind, "ins": list(ins), "label": label or name}
        return name

    def chain(self, prefix, kind_seq, first, terms):
        """left-associative chain: ((first o t1) o t2) ..."""
        acc = first
        for k, t in enumerate(terms):
            acc = self.op(f"{prefix}{k}", kind_seq, [acc, t])
        return acc

    def counts(self):
        m = sum(1 for o in self.ops.values() if o["kind"] == "mul")
        a = sum(1 for o in self.ops.values() if o["kind"] == "add")
        return m, a

    def delay(self, name):
        return MUL_STEPS if self.ops[name]["kind"] == "mul" else 1

    def critical_path(self):
        fin = {}
        for n, o in self.ops.items():          # ops are inserted in topological order
            start = max([fin[i] for i in o["ins"] if i in self.ops] + [0])
            fin[n] = start + self.delay(n)
        return max(fin.values())


def build_versions():
    vs = []
    # ---------------- V0: original Pan-Tompkins direct form (360 Hz) ----------------
    g = DFG("Original direct form")
    xc = g.op("xc", "add", ["x", "base"])
    # LPF  y = 2y1 - y2 + x - 2x6 + x12
    m1 = g.op("m_2lp1", "mul", ["lp1"]); m2 = g.op("m_2x6", "mul", ["x6"])
    t = g.op("l0", "add", [m1, "lp2"]); t = g.op("l1", "add", [t, xc])
    t = g.op("l2", "add", [t, m2]); lp = g.op("lp", "add", [t, "x12"])
    # HPF  hp = lp[n-16] - (1/32) * sum_{k=0..31} lp[n-k]   (direct 32-tap sum)
    acc = lp
    for k in range(1, 32):
        acc = g.op(f"hs{k}", "add", [acc, f"lp_{k}"])
    mh = g.op("m_div32", "mul", [acc]); hp = g.op("hp", "add", ["lp16", mh])
    # derivative  (1/8)(2hp + h1 - h3 - 2h4)
    md1 = g.op("m_2hp", "mul", [hp]); md2 = g.op("m_2h4", "mul", ["h4"])
    t = g.op("d0", "add", [md1, "h1"]); t = g.op("d1", "add", [t, "h3"])
    t = g.op("d2", "add", [t, md2]); d = g.op("m_div8", "mul", [t])
    sq = g.op("sq", "mul", [d, d])
    # MWI  (1/N) sum_{k=0..53} sq[n-k]   (direct 54-term sum)
    acc = sq
    for k in range(1, 54):
        acc = g.op(f"ms{k}", "add", [acc, f"sq_{k}"])
    g.op("m_divN", "mul", [acc])
    vs.append(g)

    # ---------------- V1: + strength reduction (x2, /8, /32 -> shifts) ----------------
    g = DFG("+ strength reduction (x2, /8, /32 to shifts)")
    xc = g.op("xc", "add", ["x", "base"])
    t = g.op("l0", "add", ["lp1<<1", "lp2"]); t = g.op("l1", "add", [t, xc])
    t = g.op("l2", "add", [t, "x6<<1"]); lp = g.op("lp", "add", [t, "x12"])
    acc = lp
    for k in range(1, 32):
        acc = g.op(f"hs{k}", "add", [acc, f"lp_{k}"])
    hp = g.op("hp", "add", ["lp16", acc])                       # acc>>5 is wiring
    t = g.op("d0", "add", [hp, "h1"]); t = g.op("d1", "add", [t, "h3"])
    d = g.op("d2", "add", [t, "h4<<1"])                         # >>3 is wiring
    sq = g.op("sq", "mul", [d, d])
    acc = sq
    for k in range(1, 54):
        acc = g.op(f"ms{k}", "add", [acc, f"sq_{k}"])
    g.op("m_divN", "mul", [acc])
    vs.append(g)

    # ---------------- V2: + constant folding of 1/N into the thresholds ----------------
    g = DFG("+ constant folding (1/N into thresholds)")
    xc = g.op("xc", "add", ["x", "base"])
    t = g.op("l0", "add", ["lp1<<1", "lp2"]); t = g.op("l1", "add", [t, xc])
    t = g.op("l2", "add", [t, "x6<<1"]); lp = g.op("lp", "add", [t, "x12"])
    acc = lp
    for k in range(1, 32):
        acc = g.op(f"hs{k}", "add", [acc, f"lp_{k}"])
    hp = g.op("hp", "add", ["lp16", acc])
    t = g.op("d0", "add", [hp, "h1"]); t = g.op("d1", "add", [t, "h3"])
    d = g.op("d2", "add", [t, "h4<<1"])
    sq = g.op("sq", "mul", [d, d])
    acc = sq
    for k in range(1, 54):
        acc = g.op(f"ms{k}", "add", [acc, f"sq_{k}"])
    vs.append(g)

    # ---------------- V3: + running-sum recurrence for HPF and MWI ----------------
    # (this is exactly the order of operations written in hls/qrs_stream.cpp)
    g = DFG("+ running-sum recurrence (HPF, MWI)")
    xc = g.op("xc", "add", ["x", "base"])
    t = g.op("l0", "add", [xc, "x6<<1"]); t = g.op("l1", "add", [t, "x12"])
    t = g.op("l2", "add", [t, "lp1<<1"]); lp = g.op("lp", "add", [t, "lp2"])
    t = g.op("s0", "add", ["ms", lp]); msn = g.op("ms'", "add", [t, "lp32"])
    hp = g.op("hp", "add", ["lp16", msn])
    t = g.op("d0", "add", [hp, "h1"]); t = g.op("d1", "add", [t, "h3"])
    d = g.op("d2", "add", [t, "h4<<1"])
    sq = g.op("sq", "mul", [d, d])
    t = g.op("w0", "add", ["mwi", sq]); g.op("mwi'", "add", [t, "sq54"])
    vs.append(g)

    # ---------------- V4: + tree-height reduction / reassociation (final) ----------------
    vs.append(final_dfg())
    return vs


def final_dfg():
    g = DFG("+ tree-height reduction (final kernel)")
    g.op("xc", "add", ["x", "base"], "xc = x - base")
    g.op("u1", "add", ["lp1<<1", "lp2"], "u1 = 2lp1 - lp2")
    g.op("u2", "add", ["x12", "x6<<1"], "u2 = x12 - 2x6")
    g.op("u3", "add", ["u1", "u2"], "u3 = u1 + u2")
    g.op("lp", "add", ["xc", "u3"], "lp = xc + u3")
    g.op("v1", "add", ["ms", "lp32"], "v1 = ms - lp32")
    g.op("ms'", "add", ["v1", "lp"], "ms' = v1 + lp")
    g.op("hp", "add", ["lp16", "ms'"], "hp = lp16 - (ms'>>5)")
    g.op("w1", "add", ["h1", "h3"], "w1 = h1 - h3")
    g.op("w2", "add", ["w1", "h4<<1"], "w2 = w1 - 2h4")
    g.op("dv", "add", ["hp", "w2"], "dv = (2hp + w2)>>3")
    g.op("sq", "mul", ["dv"], "sq = dv * dv")
    g.op("m1", "add", ["mwi", "sq54"], "m1 = mwi - sq54")
    g.op("mwi'", "add", ["m1", "sq"], "mwi' = m1 + sq")
    return g


# ---------------------------------------------------------------------------
# scheduling
# ---------------------------------------------------------------------------
def preds(g, n):
    return [i for i in g.ops[n]["ins"] if i in g.ops]


def succs(g, n):
    return [m for m, o in g.ops.items() if n in o["ins"]]


def asap(g):
    s = {}
    for n in g.ops:
        s[n] = max([s[p] + g.delay(p) for p in preds(g, n)] + [1])
    return s


def alap(g, L):
    s = {}
    for n in reversed(list(g.ops)):
        su = succs(g, n)
        s[n] = (min(s[m] for m in su) if su else L + 1) - g.delay(n)
    return s


def longest_to_sink(g):
    lp = {}
    for n in reversed(list(g.ops)):
        lp[n] = g.delay(n) + max([lp[m] for m in succs(g, n)] + [0])
    return lp


def list_schedule(g, res):
    """resource-constrained list scheduling; res = {'add': a, 'mul': m};
    multiplier is not pipelined (busy for MUL_STEPS steps)."""
    prio = longest_to_sink(g)
    done_at = {}           # op -> first step its result is available
    start = {}
    busy = {k: [] for k in res}   # list of (until_step) per unit
    step = 1
    while len(start) < len(g.ops):
        # free units
        for k in busy:
            busy[k] = [u for u in busy[k] if u > step]
        ready = [n for n in g.ops if n not in start
                 and all(p in done_at and done_at[p] <= step for p in preds(g, n))]
        ready.sort(key=lambda n: (-prio[n], list(g.ops).index(n)))
        for n in ready:
            k = g.ops[n]["kind"]
            if len(busy[k]) < res[k]:
                start[n] = step
                done_at[n] = step + g.delay(n)
                busy[k].append(step + g.delay(n))
        step += 1
    L = max(start[n] + g.delay(n) - 1 for n in g.ops)
    return start, L


def ilp_schedule(g, L, res=None, minimise_alu=True):
    """time-indexed ILP.  x[n,s]=1 if op n starts in step s (1..L).
    minimise_alu: variables also include N_alu (integer), objective N_alu.
    otherwise feasibility with fixed resources (objective 0)."""
    ops = list(g.ops)
    a0, l0 = asap(g), alap(g, L)
    if any(l0[n] < a0[n] for n in ops):
        return None
    var = []
    for n in ops:
        for s in range(a0[n], l0[n] + 1):
            var.append((n, s))
    idx = {v: i for i, v in enumerate(var)}
    nv = len(var) + (1 if minimise_alu else 0)
    A, lo, hi = [], [], []
    # each op exactly once
    for n in ops:
        row = np.zeros(nv)
        for s in range(a0[n], l0[n] + 1):
            row[idx[(n, s)]] = 1
        A.append(row); lo.append(1); hi.append(1)
    # precedence: start(m) >= start(n) + d(n)
    for n in ops:
        for m in succs(g, n):
            row = np.zeros(nv)
            for s in range(a0[m], l0[m] + 1):
                row[idx[(m, s)]] += s
            for s in range(a0[n], l0[n] + 1):
                row[idx[(n, s)]] -= s
            A.append(row); lo.append(g.delay(n)); hi.append(np.inf)
    # resources per step (multi-cycle ops occupy their unit for d steps)
    for kind in ("add", "mul"):
        for t in range(1, L + 1):
            row = np.zeros(nv)
            for (n, s) in var:
                if g.ops[n]["kind"] == kind and s <= t < s + g.delay(n):
                    row[idx[(n, s)]] = 1
            if minimise_alu and kind == "add":
                row[-1] = -1
                A.append(row); lo.append(-np.inf); hi.append(0)
            else:
                cap = res[kind] if res else 1
                A.append(row); lo.append(-np.inf); hi.append(cap)
    c = np.zeros(nv)
    if minimise_alu:
        c[-1] = 1
    integrality = np.ones(nv)
    ub = np.ones(nv)
    if minimise_alu:
        ub[-1] = len(ops)
    r = milp(c, constraints=LinearConstraint(np.array(A), lo, hi),
             integrality=integrality, bounds=Bounds(np.zeros(nv), ub))
    if not r.success:
        return None
    x = r.x
    sched = {n: s for (n, s) in var if x[idx[(n, s)]] > 0.5}
    nalu = int(round(x[-1])) if minimise_alu else (res or {}).get("add")
    return sched, nalu


# ---------------------------------------------------------------------------
# binding
# ---------------------------------------------------------------------------
def lifetimes(g, sched, L):
    """value -> (first step it must be held, last step it is read).
    Outputs written to state/output registers or memory at the end of their
    producing step need no temporary register (see RESULTS.md)."""
    arch = {"lp": "lp1", "ms'": "ms", "hp": "hp_out", "dv": "dv_out", "mwi'": "mwi_out"}
    life = {}
    for n in g.ops:
        su = succs(g, n)
        if not su:
            continue
        avail = sched[n] + g.delay(n)
        last = max(sched[m] for m in su)
        life[n] = (avail, last)
    return life, arch


def left_edge(life, exclude=()):
    items = sorted(((v, a, b) for v, (a, b) in life.items() if v not in exclude),
                   key=lambda t: (t[1], t[2]))
    regs = []          # list of [last_end, [values]]
    assign = {}
    for v, a, b in items:
        for r_i, r in enumerate(regs):
            if r[0] < a:
                r[0] = b; r[1].append(v); assign[v] = r_i
                break
        else:
            regs.append([b, [v]]); assign[v] = len(regs) - 1
    return regs, assign


def clique_partition(g, sched, kind="add"):
    """Tseng-Siewiorek clique partitioning of the FU compatibility graph
    (two ops compatible = same kind and disjoint execution steps).
    Tie-break: keep the 40-bit MWI ops together (one 40-bit ALU)."""
    ops = [n for n in g.ops if g.ops[n]["kind"] == kind]
    C = nx.Graph()
    C.add_nodes_from(ops)
    occ = {n: set(range(sched[n], sched[n] + g.delay(n))) for n in ops}
    for i, a in enumerate(ops):
        for b in ops[i + 1:]:
            if not (occ[a] & occ[b]):
                C.add_edge(a, b)
    W = nx.Graph(C)                     # working graph of super-nodes
    groups = {n: [n] for n in ops}
    wide = {"m1", "mwi'"}
    while W.number_of_edges():
        best = None
        for (a, b) in W.edges():
            common = len(set(W[a]) & set(W[b]))
            bonus = 1 if (set(groups[a]) & wide and set(groups[b]) & wide) else 0
            key = (common, bonus, -len(groups[a]) - len(groups[b]))
            if best is None or key > best[0]:
                best = (key, a, b)
        _, a, b = best
        keep = set(W[a]) & set(W[b])
        groups[a] += groups.pop(b)
        W.remove_node(b)
        for nbr in list(W[a]):
            if nbr not in keep:
                W.remove_edge(a, nbr)
    return C, list(groups.values())


# ---------------------------------------------------------------------------
# figures
# ---------------------------------------------------------------------------
SHORT = {"xc": "xc", "u1": "u1", "u2": "u2", "u3": "u3", "lp": "lp", "v1": "v1",
         "ms'": "ms'", "hp": "hp", "w1": "w1", "w2": "w2", "dv": "dv", "sq": "sq",
         "m1": "m1", "mwi'": "mwi'"}


def fig_cdfg(g, s_asap):
    fig = plt.figure(figsize=(4.45, 2.75))
    # --- left: control-flow view ---
    axc = fig.add_axes([0.0, 0.0, 0.27, 1.0]); axc.axis("off")
    axc.set_xlim(0, 1); axc.set_ylim(0, 1)
    blocks = [("IDLE\nwait start", 0.90), ("read state +\nbuffer taps", 0.70),
              ("DFG body\n(13 ALU + 1 MUL)", 0.47), ("write buffers,\nupdate state,\nptr++", 0.23),
              ("DONE\noutputs valid", 0.05)]
    for (txt, y) in blocks:
        axc.add_patch(FancyBboxPatch((0.08, y - 0.065), 0.84, 0.13,
                      boxstyle="round,pad=0.01", fc="#eef3fa", ec="#33557a", lw=0.7))
        axc.text(0.5, y, txt, ha="center", va="center", fontsize=6.6)
    for (y0, y1) in [(0.835, 0.765), (0.635, 0.535), (0.405, 0.295), (0.165, 0.115)]:
        axc.annotate("", xy=(0.5, y1), xytext=(0.5, y0),
                     arrowprops=dict(arrowstyle="-|>", lw=0.7, color="#33557a"))
    # loop back on the left edge: DONE -> IDLE
    axc.plot([0.08, 0.0, 0.0], [0.05, 0.05, 0.90], color="gray", lw=0.6)
    axc.annotate("", xy=(0.08, 0.90), xytext=(0.0, 0.90),
                 arrowprops=dict(arrowstyle="-|>", lw=0.6, color="gray"))
    axc.text(-0.03, 0.47, "next sample", fontsize=6, color="gray", rotation=90,
             ha="right", va="center")
    axc.set_xlim(-0.12, 1.0); axc.set_ylim(-0.04, 1.0)
    axc.set_title("(a) control flow", fontsize=7.5, y=0.985)

    # --- right: data-flow graph, rows = ASAP step, hand-placed ---
    ax = fig.add_axes([0.30, 0.0, 0.70, 1.0]); ax.axis("off")
    G = nx.DiGraph()
    for n, o in g.ops.items():
        G.add_node(n)
        for i in o["ins"]:
            if i in g.ops:
                G.add_edge(i, n)
    Lmax = max(s_asap.values())
    col = {"u1": -2.4, "u2": -1.5, "xc": -0.6, "v1": 0.35, "w1": 1.35, "m1": 2.45,
           "u3": -1.95, "w2": 1.35, "lp": -1.0, "ms'": -0.1, "hp": 0.55,
           "dv": 1.2, "sq": 1.85, "mwi'": 2.45}
    pos = {n: (col[n], Lmax - s_asap[n]) for n in g.ops}
    colors = ["#f6d7a7" if g.ops[n]["kind"] == "mul" else "#d6e6f5" for n in G.nodes]
    nx.draw_networkx_edges(G, pos, ax=ax, arrows=True, arrowstyle="-|>", arrowsize=6,
                           width=0.6, edge_color="#555555", node_size=330)
    nx.draw_networkx_nodes(G, pos, ax=ax, node_color=colors, edgecolors="#33557a",
                           linewidths=0.6, node_size=330)
    nx.draw_networkx_labels(G, pos, ax=ax, labels={n: SHORT[n] for n in G}, font_size=6.2,
                            font_family="DejaVu Serif")
    for r in range(1, Lmax + 1):
        ax.text(-3.2, Lmax - r, f"{r}", fontsize=6, color="gray", va="center")
    ax.text(-3.2, Lmax - 0.25, "", fontsize=6)
    ax.text(-3.35, Lmax + 0.55, "ASAP step", fontsize=6, color="gray", va="center")
    defs = ("u1 = 2lp1 - lp2\nu2 = x12 - 2x6\nxc = x - base\nu3 = u1 + u2\nlp = xc + u3\n"
            "v1 = ms - lp32\nms' = v1 + lp\nhp = lp16 - (ms'>>5)\nw1 = h1 - h3\nw2 = w1 - 2h4\n"
            "dv = (2hp + w2)>>3\nsq = dv * dv\nm1 = mwi - sq54\nmwi' = m1 + sq")
    ax.text(-2.85, Lmax - 3.45, defs, fontsize=5.6, va="top", ha="left", family="DejaVu Serif",
            linespacing=1.25, color="#222222",
            bbox=dict(boxstyle="round,pad=0.3", fc="#fafafa", ec="#cccccc", lw=0.5))
    ax.set_xlim(-3.4, 2.85); ax.set_ylim(-0.6, Lmax + 0.95)
    ax.set_title("(b) DFG of one sample (blue: add/sub, orange: multiply)",
                 fontsize=7.5, y=0.985)
    for ext in ("pdf", "png"):
        fig.savefig(os.path.join(FIG, f"cdfg.{ext}"), dpi=300, bbox_inches="tight")
    plt.close(fig)


def fig_schedule(g, schedA, LA, bindA, schedB, LB, bindB, labelA, labelB):
    fig, axs = plt.subplots(2, 1, figsize=(6.2, 2.15),
                            gridspec_kw={"height_ratios": [2, 1 + len(bindB)]})
    for ax, sched, L, bind, lab in ((axs[0], schedA, LA, bindA, labelA),
                                    (axs[1], schedB, LB, bindB, labelB)):
        units = [f"ALU{i}" for i in range(len(bind))] + ["MUL"]
        for ui, grp in enumerate(bind):
            for n in grp:
                s = sched[n]
                ax.add_patch(plt.Rectangle((s - 0.5, ui - 0.38), 1, 0.76, fc="#d6e6f5",
                                           ec="#33557a", lw=0.6))
                ax.text(s, ui, SHORT[n], ha="center", va="center", fontsize=6.3)
        s = sched["sq"]
        mu = len(bind)
        ax.add_patch(plt.Rectangle((s - 0.5, mu - 0.38), MUL_STEPS, 0.76, fc="#f6d7a7",
                                   ec="#a0602a", lw=0.6))
        ax.text(s - 0.5 + MUL_STEPS / 2, mu, "sq", ha="center", va="center", fontsize=6.3)
        ax.set_yticks(range(len(units))); ax.set_yticklabels(units, fontsize=6.5)
        ax.set_xticks(range(1, L + 1)); ax.tick_params(axis="x", labelsize=6.5)
        ax.set_xlim(0.4, max(LA, LB) + 0.6); ax.set_ylim(-0.6, len(units) - 0.4)
        ax.invert_yaxis()
        ax.set_title(lab, fontsize=7.5, loc="left")
        ax.grid(axis="x", alpha=0.25, lw=0.5)
    axs[1].set_xlabel("control step (10 ns)", fontsize=7)
    fig.tight_layout(h_pad=0.4)
    for ext in ("pdf", "png"):
        fig.savefig(os.path.join(FIG, f"schedule.{ext}"), dpi=300, bbox_inches="tight")
    plt.close(fig)


def fig_compat(C, groups, sched):
    fig, ax = plt.subplots(figsize=(2.6, 2.3))
    ax.axis("off")
    pos = nx.circular_layout(sorted(C.nodes, key=lambda n: (sched[n], n)))
    pal = ["#4c78a8", "#f58518", "#54a24b", "#e45756", "#b279a2"]
    col = {}
    for i, grp in enumerate(groups):
        for n in grp:
            col[n] = pal[i % len(pal)]
    nx.draw_networkx_edges(C, pos, ax=ax, width=0.35, edge_color="#bbbbbb")
    nx.draw_networkx_nodes(C, pos, ax=ax, node_color=[col[n] for n in C.nodes],
                           node_size=260, edgecolors="black", linewidths=0.4)
    nx.draw_networkx_labels(C, pos, ax=ax, labels={n: f"{SHORT[n]}\n{sched[n]}" for n in C.nodes},
                            font_size=5.2, font_color="white", font_family="DejaVu Serif")
    ax.set_title("ALU compatibility graph (label: op / step);\ncolour = clique = ALU instance",
                 fontsize=6.8)
    for ext in ("pdf", "png"):
        fig.savefig(os.path.join(FIG, f"compat.{ext}"), dpi=300, bbox_inches="tight")
    plt.close(fig)


# ---------------------------------------------------------------------------
def main():
    out = {"mul_steps": MUL_STEPS}
    # (a) transformations
    rows = []
    for g in build_versions():
        m, a = g.counts()
        rows.append({"version": g.name, "mult": m, "addsub": a, "cp_steps": g.critical_path()})
    out["transformations"] = rows
    print(f"\n(a) transformations  (add = 1 step, mult = {MUL_STEPS} step(s))")
    print("| Version | #Mult | #Add/Sub | Critical path (steps) |\n|---|---|---|---|")
    for r in rows:
        print(f"| {r['version']} | {r['mult']} | {r['addsub']} | {r['cp_steps']} |")

    g = final_dfg()
    L = g.critical_path()
    s0, s1 = asap(g), alap(g, L)
    out["asap_alap"] = {n: {"asap": s0[n], "alap": s1[n], "mobility": s1[n] - s0[n]} for n in g.ops}
    print(f"\n(c) final DFG: {len(g.ops)} ops, latency bound L = {L}")
    print("| op | " + " | ".join(SHORT[n] for n in g.ops) + " |")
    print("|---" * (len(g.ops) + 1) + "|")
    print("| ASAP | " + " | ".join(str(s0[n]) for n in g.ops) + " |")
    print("| ALAP | " + " | ".join(str(s1[n]) for n in g.ops) + " |")
    print("| Mobility | " + " | ".join(str(s1[n] - s0[n]) for n in g.ops) + " |")
    crit = [n for n in g.ops if s1[n] == s0[n]]
    out["critical_ops"] = crit
    print("critical (mobility 0):", crit)
    asap_alu = max(sum(1 for n in g.ops if g.ops[n]["kind"] == "add" and s0[n] == t)
                   for t in range(1, L + 1))
    out["asap_peak_alu"] = asap_alu
    print("ASAP peak ALU usage:", asap_alu)

    # list scheduling under two resource sets
    resA = {"add": 1, "mul": 1}
    resB = {"add": 3, "mul": 1}
    schedA, LA = list_schedule(g, resA)
    schedB, LB = list_schedule(g, resB)
    out["list_A"] = {"res": resA, "latency": LA, "sched": schedA}
    out["list_B"] = {"res": resB, "latency": LB, "sched": schedB}
    print(f"list scheduling 1 ALU + 1 MUL : {LA} steps  {schedA}")
    print(f"list scheduling 3 ALU + 1 MUL : {LB} steps  {schedB}")
    # ILP: min ALUs for each latency bound; min latency for 1 ALU
    ilp = []
    for Lb in range(L, LA + 1):
        r = ilp_schedule(g, Lb)
        if r:
            ilp.append({"latency": Lb, "min_alu": r[1], "sched": r[0]})
            print(f"ILP time-constrained L={Lb}: min ALUs = {r[1]}")
    out["ilp_time"] = ilp
    best1 = None
    for Lb in range(L, LA + 1):
        r = ilp_schedule(g, Lb, res={"add": 1, "mul": 1}, minimise_alu=False)
        if r:
            best1 = Lb
            break
    out["ilp_min_latency_1alu"] = best1
    print("ILP resource-constrained (1 ALU, 1 MUL): min latency =", best1)
    best2 = None
    for Lb in range(L, LA + 1):
        r = ilp_schedule(g, Lb, res={"add": 2, "mul": 1}, minimise_alu=False)
        if r:
            best2 = Lb
            break
    out["ilp_min_latency_2alu"] = best2
    print("ILP resource-constrained (2 ALU, 1 MUL): min latency =", best2)

    # the min-latency design point = ILP schedule at L with the minimum ALU count
    nB = ilp[0]["min_alu"]
    schedB2 = ilp[0]["sched"]
    schedL, LL = list_schedule(g, {"add": nB, "mul": 1})
    out["list_minlat"] = {"res": {"add": nB, "mul": 1}, "latency": LL, "sched": schedL}
    print(f"list scheduling {nB} ALU + 1 MUL : {LL} steps  {schedL}")
    use_B = schedL if LL == L else schedB2

    # (d) binding
    lifeA, arch = lifetimes(g, schedA, LA)
    lifeB, _ = lifetimes(g, use_B, L)
    regsA, asgA = left_edge(lifeA, exclude=arch)
    regsB, asgB = left_edge(lifeB, exclude=arch)
    out["left_edge"] = {"A": {"life": lifeA, "regs": [r[1] for r in regsA]},
                        "B": {"life": lifeB, "regs": [r[1] for r in regsB]},
                        "arch_bound": arch}
    print("\n(d) left-edge, min-area  :", len(regsA), "temp registers", [r[1] for r in regsA])
    print("    left-edge, min-latency:", len(regsB), "temp registers", [r[1] for r in regsB])
    C, groups = clique_partition(g, use_B)
    out["clique_B"] = groups
    out["compat_edges"] = C.number_of_edges()
    print("    clique partitioning (min-latency):", len(groups), "ALUs", groups,
          f"({C.number_of_nodes()} nodes, {C.number_of_edges()} compatibility edges)")
    CA, groupsA = clique_partition(g, schedA)
    out["clique_A"] = groupsA

    # figures
    fig_cdfg(g, s0)
    fig_schedule(g, schedA, LA, groupsA, use_B, L, groups,
                 f"min-area: 1 ALU + 1 MUL, list schedule, {LA} steps",
                 f"min-latency: {nB} ALU + 1 MUL, {L} steps (= critical path)")
    fig_compat(C, groups, use_B)
    out["schedule_min_area"] = schedA
    out["schedule_min_latency"] = use_B
    with open(os.path.join(HERE, "results.json"), "w") as fh:
        json.dump(out, fh, indent=1)
    print("\nwrote results.json and fig/cdfg, fig/schedule, fig/compat (.pdf/.png)")


if __name__ == "__main__":
    main()
