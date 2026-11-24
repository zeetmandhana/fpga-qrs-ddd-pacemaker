"""
gen_zybo_mem.py  --  memory images for the Zybo Z7-10 board demo

  rtl/mem/ecg_rec100_32k.mem   32768 raw MLII ADC codes of MIT-BIH record 100
                               (91 s), replayed from BRAM at 360 Hz
  rtl/mem/tpl_p.mem            P-wave template   (ADC offsets from baseline)
  rtl/mem/tpl_qrst.mem         intrinsic QRS-T template
  rtl/mem/tpl_paced.mem        paced (wide) ventricular complex

The P and QRS-T templates are ensemble averages of real record-100 beats
(aligned on the reference annotations). The paced complex is SYNTHETIC
(sum of Gaussians: wide negative QRS + discordant T), because MIT-BIH record
100 has no paced beats; it is only used to draw paced beats in the
heart-model scenarios. All values are 12-bit two's complement hex.

Run:  python rtl/gen_zybo_mem.py
"""

import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, "src"))

from ecg_loader import BEAT_SYMBOLS, load_ecg_record      # noqa: E402
from pan_tompkins_fixed import load_record_digital        # noqa: E402

OUT = os.path.join(HERE, "mem")
FS = 360
N_ECG = 32768


def h12(v: int) -> str:
    return f"{int(v) & 0xFFF:03x}"


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    dig = load_record_digital("100", os.path.join(ROOT, "data"))
    adc = dig["adc"]
    base = dig["baseline"]
    with open(os.path.join(OUT, "ecg_rec100_32k.mem"), "w") as fh:
        fh.write("\n".join(f"{int(v):03x}" for v in adc[:N_ECG]) + "\n")

    rec = load_ecg_record("100", data_dir=os.path.join(ROOT, "data"))
    r = np.array([s for s, sym in zip(rec.ann_sample, rec.ann_symbol)
                  if sym == "N"], dtype=np.int64)
    r = r[(r > FS) & (r < adc.size - FS)][:400]
    x = adc.astype(np.int64) - base

    # P wave: R-0.26 s .. R-0.10 s ; QRS-T: R-0.04 s .. R+0.52 s
    p0, p1 = int(0.26 * FS), int(0.10 * FS)
    q0, q1 = int(0.04 * FS), int(0.52 * FS)
    seg_p = np.mean([x[k - p0:k - p1] for k in r], axis=0)
    seg_q = np.mean([x[k - q0:k + q1] for k in r], axis=0)
    # remove the local baseline so templates start and end near 0
    iso = np.mean([x[k - int(0.30 * FS):k - int(0.27 * FS)].mean() for k in r])
    seg_p = seg_p - iso
    seg_q = seg_q - iso
    taper_p = np.hanning(seg_p.size)
    seg_p = seg_p * np.minimum(1.0, 3 * taper_p)
    ramp = np.ones(seg_q.size)
    ramp[-30:] = np.linspace(1, 0, 30)
    seg_q = seg_q * ramp

    # synthetic paced ventricular complex (wide QRS, discordant T)
    t = np.arange(int(0.52 * FS)) / FS
    paced = (-1.10 * np.exp(-((t - 0.060) / 0.025) ** 2)
             + 0.45 * np.exp(-((t - 0.120) / 0.022) ** 2)
             + 0.30 * np.exp(-((t - 0.340) / 0.055) ** 2)) * dig["gain"]

    for name, arr in (("tpl_p.mem", seg_p), ("tpl_qrst.mem", seg_q),
                      ("tpl_paced.mem", paced)):
        a = np.round(arr).astype(np.int64)
        with open(os.path.join(OUT, name), "w") as fh:
            fh.write("\n".join(h12(v) for v in a) + "\n")
        print(f"{name}: {a.size} samples, range [{a.min()}, {a.max()}]")
    print(f"ecg_rec100_32k.mem: {N_ECG} samples ({N_ECG / FS:.1f} s), "
          f"range [{adc[:N_ECG].min()}, {adc[:N_ECG].max()}]")


if __name__ == "__main__":
    main()
