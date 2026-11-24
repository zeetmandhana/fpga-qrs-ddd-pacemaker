"""
analyze.py -- turns the two simulations into the HW/SW comparison numbers.

Inputs
  sw_sim/sw_dump.txt  mailbox words written by fw/hwsw_bench.c on the NEORV32
  golden_filter.txt   hp dv mwi per sample   (gen_vectors.py, bit-exact models)
  golden_events.txt   n r sb per detection
  run_hw_sim.log      HWCYC lines from tb_hw_cycles.v (HLS + RTL decision)
Output
  results.json and a printed summary (used for RESULTS.md)

Run:  ../../../.venv/Scripts/python analyze.py
"""
import json
import os
import re

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
F_CLK = 25e6          # board clock
FS = 360              # ECG samples per second
LEARN = 720

words = [int(l, 16) for l in open(os.path.join(HERE, "sw_sim", "sw_dump.txt")) if l.strip()]
pos = 0
calib = []
for k in range(4):
    tag, c, i = words[pos:pos + 3]
    assert tag == 0xCA11B000 | k, hex(tag)
    calib.append((c, i)); pos += 3
apb = []
for k in range(4):
    tag, c, i, v = words[pos:pos + 4]
    assert tag == 0xA9B00000 | k, hex(tag)
    apb.append((c, i, v)); pos += 4
rec = np.array(words[pos:], dtype=np.uint64).reshape(-1, 9)
ns = rec.shape[0]


def s32(a):
    a = np.asarray(a, dtype=np.int64)
    return np.where(a >= 1 << 31, a - (1 << 32), a)


hp = s32(rec[:, 0]); dv = s32(rec[:, 1])
mwi = (rec[:, 2].astype(np.int64)) | (rec[:, 3].astype(np.int64) << 32)
detw = rec[:, 4].astype(np.int64)
cyc_f = rec[:, 5].astype(np.int64); cyc_d = rec[:, 6].astype(np.int64)
ins_f = rec[:, 7].astype(np.int64); ins_d = rec[:, 8].astype(np.int64)

# ---- correctness vs the golden (bit-exact) models ----
g = np.loadtxt(os.path.join(HERE, "golden_filter.txt"), dtype=np.int64)[:ns]
filt_ok = bool(np.array_equal(hp, g[:, 0]) and np.array_equal(dv, g[:, 1]) and np.array_equal(mwi, g[:, 2]))
filt_mism = int(np.sum((hp != g[:, 0]) | (dv != g[:, 1]) | (mwi != g[:, 2])))
ge = [tuple(int(x) for x in l.split()) for l in open(os.path.join(HERE, "golden_events.txt")) if l.strip()]
sw_ev = [(int(n), int(w >> 1), int(w & 1)) for n, w in enumerate(detw) if w != 0xFFFFFFFF]
det_ok = sw_ev == [e for e in ge if e[0] < ns]

# ---- cycle statistics ----
oc = int(np.median([c for c, _ in calib])); oi = int(np.median([i for _, i in calib]))
f = cyc_f - oc; d = cyc_d - oc; t = f + d
fi = ins_f - oi; di = ins_d - oi
apb_c = int(np.median([c for c, _, _ in apb])) - oc
apb_i = int(np.median([i for _, i, _ in apb])) - oi
apb_val_ok = all(v == 0x50170001 for _, _, v in apb)
det_idx = np.array([e[0] for e in sw_ev], dtype=np.int64)
post = np.arange(ns) >= LEARN


def st(a):
    a = np.asarray(a)
    return {"mean": float(a.mean()), "min": int(a.min()), "max": int(a.max())}


# ---- hardware (tb_hw_cycles.v) ----
hw = {}
for line in open(os.path.join(HERE, "run_hw_sim.log"), errors="ignore"):
    m = re.match(r"HWCYC (\S+)\s+(.*)", line.strip())
    if not m:
        continue
    kv = dict(re.findall(r"(\w+)=([\d.]+)", m.group(2)))
    hw[m.group(1)] = {k: float(v) for k, v in kv.items()}

hw_f = hw["filter_accept_to_decvalid"]; hw_d = hw["decision_decvalid_to_idle"]; hw_t = hw["total_accept_to_idle"]

sw = {"filter": st(f), "decision": st(d), "total": st(t),
      "decision_learning": st(d[~post]), "decision_after_learning": st(d[post]),
      "decision_on_detect_samples": st(d[det_idx]) if det_idx.size else None,
      "instr_filter": st(fi), "instr_decision": st(di), "instr_total": st(fi + di),
      "cpi_filter": float(f.sum() / fi.sum()), "cpi_decision": float(d.sum() / di.sum()),
      "cpi_total": float(t.sum() / (fi + di).sum())}

T_sw = sw["total"]["mean"]; T_hw = hw_t["mean"]; T_bus = apb_c
out = {
    "samples": ns, "overhead_cycles": oc, "overhead_instr": oi,
    "sw": sw, "apb_read_cycles": apb_c, "apb_read_instr": apb_i, "apb_value_ok": apb_val_ok,
    "correct_filter": filt_ok, "filter_mismatches": filt_mism,
    "correct_detections": det_ok, "sw_events": sw_ev, "golden_events": [e for e in ge if e[0] < ns],
    "hw": hw,
    "speedup": {
        "filter_mean": sw["filter"]["mean"] / hw_f["mean"],
        "decision_mean": sw["decision"]["mean"] / hw_d["mean"],
        "total_mean": T_sw / T_hw,
        "total_worst": sw["total"]["max"] / hw_t["max"],
    },
    "time_us_at_25MHz": {"sw_total_mean": T_sw / F_CLK * 1e6, "sw_total_max": sw["total"]["max"] / F_CLK * 1e6,
                         "hw_total_mean": T_hw / F_CLK * 1e6, "apb_read": T_bus / F_CLK * 1e6},
    "cpu_load_pct_at_360Hz": {"sw_only_mean": T_sw * FS / F_CLK * 100,
                              "sw_only_worst": sw["total"]["max"] * FS / F_CLK * 100,
                              "hw_one_apb_read": T_bus * FS / F_CLK * 100},
    "amdahl": {
        "loop_sw": T_bus + T_sw, "loop_hw": T_bus + T_hw,
        "fraction_accelerated": T_sw / (T_bus + T_sw),
        "kernel_speedup": T_sw / T_hw,
        "overall_speedup": (T_bus + T_sw) / (T_bus + T_hw),
        "limit_if_hw_free": (T_bus + T_sw) / T_bus,
    },
}
json.dump(out, open(os.path.join(HERE, "results.json"), "w"), indent=1)

print("samples %d | calib overhead %d cyc / %d instr" % (ns, oc, oi))
print("correct: filter %s (%d mismatching samples), detections %s %s" % (filt_ok, filt_mism, det_ok, sw_ev))
for k in ("filter", "decision", "total", "decision_learning", "decision_after_learning",
          "decision_on_detect_samples", "instr_filter", "instr_decision"):
    print("SW %-28s %s" % (k, sw[k]))
print("SW CPI filter %.2f decision %.2f total %.2f" % (sw["cpi_filter"], sw["cpi_decision"], sw["cpi_total"]))
print("APB read: %d cycles, %d instr, value ok %s" % (apb_c, apb_i, apb_val_ok))
print("HW", hw)
print("speedup", out["speedup"])
print("time_us", out["time_us_at_25MHz"])
print("cpu_load", out["cpu_load_pct_at_360Hz"])
print("amdahl", out["amdahl"])
