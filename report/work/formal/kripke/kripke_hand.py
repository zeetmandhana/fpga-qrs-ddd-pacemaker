"""
kripke_hand.py -- the small Kripke structure used for the hand-run CTL labelling.

Structure: DDD controller (abstract ticks, RTL semantics) + AV-block heart whose
retrograde V->A conduction MAY or MAY NOT occur (one nondeterministic branch),
with BUG 1 (PVARP blanking disabled) so that a retrograde P can be tracked.
16 states, 17 edges (explore.py).

Properties labelled by hand (fixpoint iterations printed below):
  phi1 = E[ !upper U AS ]   least fixpoint   Z0 = [AS],  Z_{k+1} = Z_k  u ([!upper] n pre(Z_k))
  phi2 = EG !slow_vbeat     greatest fixpt   Z0 = [!slow], Z_{k+1} = Z_k n pre(Z_k)
Both are then checked state-by-state with NuSMV on an explicit copy of the graph.
"""
import collections
import subprocess
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyArrowPatch

import explore as ex

HERE = Path(__file__).resolve().parent
NUSMV = HERE.parents[3] / "tools" / "nusmv" / "NuSMV-2.7.1-win64" / "bin" / "NuSMV.exe"


def structure():
    S, E = ex.explore("retro_nd", False)
    init = ((0, ex.LRI, 0, False), "-", False)
    succ = collections.defaultdict(list)
    for s, n in E:
        succ[s].append(n)
    order, q = [init], [init]
    while q:
        s = q.pop(0)
        for n in sorted(succ[s], key=lambda x: (x[1] != "-", x[0])):
            if n not in order:
                order.append(n)
                q.append(n)
    idx = {s: i for i, s in enumerate(order)}
    nodes = []
    for s in order:
        (ph, tv, tav, arm), ev, up = s
        nodes.append(dict(id=idx[s], phase="AVI" if ph else "AEI", t_v=tv, t_av=tav, ev=ev,
                          upper=up, slow=(ev in ("VP", "VS") and not up),
                          succ=sorted(idx[n] for n in succ[s])))
    return nodes


def pre(nodes, Z):
    return {n["id"] for n in nodes if any(t in Z for t in n["succ"])}


def label_EU(nodes, p, q):
    """E[p U q]: least fixpoint, returns list of iterates"""
    Z = {n["id"] for n in nodes if q(n)}
    its = [set(Z)]
    while True:
        Zn = Z | ({n["id"] for n in nodes if p(n)} & pre(nodes, Z))
        if Zn == Z:
            return its
        Z = Zn
        its.append(set(Z))


def label_EG(nodes, p):
    """EG p: greatest fixpoint"""
    Z = {n["id"] for n in nodes if p(n)}
    its = [set(Z)]
    while True:
        Zn = Z & pre(nodes, Z)
        if Zn == Z:
            return its
        Z = Zn
        its.append(set(Z))


def fmt(Z):
    return "{" + ",".join(f"s{i}" for i in sorted(Z)) + "}"


def nusmv_check(nodes):
    lines = ["MODULE main", "VAR s : 0..%d;" % (len(nodes) - 1), "ASSIGN", "  next(s) := case"]
    for n in nodes:
        tgt = n["succ"][0] if len(n["succ"]) == 1 else "{" + ", ".join(map(str, n["succ"])) + "}"
        lines.append(f"    s = {n['id']} : {tgt};")
    lines.append("  esac;")

    def setof(pred):
        ids = [str(n["id"]) for n in nodes if pred(n)]
        return "s in {" + ", ".join(ids) + "}" if ids else "FALSE"
    lines += ["DEFINE",
              f"  AS := {setof(lambda n: n['ev'] == 'AS')};",
              f"  VP := {setof(lambda n: n['ev'] == 'VP')};",
              f"  upper := {setof(lambda n: n['upper'])};",
              f"  slow_vbeat := {setof(lambda n: n['slow'])};",
              "-- no init(s): every state is initial, so 's = k -> phi' checks phi at state k"]
    for n in nodes:
        lines.append(f"CTLSPEC NAME phi1_s{n['id']} := (s = {n['id']} -> E[ !upper U AS ]);")
    for n in nodes:
        lines.append(f"CTLSPEC NAME phi2_s{n['id']} := (s = {n['id']} -> EG !slow_vbeat);")
    lines.append(f"CTLSPEC NAME phi1_init := (s = 0 -> E[ !upper U AS ]);")
    smv = HERE / "kripke_hand.smv"
    smv.write_text("\n".join(lines) + "\n")
    out = subprocess.run([str(NUSMV), "-dcx", str(smv)], capture_output=True, text=True).stdout
    res = {}
    for line in out.splitlines():
        if line.startswith("-- specification"):
            ok = line.rstrip().endswith("is true")
            st = int(line.split("s = ")[1].split(" ")[0])
            key = "phi1" if "E [" in line or "E[" in line else "phi2"
            res.setdefault(key, set())
            if ok:
                res[key].add(st)
    return res, out


def draw(nodes, sat1, sat2, path):
    plt.rcParams.update({"font.family": "serif", "font.size": 7.5})
    # layout: entry row, then a fork into the PMT loop (top) and the normal loop (bottom)
    pos = {0: (0, 1), 1: (1, 1), 2: (2, 1), 3: (3, 1), 4: (4, 1), 5: (5, 1),
           7: (6, 2), 9: (7, 2), 11: (5.2, 2.55),
           6: (6, 0), 8: (7, 0), 10: (8, 0), 12: (8.6, 0.85), 13: (7.6, 0.85),
           14: (6.6, 0.85) if False else (6.6, -0.75), 15: (4, -0.75)}
    pos[13] = (8, -0.75)
    pos[12] = (9, 0)
    pos[14] = (5.6, -0.75)
    pos[15] = (3.6, -0.75)
    fig, ax = plt.subplots(figsize=(6.3, 2.35))
    for n in nodes:
        x, y = pos[n["id"]]
        for t in n["succ"]:
            x2, y2 = pos[t]
            rad = 0.0
            if (n["id"], t) in ((11, 4), (15, 3)):
                rad = 0.25
            ax.add_patch(FancyArrowPatch((x, y), (x2, y2), arrowstyle="-|>", mutation_scale=7,
                                         shrinkA=9, shrinkB=9, lw=0.7, color="0.35",
                                         connectionstyle=f"arc3,rad={rad}"))
    for n in nodes:
        x, y = pos[n["id"]]
        in1, in2 = n["id"] in sat1, n["id"] in sat2
        face = "#f4c7c3" if in2 else ("#d9e8f5" if in1 else "white")
        edge = "#b3261e" if n["upper"] else ("#1a7f37" if n["slow"] else "0.2")
        ax.add_patch(plt.Circle((x, y), 0.3, facecolor=face, edgecolor=edge,
                                lw=1.6 if (n["upper"] or n["slow"]) else 0.8, zorder=3))
        ax.text(x, y + 0.07, f"s{n['id']}", ha="center", va="center", fontsize=7, weight="bold", zorder=4)
        ax.text(x, y - 0.12, n["ev"] if n["ev"] != "-" else f"{n['t_v']}", ha="center", va="center",
                fontsize=6, zorder=4)
    ax.text(0, 1.45, "reset", ha="center", fontsize=6.5)
    ax.text(6.6, 2.55, "retrograde P sensed (bug)\n$\\to$ VP at URI: PMT loop", fontsize=6.5, va="center")
    ax.text(6.0, 0.42, "retrograde P not conducted", fontsize=6.5)
    from matplotlib.patches import Patch
    from matplotlib.lines import Line2D
    ax.legend(handles=[Patch(fc="#f4c7c3", ec="0.2", label="EG $\\neg$slow holds"),
                       Patch(fc="#d9e8f5", ec="0.2", label="EG $\\neg$slow fails"),
                       Line2D([], [], marker="o", ls="", mfc="white", mec="#1a7f37", mew=1.6, label="slow V beat"),
                       Line2D([], [], marker="o", ls="", mfc="white", mec="#b3261e", mew=1.6, label="upper-rate V beat")],
              loc="lower left", fontsize=6, frameon=False, ncol=2, bbox_to_anchor=(0.0, -0.08))
    ax.set_xlim(-0.5, 9.6)
    ax.set_ylim(-1.3, 3.0)
    ax.set_aspect("equal")
    ax.axis("off")
    fig.tight_layout(pad=0.1)
    fig.savefig(path.with_suffix(".pdf"))
    fig.savefig(path.with_suffix(".png"), dpi=200)


def main():
    nodes = structure()
    up = lambda n: n["upper"]
    it1 = label_EU(nodes, lambda n: not up(n), lambda n: n["ev"] == "AS")
    it2 = label_EG(nodes, lambda n: not n["slow"])
    lines = ["Kripke structure (16 states):"]
    for n in nodes:
        lines.append(f"  s{n['id']:<2} {n['phase']} t_v={n['t_v']:<2} t_av={n['t_av']} event={n['ev']:2} "
                     f"upper={int(n['upper'])} slow={int(n['slow'])} -> {', '.join('s%d' % t for t in n['succ'])}")
    lines += ["", "phi1 = E[ !upper U AS ]  (least fixpoint)"]
    prev = set()
    for k, Z in enumerate(it1):
        lines.append(f"  Z{k:<2} = Z{k-1 if k else ''} + {fmt(Z - prev)}" if k else f"  Z0  = [AS] = {fmt(Z)}")
        prev = Z
    lines.append(f"  fixpoint after {len(it1)-1} iterations: {len(it1[-1])} states, all except "
                 f"{fmt({n['id'] for n in nodes} - it1[-1])}")
    lines += ["", "phi2 = EG !slow_vbeat  (greatest fixpoint)"]
    prev = None
    for k, Z in enumerate(it2):
        if k == 0:
            lines.append(f"  Z0  = [!slow] = all except {fmt({n['id'] for n in nodes} - Z)}")
        else:
            lines.append(f"  Z{k:<2} = Z{k-1} - {fmt(prev - Z)}")
        prev = Z
    lines.append(f"  fixpoint after {len(it2)-1} iterations: {fmt(it2[-1])}")
    res, out = nusmv_check(nodes)
    lines += ["", "NuSMV (state-by-state, explicit copy kripke_hand.smv):",
              f"  phi1 true in {fmt(res.get('phi1', set()))}  -> {'MATCH' if res.get('phi1') == it1[-1] else 'DIFFERENT'}",
              f"  phi2 true in {fmt(res.get('phi2', set()))}  -> {'MATCH' if res.get('phi2') == it2[-1] else 'DIFFERENT'}",
              f"  at the initial state s0: phi1 {'holds' if 0 in it1[-1] else 'fails'}, "
              f"phi2 {'holds' if 0 in it2[-1] else 'fails'}"]
    txt = "\n".join(lines)
    (HERE / "kripke_hand.txt").write_text(txt + "\n")
    (HERE / "kripke_hand_nusmv.log").write_text(out)
    print(txt)
    draw(nodes, it1[-1], it2[-1], HERE.parent / "fig_kripke")


if __name__ == "__main__":
    main()
