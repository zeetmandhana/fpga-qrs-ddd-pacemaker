"""
qrs_hw_detector.py  --  P17 board phase: streaming, integer QRS decision stage

The Phase-2 decision stage (pan_tompkins.decide_qrs) works OFFLINE on whole
arrays: it finds MWI peaks with scipy, learns thresholds from the first 2 s
and looks a little into the future to place the R-peak. Hardware cannot do
that. This module is the HARDWARE version of the same Pan-Tompkins rules,
written so that rtl/qrs_decision.v can copy it line for line:

  * causal, one update per 360 Hz sample, no look-ahead;
  * integers only, every multiply/divide by a constant is a shift-and-add
    (the filter chain keeps the project's ONE multiplier, the squarer);
  * MWI peak detection = "rise to a maximum, then fall to half of it"
    (the rule in Pan & Tompkins 1985), with a FALL state so the decay of one
    hump is not reported as more peaks;
  * adaptive thresholds SPKI/NPKI (1/8 updates, 1/4 on search-back),
    THR1 = NPKI + (SPKI-NPKI)/4, THR2 = THR1/2, halved when the rhythm is
    irregular; 200 ms refractory; T-wave test (slope < 1/2 of last QRS slope
    inside 360 ms); search-back with THR2 after 166 % of the normal RR mean;
  * R-peak fiducial = position of max |band-pass| during the MWI rise,
    minus the band-pass group delay (21 samples).

This is the GOLDEN MODEL for the RTL: tb_qrs_detector.v checks the RTL
detections against `detect_stream` bit for bit.
"""

from __future__ import annotations

import numpy as np

FS = 360
LEARN = 720                    # 2 s learning phase (samples)
REFRACT = 72                   # 200 ms
TWAVE = 130                    # 360 ms  (round(0.36 * 360))
BP_DELAY = 21                  # LPF (5) + HPF (16) group delay of the band-pass
MASK40 = (1 << 40) - 1         # the RTL keeps MWI-domain values in 40 bits


def mul_learn_mean_half(lsum: int) -> int:
    """NPKI init = 0.5 * mean over 720 samples = lsum * 91 >> 17 (91/2^16 ~ 1/720).

    91 = 64 + 16 + 8 + 2 + 1, so the RTL does this with shifts and adds.
    """
    return ((lsum << 6) + (lsum << 4) + (lsum << 3) + (lsum << 1) + lsum) >> 17


def rr_low_of(a: int) -> int:      # 0.921875 * avg  (0.92)
    return a - (a >> 4) - (a >> 6)


def rr_high_of(a: int) -> int:     # 1.16015625 * avg  (1.16)
    return a + (a >> 3) + (a >> 5) + (a >> 8)


def rr_missed_of(a: int) -> int:   # 1.6640625 * avg  (1.66)
    return a + (a >> 1) + (a >> 3) + (a >> 5) + (a >> 7)


def tenth_of(a: int) -> int:       # 0.099609375 * avg  (0.10)
    return (a >> 4) + (a >> 5) + (a >> 8) + (a >> 9)


class HwQrsDecision:
    """Per-sample integer decision logic (one call to step() per sample)."""

    def __init__(self) -> None:
        self.n = 0                      # sample counter
        # learning
        self.lmax = 0
        self.lsum = 0
        self.learning = True
        # thresholds (MWI domain)
        self.spki = 0
        self.npki = 0
        # MWI peak tracker
        self.rising = True              # True = RISE (tracking max), False = FALL
        self.prev_mwi = 0
        self.pk_val = 0
        self.pk_idx = 0
        self.pk_slope = 0
        self.pk_bp = 0
        self.pk_ridx = 0
        # QRS history
        self.have_qrs = False
        self.last_qrs = 0               # MWI-peak index of the last QRS
        self.last_slope = 0
        # RR averages (8-deep, sum >> 3); filled with the first RR
        self.rr_all = [0] * 8
        self.rr_ok = [0] * 8
        self.have_rr = False
        self.avg1 = 0
        self.avg2 = 0
        self.rr_low = 0
        self.rr_high = 0
        self.rr_missed = 0
        self.irregular = False
        # search-back candidate (best sub-threshold peak since last QRS)
        self.pend_v = False
        self.pend_val = 0
        self.pend_idx = 0
        self.pend_slope = 0
        self.pend_ridx = 0

    # -- helpers --------------------------------------------------------
    def _thr1(self) -> int:
        t = self.npki + ((self.spki - self.npki) >> 2)
        return (t >> 1) if self.irregular else t

    def _register(self, val: int, idx: int, slope: int, ridx: int,
                  searchback: bool) -> None:
        if searchback:
            self.spki = self.spki + ((val - self.spki) >> 2)
        else:
            self.spki = self.spki + ((val - self.spki) >> 3)
        if self.have_qrs:
            rr = idx - self.last_qrs
            if not self.have_rr:
                self.rr_all = [rr] * 8
                self.rr_ok = [rr] * 8
                self.have_rr = True
            else:
                self.rr_all = [rr] + self.rr_all[:7]
                if self.rr_low <= rr <= self.rr_high:
                    self.rr_ok = [rr] + self.rr_ok[:7]
            self.avg1 = sum(self.rr_all) >> 3
            self.avg2 = sum(self.rr_ok) >> 3
            diff = self.avg1 - self.avg2 if self.avg1 >= self.avg2 else self.avg2 - self.avg1
            self.irregular = diff > tenth_of(self.avg2)
            self.rr_low = rr_low_of(self.avg2)
            self.rr_high = rr_high_of(self.avg2)
            self.rr_missed = rr_missed_of(self.avg2)
        self.have_qrs = True
        self.last_qrs = idx
        self.last_slope = slope
        self.pend_v = False

    # -- one sample -----------------------------------------------------
    def step(self, hp: int, dv: int, mwi: int):
        """Advance one sample. Returns None or (r_peak_index, searchback_flag)."""
        n = self.n
        mwi &= MASK40
        abs_hp = -hp if hp < 0 else hp
        abs_dv = -dv if dv < 0 else dv
        det = None

        if self.learning:
            if mwi > self.lmax:
                self.lmax = mwi
            self.lsum += mwi
            if n == LEARN - 1:
                self.spki = self.lmax >> 2
                self.npki = mul_learn_mean_half(self.lsum)
                self.learning = False
            # the peak tracker runs during learning too (so it is in phase),
            # but candidates found while learning are discarded
        # ---- MWI peak tracker ----
        cand = None
        if self.rising:
            if mwi > self.pk_val:
                self.pk_val = mwi
                self.pk_idx = n
            if abs_dv > self.pk_slope:
                self.pk_slope = abs_dv
            if abs_hp > self.pk_bp:
                self.pk_bp = abs_hp
                self.pk_ridx = n - BP_DELAY
            if self.pk_val > 0 and mwi <= (self.pk_val >> 1):
                cand = (self.pk_val, self.pk_idx, self.pk_slope, self.pk_ridx)
                self.rising = False
        else:
            if mwi > self.prev_mwi:           # valley passed: new rise starts
                self.rising = True
                self.pk_val = mwi
                self.pk_idx = n
                self.pk_slope = abs_dv
                self.pk_bp = abs_hp
                self.pk_ridx = n - BP_DELAY
        self.prev_mwi = mwi

        # ---- classify a candidate peak ----
        if cand is not None and not self.learning and n >= LEARN:
            val, idx, slope, ridx = cand
            thr1 = self._thr1()
            is_qrs = False
            since = idx - self.last_qrs
            if (not self.have_qrs) or since > REFRACT:
                if val > thr1:
                    if self.have_qrs and since < TWAVE:
                        is_qrs = slope > (self.last_slope >> 1)
                    else:
                        is_qrs = True
            if is_qrs:
                self._register(val, idx, slope, ridx, searchback=False)
                det = (ridx, False)
            else:
                self.npki = self.npki + ((val - self.npki) >> 3)
                if ((not self.have_qrs) or since > REFRACT) and \
                        ((not self.pend_v) or val > self.pend_val):
                    self.pend_v = True
                    self.pend_val, self.pend_idx = val, idx
                    self.pend_slope, self.pend_ridx = slope, ridx

        # ---- search-back (checked every sample, causal) ----
        if det is None and self.have_rr and self.pend_v and \
                (n - self.last_qrs) > self.rr_missed:
            thr2 = self._thr1() >> 1
            if self.pend_val > thr2:
                ridx = self.pend_ridx
                self._register(self.pend_val, self.pend_idx, self.pend_slope,
                               ridx, searchback=True)
                det = (ridx, True)
            else:
                self.pend_v = False            # nothing worth keeping

        self.n += 1
        return det


def detect_stream(hp: np.ndarray, dv: np.ndarray, mwi: np.ndarray):
    """Run the streaming decision over whole arrays.

    Returns (r_peaks, events) where events is a list of
    (sample_index_of_decision, r_peak_index, searchback) in time order.
    """
    dec = HwQrsDecision()
    events = []
    for i in range(len(mwi)):
        d = dec.step(int(hp[i]), int(dv[i]), int(mwi[i]))
        if d is not None:
            events.append((i, d[0], d[1]))
    r = np.array([e[1] for e in events], dtype=np.int64)
    return r, events
