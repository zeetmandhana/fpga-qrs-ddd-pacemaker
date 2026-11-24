"""make_submission.py -- build the course submission ZIP: report PDF + relevant source code.

Writes report/VL401_G17_P17.zip with one top folder VL401_G17_P17/ containing
  VL401_G17_P17.pdf, README.md and the source/results folders of the project.
Generated folders (Vivado/HLS projects, simulator snapshots, SymbiYosys work dirs, object files),
logs, installed tools and the internal TA demo guide are left out. Files are read straight from
the project (no copy is made on disk).   Run:  python report/make_submission.py
"""
import os
import zipfile

NAME = "VL401_G17_P17"
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(HERE, NAME + ".zip")
LIMIT = 50 * 1024 * 1024
MAX_FILE = 1024 * 1024                      # skip anything bigger, except ALLOW_BIG

TREES = ["src", "tests", "data", "hls", "rtl", "vivado", "report/work", "results", "neorv32_ip"]
SINGLE = {"requirements.txt": "requirements.txt", "tools/plot_ila_ecg.py": "tools/plot_ila_ecg.py"}

SRC_EXT = {".py", ".v", ".sv", ".vh", ".vhd", ".c", ".h", ".cpp", ".s", ".ld", ".tcl", ".bat",
           ".xdc", ".smv", ".sby", ".ys", ".kiss2", ".pla", ".eqn", ".blif", ".md", ".txt", ".csv",
           ".json", ".mem", ".hex", ".rpt", ".png", ".jpg", ".pdf", ".wcfg", ".dot", ".ipynb",
           ".dat", ".hea", ".atr", ".html", ".css", ".js", ".cmd", ".fsm", ".script", ".cfg"}
SKIP_DIRS = {"xsim.dir", ".Xil", "__pycache__", ".pytest_cache", "_ide", "build", "xsim.codeCov",
             "logs_hls"}
SKIP_PREFIX = ("hls/qrs_filter/", "hls/qrs_filter_hls/", "hls/qrs_filter_z7/", "hls/qrs_stream_hls/",
               "hls/logs/", "vivado/p17_pacemaker/", "vivado/p17_zybo/", "vivado/p17_zybo_bd/",
               "report/work/formal/replay/sim_")
SKIP_NAMES = {"dfx_runtime.txt", "clockInfo.txt", "ip_status_before_rebuild.txt", ".gitignore"}
ALLOW_BIG = {"report/work/sim/rand_vectors.txt", "vivado/zybo_reports/p17_soc_ila.bit"}
EXTRA = ["vivado/zybo_reports/p17_soc_ila.bit", "vivado/zybo_reports/p17_soc_ila.ltx"]


def wanted(rel: str, size: int) -> bool:
    parts = rel.split("/")
    if any(p in SKIP_DIRS for p in parts[:-1]) or rel.startswith(SKIP_PREFIX):
        return False
    # SymbiYosys work folders report/work/formal/sby/ddd*/...
    if rel.startswith("report/work/formal/sby/") and len(parts) > 5 and parts[4].startswith("ddd"):
        return False
    name = parts[-1]
    if name in SKIP_NAMES or "backup" in name:
        return False
    ext = os.path.splitext(name)[1].lower()
    if ext == ".xml" and rel.startswith(("neorv32_ip/", "report/work/formal/cex/")):
        pass                                # IP descriptor / NuSMV counterexample traces
    elif ext == ".log":                     # keep only small run logs of the report experiments
        if not (rel.startswith("report/work/") and size < 100 * 1024):
            return False
    elif ext == ".out":
        if not (rel.startswith("report/work/") and size < 100 * 1024):
            return False
    elif ext not in SRC_EXT:
        return False
    if rel.startswith("data/") and ext in {".dat", ".hea", ".atr"}:
        return True
    return size <= MAX_FILE or rel in ALLOW_BIG


def collect():
    files = []
    for tree in TREES:
        for dirpath, dirnames, filenames in os.walk(os.path.join(ROOT, tree)):
            dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
            for f in filenames:
                full = os.path.join(dirpath, f)
                rel = os.path.relpath(full, ROOT).replace("\\", "/")
                if wanted(rel, os.path.getsize(full)):
                    files.append(rel)
    files += [r for r in EXTRA if r not in files]
    return sorted(set(files))


def main():
    files = collect()
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        z.write(os.path.join(HERE, NAME, NAME + ".pdf"), f"{NAME}/{NAME}.pdf")
        z.write(os.path.join(HERE, "submission_README.md"), f"{NAME}/README.md")
        for src, dst in SINGLE.items():
            z.write(os.path.join(ROOT, src), f"{NAME}/{dst}")
        for rel in files:
            z.write(os.path.join(ROOT, rel), f"{NAME}/{rel}")
    raw = sum(os.path.getsize(os.path.join(ROOT, r)) for r in files)
    size = os.path.getsize(OUT)
    by_top = {}
    for r in files:
        top = "/".join(r.split("/")[:2]) if r.startswith("report/") else r.split("/")[0]
        n, s = by_top.get(top, (0, 0))
        by_top[top] = (n + 1, s + os.path.getsize(os.path.join(ROOT, r)))
    for top, (n, s) in sorted(by_top.items()):
        print(f"  {top:<14} {n:5d} files {s / 1e6:7.2f} MB")
    print(f"wrote {OUT}: {len(files) + 2 + len(SINGLE)} files, {raw / 1e6:.1f} MB raw, "
          f"{size / 1e6:.2f} MB zipped (limit 50 MB)")
    if size > LIMIT:
        raise SystemExit("ZIP is over the 50 MB limit")


if __name__ == "__main__":
    main()
