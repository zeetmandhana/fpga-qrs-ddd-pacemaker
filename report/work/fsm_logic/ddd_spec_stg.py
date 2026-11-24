"""
ddd_spec_stg.py -- VL401 report, Section 5.1 (state minimisation)

The DDD pacemaker controller written the way a designer first draws it from the
pacemaker timing-cycle specification: one state per timing period.

  V-A interval (after a ventricular event)          A-V interval (after an atrial event)
    VRF  VRP and PVARP both running                   AVD  AV delay (AVI) running
    PVA  VRP over, PVARP running (A blanked)          URW  AVI over, waiting for URI
    VRO  PVARP over, VRP running (V blanked)
    ALR  both over: alert for A, or AEI timeout -> AP

Mealy machine, one transition per 1 ms tick.
  inputs  (7): a v r b e m u   (a/v = intrinsic sense this tick;
               r = t_v>=VRP, b = t_v<PVARP, e = t_v>=AEI, m = t_av>=AVI, u = t_v>=URI)
  outputs (4): VS VP AS AP

The timer comparators are inputs, so the timers themselves stay in the datapath.
Input combinations that the monotonic timers make impossible in a state are
don't-cares (t_v only grows inside an interval, so once r=1 it stays 1 and once
b=0 it stays 0; t_av only grows, so once m=1 it stays 1):
  PVA: r=0 impossible    VRO: b=1 impossible    ALR: r=0 or b=1 impossible
  URW: m=0 impossible

This script
  1. writes the machine in the professor's kit formats (.kiss2 / .fsm), complete
     and incompletely specified (don't-care rows omitted);
  2. runs an implication chart (compatibility, for the incompletely specified
     machine) and the partition method (complete machine), plus the kit's own
     pure-Python partition step (vl401.py partition_refine);
  3. builds the minimised machine and checks it against the RTL controller
     (rtl/ddd_pacemaker.v: one phase bit + event priority)
       (a) symbolically: product machine over all 128 input vectors,
       (b) concretely: exhaustive state-space exploration of the timers for
           several legal parameter sets, which also proves the don't-care
           assumptions are never violated;
  4. draws the STG and the implication chart.
Run:  .venv\\Scripts\\python report\\work\\fsm_logic\\ddd_spec_stg.py
"""
from __future__ import annotations

import contextlib
import io
import itertools
import json
import os
import sys
from collections import deque

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
KIT = os.path.join(ROOT, "tools", "professor_kit", "VL401_Synthesis")

INPUTS = ["a", "v", "r", "b", "e", "m", "u"]
OUTPUTS = ["VS", "VP", "AS", "AP"]
VA = ["VRF", "PVA", "VRO", "ALR"]
AV = ["AVD", "URW"]
STATES = VA + AV
RESET = "VRF"           # no don't-cares in VRF, so it is a safe reset state for every parameter set
DESC = {"VRF": "VRP + PVARP running", "PVA": "PVARP only (A blanked)",
        "VRO": "VRP only (V blanked)", "ALR": "alert: wait A or AEI",
        "AVD": "AV delay running", "URW": "AVI over, wait URI"}
ALL_X = [tuple(bits) for bits in itertools.product((0, 1), repeat=7)]


def xd(x):
    return dict(zip(INPUTS, x))


def care(state, x) -> bool:
    d = xd(x)
    if state == "PVA":
        return d["r"] == 1
    if state == "VRO":
        return d["b"] == 0
    if state == "ALR":
        return d["r"] == 1 and d["b"] == 0
    if state == "URW":
        return d["m"] == 1
    return True


def spec_out(state, x):
    """Outputs written from the specification text (not from the RTL)."""
    d = xd(x)
    vs = d["v"] & d["r"]                                 # V sensed outside VRP
    if state in VA:
        a_ok = d["a"] & (1 - d["b"])                     # A sensed outside PVARP
        as_ = (1 - vs) & a_ok
        ap = (1 - vs) & (1 - a_ok) & d["e"]              # AEI timeout -> atrial pace
        return (vs, 0, as_, ap)
    vp = (1 - vs) & d["m"] & d["u"]                      # AVI over and URI respected
    return (vs, vp, 0, 0)


def spec_next(state, x):
    d = xd(x)
    vs, vp, as_, ap = spec_out(state, x)
    if vs or vp:
        return "VRF"                                     # new V-A interval, both refractory
    if as_ or ap:
        return "AVD"                                     # new A-V interval
    if state in VA:                                      # which periods are still running
        return {(0, 1): "VRF", (1, 1): "PVA", (0, 0): "VRO", (1, 0): "ALR"}[(d["r"], d["b"])]
    return "URW" if d["m"] else "AVD"


# ---------------------------------------------------------------- RTL controller
def rtl_ctrl(phase, x):
    """rtl/ddd_pacemaker.v, one tick, with the timer comparisons given as inputs.
    phase 0 = PH_AEI, 1 = PH_AVI.  Returns (outputs, next_phase)."""
    d = xd(x)
    vs = vp = as_ = ap = 0
    nphase = phase
    if d["v"] and d["r"]:
        vs = 1
        nphase = 0
    else:
        if phase == 1 and d["m"] and d["u"]:
            vp = 1
            nphase = 0
        if not vp and phase == 0:
            blanked = d["b"]
            if d["a"] and not blanked:
                as_ = 1
                nphase = 1
            elif d["e"]:
                ap = 1
                nphase = 1
    return (vs, vp, as_, ap), nphase


# ---------------------------------------------------------------- KISS2 / .fsm writers
def disjoint_cubes(minterms: set, nvar: int):
    """Disjoint cube cover of a set of minterms (tuples) by Shannon splitting."""
    out = []

    def rec(prefix, depth, ms):
        if not ms:
            return
        if len(ms) == 2 ** (nvar - depth):
            out.append(prefix + "-" * (nvar - depth))
            return
        for bit in (0, 1):
            rec(prefix + str(bit), depth + 1, {m for m in ms if m[depth] == bit})
    rec("", 0, set(minterms))
    return out


def machine_rows(states, nxt, out, carefn):
    rows = []
    for s in states:
        groups = {}
        for x in ALL_X:
            if carefn(s, x):
                groups.setdefault((nxt(s, x), out(s, x)), set()).add(x)
        for (ns, o), ms in sorted(groups.items()):
            for cube in disjoint_cubes(ms, 7):
                rows.append((cube, s, ns, "".join(map(str, o))))
    return rows


def write_kiss(path, rows, nstates, reset, header):
    with open(path, "w") as f:
        f.write(header)
        f.write(".i 7\n.o 4\n.s %d\n.p %d\n.r %s\n" % (nstates, len(rows), reset))
        for r in rows:
            f.write("%s %s %s %s\n" % r)
        f.write(".e\n")


def write_fsm_table(path, states, nxt, out, carefn, reset, header):
    cols = ["".join(map(str, x)) for x in ALL_X]
    with open(path, "w") as f:
        f.write(header)
        f.write("inputs: " + " ".join(cols) + "\n")
        f.write("reset: %s\n" % reset)
        for s in states:
            ents = []
            for x in ALL_X:
                ents.append("%s/%s" % (nxt(s, x), "".join(map(str, out(s, x)))) if carefn(s, x) else "-")
            f.write(s + " " + " ".join(ents) + "\n")


# ---------------------------------------------------------------- minimisation
def implication_chart(states, nxt, out, carefn):
    """Compatibility implication chart for an incompletely specified Mealy machine."""
    pairs = list(itertools.combinations(states, 2))
    cell = {}
    for p, q in pairs:
        both = [x for x in ALL_X if carefn(p, x) and carefn(q, x)]
        conflict = [x for x in both if out(p, x) != out(q, x)]
        if conflict:
            cell[(p, q)] = {"status": "X1", "why": "outputs differ, e.g. input %s" % "".join(map(str, conflict[0])),
                            "implied": []}
        else:
            imp = sorted({tuple(sorted((nxt(p, x), nxt(q, x)))) for x in both if nxt(p, x) != nxt(q, x)})
            cell[(p, q)] = {"status": "?", "why": "", "implied": imp, "n_common_inputs": len(both)}
    rnd = 1
    changed = True
    while changed:
        rnd += 1
        changed = False
        for k, c in cell.items():
            if c["status"] != "?":
                continue
            for ip in c["implied"]:
                if cell[ip]["status"].startswith("X"):
                    c["status"] = "X%d" % rnd
                    c["why"] = "implies incompatible pair %s-%s" % ip
                    changed = True
                    break
    for c in cell.values():
        if c["status"] == "?":
            c["status"] = "OK"
    return cell


def maximal_compatibles(states, cell):
    import networkx as nx
    g = nx.Graph()
    g.add_nodes_from(states)
    g.add_edges_from(k for k, c in cell.items() if c["status"] == "OK")
    return [sorted(c, key=states.index) for c in nx.find_cliques(g)]


def closed_cover(states, classes, nxt, carefn):
    """Check that a set of classes covers all states and is closed."""
    covers = all(any(s in c for c in classes) for s in states)
    closed = True
    for c in classes:
        for x in ALL_X:
            succ = {nxt(s, x) for s in c if carefn(s, x)}
            if succ and not any(succ <= set(k) for k in classes):
                closed = False
    return covers, closed


def partition_method(states, nxt, out):
    P = {}
    for s in states:
        P.setdefault(tuple(out(s, x) for x in ALL_X), []).append(s)
    P = list(P.values())
    history = [[list(g) for g in P]]
    while True:
        gid = {s: i for i, g in enumerate(P) for s in g}
        newP = []
        for g in P:
            sub = {}
            for s in g:
                sub.setdefault(tuple(gid[nxt(s, x)] for x in ALL_X), []).append(s)
            newP.extend(sub.values())
        history.append([list(g) for g in newP])
        if len(newP) == len(P):
            return newP, history
        P = newP


# ---------------------------------------------------------------- equivalence checks
def product_check(m_states, m_reset, m_next, m_out, m_care):
    """BFS over (machine state, RTL phase) for every care input vector."""
    start = (m_reset, 0)
    seen = {start}
    q = deque([start])
    checked = 0
    while q:
        s, ph = q.popleft()
        for x in ALL_X:
            if not m_care(s, x):
                continue
            o_m = m_out(s, x)
            o_r, nph = rtl_ctrl(ph, x)
            checked += 1
            if o_m != o_r:
                return {"equal": False, "state": s, "phase": ph, "input": "".join(map(str, x)),
                        "machine": o_m, "rtl": o_r}
            nxt_pair = (m_next(s, x), nph)
            if nxt_pair not in seen:
                seen.add(nxt_pair)
                q.append(nxt_pair)
    return {"equal": True, "reachable_pairs": sorted(seen), "checked": checked}


def concrete_check(params, nxt, out, carefn, reset_state):
    """Exhaustive exploration of the real timers (rtl/ddd_pacemaker.v semantics).
    State = (phase, t_v, t_av, spec state); inputs (a, v) every tick."""
    lri, avi, uri, pvarp, vrp = params
    aei = lri - avi
    start = (0, lri, 0, reset_state)
    seen = {start}
    q = deque([start])
    viol_dc = viol_out = 0
    first = None
    steps = 0
    while q:
        ph, t_v, t_av, s = q.popleft()
        tv = lri if t_v >= lri else t_v + 1
        tav = t_av + 1 if ph == 1 else 0
        for a in (0, 1):
            for v in (0, 1):
                x = (a, v, int(tv >= vrp), int(tv < pvarp), int(tv >= aei), int(tav >= avi), int(tv >= uri))
                steps += 1
                o_r, nph = rtl_ctrl(ph, x)
                if not carefn(s, x):
                    viol_dc += 1
                    first = first or ("don't-care hit", s, x)
                    continue
                if out(s, x) != o_r:
                    viol_out += 1
                    first = first or ("output differs", s, x)
                vs, vp, as_, ap = o_r
                if vs or vp:
                    ntv, ntav = 0, 0
                elif as_ or ap:
                    ntv, ntav = tv, 0
                else:
                    ntv, ntav = tv, tav
                st = (nph, ntv, ntav, nxt(s, x))
                if st not in seen:
                    seen.add(st)
                    q.append(st)
    return {"params(LRI,AVI,URI,PVARP,VRP)": list(params), "AEI": aei, "reachable_states": len(seen),
            "transitions_checked": steps, "dont_care_violations": viol_dc,
            "output_mismatches": viol_out, "first_problem": str(first) if first else None}


def rtl_vs_python_model(params, ticks=300000, seed=7):
    """Cross-check of the rtl_ctrl+timer mirror against src/pacemaker.py (random senses)."""
    import random
    sys.path.insert(0, os.path.join(ROOT, "src"))
    from pacemaker import DDDParameters, DDDPacemaker
    lri, avi, uri, pvarp, vrp = params
    pm = DDDPacemaker(DDDParameters(lri_ms=lri, avi_ms=avi, uri_ms=uri, pvarp_ms=pvarp, vrp_ms=vrp))
    rnd = random.Random(seed)
    ph, t_v, t_av = 0, lri, 0
    mism = 0
    for _ in range(ticks):
        a = int(rnd.random() < 0.004)
        v = int(rnd.random() < 0.004)
        tv = lri if t_v >= lri else t_v + 1
        tav = t_av + 1 if ph == 1 else 0
        x = (a, v, int(tv >= vrp), int(tv < pvarp), int(tv >= lri - avi), int(tav >= avi), int(tv >= uri))
        o_r, nph = rtl_ctrl(ph, x)
        o = pm.step(bool(a), bool(v))
        o_p = (int(o.v_sense), int(o.v_pace), int(o.a_sense), int(o.a_pace))
        mism += int(o_r != o_p)
        vs, vp, as_, ap = o_r
        if vs or vp:
            t_v, t_av = 0, 0
        elif as_ or ap:
            t_v, t_av = tv, 0
        else:
            t_v, t_av = tv, tav
        ph = nph
    return mism


# ---------------------------------------------------------------- figures
def draw_figures(cell, merged_classes):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.patches import Circle, FancyArrowPatch, Rectangle
    plt.rcParams.update({"font.family": "serif", "font.size": 8, "pdf.fonttype": 42})

    # ---- Figure 1: spec STG (6 states) -> minimised STG (2 states)
    fig = plt.figure(figsize=(6.3, 2.35))
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(0, 12.6)
    ax.set_ylim(0, 4.7)
    ax.set_aspect("equal")
    ax.axis("off")
    PT = 72 * 6.3 / 12.6          # points per data unit
    R = 0.42
    pos = {"VRF": (1.0, 3.5), "PVA": (3.1, 3.5), "VRO": (1.0, 1.3), "ALR": (3.1, 1.3),
           "AVD": (5.6, 3.5), "URW": (5.6, 1.3)}

    def node(xy, name, fc="white", r=R, fs=8):
        ax.add_patch(Circle(xy, r, fc=fc, ec="black", lw=0.8, zorder=3))
        ax.text(*xy, name, ha="center", va="center", fontsize=fs, zorder=4)

    def arrow(p, q, label="", rad=0.0, fs=6.2, lpos=0.5, off=(0, 0), r=R, color="black"):
        a = FancyArrowPatch(p, q, connectionstyle="arc3,rad=%s" % rad, arrowstyle="-|>",
                            mutation_scale=7, lw=0.7, color=color, shrinkA=r * PT,
                            shrinkB=r * PT + 0.5, zorder=4)
        ax.add_patch(a)
        if label:
            mx = p[0] + (q[0] - p[0]) * lpos + off[0]
            my = p[1] + (q[1] - p[1]) * lpos + off[1]
            ax.text(mx, my, label, fontsize=fs, ha="center", va="center", color=color,
                    bbox=dict(fc="white", ec="none", pad=0.4), zorder=5)

    # group boxes
    ax.add_patch(Rectangle((0.3, 0.55), 3.5, 3.75, fc="#eef3fb", ec="#5b7db1", lw=0.7, ls="--", zorder=0))
    ax.text(2.05, 4.47, "V-A interval (merge to AEI)", ha="center", fontsize=7, color="#33507a")
    ax.add_patch(Rectangle((4.9, 0.55), 1.4, 3.75, fc="#fbf1e6", ec="#b5763a", lw=0.7, ls="--", zorder=0))
    ax.text(5.6, 4.47, "A-V (to AVI)", ha="center", fontsize=7, color="#7a4a1d")
    for s, p in pos.items():
        node(p, s)
    arrow(pos["VRF"], pos["PVA"], "r b", off=(0, 0.2))
    arrow(pos["VRF"], pos["VRO"], "r' b'", off=(-0.33, 0))
    arrow(pos["VRF"], pos["ALR"], "r b'", lpos=0.5, off=(0.18, 0.1))
    arrow(pos["PVA"], pos["ALR"], "b'", off=(0.2, 0))
    arrow(pos["VRO"], pos["ALR"], "r", off=(0, -0.2))
    arrow(pos["ALR"], pos["AVD"], "AS/AP", lpos=0.5, off=(-0.05, 0.2))
    arrow(pos["AVD"], pos["URW"], "m", off=(-0.2, 0))
    ax.text(3.45, 0.22, "every state: VS/VP -> VRF, AS/AP -> AVD (not all arcs drawn)",
            fontsize=6.0, ha="center", color="#444444")
    # minimise arrow
    ax.text(7.25, 2.85, "minimise\n6 -> 2", ha="center", va="center", fontsize=7.5)
    ax.annotate("", xy=(7.85, 2.3), xytext=(6.65, 2.3),
                arrowprops=dict(arrowstyle="-|>", lw=1.0, color="black"))
    # minimised machine
    pA, pB = (9.0, 2.3), (11.7, 2.3)
    node(pA, "AEI", fc="#eef3fb", r=0.5)
    node(pB, "AVI", fc="#fbf1e6", r=0.5)
    arrow(pA, pB, "AS = VS' a b'\nAP = VS' (a b')' e", rad=-0.5, lpos=0.5, off=(0, 0.95), r=0.5)
    arrow(pB, pA, "VS = v r\nVP = VS' m u", rad=-0.5, lpos=0.5, off=(0, -0.95), r=0.5)
    ax.text(9.0, 1.25, "no event:\nstay", ha="center", fontsize=6.0)
    ax.text(11.7, 1.25, "no event:\nstay", ha="center", fontsize=6.0)
    ax.text(10.35, 4.45, "= RTL phase bit (ddd_pacemaker.v)", ha="center", fontsize=7)
    for ext in ("pdf", "png"):
        fig.savefig(os.path.join(HERE, "fig_ddd_stg_minimisation." + ext), dpi=300)
    plt.close(fig)

    # ---- Figure 2: implication chart
    n = len(STATES)
    fig, ax = plt.subplots(figsize=(3.1, 2.5))
    ax.set_xlim(0, n - 1)
    ax.set_ylim(0, n - 1)
    ax.invert_yaxis()
    ax.axis("off")
    for i in range(1, n):
        for j in range(i):
            p, q = STATES[j], STATES[i]
            c = cell[(p, q)]
            ok = c["status"] == "OK"
            ax.add_patch(Rectangle((j, i - 1), 1, 1, fc="#e9f5e9" if ok else "#fbeaea", ec="black", lw=0.6))
            txt = "OK" if ok else "X"
            ax.text(j + 0.5, i - 0.5, txt, ha="center", va="center", fontsize=8,
                    color="#1b6e20" if ok else "#a3161a", fontweight="bold")
    for i in range(1, n):
        ax.text(-0.12, i - 0.5, STATES[i], ha="right", va="center", fontsize=7.5)
    for j in range(n - 1):
        ax.text(j + 0.5, n - 1 + 0.12, STATES[j], ha="center", va="top", fontsize=7.5)
    ax.set_xlim(-0.9, n - 1)
    ax.set_ylim(n - 1 + 0.55, -0.05)
    fig.tight_layout(pad=0.1)
    for ext in ("pdf", "png"):
        fig.savefig(os.path.join(HERE, "fig_ddd_implication_chart." + ext), dpi=300)
    plt.close(fig)


# ---------------------------------------------------------------- main
def main():
    res = {}
    hdr = ("# DDD pacemaker controller, specification-level STG (P17, VL401 report Sec. 5.1)\n"
           "# inputs : a v r b e m u   (r=t_v>=VRP b=t_v<PVARP e=t_v>=AEI m=t_av>=AVI u=t_v>=URI)\n"
           "# outputs: VS VP AS AP\n"
           "# states : " + "  ".join("%s=%s" % (s, DESC[s]) for s in STATES) + "\n")
    always = lambda s, x: True
    rows_c = machine_rows(STATES, spec_next, spec_out, always)
    rows_dc = machine_rows(STATES, spec_next, spec_out, care)
    write_kiss(os.path.join(HERE, "ddd_spec_complete.kiss2"), rows_c, len(STATES), RESET,
               hdr + "# completely specified version (every input in every state)\n")
    write_kiss(os.path.join(HERE, "ddd_spec_dc.kiss2"), rows_dc, len(STATES), RESET,
               hdr + "# incompletely specified: impossible inputs (monotonic timers) omitted = don't care\n")
    write_fsm_table(os.path.join(HERE, "ddd_spec_complete.fsm"), STATES, spec_next, spec_out, always, RESET,
                    hdr + "# kit table format, 128 input columns (a v r b e m u)\n")
    write_fsm_table(os.path.join(HERE, "ddd_spec_dc.fsm"), STATES, spec_next, spec_out, care, RESET,
                    hdr + "# kit table format; '-' = don't care (input impossible in that state)\n")
    n_dc = sum(1 for s in STATES for x in ALL_X if not care(s, x))
    res["machine"] = {"states": len(STATES), "inputs": 7, "outputs": 4,
                      "kiss_rows_complete": len(rows_c), "kiss_rows_dc": len(rows_dc),
                      "dont_care_entries": n_dc, "total_entries": len(STATES) * 128}

    # implication chart (incompletely specified machine)
    cell = implication_chart(STATES, spec_next, spec_out, care)
    res["implication_chart"] = {"%s-%s" % k: v for k, v in cell.items()}
    mc = maximal_compatibles(STATES, cell)
    res["maximal_compatibles"] = mc
    covers, closed = closed_cover(STATES, mc, spec_next, care)
    res["cover_of_maximal_compatibles"] = {"covers_all": covers, "closed": closed, "states_after": len(mc)}

    # partition method (complete machine)
    classes, hist = partition_method(STATES, spec_next, spec_out)
    res["partition_complete"] = {"passes": hist, "classes": classes}

    # kit's own pure-Python partition step on the complete .kiss2
    sys.path.insert(0, KIT)
    import vl401
    m = vl401.read_fsm(os.path.join(HERE, "ddd_spec_complete.kiss2"))
    T, complete = vl401.full_table(m)
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        kit_classes = vl401.partition_refine(m, T, verbose=False)
    with open(os.path.join(HERE, "kit_partition_ddd_spec.txt"), "w") as f:
        f.write("vl401.py partition_refine (professor's kit, pure-Python step 2 of 'minimize'),\n"
                "run on Windows by importing the kit; STAMINA (step 3) needs the Linux binary.\n"
                "File: ddd_spec_complete.kiss2, complete=%s\n" % complete)
        f.write(buf.getvalue())
        f.write("\nResult classes: %s\n" % kit_classes)
    res["kit_partition_classes"] = kit_classes

    # minimised machine: AEI = V-A sub-states, AVI = A-V sub-states
    cls_name = {}
    for c in mc:
        nm = "AEI" if c[0] in VA else "AVI"
        for s in c:
            cls_name[s] = nm
    rep = {"AEI": "VRF", "AVI": "AVD"}      # members with no don't-cares
    m_next = lambda S, x: cls_name[spec_next(rep[S], x)]
    m_out = lambda S, x: spec_out(rep[S], x)
    rows_m = machine_rows(["AEI", "AVI"], m_next, m_out, always)
    write_kiss(os.path.join(HERE, "ddd_min.kiss2"), rows_m, 2, "AEI",
               "# minimised DDD controller (2 states) from ddd_spec_dc.kiss2\n")
    res["minimised"] = {"states": 2, "kiss_rows": len(rows_m)}

    # (a) product machines against the RTL controller
    res["product_spec_vs_rtl"] = product_check(STATES, RESET, spec_next, spec_out, care)
    pm = product_check(["AEI", "AVI"], "AEI", m_next, m_out, always)
    res["product_min_vs_rtl"] = pm
    res["min_is_rtl_phase"] = pm["equal"] and sorted(pm["reachable_pairs"]) == [("AEI", 0), ("AVI", 1)]

    # (b) concrete timers, several legal parameter sets (range check of ddd_driver.c)
    psets = [(1000, 180, 500, 320, 250),     # defaults
             (400, 350, 350, 500, 400),      # AEI=50 < VRP, PVARP > LRI
             (2000, 30, 300, 150, 400),      # PVARP < VRP, long LRI
             (400, 30, 400, 150, 150),       # URI = LRI, PVARP = VRP
             (857, 120, 450, 250, 300)]      # PVARP < VRP, mid values
    res["concrete"] = [concrete_check(p, spec_next, spec_out, care, RESET) for p in psets]
    res["rtl_mirror_vs_pacemaker_py_mismatches(defaults,300k ticks)"] = rtl_vs_python_model(psets[0])

    # the 8-phase qrs_decision controller: kit partition (should already be minimal)
    mq = vl401.read_fsm(os.path.join(HERE, "qrs_decision_ctrl.kiss2"))
    Tq, cq = vl401.full_table(mq)
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        qcls = vl401.partition_refine(mq, Tq, verbose=True)
    with open(os.path.join(HERE, "kit_partition_qrs_decision.txt"), "w") as f:
        f.write("vl401.py partition_refine on qrs_decision_ctrl.kiss2 (complete=%s)\n" % cq)
        f.write(buf.getvalue())
        f.write("\nResult: %d classes for %d states\n" % (len(qcls), len(mq.states)))
    res["qrs_decision_partition"] = {"states": len(mq.states), "classes": len(qcls)}

    draw_figures(cell, mc)
    with open(os.path.join(HERE, "ddd_spec_results.json"), "w") as f:
        json.dump(res, f, indent=1, default=str)
    # short console summary
    print("machine:", res["machine"])
    print("implication chart:", {k: v["status"] for k, v in res["implication_chart"].items()})
    print("maximal compatibles:", mc, "cover:", res["cover_of_maximal_compatibles"])
    print("partition (complete):", classes, "passes:", len(hist))
    print("kit partition:", kit_classes)
    print("product spec vs rtl:", {k: v for k, v in res["product_spec_vs_rtl"].items() if k != "reachable_pairs"},
          "pairs:", len(res["product_spec_vs_rtl"].get("reachable_pairs", [])))
    print("product min vs rtl:", res["min_is_rtl_phase"], pm.get("checked"))
    for c in res["concrete"]:
        print("concrete:", c)
    print("rtl mirror vs pacemaker.py mismatches:", res["rtl_mirror_vs_pacemaker_py_mismatches(defaults,300k ticks)"])
    print("qrs_decision partition:", res["qrs_decision_partition"])


if __name__ == "__main__":
    main()
