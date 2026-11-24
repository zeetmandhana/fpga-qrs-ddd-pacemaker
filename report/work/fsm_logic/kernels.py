"""
kernels.py -- VL401 report Sec. 5.4: algebraic kernels / co-kernels of the four
event-priority outputs (espresso SOP) by the recursive kernel algorithm, and the
literal count after extracting the best common kernels. Cross-check of the
professor's kit (SIS) output in results/stage6c_espresso_vl401_colab.txt.
"""
from __future__ import annotations

import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
VARS = ["p", "a", "v", "r", "m", "u", "e", "b"]
ESPRESSO = {"VS": ["--11----"],
            "VP": ["1-0-11--", "1--011--"],
            "AS": ["010----0", "01-0---0"],
            "AP": ["000---1-", "00-0--1-", "0-0---11", "0--0--11"]}
ORDER = [v + s for v in VARS for s in ("", "'")]       # literal order p p' a a' ...


def cube_lits(c):
    return frozenset(v if ch == "1" else v + "'" for v, ch in zip(VARS, c) if ch != "-")


def fmt(F):
    return " + ".join("".join(sorted(c, key=ORDER.index)) or "1" for c in F)


def cube_free(F):
    return len(F) > 1 and not frozenset.intersection(*F)


def kernels(F, start=0, co=frozenset()):
    """Return list of (kernel, co-kernel). F: list of literal sets."""
    out = []
    for i in range(start, len(ORDER)):
        lit = ORDER[i]
        S = [c for c in F if lit in c]
        if len(S) < 2:
            continue
        common = frozenset.intersection(*S)
        if any(ORDER.index(l) < i for l in common):
            continue                                     # found from an earlier literal
        Fk = [c - common for c in S]
        out += kernels(Fk, i + 1, co | common)
    if cube_free(F):
        out.append((F, co))
    return out


def level(K, memo=None):
    sub = [k for k, _ in kernels(K) if set(k) != set(K)]
    return 0 if not sub else 1 + max(level(k) for k in sub)


def main():
    res = {}
    total_sop = 0
    for name, cubes in ESPRESSO.items():
        F = [cube_lits(c) for c in cubes]
        total_sop += sum(len(c) for c in F)
        ks = kernels(F)
        res[name] = {"sop": fmt(F), "literals": sum(len(c) for c in F),
                     "kernels": [{"kernel": fmt(k), "co_kernel": "".join(sorted(co, key=ORDER.index)) or "1",
                                  "level": level(k)} for k, co in ks]}
    # extraction used for the literal count: t4 = r'+v' (common to VP, AS, AP), t5 = a'+b (AP)
    extracted = {"t4": "r' + v'", "t5": "a' + b", "VS": "r v", "VP": "t4 m p u",
                 "AS": "t4 a b' p'", "AP": "t4 t5 e p'"}
    lit_after = 2 + 2 + 2 + 4 + 4 + 4
    res["SUMMARY"] = {"literals_sop": total_sop, "after_common_kernel_extraction": lit_after,
                      "extracted_network": extracted,
                      "note": "t4 = r'+v' is algebraically a kernel; Boolean resubstitution sees t4 = VS' "
                              "and t5*p'*t4 = AS'-related, which SIS script.rugged uses to reach 14 literals"}
    with open(os.path.join(HERE, "kernels.json"), "w") as f:
        json.dump(res, f, indent=1)
    for name in ESPRESSO:
        print(name, res[name]["sop"], "(%d lits)" % res[name]["literals"])
        for k in res[name]["kernels"]:
            print("    kernel %-28s co-kernel %-6s level %d" % (k["kernel"], k["co_kernel"], k["level"]))
    print(res["SUMMARY"])


if __name__ == "__main__":
    main()
