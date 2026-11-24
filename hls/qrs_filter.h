#ifndef QRS_FILTER_H
#define QRS_FILTER_H

// P17 Phase 4 -- hand-written HLS: Pan-Tompkins integer filter chain.
//
//   raw ADC --> low-pass --> high-pass --> derivative --> square --> MWI(sum)
//
// Only ONE multiplier is used (the squarer); every other stage is adds and
// arithmetic shifts, and the moving-window integrator emits a running SUM so
// no divider is needed. Bit-accurate against src/pan_tompkins_fixed.py.

#include "ap_int.h"

#define QRS_MAX_N      20000   // test-vector length
#define QRS_MWI_WINDOW 54      // 150 ms at 360 Hz

typedef ap_int<16> sample_t;   // raw ADC code (11-bit, signed-extended)
typedef ap_int<32> filt_t;     // LPF / HPF / derivative / moving-sum
typedef ap_int<64> acc_t;      // squared value and MWI running sum

// Streams n samples through the filter chain, one sample per II=1 iteration.
void qrs_filter(const sample_t x_in[QRS_MAX_N], acc_t mwi_out[QRS_MAX_N],
                int n, filt_t baseline);

#endif  // QRS_FILTER_H
