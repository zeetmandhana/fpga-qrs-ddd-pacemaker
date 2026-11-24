"""
gen_ecg_mem.py  --  P17 Phase 6: ECG BRAM init file for the board demo

Writes the first 640 MLII samples of record 100, scaled to 8 bits, as a
$readmemh file (one hex byte per line) for the demo top's ECG replay BRAM.

Run (venv active, from project root):  python rtl/gen_ecg_mem.py
"""

import os
import sys

import numpy as np

_HERE = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.dirname(_HERE)
sys.path.insert(0, os.path.join(_ROOT, "src"))

from ecg_loader import load_ecg_record     # noqa: E402

N = 640


def main() -> None:
    rec = load_ecg_record("100", data_dir=os.path.join(_ROOT, "data"))
    sig = rec.signal[:N]
    lo, hi = float(sig.min()), float(sig.max())
    scaled = np.round((sig - lo) / (hi - lo) * 255.0).astype(int)
    scaled = np.clip(scaled, 0, 255)
    out = os.path.join(_HERE, "ecg_samples.mem")
    with open(out, "w") as fh:
        for v in scaled:
            fh.write(f"{v:02x}\n")
    print(f"Wrote {N} samples to {out} (8-bit, range {lo:.3f}..{hi:.3f} mV -> 0..255)")


if __name__ == "__main__":
    main()
