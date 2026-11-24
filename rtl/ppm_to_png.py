"""ppm_to_png.py  --  convert the simulated screen frames (results/sim_frame_*.ppm) to PNG."""
import glob
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
for ppm in glob.glob(os.path.join(ROOT, "results", "sim_frame_*.ppm")):
    with open(ppm) as fh:
        tok = fh.read().split()
    w, h = int(tok[1]), int(tok[2])
    px = np.array(tok[4:4 + 3 * w * h], dtype=np.uint8).reshape(h, w, 3)
    out = ppm[:-4] + ".png"
    Image.fromarray(px).save(out)
    print(f"{out}  ({w}x{h})")
