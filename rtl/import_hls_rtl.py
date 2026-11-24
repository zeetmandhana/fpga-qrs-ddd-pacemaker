"""
import_hls_rtl.py  --  copy the Vitis-HLS Verilog of qrs_stream into rtl/hls_qrs_stream/

The generated LUT-RAM modules initialise themselves with
$readmemh("./<name>.dat"), a path relative to wherever the simulator/synthesis
runs. All the .dat files are zero (the C code starts its delay lines at 0), so
the $readmemh is replaced by an equivalent zero-initialisation loop. Nothing
else in the generated RTL is touched.

Run:  python rtl/import_hls_rtl.py
"""

import glob
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(os.path.dirname(HERE), "hls", "qrs_stream_hls", "sol1", "syn", "verilog")
DST = os.path.join(HERE, "hls_qrs_stream")


def main() -> None:
    os.makedirs(DST, exist_ok=True)
    for dat in glob.glob(os.path.join(SRC, "*.dat")):
        words = open(dat).read().split()
        assert all(int(w, 16) == 0 for w in words), f"non-zero init in {dat}"
    n = 0
    for v in glob.glob(os.path.join(SRC, "*.v")):
        text = open(v).read()
        text = re.sub(
            r'\$readmemh\("\./[^"]+\.dat", ram\);',
            "begin : zero_init integer i; for (i = 0; i < AddressRange; i = i + 1) "
            "ram[i] = {DataWidth{1'b0}}; end  // was $readmemh(<all-zero .dat>)",
            text)
        with open(os.path.join(DST, os.path.basename(v)), "w") as fh:
            fh.write(text)
        n += 1
    print(f"copied {n} Verilog files to {DST}")


if __name__ == "__main__":
    main()
