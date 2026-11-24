r"""run_regression.py -- re-run every self-checking testbench and collect the verdicts.

A job passes only if the testbench prints its own PASS line, there is no FAIL / mismatch line,
no "Assertion failed" and no line starting with ERROR (compile or elaboration errors).
Run:  .venv\Scripts\python report\work\sim\run_regression.py   (writes regression_summary.txt)
The full-SoC testbench (rtl\run_top_sim.bat, ~1 h) is run separately.
"""
import os
import re
import subprocess
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
W = os.path.join(ROOT, "report", "work")
JOBS = [  # name, bat, regex of the testbench's own PASS line
    ("event_priority (256 vectors)", r"rtl\run_ev_sim.bat", r"EVENT_PRIORITY RTL == truth table : PASS"),
    ("DDD directed (3 x 6000 ticks)", r"rtl\run_sim.bat", r"RTL BIT-EXACT PASS"),
    ("closed loop (6 x 12000 ticks)", r"rtl\run_cl_sim.bat", r"CLOSED-LOOP BIT-EXACT PASS"),
    ("DDD constrained random + 19 SVA", r"report\work\sim\run_random.bat", r"RANDOM REGRESSION PASS"),
    ("DDD directed + closed loop + 19 SVA", r"report\work\sim\run_directed_sva.bat", r"CLOSED-LOOP BIT-EXACT PASS"),
    ("QRS detector (rec 100 + 208)", r"rtl\run_det_sim.bat", r"BIT-EXACT PASS: \d+ detections"),
    ("AXI4-Lite -> APB bridge", r"report\work\sim\run_bridge_sim.bat", r"AXI-APB BRIDGE PASS"),
    ("VGA timing", r"rtl\run_vga_sim.bat", r"VGA TIMING PASS"),
    ("baselines B0/B1 (100k samples)", r"report\work\paper\run_sim.bat", r"BASELINES BIT-EXACT PASS"),
    ("hand-HLS FSMDs (2 x 20k samples)", r"report\work\hand_hls\sim\run_sim.bat", r"BIT-EXACT PASS"),
]
os.makedirs(os.path.join(W, "sim", "logs"), exist_ok=True)
lines = []
for name, bat, pat in JOBS:
    t0 = time.time()
    p = subprocess.run(["cmd", "/c", os.path.join(ROOT, bat)], capture_output=True, text=True,
                       errors="replace", cwd=ROOT)
    out = p.stdout + p.stderr
    problems = []
    if not re.search(pat, out):
        problems.append("no PASS line")
    if re.search(r"Assertion failed", out):
        problems.append("assertion failed")
    if re.search(r"(?m)^ERROR", out):
        problems.append("ERROR in log")
    if re.search(r"(?i)\bFAIL\b", out):
        problems.append("FAIL in log")
    verdict = [l.strip() for l in out.splitlines() if re.search(pat, l)][-2:]
    status = "PASS" if not problems else "FAIL (" + ", ".join(problems) + ")"
    lines.append(f"{status:6s} {name:36s} {time.time() - t0:6.1f} s  | " + " / ".join(verdict))
    print(lines[-1], flush=True)
    with open(os.path.join(W, "sim", "logs", re.sub(r"\W+", "_", name) + ".log"), "w", encoding="utf-8") as fh:
        fh.write(out)
with open(os.path.join(W, "sim", "regression_summary.txt"), "w", encoding="utf-8") as fh:
    fh.write("\n".join(lines) + "\n")
