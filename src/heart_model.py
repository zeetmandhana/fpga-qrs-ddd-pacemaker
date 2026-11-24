"""
heart_model.py  --  P17 Phase 3: a simple closed-loop heart model

Just enough electrophysiology to exercise the DDD pacemaker in closed loop:
a sinus (atrial) source, antegrade AV conduction (atrium -> ventricle),
optional retrograde VA conduction (ventricle -> atrium, the cause of PMT),
and an optional ventricular escape rhythm.

Each chamber "activates" when it is depolarised -- intrinsically (sinus / escape
/ conducted) OR by a pacing pulse. The model schedules the *consequences* of each
activation; the simulator feeds the intrinsic depolarisations to the pacemaker
and tells the model which chambers actually fired (intrinsic or paced).

This is a teaching model, not a biophysical one. All times are in ms.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass
class HeartParams:
    name: str
    description: str
    sinus_ms: int | None          # intrinsic atrial (sinus) interval; None = no sinus
    av_conduction_ms: int | None  # antegrade AV delay; None = complete AV block
    va_conduction_ms: int | None  # retrograde VA delay; None = no retrograde
    vent_escape_ms: int | None    # ventricular escape interval; None = none


# Scenarios used for the closed-loop tests.
SCENARIOS: dict[str, HeartParams] = {
    "normal": HeartParams(
        "normal", "Normal sinus ~75 bpm with intact AV conduction",
        sinus_ms=800, av_conduction_ms=150, va_conduction_ms=None,
        vent_escape_ms=None),
    "brady": HeartParams(
        "brady", "Sinus bradycardia ~40 bpm, conduction intact",
        sinus_ms=1500, av_conduction_ms=150, va_conduction_ms=None,
        vent_escape_ms=None),
    "block": HeartParams(
        "block", "Complete AV block, normal sinus ~75 bpm (no conduction)",
        sinus_ms=800, av_conduction_ms=None, va_conduction_ms=None,
        vent_escape_ms=1500),
    "dual": HeartParams(
        "dual", "AV block + sinus bradycardia (needs AV-sequential pacing)",
        sinus_ms=1500, av_conduction_ms=None, va_conduction_ms=None,
        vent_escape_ms=1500),
    "pmt": HeartParams(
        "pmt", "AV block + retrograde VA conduction (PMT substrate)",
        sinus_ms=900, av_conduction_ms=None, va_conduction_ms=280,
        vent_escape_ms=1500),
}


class HeartModel:
    """Schedules intrinsic depolarisations and responds to chamber activations."""

    def __init__(self, params: HeartParams, start_sinus_ms: int = 300):
        self.p = params
        self.next_sinus = start_sinus_ms if params.sinus_ms else None
        self.next_escape = params.vent_escape_ms if params.vent_escape_ms else None
        self.pending_av: int | None = None   # scheduled conducted V depolarisation
        self.pending_va: int | None = None   # scheduled retrograde A depolarisation

    def intrinsic(self, tick: int) -> tuple[bool, bool]:
        """Intrinsic depolarisations present on the leads at this tick."""
        a = ((self.next_sinus is not None and tick == self.next_sinus) or
             (self.pending_va is not None and tick == self.pending_va))
        v = ((self.pending_av is not None and tick == self.pending_av) or
             (self.next_escape is not None and tick == self.next_escape))
        return a, v

    def update(self, tick: int, atrial_activation: bool,
               ventricular_activation: bool) -> None:
        """Advance the model given which chambers actually fired this tick."""
        if atrial_activation:
            # overdrive the sinus and cancel any retrograde impulse heading up
            if self.p.sinus_ms:
                self.next_sinus = tick + self.p.sinus_ms
            self.pending_va = None
            # antegrade conduction to the ventricle (unless AV block)
            if self.p.av_conduction_ms is not None:
                self.pending_av = tick + self.p.av_conduction_ms

        if ventricular_activation:
            if self.p.vent_escape_ms:
                self.next_escape = tick + self.p.vent_escape_ms
            self.pending_av = None          # impulse arrived / ventricle fired
            # retrograde conduction back to the atrium (the PMT substrate)
            self.pending_va = (tick + self.p.va_conduction_ms
                               if self.p.va_conduction_ms is not None else None)
