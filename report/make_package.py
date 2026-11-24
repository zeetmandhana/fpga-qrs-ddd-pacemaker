"""make_package.py -- build the Overleaf package of the VL401 report.
Creates report/VL401_G17_P17_overleaf.zip (the .tex, the compiled PDF, every figure the .tex uses and
the TikZ source of the block diagram). Run after pdflatex:  python report/make_package.py
"""
import os
import re
import zipfile

NAME = "VL401_G17_P17"
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, NAME)
TEX = os.path.join(SRC, NAME + ".tex")
tex = open(TEX, encoding="utf-8").read()
figs = sorted(set(re.findall(r"\{([\w\-]+\.(?:pdf|png|jpg))\}", tex)))
files = [NAME + ".tex", NAME + ".pdf", "figures_src/block_diagram.tex"] + figs
out = os.path.join(HERE, NAME + "_overleaf.zip")
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for f in files:
        path = os.path.join(SRC, f)
        if not os.path.exists(path):
            raise SystemExit("missing: " + f)
        z.write(path, NAME + "/" + f)
print("wrote", out, "with", len(files), "files:", ", ".join(files))
