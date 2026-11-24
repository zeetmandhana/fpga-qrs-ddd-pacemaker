"""
pacemaker.py  --  P17 Phase 3: DDD pacemaker timing controller (golden model)

A discrete-time (1 ms tick) model of a dual-chamber (DDD) pacemaker's timing
logic. It is written with small integer counters and an explicit event-priority
decision each tick, so it maps directly to the timing automaton / ESPRESSO-BDD
block that will be built later and is friendly to model checking.

This is a MODEL ONLY -- no RTL/HLS, no RV32/APB, no formal proofs yet. The
closed-loop heart model lives in heart_model.py and the simulator in
pacemaker_sim.py.

DDD timing intervals
--------------------
  LRI   Lower Rate Interval   - longest allowed V-V interval (sets the min rate)
  AVI   AV Interval           - A event -> paced V if the ventricle stays silent
  URI   Upper Rate Interval   - shortest allowed V-V interval (caps the max rate)
  PVARP Post-Ventricular Atrial Refractory Period - atrial sensing blanked after V
  VRP   Ventricular Refractory Period            - ventricular sensing blanked after V
  AEI   Atrial Escape Interval = LRI - AVI       - V -> paced A if the atrium is silent

Events: AS = atrial sense, VS = ventricular sense (intrinsic, sensed);
        AP = atrial pace,  VP = ventricular pace (delivered by the device).
"""

from __future__ import annotations

from dataclasses import dataclass


# ---------------------------------------------------------------------------
# Programmable parameters (what the RV32 would set, range-checked, over APB)
# ---------------------------------------------------------------------------

@dataclass
class DDDParameters:
    lri_ms: int = 1000     # lower rate interval  (1000 ms = 60 bpm floor)
    avi_ms: int = 180      # AV delay
    uri_ms: int = 500      # upper rate interval  (500 ms = 120 bpm ceiling)
    pvarp_ms: int = 320    # post-ventricular atrial refractory period
    vrp_ms: int = 250      # ventricular refractory period

    @property
    def aei_ms(self) -> int:
        """Atrial escape interval (V -> A pace timeout)."""
        return self.lri_ms - self.avi_ms

    def validate(self) -> None:
        """Range-check the programmed values; raise ValueError on anything unsafe.

        This is the software mirror of the range check the RV32 would apply
        before writing the timing registers.
        """
        e = []
        if not (400 <= self.lri_ms <= 2000):
            e.append(f"LRI {self.lri_ms} ms outside [400, 2000]")
        if not (30 <= self.avi_ms <= 350):
            e.append(f"AVI {self.avi_ms} ms outside [30, 350]")
        if not (300 <= self.uri_ms <= self.lri_ms):
            e.append(f"URI {self.uri_ms} ms outside [300, LRI={self.lri_ms}]")
        if not (150 <= self.pvarp_ms <= 500):
            e.append(f"PVARP {self.pvarp_ms} ms outside [150, 500]")
        if not (150 <= self.vrp_ms <= 400):
            e.append(f"VRP {self.vrp_ms} ms outside [150, 400]")
        if self.avi_ms >= self.lri_ms:
            e.append("AVI must be < LRI")
        if self.uri_ms < self.avi_ms:
            e.append("URI must be >= AVI (cannot pace V faster than the AV delay)")
        if e:
            raise ValueError("Invalid DDD parameters: " + "; ".join(e))


@dataclass
class StepOutput:
    """What happened on one tick."""
    a_sense: bool = False   # AS
    v_sense: bool = False   # VS
    a_pace: bool = False    # AP
    v_pace: bool = False    # VP


# ---------------------------------------------------------------------------
# The DDD timing controller
# ---------------------------------------------------------------------------

class DDDPacemaker:
    """Dual-chamber (DDD) pacemaker timing logic, advanced one 1 ms tick at a time.

    `enforce_pvarp` exists so a bug can be injected: with it False the atrial
    channel ignores the PVARP blanking and will sense retrograde P-waves, which
    is the classic cause of pacemaker-mediated tachycardia (PMT). It is True
    (correct) by default.
    """

    AEI = "AEI"   # waiting for an atrial event (the V-A portion of the cycle)
    AVI = "AVI"   # an atrial event occurred; waiting for a ventricular event

    def __init__(self, params: DDDParameters, enforce_pvarp: bool = True,
                 validate: bool = True):
        if validate:
            params.validate()
        self.p = params
        self.enforce_pvarp = enforce_pvarp
        # timers (ms since the relevant event)
        self.t_v = params.lri_ms      # time since last ventricular event
        self.t_av = 0                 # time since the atrial event that opened AVI
        self.phase = self.AEI

    # -- internal state transitions --
    def _on_vent_event(self) -> None:
        self.t_v = 0
        self.t_av = 0
        self.phase = self.AEI

    def _on_atr_event(self) -> None:
        self.t_av = 0
        self.phase = self.AVI

    def step(self, a_intrinsic: bool, v_intrinsic: bool) -> StepOutput:
        """Advance 1 ms. Inputs are the raw intrinsic depolarisations present on
        the atrial / ventricular leads this tick; outputs are the device events.
        """
        p = self.p
        self.t_v += 1
        if self.phase == self.AVI:
            self.t_av += 1
        out = StepOutput()

        # (1) Ventricular sensing -- blanked during the VRP after a V event.
        if v_intrinsic and self.t_v >= p.vrp_ms:
            out.v_sense = True

        if out.v_sense:
            self._on_vent_event()
            return out                       # V event ends the cycle for this tick

        # (2) Ventricular pacing -- AVI timed out; honour the URI (upper rate).
        if self.phase == self.AVI and self.t_av >= p.avi_ms:
            if self.t_v >= p.uri_ms:
                out.v_pace = True
                self._on_vent_event()
                return out
            # else: AVI done but URI not yet reached -> hold VP (rate limiting)

        # (3) Atrial side -- only while waiting for an atrial event (AEI phase).
        if self.phase == self.AEI:
            atrial_blanked = self.enforce_pvarp and self.t_v < p.pvarp_ms
            if a_intrinsic and not atrial_blanked:
                out.a_sense = True
                self._on_atr_event()
            elif self.t_v >= p.aei_ms:
                out.a_pace = True
                self._on_atr_event()

        return out


# ---------------------------------------------------------------------------
# Manual smoke test:  python src/pacemaker.py
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    p = DDDParameters()
    p.validate()
    print(f"DDD parameters OK: LRI={p.lri_ms} AVI={p.avi_ms} URI={p.uri_ms} "
          f"PVARP={p.pvarp_ms} VRP={p.vrp_ms} (AEI={p.aei_ms}) ms")
    # With no intrinsic activity at all, the device must pace both chambers at
    # the lower rate: AP every LRI, each followed by VP after AVI.
    pm = DDDPacemaker(p)
    aps = vps = 0
    first_ap = first_vp = None
    for t in range(3000):
        o = pm.step(False, False)
        if o.a_pace:
            aps += 1
            if first_ap is None:
                first_ap = t
        if o.v_pace:
            vps += 1
            if first_vp is None:
                first_vp = t
    print(f"No intrinsic activity over 3 s: AP={aps}, VP={vps}; "
          f"first AP at {first_ap} ms, first VP at {first_vp} ms "
          f"(expect VP ~AVI after AP)")
