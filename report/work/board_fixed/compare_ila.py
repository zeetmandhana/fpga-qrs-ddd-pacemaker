"""compare_ila.py -- board test of the rebuilt bitstream (pacemaker fixes, 2026-11-20).

Summarises the seven ILA captures taken with the new bitstream (results/ila_fixed) next to the
captures taken with the old bitstream on 2026-11-11 (results/ila), writes the plots and
ila_summary.txt for the new captures, and board_fixed_comparison.txt here.
Run: .venv\\Scripts\\python report\\work\\board_fixed\\compare_ila.py
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import plot_ila_ecg as ila  # noqa: E402

OLD = os.path.join(ROOT, "results", "ila")
NEW = os.path.join(ROOT, "results", "ila_fixed")
TAGS = ["s1_mitbih_replay", "s2_normal_sinus", "s3_sinus_brady", "s4_av_block",
        "s5_av_block_brady", "s6_pmt_guard_off", "s6_pmt_guard_on"]

# plots + summary for the new captures
ila.ILA_DIR = NEW
ila.main()

keys = ("mode", "contiguous", "hr", "qrs", "ap", "vp", "as", "vs")
lines = ["Board test of the rebuilt bitstream (p17_soc_ila_fixed) vs the 2026-11-11 bitstream",
         "each capture = 8,192 consecutive 360 Hz samples (22.8 s) on the Zybo Z7-10", "",
         f"{'scenario':20s} | {'old: HR  QRS AP VP AS VS':28s} | {'new: HR  QRS AP VP AS VS':28s} | same?"]
all_ok = True
for t in TAGS:
    o = ila.summarize(ila.load(os.path.join(OLD, t + ".csv")))
    n = ila.summarize(ila.load(os.path.join(NEW, t + ".csv")))
    fmt = lambda s: f"{s['hr']:5.1f} {s['qrs']:3d} {s['ap']:2d} {s['vp']:2d} {s['as']:2d} {s['vs']:2d}"
    # captures start at a random point of the rhythm, so allow +-1 event per type and +-1 bpm
    same = (o["mode"] == n["mode"] and n["contiguous"] and abs(o["hr"] - n["hr"]) <= 1.0 and
            all(abs(o[k] - n[k]) <= 1 for k in ("qrs", "ap", "vp", "as", "vs")))
    all_ok &= same
    lines.append(f"{t:20s} | {fmt(o):28s} | {fmt(n):28s} | {'yes' if same else 'NO'}")
lines += ["", "RESULT: " + ("new bitstream behaves the same as the old one in all 7 scenarios"
                            if all_ok else "DIFFERENCE FOUND - check the captures")]
text = "\n".join(lines)
print(text)
open(os.path.join(HERE, "board_fixed_comparison.txt"), "w").write(text + "\n")
