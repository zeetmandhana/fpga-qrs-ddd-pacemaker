"""
gen_closed_loop_vectors.py  --  golden vectors for the HARDWARE closed loop

Runs the Python closed loop (heart_model.HeartModel + pacemaker.DDDPacemaker,
exactly as pacemaker_sim.run_closed_loop) and records per 1 ms tick:

    a_in v_in as vs ap vp

tb_closed_loop.v runs rtl/heart_model.v + rtl/ddd_pacemaker_apb.v in a closed
loop on its own (no replayed inputs) and checks every tick against this file.
The PMT scenario is exported twice: PVARP 250 ms (< 280 ms retrograde VA time
-> pacemaker-mediated tachycardia) and the safe default 320 ms.

Run (venv active, project root):  python rtl/gen_closed_loop_vectors.py
"""

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(_HERE), "src"))

from heart_model import SCENARIOS, HeartModel          # noqa: E402
from pacemaker import DDDParameters, DDDPacemaker       # noqa: E402

OUT = os.path.join(_HERE, "tb_data")
DURATION_MS = 12000
# (file tag, scenario name, scen code used by heart_model.v, PVARP)
CASES = [("normal", "normal", 1, 320), ("brady", "brady", 2, 320),
         ("block", "block", 3, 320), ("dual", "dual", 4, 320),
         ("pmt250", "pmt", 5, 250), ("pmt320", "pmt", 5, 320)]


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for tag, sc, code, pvarp in CASES:
        p = DDDParameters(pvarp_ms=pvarp)
        p.validate()
        pm = DDDPacemaker(p, enforce_pvarp=True)
        heart = HeartModel(SCENARIOS[sc])
        rows = []
        for tick in range(DURATION_MS):
            a_in, v_in = heart.intrinsic(tick)
            out = pm.step(a_in, v_in)
            rows.append((int(a_in), int(v_in), int(out.a_sense), int(out.v_sense),
                         int(out.a_pace), int(out.v_pace)))
            heart.update(tick, a_in or out.a_pace, v_in or out.v_pace)
        with open(os.path.join(OUT, f"cl_{tag}.txt"), "w") as fh:
            fh.write(f"{p.lri_ms} {p.avi_ms} {p.uri_ms} {p.pvarp_ms} {p.vrp_ms} {code}\n")
            fh.write(f"{len(rows)}\n")
            for r in rows:
                fh.write(" ".join(str(x) for x in r) + "\n")
        s = [sum(r[k] for r in rows) for k in range(6)]
        print(f"{tag:7}: {DURATION_MS} ticks  A_in={s[0]} V_in={s[1]} "
              f"AS={s[2]} VS={s[3]} AP={s[4]} VP={s[5]}")


if __name__ == "__main__":
    main()
