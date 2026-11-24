"""
twolevel_qm.py -- VL401 report Sec. 5.3: our own Quine-McCluskey / unate
covering result for the event-priority block, compared with ESPRESSO from the
professor's kit (results/stage6c_espresso_vl401_colab.txt).

Prime implicants come from the project's own QM code (src/event_priority.py,
imported, not modified). The covering table is then reduced step by step
(essential primes, row dominance, column dominance) and the remaining cyclic
core, if any, is solved exactly by branch and bound (qm.py).
"""
from __future__ import annotations

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "src"))
import event_priority as ep                      # noqa: E402
from qm import cube_minterms, exact_cover, lits, reduce_table   # noqa: E402

# espresso result from the professor's kit (inputs p a v r m u e b)
ESPRESSO = {"VS": ["--11----"],
            "VP": ["1-0-11--", "1--011--"],
            "AS": ["010----0", "01-0---0"],
            "AP": ["000---1-", "00-0--1-", "0-0---11", "0--0--11"]}


def main():
    res = {}
    tot_c = tot_l = 0
    for oi, name in enumerate(ep.OUTPUTS):
        on = frozenset(ep.minterms(oi))
        pis = sorted(ep.prime_implicants(on))
        cols = {p: set(cube_minterms(p) & on) for p in pis}
        rows = {m: {p for p in pis if m in cols[p]} for m in on}
        ess = sorted({next(iter(c)) for m, c in rows.items() if len(c) == 1})
        # table after removing only the essential primes
        rem_rows = {m: c for m, c in rows.items() if not any(m in cols[e] for e in ess)}
        rem_cols = {p for c in rem_rows.values() for p in c}
        log = []
        chosen, core_rows, core_cols = reduce_table(rows, cols, log)
        core_cols = {c: r for c, r in core_cols.items() if r}
        rest, cost = exact_cover(core_rows, core_cols) if core_rows else ([], (0, 0))
        cover = sorted(chosen + rest)
        same = sorted(cover) == sorted(ESPRESSO[name])
        tot_c += len(cover)
        tot_l += sum(lits(c) for c in cover)
        res[name] = {
            "on_minterms": len(on), "prime_implicants": len(pis), "primes": pis,
            "essential_primes": ess,
            "table_initial(rows x cols)": [len(rows), len(pis)],
            "table_after_essentials(rows x cols)": [len(rem_rows), len(rem_cols)],
            "reduction_log": log,
            "cyclic_core(rows x cols)": [len(core_rows), len(core_cols)],
            "cyclic_core_cols": sorted(core_cols),
            "branch_and_bound_picks": rest,
            "minimum_cover": cover, "products": len(cover),
            "literals": sum(lits(c) for c in cover), "sop": ep.sop_to_str(cover),
            "equals_espresso": same,
            "project_greedy_minimise": ep.minimise(set(on)),
        }
    res["TOTAL"] = {"products": tot_c, "literals": tot_l,
                    "espresso_products": sum(len(v) for v in ESPRESSO.values()),
                    "espresso_literals": sum(lits(c) for v in ESPRESSO.values() for c in v)}
    with open(os.path.join(HERE, "twolevel_qm.json"), "w") as f:
        json.dump(res, f, indent=1)
    for name in ep.OUTPUTS:
        r = res[name]
        print("%s: ON=%d PIs=%d ess=%s table %s -> after ess %s -> core %s | cover %d cubes %d lits | ==espresso %s"
              % (name, r["on_minterms"], r["prime_implicants"], r["essential_primes"], r["table_initial(rows x cols)"],
                 r["table_after_essentials(rows x cols)"], r["cyclic_core(rows x cols)"], r["products"], r["literals"],
                 r["equals_espresso"]))
        print("    PIs:", r["primes"], " log:", r["reduction_log"], " B&B:", r["branch_and_bound_picks"])
    print("TOTAL", res["TOTAL"])


if __name__ == "__main__":
    main()
