# Professor's kit runs still needed in Colab (Linux binaries: STAMINA, NOVA, JEDI, espresso, SIS)

Copy these 4 files from `report/work/fsm_logic/` into the kit's `my_problems/`
folder in the Colab notebook (same notebook as the espresso run):

- `ddd_spec_complete.kiss2`  (DDD spec STG, 6 states, completely specified)
- `ddd_spec_dc.kiss2`        (same, impossible inputs omitted = don't care)
- `qrs_decision_ctrl.kiss2`  (8-phase qrs_decision controller)
- `ddd_min.kiss2`            (our 2-state result, for reference)

Then run, from the kit folder (`/content/VL401_Synthesis`):

```
# Lab 1 - state minimisation
python3 vl401.py minimize my_problems/ddd_spec_complete.kiss2 --brief --save my_problems/ddd_min_partition.kiss2
python3 vl401.py minimize my_problems/ddd_spec_dc.kiss2 --save my_problems/ddd_min_stamina.kiss2
python3 vl401.py minimize my_problems/qrs_decision_ctrl.kiss2

# Lab 2 - state encoding of the 8-phase controller (binary, gray, one-hot, NOVA, JEDI,
#          our custom code; MUSTANG weights in step 2; exhaustive = all 40320 codes, ~11 min)
python3 vl401.py encode my_problems/qrs_decision_ctrl.kiss2 --multilevel --codes IDL=000,TRK=001,CLS=010,REG=100,AVG=011,LIM=110,SBK=111,END=101
python3 vl401.py encode my_problems/qrs_decision_ctrl.kiss2 --exhaustive --max-tries 40320
```

Expected (from our own Windows scripts, to compare):
- minimize ddd_spec_complete: partition P1 = P2 = {VRF,PVA,VRO,ALR} {AVD,URW} -> 2 states
  (already confirmed on Windows with the kit's own Python partition step:
  `kit_partition_ddd_spec.txt`); STAMINA should also print 2 states.
- minimize ddd_spec_dc (incompletely specified): partition skipped, STAMINA -> 2 states.
- minimize qrs_decision_ctrl: 8 classes, already minimal (`kit_partition_qrs_decision.txt`).
- encode: per-output literals, our exact QM count (`encoding_search.json`):
  binary 46, gray 51, custom 42 (best possible = 42, reached by 6 of 5040 codes with IDL=000;
  worst 71). espresso is heuristic, so the kit's numbers may differ by a literal or two.
