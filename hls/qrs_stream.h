#ifndef QRS_STREAM_H
#define QRS_STREAM_H

// P17 board phase -- per-sample (streaming) hand-HLS Pan-Tompkins filter chain.
//
//   raw ADC --> low-pass --> high-pass --> derivative --> square --> MWI(sum)
//
// One call = one 360 Hz sample. The filter state lives in static circular
// buffers, so the block can sit in the FPGA and be started once per sample.
// Only ONE multiplier (the squarer); everything else is add / shift.
// Bit-accurate against src/pan_tompkins_fixed.py::fixed_filter_chain
// (same equations as the Phase-4 array version qrs_filter.cpp).
//
// Value bounds for an 11-bit ADC (|x - baseline| <= 1024):
//   |lp| <= 36*1024, |hp| <= 2*|lp|max, |dv| <= 55296, sq < 2^32, mwi < 2^38.

#include "ap_int.h"

#define QRS_MWI_WINDOW 54          // 150 ms at 360 Hz

typedef ap_int<16>  sample_t;      // raw ADC code
typedef ap_int<32>  filt_t;        // LPF / HPF / derivative / moving sum
typedef ap_uint<32> sq_t;          // squared derivative (< 2^32)
typedef ap_uint<40> mwi_t;         // MWI running sum (< 2^38)

void qrs_stream(sample_t x, filt_t baseline,
                filt_t *hp_out, filt_t *dv_out, mwi_t *mwi_out);

#endif  // QRS_STREAM_H
