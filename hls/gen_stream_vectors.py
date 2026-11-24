"""
gen_stream_vectors.py  --  test vectors for the streaming HLS block and the RTL detector

Writes, from the Python golden models:
  hls/tb_data/stream_rec100_input.txt     raw ADC (20000 samples, record 100)
  hls/tb_data/stream_rec100_expected.txt  "hp dv mwi" per sample (fixed_filter_chain)
  rtl/tb_data/det_<rec>_adc.txt           raw ADC for the RTL detector testbench
  rtl/tb_data/det_<rec>_events.txt        expected detections "decision_sample r_peak searchback"

Run (venv active, project root):  python hls/gen_stream_vectors.py
"""

import os
import sys

import numpy as np

_HERE = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.dirname(_HERE)
sys.path.insert(0, os.path.join(_ROOT, "src"))

from pan_tompkins_fixed import fixed_filter_chain, load_record_digital  # noqa: E402
from qrs_hw_detector import MASK40, detect_stream                         # noqa: E402

HLS_N = 20000
RTL_N = 100000          # ~278 s per record for the RTL detector check
RTL_RECORDS = ["100", "208"]


def main() -> None:
    hls_out = os.path.join(_HERE, "tb_data")
    rtl_out = os.path.join(_ROOT, "rtl", "tb_data")
    os.makedirs(hls_out, exist_ok=True)
    os.makedirs(rtl_out, exist_ok=True)

    dig = load_record_digital("100", os.path.join(_ROOT, "data"))
    adc = dig["adc"][:HLS_N]
    st = fixed_filter_chain(adc, dig["baseline"])
    np.savetxt(os.path.join(hls_out, "stream_rec100_input.txt"), adc, fmt="%d")
    with open(os.path.join(hls_out, "stream_rec100_expected.txt"), "w") as fh:
        for h, d, m in zip(st["hp"], st["dv"], st["mwi"]):
            fh.write(f"{int(h)} {int(d)} {int(m) & MASK40}\n")
    print(f"HLS vectors: {HLS_N} samples, mwi max {int(st['mwi'].max())}")

    for rec in RTL_RECORDS:
        dig = load_record_digital(rec, os.path.join(_ROOT, "data"))
        adc = dig["adc"][:RTL_N]
        st = fixed_filter_chain(adc, dig["baseline"])
        _, events = detect_stream(st["hp"], st["dv"], st["mwi"])
        np.savetxt(os.path.join(rtl_out, f"det_{rec}_adc.txt"), adc, fmt="%d")
        with open(os.path.join(rtl_out, f"det_{rec}_events.txt"), "w") as fh:
            for (n, r, sb) in events:
                fh.write(f"{n} {r} {int(sb)}\n")
        print(f"RTL vectors rec {rec}: {RTL_N} samples, {len(events)} detections "
              f"({sum(1 for e in events if e[2])} search-back)")


if __name__ == "__main__":
    main()
