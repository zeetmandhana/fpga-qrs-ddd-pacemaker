"""
gen_ev_truth.py  --  P17 Phase 6: truth table for the event-priority RTL check.
Writes all 256 rows "p a v r m u e b  vs vp as ap" from src/event_priority.py
(verified == pacemaker.py) for tb_event_priority.v to compare against.
"""
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.dirname(_HERE)
sys.path.insert(0, os.path.join(_ROOT, "src"))

from event_priority import N, assignment, decide          # noqa: E402

os.makedirs(os.path.join(_HERE, "tb_data"), exist_ok=True)
out = os.path.join(_HERE, "tb_data", "ev_truth.txt")
with open(out, "w") as fh:
    for idx in range(1 << N):
        bits = assignment(idx)
        outs = decide(*bits)
        fh.write(" ".join(map(str, bits)) + " " + " ".join(map(str, outs)) + "\n")
print(f"Wrote {1 << N} rows to {out}")
