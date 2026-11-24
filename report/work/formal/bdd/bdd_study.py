"""
bdd_study.py -- ROBDD study of the P17 event-priority block (8 inputs, 4 outputs).

1. Shared ROBDD size for several variable orders + dynamic sifting (dd package)
   and the exhaustive optimum over all 8! = 40,320 orders (classical counting).
2. Equivalence checking: every implementation of the block is built as a BDD in
   ONE manager; equal functions give the identical (canonical) node.
3. Results -> bdd_results.json / bdd_results.txt

Node counts are reported two ways:
  classical  = textbook ROBDD (no complemented edges), internal nodes + 2 terminals
  dd         = the dd package's BDD (complemented edges, one terminal)
"""
import itertools
import json
import re
import sys
import time
from pathlib import Path

from dd.autoref import BDD

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "src"))
from event_priority import VARS, OUTPUTS, decide, assignment  # noqa: E402

HERE = Path(__file__).resolve().parent
OUT = {}

# ---------------------------------------------------------------------------
# truth tables (index: p is the MSB, as in src/event_priority.py)
# ---------------------------------------------------------------------------
TT = [[decide(*assignment(i))[k] for i in range(256)] for k in range(4)]


def classical_size(order):
    """Exact shared-ROBDD node count for `order` (list of var names), no complement edges."""
    pos = [VARS.index(v) for v in order]          # level -> original bit index
    tables = []
    for k in range(4):
        t = 0
        for idx in range(256):
            # value of the input vector whose level-j variable is bit (7-j) of idx
            orig = 0
            for j, src in enumerate(pos):
                if (idx >> (7 - j)) & 1:
                    orig |= 1 << (7 - src)
            if TT[k][orig]:
                t |= 1 << idx
        tables.append(t)
    nodes = 0
    consts = set()
    for lvl in range(8):
        width = 1 << (8 - lvl)
        half = width >> 1
        mask = (1 << width) - 1
        hmask = (1 << half) - 1
        seen = set()
        for t in tables:
            for c in range(1 << lvl):
                s = (t >> (c * width)) & mask
                lo, hi = s & hmask, s >> half
                if lo != hi:
                    seen.add(s)
        nodes += len(seen)
    # terminals that are actually used
    for t in tables:
        if t != 0:
            consts.add(1)
        if t != (1 << 256) - 1:
            consts.add(0)
    return nodes + len(consts)


def build(bdd, exprs):
    return {k: bdd.add_expr(e) for k, e in exprs.items()}


def dd_shared(bdd, roots):
    return len(bdd._bdd.descendants([r.node for r in roots]))


def tt_exprs():
    """sum-of-minterms expression of each output (the truth table itself)."""
    ex = {}
    for k, o in enumerate(OUTPUTS):
        terms = []
        for i in range(256):
            if TT[k][i]:
                bits = assignment(i)
                terms.append("(" + " & ".join(v if b else "!" + v for v, b in zip(VARS, bits)) + ")")
        ex[o] = " | ".join(terms) if terms else "FALSE"
    return ex


def sop(s):
    """kit notation (p'ar'b' + ...) -> dd expression"""
    terms = []
    for t in s.split("+"):
        t = t.strip()
        lits = re.findall(r"[a-z][0-9]*'?", t)
        terms.append("(" + " & ".join(("!" + l[:-1]) if l.endswith("'") else l for l in lits) + ")")
    return " | ".join(terms)


def verilog_exprs(path):
    """parse rtl/event_priority.v (wire t_* = ...; assign out = ...;)"""
    txt = Path(path).read_text()
    txt = re.sub(r"//.*", "", txt)
    wires = dict(re.findall(r"wire\s+(t_\w+)\s*=\s*([^;]+);", txt))
    assigns = dict(re.findall(r"assign\s+(\w+)\s*=\s*([^;]+);", txt))

    def conv(e):
        e = e.replace("~", "!")
        return re.sub(r"\bt_\w+\b", lambda m: "(" + conv(wires[m.group(0)]) + ")", e)
    name = {"vs": "VS", "vp": "VP", "as_o": "AS", "ap": "AP"}
    return {name[k]: conv(v) for k, v in assigns.items()}


def main():
    t0 = time.time()
    natural = list(VARS)                                   # p a v r m u e b
    orders = {
        "natural p,a,v,r,m,u,e,b": natural,
        "reversed b,e,u,m,r,v,a,p": natural[::-1],
        "timers first e,b,u,m,r,p,a,v": ["e", "b", "u", "m", "r", "p", "a", "v"],
    }
    # ---- exhaustive optimum (classical counting) ----
    best, worst, hist = None, None, {}
    for perm in itertools.permutations(VARS):
        n = classical_size(perm)
        hist[n] = hist.get(n, 0) + 1
        if best is None or n < best[0]:
            best = (n, perm)
        if worst is None or n > worst[0]:
            worst = (n, perm)
    t_exh = time.time() - t0
    orders["exhaustive best " + ",".join(best[1])] = list(best[1])
    orders["exhaustive worst " + ",".join(worst[1])] = list(worst[1])

    # ---- dd: same orders + sifting ----
    rows = []
    for label, order in orders.items():
        bdd = BDD()
        bdd.declare(*order)
        bdd.reorder({v: i for i, v in enumerate(order)})
        f = build(bdd, tt_exprs())
        rows.append({"ordering": label, "classical": classical_size(order),
                     "dd": dd_shared(bdd, list(f.values()))})
    # sifting from the natural order and from the worst order
    sift = []
    for label, order in (("natural", natural), ("worst", list(worst[1]))):
        bdd = BDD()
        bdd.declare(*order)
        bdd.reorder({v: i for i, v in enumerate(order)})
        f = build(bdd, tt_exprs())
        bdd.collect_garbage()
        before = dd_shared(bdd, list(f.values()))
        bdd.reorder(None)                                   # Rudell sifting
        new_order = sorted(bdd.vars, key=lambda v: bdd.vars[v])
        sift.append({"start": label, "dd_before": before, "dd_after": dd_shared(bdd, list(f.values())),
                     "order_after": ",".join(new_order),
                     "classical_after": classical_size(new_order)})

    # ---- equivalence checking in one manager ----
    bdd = BDD()
    bdd.declare(*natural, "t4", "t5")      # t4/t5 = SIS gkx intermediate nodes (substituted below)
    impls = {}
    impls["truth table (src/event_priority.py)"] = build(bdd, tt_exprs())
    impls["espresso SOP (9 products, kit)"] = build(bdd, {
        "VS": sop("vr"), "VP": sop("pv'mu + pr'mu"), "AS": sop("p'av'b' + p'ar'b'"),
        "AP": sop("p'a'v'e + p'a'r'e + p'v'eb + p'r'eb")})
    impls["factored form (kit STEP 1)"] = build(bdd, {
        "VS": "r & v", "VP": "m & p & u & (!v | !r)", "AS": "a & !b & !p & (!v | !r)",
        "AP": "e & !p & (!v | !r) & (b | !a)"})
    t4, t5 = "(!v | !r)", "(b | !a)"
    impls["SIS gkx kernels t4=v'+r', t5=b+a'"] = build(bdd, {
        "VS": "r & v", "VP": f"{t4} & m & p & u", "AS": f"{t4} & a & !b & !p",
        "AP": f"{t4} & {t5} & e & !p"})
    VSx = "(v & r)"
    ASx = f"(!{VSx} & a & !b & !p)"
    impls["SIS script.rugged (14 literals)"] = build(bdd, {
        "VS": VSx, "VP": f"!{VSx} & m & p & u", "AS": ASx, "AP": f"!{VSx} & !{ASx} & e & !p"})
    impls["RTL rtl/event_priority.v (parsed)"] = build(bdd, verilog_exprs(ROOT / "rtl" / "event_priority.v"))
    yosys_blif = HERE / "event_priority_abc.blif"
    if yosys_blif.exists():
        impls["Yosys + ABC netlist (BLIF)"] = build(bdd, blif_exprs(yosys_blif))
    ref = impls["truth table (src/event_priority.py)"]
    eq_rows = []
    for name, f in impls.items():
        eq_rows.append({"impl": name,
                        "nodes": {o: f[o].node for o in OUTPUTS},
                        "equal": all(f[o] == ref[o] for o in OUTPUTS)})

    OUT.update({"orders": rows, "sifting": sift, "exhaustive_seconds": round(t_exh, 1),
                "histogram_classical": dict(sorted(hist.items())),
                "best": [best[0], ",".join(best[1])], "worst": [worst[0], ",".join(worst[1])],
                "equivalence": eq_rows,
                "n_best_orders": hist[best[0]]})
    (HERE / "bdd_results.json").write_text(json.dumps(OUT, indent=1))
    lines = ["Shared ROBDD of the event-priority block (4 outputs, 8 inputs)", "",
             f"{'ordering':42s} classical  dd(complement edges)"]
    for r in rows:
        lines.append(f"{r['ordering']:42s} {r['classical']:9d}  {r['dd']:5d}")
    lines.append("")
    for s in sift:
        lines.append(f"sifting from {s['start']:8s}: dd {s['dd_before']} -> {s['dd_after']} nodes, "
                     f"order {s['order_after']} (classical {s['classical_after']})")
    lines.append(f"exhaustive over 40,320 orders ({t_exh:.1f} s): best {best[0]} "
                 f"({hist[best[0]]} orders reach it), worst {worst[0]}")
    lines.append("")
    lines.append("Equivalence (same canonical node as the truth-table BDD for all 4 outputs):")
    for e in eq_rows:
        lines.append(f"  {e['impl']:42s} {'EQUAL' if e['equal'] else 'DIFFERENT'}  nodes {e['nodes']}")
    txt = "\n".join(lines)
    (HERE / "bdd_results.txt").write_text(txt + "\n")
    print(txt)


def blif_exprs(path):
    """Yosys BLIF (.names covers) -> dd expressions of the 4 outputs."""
    txt = Path(path).read_text().replace("\\\n", " ")
    defs, cur = {}, None
    for line in txt.splitlines():
        line = line.strip()
        if line.startswith(".names"):
            sig = line.split()[1:]
            cur = (sig[:-1], sig[-1], [])
            defs[sig[-1]] = cur
        elif cur is not None and line and not line.startswith("."):
            parts = line.split()
            if len(parts) == 2:
                cur[2].append((parts[0], parts[1]))
            elif len(parts) == 1:          # constant
                cur[2].append(("", parts[0]))
        elif line.startswith("."):
            cur = None if not line.startswith(".names") else cur
    memo = {}

    def expr(sig):
        if sig in VARS:
            return sig
        if sig in memo:
            return memo[sig]
        ins, _, rows = defs[sig]
        terms = []
        for cube, val in rows:
            lits = [(expr(i) if c == "1" else "!(" + expr(i) + ")") for i, c in zip(ins, cube) if c != "-"]
            terms.append("(" + (" & ".join(lits) if lits else "TRUE") + ")")
        e = " | ".join(terms) if terms else "FALSE"
        if rows and rows[0][1] == "0":
            e = "!(" + e + ")"
        memo[sig] = "(" + e + ")"
        return memo[sig]
    name = {"vs": "VS", "vp": "VP", "as_o": "AS", "ap": "AP"}
    return {name[k]: expr(k) for k in name}


if __name__ == "__main__":
    main()
