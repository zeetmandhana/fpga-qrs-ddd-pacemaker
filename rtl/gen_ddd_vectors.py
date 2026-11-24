"""
gen_ddd_vectors.py  --  P17 Phase 6: golden vectors for the DDD pacemaker RTL

Runs the Phase-3 Python controller (pacemaker.DDDPacemaker) in closed loop with
the heart model and records, for every 1 ms tick, the raw lead inputs and the
device outputs:

    a_in v_in  as vs ap vp

The Verilog testbench (tb_ddd_pacemaker.v) replays a_in/v_in into the RTL DUT
and checks that as/vs/ap/vp match bit-for-bit -- so the hardware controller is
proven equal to the verified software golden model.

Run (venv active, from project root):  python rtl/gen_ddd_vectors.py
"""

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.dirname(_HERE)
sys.path.insert(0, os.path.join(_ROOT, "src"))

from heart_model import SCENARIOS, HeartModel          # noqa: E402
from pacemaker import DDDParameters, DDDPacemaker       # noqa: E402

OUT = os.path.join(_HERE, "tb_data")
DURATION_MS = 6000
SCENARIOS_TO_EXPORT = ["normal", "block", "dual"]       # cover VS, AS, VP, AP


def record(scenario: str, params: DDDParameters, duration_ms: int):
    pm = DDDPacemaker(params, enforce_pvarp=True)
    heart = HeartModel(SCENARIOS[scenario])
    rows = []
    for tick in range(duration_ms):
        a_in, v_in = heart.intrinsic(tick)
        out = pm.step(a_in, v_in)
        rows.append((int(a_in), int(v_in),
                     int(out.a_sense), int(out.v_sense),
                     int(out.a_pace), int(out.v_pace)))
        atrial_act = a_in or out.a_pace
        vent_act = v_in or out.v_pace
        heart.update(tick, atrial_act, vent_act)
    return rows


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    params = DDDParameters()
    params.validate()
    # one line of params for the testbench to program over APB
    with open(os.path.join(OUT, "ddd_params.txt"), "w") as fh:
        fh.write(f"{params.lri_ms} {params.avi_ms} {params.uri_ms} "
                 f"{params.pvarp_ms} {params.vrp_ms}\n")

    for sc in SCENARIOS_TO_EXPORT:
        rows = record(sc, params, DURATION_MS)
        path = os.path.join(OUT, f"ddd_{sc}.txt")
        with open(path, "w") as fh:
            fh.write(f"{len(rows)}\n")
            for r in rows:
                fh.write(" ".join(str(x) for x in r) + "\n")
        n_ap = sum(r[4] for r in rows)
        n_vp = sum(r[5] for r in rows)
        n_as = sum(r[2] for r in rows)
        n_vs = sum(r[3] for r in rows)
        print(f"  {sc:7}: {len(rows)} ticks  AS={n_as} VS={n_vs} AP={n_ap} VP={n_vp}")

    print(f"\nParams: LRI={params.lri_ms} AVI={params.avi_ms} URI={params.uri_ms} "
          f"PVARP={params.pvarp_ms} VRP={params.vrp_ms}")
    print(f"Wrote vectors to {OUT}")


if __name__ == "__main__":
    main()
