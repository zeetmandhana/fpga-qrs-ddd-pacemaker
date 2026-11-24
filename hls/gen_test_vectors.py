"""
gen_test_vectors.py  --  P17 Phase 4: export bit-exact HLS test vectors

Writes the raw ADC input and the expected integer MWI output of the fixed-point
filter chain for record 100, so the HLS C testbench can check the hardware
filter bit-for-bit against the Python golden model.

Run (venv active, from project root):
    python hls/gen_test_vectors.py
"""

import os
import sys

import numpy as np

_HERE = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.dirname(_HERE)
sys.path.insert(0, os.path.join(_ROOT, "src"))

from pan_tompkins_fixed import fixed_filter_chain, load_record_digital  # noqa: E402

N = 20000          # samples to export (~55 s at 360 Hz; exercises all delays)
RECORD = "100"
OUT = os.path.join(_HERE, "tb_data")


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    dig = load_record_digital(RECORD, os.path.join(_ROOT, "data"))
    adc = dig["adc"][:N]
    baseline = dig["baseline"]
    stages = fixed_filter_chain(adc, baseline)
    mwi = stages["mwi"]

    np.savetxt(os.path.join(OUT, "rec100_input.txt"), adc, fmt="%d")
    np.savetxt(os.path.join(OUT, "rec100_expected_mwi.txt"), mwi, fmt="%d")
    with open(os.path.join(OUT, "meta.txt"), "w") as fh:
        fh.write(f"record {RECORD}\nn {N}\nbaseline {baseline}\n"
                 f"mwi_window {stages['mwi_window']}\n")

    print(f"Wrote {N} samples to {OUT}")
    print(f"  baseline={baseline}  mwi range=[{int(mwi.min())},{int(mwi.max())}]")
    print(f"  adc range=[{int(adc.min())},{int(adc.max())}]")


if __name__ == "__main__":
    main()
