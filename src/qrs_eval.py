"""
qrs_eval.py  --  P17 Phase 2: scoring a QRS detector against reference beats.

Matches detected R-peaks to the MIT-BIH reference beat annotations within a time
tolerance and computes the standard figures of merit:

    Sensitivity (Se)            = TP / (TP + FN)   -- fraction of real beats found
    Positive predictivity (+P)  = TP / (TP + FP)   -- fraction of detections correct

A detection matches a reference beat if it lies within +/- `tolerance` samples
(default 150 ms). Matching is one-to-one and nearest-first, so a single detection
cannot claim two beats and vice-versa. Only MIT-BIH *beat* symbols count as
reference beats (non-beat markers such as '+' are excluded).
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np


@dataclass
class MatchResult:
    tp: int
    fp: int
    fn: int
    matched_ref: np.ndarray     # reference indices that were detected (TP)
    matched_det: np.ndarray     # detection indices that hit a beat (TP)
    missed_ref: np.ndarray      # reference beats with no detection (FN)
    extra_det: np.ndarray       # detections with no reference beat (FP)

    @property
    def sensitivity(self) -> float:
        d = self.tp + self.fn
        return self.tp / d if d else 0.0

    @property
    def positive_predictivity(self) -> float:
        d = self.tp + self.fp
        return self.tp / d if d else 0.0


def match_detections(ref: np.ndarray, det: np.ndarray,
                     tolerance: int) -> MatchResult:
    """One-to-one nearest match of detections to reference beats within tolerance."""
    ref = np.sort(np.asarray(ref, dtype=np.int64))
    det = np.sort(np.asarray(det, dtype=np.int64))
    det_used = np.zeros(det.size, dtype=bool)

    tp_ref, tp_det, missed = [], [], []
    start = 0
    for r in ref:
        # advance to the first detection that could be within range
        while start < det.size and det[start] < r - tolerance:
            start += 1
        best, best_dist = -1, tolerance + 1
        k = start
        while k < det.size and det[k] <= r + tolerance:
            if not det_used[k]:
                dist = abs(int(det[k]) - int(r))
                if dist < best_dist:
                    best, best_dist = k, dist
            k += 1
        if best >= 0:
            det_used[best] = True
            tp_ref.append(int(r))
            tp_det.append(int(det[best]))
        else:
            missed.append(int(r))

    extra = det[~det_used]
    return MatchResult(
        tp=len(tp_ref),
        fp=int(extra.size),
        fn=len(missed),
        matched_ref=np.array(tp_ref, dtype=np.int64),
        matched_det=np.array(tp_det, dtype=np.int64),
        missed_ref=np.array(missed, dtype=np.int64),
        extra_det=np.asarray(extra, dtype=np.int64),
    )
