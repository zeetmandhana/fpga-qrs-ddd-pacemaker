// P17 Phase 4 -- hand-written HLS Pan-Tompkins integer filter chain.
// Bit-accurate mirror of src/pan_tompkins_fixed.py::fixed_filter_chain.
//
// All shift registers start at 0, so the boundary behaviour (taps before the
// stream has filled) matches the Python reference exactly. All right shifts are
// arithmetic (floor), matching ap_int<>::operator>> and Python's >>.

#include "qrs_filter.h"

void qrs_filter(const sample_t x_in[QRS_MAX_N], acc_t mwi_out[QRS_MAX_N],
                int n, filt_t baseline) {
    // Delay-line shift registers (partitioned so the shifts are pure rewiring).
    filt_t xsr[13];     // x[i] .. x[i-12]
    filt_t lpsr[33];    // lp[i] .. lp[i-32]
    filt_t hpsr[5];     // hp[i] .. hp[i-4]
    acc_t  sqsr[QRS_MWI_WINDOW + 1];   // sq[i] .. sq[i-54]
#pragma HLS ARRAY_PARTITION variable=xsr complete dim=1
#pragma HLS ARRAY_PARTITION variable=lpsr complete dim=1
#pragma HLS ARRAY_PARTITION variable=hpsr complete dim=1
#pragma HLS ARRAY_PARTITION variable=sqsr complete dim=1

    for (int k = 0; k < 13; k++) xsr[k] = 0;
    for (int k = 0; k < 33; k++) lpsr[k] = 0;
    for (int k = 0; k < 5; k++) hpsr[k] = 0;
    for (int k = 0; k <= QRS_MWI_WINDOW; k++) sqsr[k] = 0;

    filt_t lp1 = 0, lp2 = 0;            // lp[i-1], lp[i-2]
    acc_t moving_sum = 0;              // 32-tap running sum (HPF)
    acc_t mwi_sum = 0;                // 54-tap running sum (MWI)

    for (int i = 0; i < n; i++) {
#pragma HLS PIPELINE II=1
        // --- shift x register, insert centred sample ---
        for (int k = 12; k > 0; k--) xsr[k] = xsr[k - 1];
        xsr[0] = (filt_t)x_in[i] - baseline;

        // --- low-pass: lp = x - 2x[-6] + x[-12] + 2lp[-1] - lp[-2] ---
        filt_t lp = xsr[0] - (xsr[6] << 1) + xsr[12] + (lp1 << 1) - lp2;
        lp2 = lp1;
        lp1 = lp;

        // --- shift lp register ---
        for (int k = 32; k > 0; k--) lpsr[k] = lpsr[k - 1];
        lpsr[0] = lp;

        // --- high-pass: ms += lp - lp[-32];  hp = lp[-16] - (ms >> 5) ---
        moving_sum += (acc_t)lpsr[0] - (acc_t)lpsr[32];
        filt_t hp = lpsr[16] - (filt_t)(moving_sum >> 5);

        // --- shift hp register ---
        for (int k = 4; k > 0; k--) hpsr[k] = hpsr[k - 1];
        hpsr[0] = hp;

        // --- derivative: (2hp + hp[-1] - hp[-3] - 2hp[-4]) >> 3 ---
        filt_t num = (hpsr[0] << 1) + hpsr[1] - hpsr[3] - (hpsr[4] << 1);
        filt_t d = num >> 3;

        // --- square: THE one multiplier ---
        acc_t sq = (acc_t)d * (acc_t)d;

        // --- shift sq register ---
        for (int k = QRS_MWI_WINDOW; k > 0; k--) sqsr[k] = sqsr[k - 1];
        sqsr[0] = sq;

        // --- moving-window integration (running sum over 54 samples) ---
        mwi_sum += sqsr[0] - sqsr[QRS_MWI_WINDOW];
        mwi_out[i] = mwi_sum;
    }
}
