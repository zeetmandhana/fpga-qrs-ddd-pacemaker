"""
gen_random_vectors.py  --  constrained-random stimulus + golden outputs for the DDD RTL

For each of N_SETS parameter sets (random, LEGAL per DDDParameters.validate,
biased towards range corners) it drives the Python golden controller with
random lead inputs and records, per 1 ms tick:
    a_in v_in | AS VS AP VP ARR
ARR = upper-rate flag the RTL raises (V event with t_v <= URI).
It also counts functional-coverage bins from the golden model's internal state.

Output: rand_vectors.txt  (blocks: "P lri avi uri pvarp vrp nticks" + rows)
        func_coverage.json
"""

from __future__ import annotations

import json
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "src"))
from pacemaker import DDDParameters, DDDPacemaker   # noqa: E402

N_SETS = 60
TICKS = 5000
SEED = 17


def pick(rng, lo, hi):
    r = rng.random()
    if r < 0.2:
        return lo
    if r < 0.4:
        return hi
    return rng.randint(lo, hi)


def random_params(rng):
    while True:
        lri = pick(rng, 400, 2000)
        avi = pick(rng, 30, min(350, lri - 1))
        uri = pick(rng, max(300, avi), lri)
        pvarp = pick(rng, 150, 500)
        vrp = pick(rng, 150, 400)
        p = DDDParameters(lri, avi, uri, pvarp, vrp)
        try:
            p.validate()
            return p
        except ValueError:
            continue


def main() -> None:
    rng = random.Random(SEED)
    bins = {k: 0 for k in (
        "AS", "VS", "AP", "VP", "ARR",
        "a_in_ignored_in_PVARP", "v_in_ignored_in_VRP", "a_in_ignored_in_AVI_phase",
        "VP_held_by_URI", "VP_at_AVI", "AS_then_VP", "AP_then_VS", "a_and_v_same_tick",
        "param_lri_min", "param_lri_max", "param_avi_min", "param_avi_max",
        "param_uri_eq_lri", "param_pvarp_gt_aei", "param_vrp_max")}
    lines = []
    total = 0
    for s in range(N_SETS):
        p = random_params(rng)
        bins["param_lri_min"] += p.lri_ms == 400
        bins["param_lri_max"] += p.lri_ms == 2000
        bins["param_avi_min"] += p.avi_ms == 30
        bins["param_avi_max"] += p.avi_ms == 350
        bins["param_uri_eq_lri"] += p.uri_ms == p.lri_ms
        bins["param_pvarp_gt_aei"] += p.pvarp_ms > p.aei_ms
        bins["param_vrp_max"] += p.vrp_ms == 400
        pm = DDDPacemaker(p)
        pa = rng.choice([0.0, 0.0005, 0.002, 0.006, 0.02])
        pv = rng.choice([0.0, 0.0005, 0.002, 0.006, 0.02])
        lines.append(f"P {p.lri_ms} {p.avi_ms} {p.uri_ms} {p.pvarp_ms} {p.vrp_ms} {TICKS}")
        last_atr = None
        for _ in range(TICKS):
            a = rng.random() < pa
            v = rng.random() < pv
            if rng.random() < 0.002:          # force simultaneous A and V activity
                a = v = True
            tv = pm.t_v + 1                    # value the step will compare
            phase = pm.phase
            tav = pm.t_av + (1 if phase == pm.AVI else 0)
            o = pm.step(a, v)
            arr = int((o.v_sense or o.v_pace) and tv <= p.uri_ms)
            # functional coverage
            bins["a_and_v_same_tick"] += a and v
            if a and phase == pm.AEI and tv < p.pvarp_ms and not o.v_sense:
                bins["a_in_ignored_in_PVARP"] += 1
            if a and phase == pm.AVI and not o.v_sense:
                bins["a_in_ignored_in_AVI_phase"] += 1
            if v and tv < p.vrp_ms:
                bins["v_in_ignored_in_VRP"] += 1
            if phase == pm.AVI and tav >= p.avi_ms and tv < p.uri_ms and not o.v_sense:
                bins["VP_held_by_URI"] += 1
            if o.v_pace and tav == p.avi_ms:
                bins["VP_at_AVI"] += 1
            if o.a_sense or o.a_pace:
                last_atr = "AS" if o.a_sense else "AP"
            if o.v_pace and last_atr == "AS":
                bins["AS_then_VP"] += 1
            if o.v_sense and last_atr == "AP":
                bins["AP_then_VS"] += 1
            if o.v_sense or o.v_pace:
                last_atr = None
            for k, val in (("AS", o.a_sense), ("VS", o.v_sense), ("AP", o.a_pace),
                           ("VP", o.v_pace), ("ARR", arr)):
                bins[k] += int(val)
            lines.append(f"{int(a)} {int(v)} {int(o.a_sense)} {int(o.v_sense)} "
                         f"{int(o.a_pace)} {int(o.v_pace)} {arr}")
        total += TICKS
    with open(os.path.join(HERE, "rand_vectors.txt"), "w") as fh:
        fh.write(f"{N_SETS}\n" + "\n".join(lines) + "\n")
    with open(os.path.join(HERE, "func_coverage.json"), "w") as fh:
        json.dump({"sets": N_SETS, "ticks": total, "bins": bins}, fh, indent=2)
    print(f"{N_SETS} parameter sets x {TICKS} ticks = {total} ticks")
    for k, v in bins.items():
        print(f"  {k:28s} {v}")


if __name__ == "__main__":
    main()
