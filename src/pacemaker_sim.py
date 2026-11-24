"""
pacemaker_sim.py  --  P17 Phase 3: closed-loop DDD pacemaker simulation

Couples the DDD timing controller (pacemaker.py) to the heart model
(heart_model.py) at 1 ms resolution, runs the clinical scenarios, checks the
safety / liveness properties at run time, and draws marker (ladder) diagrams.

Runtime properties checked (software precursors to the later CTL proofs):
  * SAFETY   -- the device never paces both chambers on the same tick (no AP&VP).
  * SAFETY   -- the upper rate is respected: no paced V closer than URI.
  * LIVENESS -- the ventricle always beats within the lower rate interval (LRI).

It also demonstrates pacemaker-mediated tachycardia (PMT): with the (buggy)
atrial channel sensing retrograde P-waves inside PVARP, the ventricular rate
locks to the upper rate; with the correct PVARP blanking it does not.

Usage (venv active, from project root):
    python src/pacemaker_sim.py
"""

from __future__ import annotations

import json
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

from heart_model import SCENARIOS, HeartModel, HeartParams
from pacemaker import DDDPacemaker, DDDParameters

SRC_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SRC_DIR)
RESULTS_DIR = os.path.join(PROJECT_ROOT, "results")


def run_closed_loop(params: DDDParameters, heart_params: HeartParams,
                    duration_ms: int, enforce_pvarp: bool = True,
                    validate: bool = True) -> dict:
    """Run one closed-loop simulation; return event logs and activation times."""
    pm = DDDPacemaker(params, enforce_pvarp=enforce_pvarp, validate=validate)
    heart = HeartModel(heart_params)

    log = {"AS": [], "VS": [], "AP": [], "VP": []}
    v_events = []          # (tick, 'VP'/'VS') device ventricular events
    vent_acts = []         # ticks the ventricle actually depolarised (any cause)
    atr_acts = []          # ticks the atrium actually depolarised (any cause)
    both_pace = []         # ticks where AP and VP coincided (should never happen)

    for tick in range(duration_ms):
        a_in, v_in = heart.intrinsic(tick)
        out = pm.step(a_in, v_in)

        if out.a_sense:
            log["AS"].append(tick)
        if out.v_sense:
            log["VS"].append(tick)
        if out.a_pace:
            log["AP"].append(tick)
        if out.v_pace:
            log["VP"].append(tick)
        if out.a_pace and out.v_pace:
            both_pace.append(tick)

        atrial_act = a_in or out.a_pace
        vent_act = v_in or out.v_pace
        if atrial_act:
            atr_acts.append(tick)
        if vent_act:
            vent_acts.append(tick)
        if out.v_pace or out.v_sense:
            v_events.append((tick, "VP" if out.v_pace else "VS"))

        heart.update(tick, atrial_act, vent_act)

    return {"log": log, "v_events": v_events, "vent_acts": vent_acts,
            "atr_acts": atr_acts, "both_pace": both_pace,
            "duration_ms": duration_ms}


def _intervals(ticks: list[int]) -> list[int]:
    return [b - a for a, b in zip(ticks, ticks[1:])]


def check_safety(params: DDDParameters, sim: dict) -> dict:
    """Evaluate the safety / liveness properties on one simulation run."""
    checks = []

    # SAFETY 1: never AP and VP on the same tick
    checks.append({
        "name": "never AP and VP on the same tick (no cross-chamber short)",
        "passed": len(sim["both_pace"]) == 0,
        "detail": f"{len(sim['both_pace'])} violations",
    })

    # SAFETY 2: URI respected -- no paced V closer than URI to the previous V
    uri_viol, prev = 0, None
    for (t, typ) in sim["v_events"]:
        if prev is not None and typ == "VP" and (t - prev) < params.uri_ms:
            uri_viol += 1
        prev = t
    checks.append({
        "name": f"upper rate respected: no VP faster than URI ({params.uri_ms} ms)",
        "passed": uri_viol == 0,
        "detail": f"{uri_viol} violations",
    })

    # LIVENESS: ventricle beats within LRI (+ small tolerance)
    vv = _intervals(sim["vent_acts"])
    max_gap = max(vv) if vv else 0
    checks.append({
        "name": f"ventricle always beats within LRI+tol ({params.lri_ms}+20 ms)",
        "passed": (max_gap <= params.lri_ms + 20) if vv else False,
        "detail": f"max V-V gap {max_gap} ms",
    })

    vrate = 60000.0 / (sum(vv) / len(vv)) if vv else 0.0
    aa = _intervals(sim["atr_acts"])
    arate = 60000.0 / (sum(aa) / len(aa)) if aa else 0.0
    return {
        "checks": checks,
        "all_passed": all(c["passed"] for c in checks),
        "vent_rate_bpm": round(vrate, 1),
        "atr_rate_bpm": round(arate, 1),
        "n_AP": len(sim["log"]["AP"]), "n_VP": len(sim["log"]["VP"]),
        "n_AS": len(sim["log"]["AS"]), "n_VS": len(sim["log"]["VS"]),
        "min_vv_ms": min(vv) if vv else 0, "max_vv_ms": max_gap,
    }


# ---------------------------------------------------------------------------
# Plotting: marker / ladder diagrams
# ---------------------------------------------------------------------------

def _draw_markers(ax, log: dict, t0: float, t1: float) -> None:
    def win(ticks):
        return [t / 1000.0 for t in ticks if t0 <= t / 1000.0 <= t1]
    # Atrium row = 1, Ventricle row = 0. Senses = hollow, Paces = filled stem.
    for t in win(log["AP"]):
        ax.vlines(t, 1.0, 1.35, color="#1f4e79", lw=1.4)
    ax.plot(win(log["AP"]), [1.35] * len(win(log["AP"])), "v",
            color="#1f4e79", ms=8, label="AP (atrial pace)")
    ax.plot(win(log["AS"]), [1.0] * len(win(log["AS"])), "o", mfc="none",
            mec="#1f4e79", mew=1.6, ms=9, label="AS (atrial sense)")
    for t in win(log["VP"]):
        ax.vlines(t, 0.0, 0.35, color="#c00000", lw=1.4)
    ax.plot(win(log["VP"]), [0.35] * len(win(log["VP"])), "v",
            color="#c00000", ms=8, label="VP (ventricular pace)")
    ax.plot(win(log["VS"]), [0.0] * len(win(log["VS"])), "o", mfc="none",
            mec="#c00000", mew=1.6, ms=9, label="VS (ventricular sense)")
    ax.set_yticks([0.0, 1.0])
    ax.set_yticklabels(["Ventricle", "Atrium"])
    ax.set_ylim(-0.4, 1.7)
    ax.set_xlim(t0, t1)
    ax.grid(True, axis="x", alpha=0.3)


def plot_scenarios(params: DDDParameters, results: dict, window_s: float,
                   out_png: str) -> None:
    names = list(results.keys())
    fig, axes = plt.subplots(len(names), 1, figsize=(13, 2.1 * len(names)),
                             sharex=True)
    if len(names) == 1:
        axes = [axes]
    for ax, name in zip(axes, names):
        sim, rep, hp = results[name]
        _draw_markers(ax, sim["log"], 0.0, window_s)
        ax.set_ylabel(name, fontsize=9)
        status = "SAFE" if rep["all_passed"] else "VIOLATION"
        ax.set_title(f"{hp.description}  |  V-rate {rep['vent_rate_bpm']} bpm, "
                     f"A-rate {rep['atr_rate_bpm']} bpm  |  {status}",
                     fontsize=9, loc="left")
    axes[0].legend(loc="upper right", ncol=4, fontsize=7, framealpha=0.9)
    axes[-1].set_xlabel("Time (s)")
    fig.suptitle(f"DDD closed-loop scenarios  (LRI={params.lri_ms} AVI={params.avi_ms} "
                 f"URI={params.uri_ms} PVARP={params.pvarp_ms} VRP={params.vrp_ms} ms)",
                 fontsize=11)
    fig.tight_layout(rect=(0, 0, 1, 0.98))
    os.makedirs(os.path.dirname(out_png), exist_ok=True)
    fig.savefig(out_png, dpi=150)
    plt.close(fig)


def plot_pmt(params: DDDParameters, safe: dict, bug: dict, window_s: float,
             out_png: str) -> None:
    fig, axes = plt.subplots(2, 1, figsize=(13, 5.5), sharex=True)
    for ax, (sim, rep), title in [
        (axes[0], safe, "CORRECT: PVARP blanking ON -> retrograde P ignored"),
        (axes[1], bug, "INJECTED BUG: PVARP blanking OFF -> retrograde P sensed = PMT")]:
        _draw_markers(ax, sim["log"], 0.0, window_s)
        ax.set_title(f"{title}   (V-rate {rep['vent_rate_bpm']} bpm, "
                     f"min V-V {rep['min_vv_ms']} ms)", fontsize=10, loc="left")
    axes[0].legend(loc="upper right", ncol=4, fontsize=7, framealpha=0.9)
    axes[-1].set_xlabel("Time (s)")
    fig.suptitle(f"Pacemaker-mediated tachycardia (PMT) counterexample "
                 f"(URI={params.uri_ms} ms = {60000 // params.uri_ms} bpm ceiling)",
                 fontsize=11)
    fig.tight_layout(rect=(0, 0, 1, 0.96))
    fig.savefig(out_png, dpi=150)
    plt.close(fig)


# ---------------------------------------------------------------------------
def main() -> None:
    params = DDDParameters()
    params.validate()
    duration = 12000   # 12 s per scenario

    print(f"DDD parameters: LRI={params.lri_ms} AVI={params.avi_ms} "
          f"URI={params.uri_ms} PVARP={params.pvarp_ms} VRP={params.vrp_ms} "
          f"(AEI={params.aei_ms}) ms\n")

    base_scenarios = ["normal", "brady", "block", "dual"]
    results = {}
    summary = {"parameters": vars(params), "scenarios": {}}
    for name in base_scenarios:
        hp = SCENARIOS[name]
        sim = run_closed_loop(params, hp, duration)
        rep = check_safety(params, sim)
        results[name] = (sim, rep, hp)
        summary["scenarios"][name] = rep
        flags = "  ".join(c["name"].split(":")[0] + ("=ok" if c["passed"] else "=FAIL")
                          for c in rep["checks"])
        print(f"[{name:6}] V={rep['vent_rate_bpm']:>5} bpm  A={rep['atr_rate_bpm']:>5} bpm  "
              f"AP={rep['n_AP']} VP={rep['n_VP']} AS={rep['n_AS']} VS={rep['n_VS']}  "
              f"-> {'ALL SAFE' if rep['all_passed'] else 'VIOLATION'}")

    # PMT demonstration: same heart, correct vs buggy PVARP handling
    pmt_hp = SCENARIOS["pmt"]
    safe_sim = run_closed_loop(params, pmt_hp, duration, enforce_pvarp=True)
    bug_sim = run_closed_loop(params, pmt_hp, duration, enforce_pvarp=False)
    safe_rep = check_safety(params, safe_sim)
    bug_rep = check_safety(params, bug_sim)
    summary["scenarios"]["pmt_safe"] = safe_rep
    summary["scenarios"]["pmt_bug"] = bug_rep
    print(f"\n[pmt_safe] correct PVARP: V={safe_rep['vent_rate_bpm']} bpm "
          f"(min V-V {safe_rep['min_vv_ms']} ms) -> "
          f"{'ALL SAFE' if safe_rep['all_passed'] else 'VIOLATION'}")
    print(f"[pmt_bug ] PVARP blanking OFF: V={bug_rep['vent_rate_bpm']} bpm "
          f"(min V-V {bug_rep['min_vv_ms']} ms) -> "
          f"{'PMT at upper rate' if bug_rep['min_vv_ms'] <= params.uri_ms + 2 else 'ok'}")

    os.makedirs(RESULTS_DIR, exist_ok=True)
    with open(os.path.join(RESULTS_DIR, "stage3_pacemaker_metrics.json"), "w") as fh:
        json.dump(summary, fh, indent=2)

    scen_png = os.path.join(RESULTS_DIR, "stage3_scenarios.png")
    pmt_png = os.path.join(RESULTS_DIR, "stage3_pmt.png")
    print(f"\nPlotting scenarios -> {scen_png}")
    plot_scenarios(params, results, 6.0, scen_png)
    print(f"Plotting PMT counterexample -> {pmt_png}")
    plot_pmt(params, (safe_sim, safe_rep), (bug_sim, bug_rep), 6.0, pmt_png)
    print("\nDone.")


if __name__ == "__main__":
    main()
