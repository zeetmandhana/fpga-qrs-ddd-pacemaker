# Verilator 5.055 --lint-only -Wall (OSS CAD Suite 2026-11-20), hand-written RTL

| module | warnings | categories | real errors |
|---|---|---|---|
| ddd_pacemaker | 27 | BLKSEQ 27 | 0 |
| ddd_pacemaker_apb | 29 | BLKSEQ 27 (from ddd_pacemaker), UNUSEDSIGNAL 2 (PADDR[1:0], PWDATA[31:16]) | 0 |
| event_priority | 0 | - | 0 |
| heart_model | 23 | BLKSEQ 19, WIDTHEXPAND 4 | 0 |
| qrs_decision | 23 | WIDTHEXPAND 16, UNUSEDSIGNAL 7 (discarded LSBs / sign bit of shift-add products) | 0 |
| demo_ctrl_apb | 2 | UNUSEDSIGNAL 2 (PADDR[1:0], PWDATA[31:3]) | 0 |
| xbus_apb_bridge | 0 | - | 0 |
| ecg_source | 2 | WIDTHTRUNC 2 (8-bit index into 57-entry ROM; guarded: index <= 56 while p_on) | 0 |

The only %Error lines are Verilator's "Exiting due to N warning(s)".
Waivers (reviewed): BLKSEQ = intentional blocking temporaries inside one clocked
process (next-state computed in the same tick, mirrors the golden model; never read
across cycles); WIDTHEXPAND = intended zero-extension of narrower unsigned operands;
UNUSEDSIGNAL = unused bus bits / discarded fraction bits; WIDTHTRUNC = bounded index.
Logs: *.lint.txt
