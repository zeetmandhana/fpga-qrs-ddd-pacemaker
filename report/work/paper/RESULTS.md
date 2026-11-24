# Section 9 — Pan–Tompkins (chosen paper) vs baselines

Same input (MIT-BIH MLII, 360 Hz, raw 11-bit ADC), same matcher (±150 ms, whole
records 100/101/106/208/234 = 11,873 beats), same device (xc7z010clg400-1, OOC
post-route, 10 ns clock target). Thresholds of the baselines tuned on record 100
only (best F1), then frozen. All three detectors bit-exact RTL vs Python
(B0/B1: tb_qrs_baselines.v, 344/344 detections on 100k samples; E: earlier
tb_qrs_detector.v, 814 detections).

| Metric | B0 fixed threshold on raw ECG | B1 PT filters + fixed MWI threshold | E full Pan–Tompkins (adaptive) |
|---|---|---|---|
| Gross Se (%) | 98.56 | 99.21 | **99.55** |
| Gross +P (%) | 88.36 | 98.40 | **99.92** |
| TP / FP / FN | 11,702 / 1,541 / 171 | 11,779 / 192 / 94 | 11,820 / 9 / 53 |
| LUT (of which LUTRAM) | 16 (0) | 510 (162) | 2,850 (162) |
| FF | 73 | 619 | 2,385 |
| DSP / BRAM | 0 / 0 | 3 / 0 | 3 / 0 |
| WNS @10 ns → Fmax | +6.092 → 256 MHz | +2.658 → 136 MHz | −0.421 → 96 MHz |
| Mean decision delay after R peak | −15 ms (fires on upstroke) | +14 ms (fiducial −7 samples) | +217 ms |

Per record (Se / +P):

| rec | beats | B0 | B1 | E |
|---|---|---|---|---|
| 100 | 2273 | 100.00 / 100.00 (training) | 100.00 / 100.00 (training) | 99.87 / 100.00 |
| 101 | 1865 | 99.62 / 98.99 | 99.57 / 98.78 | 99.84 / 99.79 |
| 106 | 2027 | 96.10 / 64.23 | 99.16 / 96.22 | 99.01 / 100.00 |
| 208 | 2955 | 98.00 / 87.73 | 97.70 / 97.14 | 99.29 / 99.83 |
| 234 | 2753 | 99.06 / 98.84 | 99.96 / 99.82 | 99.78 / 100.00 |

Key points: the paper's adaptive dual thresholds + search-back + T-wave test cut
false detections 1,541 → 192 → 9 (−99.4 % vs B0) and missed beats 171 → 53, at
the cost of 2,834 LUTs and ~200 ms decision delay (the search window). Pan &
Tompkins report 99.3 % of QRS complexes detected on the full 24 h MIT-BIH set;
we measure Se 99.55 % / +P 99.92 % on 5 records (subset, 360 Hz integer, so not
the same test set). B0 at 100 % on record 100 is overfitting to its training
record: the same constant collapses to +P 64 % on record 106 (PVCs, larger T waves).

Files: baseline_eval.py, paper_results.{txt,json}, rtl/qrs_baselines.v,
rtl/tb_qrs_baselines.v (+ run_sim.bat, sim.log), impl/ooc_three.tcl, impl/*_util.rpt,
impl/*_timing.rpt, impl/ooc_from_reports.txt.
Bug found while doing this: TB race (inputs changed with blocking assignment on the
sampling edge) -> fixed by nonblocking TB drive; RTL unchanged.
