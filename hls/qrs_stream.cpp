// P17 board phase -- per-sample hand-HLS Pan-Tompkins filter chain.
// Bit-accurate mirror of src/pan_tompkins_fixed.py::fixed_filter_chain,
// written for a 360 Hz stream: one call per sample, state in static circular
// buffers (LUT-RAM) instead of shift registers, so it costs a few hundred
// LUTs instead of thousands of flip-flops. At 360 Hz there are ~69,000 clock
// cycles per sample, so the short sequential schedule is never a bottleneck.

#include "qrs_stream.h"

void qrs_stream(sample_t x, filt_t baseline,
                filt_t *hp_out, filt_t *dv_out, mwi_t *mwi_out) {
#pragma HLS INTERFACE mode=ap_none port=x
#pragma HLS INTERFACE mode=ap_none port=baseline
#pragma HLS INTERFACE mode=ap_vld port=hp_out
#pragma HLS INTERFACE mode=ap_vld port=dv_out
#pragma HLS INTERFACE mode=ap_vld port=mwi_out
#pragma HLS INTERFACE mode=ap_ctrl_hs port=return
#pragma HLS ALLOCATION operation instances=mul limit=1

    // circular delay lines; all start at 0 like the Python boundary handling
    static filt_t xbuf[16]  = {0};          // x[i] .. x[i-12]   (16 deep)
    static filt_t lpbuf[64] = {0};          // lp[i] .. lp[i-32] (64 deep)
    static filt_t hpbuf[8]  = {0};          // hp[i] .. hp[i-4]  (8 deep)
    static sq_t   sqbuf[64] = {0};          // sq[i] .. sq[i-54] (64 deep)
#pragma HLS BIND_STORAGE variable=xbuf  type=ram_2p impl=lutram
#pragma HLS BIND_STORAGE variable=lpbuf type=ram_2p impl=lutram
#pragma HLS BIND_STORAGE variable=hpbuf type=ram_2p impl=lutram
#pragma HLS BIND_STORAGE variable=sqbuf type=ram_2p impl=lutram

    static ap_uint<6> i64 = 0;              // write index mod 64
    static ap_uint<4> i16 = 0;              // write index mod 16
    static ap_uint<3> i8  = 0;              // write index mod 8
    static filt_t lp1 = 0, lp2 = 0;         // lp[i-1], lp[i-2]
    static filt_t moving_sum = 0;           // 32-tap running sum (HPF)
    static ap_uint<40> mwi_sum = 0;         // 54-tap running sum (MWI)

    // --- low-pass: lp = x - 2x[-6] + x[-12] + 2lp[-1] - lp[-2] ---
    filt_t xc = (filt_t)x - baseline;
    xbuf[i16] = xc;
    filt_t x6  = xbuf[(ap_uint<4>)(i16 - 6)];
    filt_t x12 = xbuf[(ap_uint<4>)(i16 - 12)];
    filt_t lp = xc - (x6 << 1) + x12 + (lp1 << 1) - lp2;
    lp2 = lp1;
    lp1 = lp;

    // --- high-pass: ms += lp - lp[-32];  hp = lp[-16] - (ms >> 5) ---
    lpbuf[i64] = lp;
    filt_t lp16 = lpbuf[(ap_uint<6>)(i64 - 16)];
    filt_t lp32 = lpbuf[(ap_uint<6>)(i64 - 32)];
    moving_sum = moving_sum + lp - lp32;
    filt_t hp = lp16 - (moving_sum >> 5);

    // --- derivative: (2hp + hp[-1] - hp[-3] - 2hp[-4]) >> 3 ---
    hpbuf[i8] = hp;
    filt_t h1 = hpbuf[(ap_uint<3>)(i8 - 1)];
    filt_t h3 = hpbuf[(ap_uint<3>)(i8 - 3)];
    filt_t h4 = hpbuf[(ap_uint<3>)(i8 - 4)];
    filt_t num = (hp << 1) + h1 - h3 - (h4 << 1);
    filt_t d = num >> 3;

    // --- square: THE one multiplier ---
    ap_int<33> ds = d;
    sq_t sq = (sq_t)(ds * ds);

    // --- moving-window integration: running sum over 54 samples ---
    sqbuf[i64] = sq;
    sq_t sq54 = sqbuf[(ap_uint<6>)(i64 - QRS_MWI_WINDOW)];
    mwi_sum = mwi_sum + sq - sq54;

    i64++;
    i16++;
    i8++;

    *hp_out = hp;
    *dv_out = d;
    *mwi_out = mwi_sum;
}
