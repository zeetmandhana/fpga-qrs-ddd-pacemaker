# VL401 Course Project: Group 17, P17 (QRS Detector and DDD Pacemaker Controller)

Garigipati Uma Bharathi (B23262), Zeet Mandhana (B24504). Instructor: Dr. Bikram Paul.
Repository: https://github.com/zeetmandhana/fpga-qrs-ddd-pacemaker

**Report:** `VL401_G17_P17.pdf` (Sections 1-12 are pages 4-15). Every number in the report comes
from a script or log in this folder. Appendix A of the report lists the commands.

## Folder layout

| Folder | Contents |
|---|---|
| `src/` | Python golden models: ECG loader, Pan-Tompkins (float and integer), streaming HW detector model, DDD pacemaker, heart model, explicit-state CTL checker, event-priority logic (QM + ROBDD) |
| `tests/` | 48 pytest checks of the golden models |
| `data/` | The five MIT-BIH records used (100, 101, 106, 208, 234; PhysioNet, ODC-By 1.0) |
| `hls/` | Vitis HLS kernels `qrs_filter` and `qrs_stream` (per-sample detector filter chain), testbenches, vectors, run scripts |
| `rtl/` | Verilog RTL: `ddd_pacemaker.v`, APB slave, `event_priority.v`, `qrs_decision.v`, `heart_model.v`, bridges, HDMI/ECG display, Zybo top; testbenches; NEORV32 firmware sources (`rtl/firmware`) |
| `rtl/bd/` | Module-reference blocks of the IP-Integrator SoC (AXI-Lite to APB, slaves, ILA tap, JTAG debug) |
| `vivado/` | Tcl/batch scripts that create the projects and the block design, add ILA/VIO, rebuild the bitstream and capture ILA data; XDC constraints |
| `vivado/zybo_reports/` | Final bitstream `p17_soc_ila.bit` + `p17_soc_ila.ltx` (ILA probes) and the utilisation, timing and power reports |
| `report/work/` | The experiments of the report, one folder per topic, most with a `RESULTS.md`: `paper` (baseline vs Pan-Tompkins), `sim` (constrained-random, SVA, coverage, regression), `hand_hls` (CDFG, scheduling, ILP, binding, FSMD), `fsm_logic` (state minimisation, encodings, ESPRESSO/SIS), `formal` (NuSMV, BDD, SymbiYosys), `hwsw` (HW vs SW cycles), `lint`, `refs`, `figs`, `board_fixed` |
| `results/` | Logs, plots and the board ILA captures (`results/ila` original bitstream, `results/ila_fixed` rebuilt bitstream; CSV + PNG) |
| `neorv32_ip/` | NEORV32 RISC-V core (BSD-3-Clause, S. Nolting) packaged as a Vivado IP with our firmware image; third-party code, used unchanged apart from the image |
| `tools/plot_ila_ecg.py` | Rebuilds the ECG and event plots from the ILA CSV files |

## Tools used

- AMD Vivado / Vitis HLS 2025.2 (board: Digilent Zybo Z7-10, xc7z010clg400-1)
- Python 3.14 with `requirements.txt` (numpy, scipy, matplotlib, wfdb, pandas, dd, networkx, pytest)
- NuSMV 2.7.1; OSS CAD Suite (Yosys, SymbiYosys, Verilator, yices, bitwuzla)
- NEORV32 v1.13.2 and the xPack `riscv-none-elf-gcc` 15.2 toolchain for the firmware
- The course Digital Logic Synthesis Kit (`vl401.py`, SIS, ESPRESSO, STAMINA, NOVA, JEDI), run in Google Colab

## Main commands (run from this folder on Windows)

```
.venv\Scripts\python -m pytest tests -q                       # golden models (48 tests)
.venv\Scripts\python src\evaluate_hw_detector.py              # Se/+P on 5 MIT-BIH records
.venv\Scripts\python report\work\paper\baseline_eval.py       # Sec. 9: B0 / B1 / Pan-Tompkins
.venv\Scripts\python report\work\sim\run_regression.py        # all xsim testbenches, SVA, coverage
.venv\Scripts\python report\work\hand_hls\hand_hls.py         # Sec. 4 DFGs, schedules, ILP, binding
NuSMV -dcx report\work\formal\ddd_oa.smv                      # Sec. 8 CTL properties
report\work\formal\sby\run_demo.bat                           # Sec. 8 SymbiYosys proofs
hls\run_hls_z7.bat                                            # HLS IP (csim, csynth, export)
vivado -source vivado\create_zybo_bd.tcl                      # SoC block design + bitstream
vivado -mode batch -source vivado\ila_capture_batch.tcl       # board ILA captures
```

## Notes

- The scripts were run with the project at `C:\Vivadoproject\P17_QRS_Pacemaker`. Some testbenches
  (`TB_DIR`) and Vivado Tcl scripts use that absolute path; edit it if you unpack elsewhere.
- Generated folders are not included and are recreated by the scripts: the Vivado projects
  (`vivado/p17_*`), the HLS solutions (`hls/qrs_*_hls`, `hls/qrs_filter*`), simulator snapshots
  (`xsim.dir`), SymbiYosys work folders and firmware object files.
- Debug cores (ILA/VIO) need the JTAG clock at 5 MHz; the capture scripts set this.
