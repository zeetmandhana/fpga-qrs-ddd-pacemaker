"""Writes run_sw_sim.bat (NEORV32 v1.13.2 compile order from its file_list_soc.f,
with the default IMEM image replaced by the benchmark firmware image)."""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
CORE = os.path.join("C:" + os.sep, "NEORV32", "neorv32", "rtl", "core")
LIST = os.path.join("C:" + os.sep, "NEORV32", "neorv32", "rtl", "file_list_soc.f")

files = []
for line in open(LIST):
    f = line.strip().replace("$NEORV32_HOME/rtl/core/", "")
    if not f:
        continue
    if f == "neorv32_imem_image.vhd":
        files.append(os.path.join("..", "fw", "build", "neorv32_imem_image.vhd"))
    else:
        files.append(os.path.join(CORE, f))

up = os.path.join("..", "..", "..", "..", "rtl")
lines = [
    "@echo off",
    "rem HW/SW benchmark: fw/hwsw_bench.c on the NEORV32 (board configuration, v1.13.2) in xsim.",
    'call "' + os.path.join("C:" + os.sep, "AMDDesignTools", "2025.2", "Vivado", "settings64.bat") + '"',
    'cd /d "%~dp0sw_sim"',
    "call xvhdl --work neorv32 " + " ".join(files),
    "call xvhdl " + os.path.join("..", "neorv32_p17.vhd"),
    "call xvlog " + " ".join([os.path.join(up, "xbus_apb_bridge.v"), os.path.join(up, "demo_ctrl_apb.v"),
                              os.path.join("..", "tb_sw_bench.v")]),
    "call xelab tb_sw_bench -L neorv32 -s tb_sw_snap -timescale 1ns/1ps",
    "call xsim tb_sw_snap -runall",
    "echo SIM_EXIT=%ERRORLEVEL%",
    "",
]
with open(os.path.join(HERE, "run_sw_sim.bat"), "w", newline="") as fh:
    fh.write("\r\n".join(lines))
print("wrote run_sw_sim.bat with", len(files), "NEORV32 files")
