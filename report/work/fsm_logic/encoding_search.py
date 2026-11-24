"""
encoding_search.py -- VL401 report Sec. 5.2: two-level cost of every 3-bit
encoding of the 8-phase qrs_decision controller (qrs_decision_ctrl.kiss2).

Cost = literals of the exact minimum SOP of the 3 next-state bits + 8 outputs,
each minimised separately with qm.py (all 8 codes are used, so there are no
unused-code don't-cares). IDLE is fixed to 000: complementing a code bit only
flips literal polarities, so this loses nothing. Also scores the adjacency
(MUSTANG-style) idea: pairs of states with a common next state or a common
predecessor should get codes at Hamming distance 1.
Writes encoding_search.json and prints the table.
"""
from __future__ import annotations

import itertools
import json
import os

from qm import minimise

HERE = os.path.dirname(os.path.abspath(__file__))
ST = ["IDL", "TRK", "CLS", "REG", "AVG", "LIM", "SBK", "END"]
OUTS = ["ld", "trk", "cls", "rg", "avg", "lim", "sbk", "cnt"]


def ctrl(state, i, f, s):
    """qrs_decision.v phase transitions; returns (next, outputs)."""
    o = dict.fromkeys(OUTS, 0)
    if state == "IDL":
        o["ld"] = i
        return ("TRK" if i else "IDL"), o
    nxt = {"TRK": "CLS", "CLS": "REG", "REG": "AVG", "AVG": "LIM", "END": "IDL"}
    key = {"TRK": "trk", "CLS": "cls", "REG": "rg", "AVG": "avg", "LIM": "lim", "SBK": "sbk", "END": "cnt"}
    o[key[state]] = 1
    if state == "LIM":
        return ("END" if f else "SBK"), o
    if state == "SBK":
        return ("REG" if s else "END"), o
    return nxt[state], o


def cost(codes):
    """codes: state -> int (3 bits). Returns (next-state literals, output literals, covers)."""
    on = {k: set() for k in ["n2", "n1", "n0"] + OUTS}
    for st in ST:
        for i, f, s in itertools.product((0, 1), repeat=3):
            m = (codes[st] << 3) | (i << 2) | (f << 1) | s
            ns, o = ctrl(st, i, f, s)
            for b, name in zip((2, 1, 0), ("n2", "n1", "n0")):
                if (codes[ns] >> b) & 1:
                    on[name].add(m)
            for k in OUTS:
                if o[k]:
                    on[k].add(m)
    res = {k: minimise(frozenset(v), frozenset(), 6) for k, v in on.items()}
    ns_l = sum(res[k][1] for k in ("n2", "n1", "n0"))
    out_l = sum(res[k][1] for k in OUTS)
    return ns_l, out_l, {k: list(v[0]) for k, v in res.items()}


def hd(a, b):
    return bin(a ^ b).count("1")


def adjacency_score(codes):
    """MUSTANG-like fan-in/fan-out pairs that are adjacent (distance 1)."""
    pairs = set()
    succ = {st: set() for st in ST}
    pred = {st: set() for st in ST}
    for st in ST:
        for i, f, s in itertools.product((0, 1), repeat=3):
            ns, _ = ctrl(st, i, f, s)
            succ[st].add(ns)
            pred[ns].add(st)
    for a, b in itertools.combinations(ST, 2):
        w = len(succ[a] & succ[b]) + len(pred[a] & pred[b])
        if w:
            pairs.add((a, b, w))
    return sum(w for a, b, w in pairs if hd(codes[a], codes[b]) == 1), sorted(pairs)


def main():
    named = {
        "binary (as written, P_IDLE=0..P_END=7)": dict(zip(ST, range(8))),
        "Gray chain (IDL TRK CLS REG AVG LIM SBK END)": dict(zip(ST, [0, 1, 3, 2, 6, 7, 5, 4])),
    }
    results = []
    for perm in itertools.permutations(range(1, 8)):
        codes = dict(zip(ST, (0,) + perm))
        nl, ol, _ = cost(codes)
        results.append((nl + ol, nl, perm))
    results.sort()
    best_total, best_ns, best_perm = results[0]
    worst_total, worst_ns, worst_perm = results[-1]
    best_codes = dict(zip(ST, (0,) + best_perm))
    named["exhaustive minimum (custom)"] = best_codes
    named["exhaustive maximum (worst)"] = dict(zip(ST, (0,) + worst_perm))
    n_best = sum(1 for r in results if r[0] == best_total)
    table = []
    for name, codes in named.items():
        nl, ol, covers = cost(codes)
        adj, pairs = adjacency_score(codes)
        table.append({"encoding": name, "codes": {k: format(v, "03b") for k, v in codes.items()},
                      "next_state_literals": nl, "output_literals": ol, "total": nl + ol,
                      "adjacency_weight_satisfied": adj, "next_state_cover": {k: covers[k] for k in ("n2", "n1", "n0")}})
    out = {"assignments_tried": len(results), "best_total": best_total, "worst_total": worst_total,
           "n_assignments_reaching_best": n_best,
           "histogram_total": {str(k): sum(1 for r in results if r[0] == k) for k in sorted({r[0] for r in results})},
           "adjacency_pairs(a,b,weight)": adjacency_score(best_codes)[1], "table": table}
    with open(os.path.join(HERE, "encoding_search.json"), "w") as f:
        json.dump(out, f, indent=1)
    print("tried", len(results), "best", best_total, "(", n_best, "assignments)", "worst", worst_total)
    for t in table:
        print("%-46s NS=%2d OUT=%2d total=%2d adj=%d %s" % (t["encoding"], t["next_state_literals"],
              t["output_literals"], t["total"], t["adjacency_weight_satisfied"], t["codes"]))
        print("      next-state cover:", t["next_state_cover"])


if __name__ == "__main__":
    main()
