"""
reach_bdd.py -- symbolic reachability of the NuSMV pacemaker models with BDDs (dd).

The state is bit-encoded exactly like the NuSMV model (phase 1 bit, t_v 4 bits
0..11, t_av 4 bits 0..10, [armed], tick, [a, v]). The transition relation
T(x, x') is built as a BDD from the model's next-state function (for every
in-range current state and input, the next register values; next-state inputs
are left free). Reachability is the image fixpoint
    R_0 = Init,   R_{k+1} = R_k  OR  (EXISTS x . R_k(x) AND T(x,x'))[x' -> x]
and |R| is counted with bdd.count. The count and the number of iterations are
compared with NuSMV's print_reachable_states / system diameter.
"""
import itertools
import json
import re
from pathlib import Path

from dd.autoref import BDD

HERE = Path(__file__).resolve().parent
LRI, AVI, URI, PVARP, VRP, VA = 10, 2, 5, 4, 3, 3
AEI = LRI - AVI


def step(env, pvarp_on, vrp_on, ph, t_v, t_av, armed, tick, a, v):
    """next (phase, t_v, t_av, armed) -- identical to gen_smv.py / rtl/ddd_pacemaker.v"""
    tv = min(t_v + 1, LRI + 1)
    tav = min(t_av + 1, 10) if ph == 1 else 0
    if env == "pmt":
        v = False
        a = tick and armed and tv == VA
    VS = tick and v and (not vrp_on or tv >= VRP)
    VP = tick and not VS and ph == 1 and tav >= AVI and tv >= URI
    bl = pvarp_on and tv < PVARP
    AS = tick and not VS and not VP and ph == 0 and a and not bl
    AP = tick and not VS and not VP and ph == 0 and not AS and tv >= AEI
    if not tick:
        return ph, t_v, t_av, armed
    nph = 0 if (VS or VP) else (1 if (AS or AP) else ph)
    ntv = 0 if (VS or VP) else tv
    ntav = 0 if (VS or VP or AS or AP) else tav
    narm = True if (VS or VP) else (False if a else armed)
    return nph, ntv, ntav, narm


def run(name, env, pvarp_on=True, vrp_on=True):
    regs = ["ph"] + [f"tv{i}" for i in range(4)] + [f"ta{i}" for i in range(4)]
    if env == "pmt":
        regs += ["arm"]
        ins = ["tick"]
    else:
        ins = ["tick", "a", "v"]
    x = regs + ins
    xp = [s + "_n" for s in x]
    bdd = BDD()
    # interleave current/next bits (usual good order for transition relations)
    bdd.declare(*[w for pair in zip(x, xp) for w in pair])

    def enc(vals):
        ph, t_v, t_av, arm, ivals = vals
        d = {"ph": bool(ph)}
        d.update({f"tv{i}": bool((t_v >> i) & 1) for i in range(4)})
        d.update({f"ta{i}": bool((t_av >> i) & 1) for i in range(4)})
        if env == "pmt":
            d["arm"] = bool(arm)
        d.update({k: bool(b) for k, b in zip(ins, ivals)})
        return d

    T = bdd.false
    arms = (False, True) if env == "pmt" else (False,)
    for ph, t_v, t_av, arm in itertools.product((0, 1), range(12), range(11), arms):
        for ivals in itertools.product((False, True), repeat=len(ins)):
            tick = ivals[0]
            a = ivals[1] if env == "oa" else False
            v = ivals[2] if env == "oa" else False
            nph, ntv, ntav, narm = step(env, pvarp_on, vrp_on, ph, t_v, t_av, arm, tick, a, v)
            cur = bdd.cube(enc((ph, t_v, t_av, arm, ivals)))
            nxt = {"ph_n": bool(nph)}
            nxt.update({f"tv{i}_n": bool((ntv >> i) & 1) for i in range(4)})
            nxt.update({f"ta{i}_n": bool((ntav >> i) & 1) for i in range(4)})
            if env == "pmt":
                nxt["arm_n"] = bool(narm)
            T = T | (cur & bdd.cube(nxt))
    init = {"ph": False, "ta0": False, "ta1": False, "ta2": False, "ta3": False}
    init.update({f"tv{i}": bool((LRI >> i) & 1) for i in range(4)})
    if env == "pmt":
        init["arm"] = False
    R = bdd.cube(init)
    ren = dict(zip(xp, x))
    k = 0
    sizes = []
    while True:
        img = bdd.exist(x, R & T)
        img = bdd.let(ren, img)
        Rn = R | img
        sizes.append(bdd.count(Rn, nvars=len(x)))
        if Rn == R:
            break
        R = Rn
        k += 1
    count = int(bdd.count(R, nvars=len(x)))
    return {"model": name, "reachable": count, "iterations": k,
            "T_nodes": T.dag_size, "R_nodes": R.dag_size, "state_bits": len(x)}


def nusmv(model):
    log = (HERE / f"nusmv_{model}.log").read_text()
    m = re.search(r"reachable states: (\d+)", log)
    d = re.search(r"system diameter: (\d+)", log)
    return int(m.group(1)), int(d.group(1))


def main():
    rows = []
    for model, env, pv, vr in (("ddd_oa", "oa", True, True), ("ddd_pmt", "pmt", True, True),
                               ("ddd_pmt_bug1", "pmt", False, True), ("ddd_oa_bug1", "oa", False, True),
                               ("ddd_oa_bug2", "oa", True, False)):
        r = run(model, env, pv, vr)
        n, dia = nusmv(model)
        r["nusmv_reachable"], r["nusmv_diameter"] = n, dia
        r["match"] = (n == r["reachable"])
        rows.append(r)
        print(f"{model:14s} dd: {r['reachable']:4d} states in {r['iterations']:2d} image steps "
              f"(T {r['T_nodes']} nodes, R {r['R_nodes']} nodes) | NuSMV: {n} states, diameter {dia} "
              f"-> {'MATCH' if r['match'] else 'DIFFERENT'}")
    (HERE / "reach_results.json").write_text(json.dumps(rows, indent=1))


if __name__ == "__main__":
    main()
