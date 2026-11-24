"""
cex_to_stim.py -- turn a NuSMV counterexample (XML trace) into an xsim stimulus file.

Each NuSMV state = one clock cycle of rtl/ddd_pacemaker.v:
  inputs  : tick (-> tick_en), a (-> a_sense_in), v (-> v_sense_in)
  expected: registers phase/t_v/t_av BEFORE the edge, outputs AP/VP/AS/VS AFTER it.
A lasso (loop) is unrolled UNROLL extra times so the violation repeats on the RTL.

usage: python cex_to_stim.py cex/<name>.xml stim/<name>.txt [unroll]
"""
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

FIELDS = ["tick", "a", "v", "phase", "t_v", "t_av", "AP", "VP", "AS", "VS"]


def val(s):
    s = s.strip()
    if s in ("TRUE", "FALSE"):
        return 1 if s == "TRUE" else 0
    if s == "PH_AEI":
        return 0
    if s == "PH_AVI":
        return 1
    return int(s)


def parse(xml_path):
    root = ET.parse(xml_path).getroot()
    states = []
    for st in root.iter("state"):
        d = {v.get("variable"): val(v.text) for v in st.iter("value")}
        states.append(d)
    loops = root.find("loops")
    loop = int(loops.text.split()[0]) if loops is not None and loops.text.strip() else None
    return states, loop


def unrolled(states, loop, unroll):
    if loop is None:
        return states, None
    key = lambda d: tuple(d[f] for f in ("phase", "t_v", "t_av", "tick", "a", "v"))
    cyc_end = len(states) - 1 if key(states[-1]) == key(states[loop - 1]) else len(states)
    cycle = states[loop - 1:cyc_end]
    seq = states[:cyc_end] + cycle * unroll
    return seq, len(cycle)


def main():
    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    unroll = int(sys.argv[3]) if len(sys.argv) > 3 else 4
    states, loop = parse(src)
    seq, clen = unrolled(states, loop, unroll)
    dst.parent.mkdir(parents=True, exist_ok=True)
    with open(dst, "w") as fh:
        fh.write(f"{len(seq)}\n")
        for d in seq:
            fh.write(" ".join(str(d[f]) for f in FIELDS) + "\n")
    print(f"{src.name}: {len(states)} trace states, loop starts at state {loop}, "
          f"cycle length {clen}, {len(seq)} replay cycles -> {dst}")


if __name__ == "__main__":
    main()
