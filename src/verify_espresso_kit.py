"""
verify_espresso_kit.py  --  check the professor's-kit results for the event-priority block

The A2DSL Digital Logic Synthesis Kit (vl401.py + Berkeley espresso / SIS, run
on Google Colab -- see results/stage6c_espresso_vl401_colab.txt) produced:

  espresso (two-level, 9 products / 34 literals, confirmed exact):
      VS = vr
      VP = pv'mu + pr'mu
      AS = p'av'b' + p'ar'b'
      AP = p'a'v'e + p'a'r'e + p'v'eb + p'r'eb
  SIS script.rugged (multi-level, 14 literals):
      VS = rv,  VP = VS' mpu,  AS = VS' ab'p',  AP = VS' AS' ep'

This script checks both against the golden decision function
(src/event_priority.decide, itself verified against pacemaker.py) for all
2^8 = 256 input combinations, and parses the espresso PLA cover rows exactly
as printed by the kit.

Run:  python src/verify_espresso_kit.py
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from event_priority import decide  # noqa: E402

INPUTS = "p a v r m u e b".split()
OUTPUTS = ["VS", "VP", "AS", "AP"]

# espresso cover exactly as printed by vl401.py twolevel (STEP 2)
ESPRESSO_PLA = [
    ("1--011--", "0100"), ("01-0---0", "0010"), ("1-0-11--", "0100"),
    ("00-0--1-", "0001"), ("010----0", "0010"), ("0-0---11", "0001"),
    ("--11----", "1000"), ("000---1-", "0001"), ("0--0--11", "0001"),
]


def eval_pla(bits: list[int]) -> tuple[int, int, int, int]:
    out = [0, 0, 0, 0]
    for cube, outs in ESPRESSO_PLA:
        if all(c == "-" or int(c) == x for c, x in zip(cube, bits)):
            for k, o in enumerate(outs):
                if o == "1":
                    out[k] = 1
    return tuple(out)


def espresso_eqs(p, a, v, r, m, u, e, b):
    n = lambda x: 1 - x
    vs = v & r
    vp = (p & n(v) & m & u) | (p & n(r) & m & u)
    as_ = (n(p) & a & n(v) & n(b)) | (n(p) & a & n(r) & n(b))
    ap = (n(p) & n(a) & n(v) & e) | (n(p) & n(a) & n(r) & e) | \
         (n(p) & n(v) & e & b) | (n(p) & n(r) & e & b)
    return vs, vp, as_, ap


def rugged_eqs(p, a, v, r, m, u, e, b):
    n = lambda x: 1 - x
    vs = r & v
    vp = n(vs) & m & p & u
    as_ = n(vs) & a & n(b) & n(p)
    ap = n(vs) & n(as_) & e & n(p)
    return vs, vp, as_, ap


def main() -> int:
    bad = {"pla": 0, "sop": 0, "rugged": 0}
    for i in range(256):
        bits = [(i >> (7 - k)) & 1 for k in range(8)]
        ref = tuple(int(x) for x in decide(*bits))
        bad["pla"] += eval_pla(bits) != ref
        bad["sop"] += espresso_eqs(*bits) != ref
        bad["rugged"] += rugged_eqs(*bits) != ref
    lits = sum(sum(c != "-" for c in cube) for cube, _ in ESPRESSO_PLA)
    print(f"espresso cover: {len(ESPRESSO_PLA)} products, {lits} literals")
    for k, v in bad.items():
        print(f"  {k:7s} vs golden decide(): {256 - v}/256 match, {v} mismatches")
    ok = all(v == 0 for v in bad.values())
    print("PASS: professor-kit espresso and SIS results == golden event-priority logic"
          if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
