# P17 Phase 4 - HLS filter chain: resource, timing & throughput
Device: xc7a100t-csg324-1 | Golden model: bit-exact (C-sim, 0 mismatches)
| Resource | Used | Available | Util % |
|----------|------|-----------|--------|
| LUT | 1705 | 63400 | 2 |
| FF | 5315 | 126800 | 4 |
| DSP48 | 4 | 240 | 1 |
| BRAM_18K | 0 | 270 | 0 |
| URAM | 0 | 0 | 0 |
- Clock: target 10.0 ns (100 MHz); estimated 10.62 ns (Fmax ~ 94.2 MHz, uncertainty 2.7 ns)
- Pipeline: II = 1 (one ECG sample per clock), iteration latency 7 cycles
- Throughput: ~94.2 Msample/s vs 360 Hz required -> ~261,666x real-time headroom
- Multiplier: one (the squarer, 29x29->58-bit) -> 4 DSP48 primitives; every other stage is adds + shifts (0 DSP)
Power (ESTIMATE): exact dynamic power needs Vivado place-and-route + report_power. For this size (4 DSP, ~5.3k FF, ~1.7k LUT, 0 BRAM) at ~100 MHz on Artix-7, dynamic power is in the low-tens-of-mW range; device static power dominates (~0.1 W). Reported as an estimate, not a measured figure.
