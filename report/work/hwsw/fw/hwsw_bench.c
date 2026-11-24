/*
 * hwsw_bench.c -- software-only Pan-Tompkins detector on the board's NEORV32
 * (rv32i + Zicntr, NO M extension: the squarer becomes a libgcc __mulsi3 call).
 *
 *   qrs_filter() : line-for-line C port of hls/qrs_stream.cpp (the HLS IP)
 *   qrs_decide() : line-for-line C port of src/qrs_hw_detector.py::HwQrsDecision
 *                  (the golden model of rtl/qrs_decision.v)
 *
 * For every sample the firmware reads mcycle/minstret around each function and
 * streams 9 words per sample to a testbench mailbox on the external bus:
 *   hp, dv, mwi[31:0], mwi[39:32], det (0xFFFFFFFF = none, else ridx<<1 | sb),
 *   filter cycles, decision cycles, filter instructions, decision instructions
 * (all counts are raw; the empty-window overhead is reported separately).
 * The mailbox writes happen outside the timed windows.
 */
#include <neorv32.h>
#include <stdint.h>
#include "samples.h"

#define MB_DATA (*(volatile uint32_t *)0xA0000000u)   /* testbench mailbox: data  */
#define MB_DONE (*(volatile uint32_t *)0xA0000004u)   /* testbench mailbox: done  */
#define APB_ID  (*(volatile uint32_t *)0x90000124u)   /* demo_ctrl_apb ID (0x50170001) */

#define BARRIER() __asm__ volatile ("" ::: "memory")

static inline uint32_t rdcycle(void)   { return neorv32_cpu_csr_read(CSR_MCYCLE); }
static inline uint32_t rdinstret(void) { return neorv32_cpu_csr_read(CSR_MINSTRET); }

/* ======================= filter chain (hls/qrs_stream.cpp) ======================= */
#define MASK40 ((1ULL << 40) - 1ULL)
#define QRS_MWI_WINDOW 54

static int32_t  xbuf[16];          /* x[i] .. x[i-12]   */
static int32_t  lpbuf[64];         /* lp[i] .. lp[i-32] */
static int32_t  hpbuf[8];          /* hp[i] .. hp[i-4]  */
static uint32_t sqbuf[64];         /* sq[i] .. sq[i-54] */
static uint32_t i64, i16, i8;      /* write indices mod 64 / 16 / 8 */
static int32_t  lp1, lp2;          /* lp[i-1], lp[i-2] */
static int32_t  moving_sum;        /* 32-tap running sum (HPF) */
static uint64_t mwi_sum;           /* 54-tap running sum (MWI), 40 bits */

typedef struct { int32_t hp, dv; uint64_t mwi; } filt_out_t;

__attribute__((noinline))
void qrs_filter(int32_t x, int32_t baseline, filt_out_t *o)
{
    /* low-pass: lp = x - 2x[-6] + x[-12] + 2lp[-1] - lp[-2] */
    int32_t xc = x - baseline;
    xbuf[i16] = xc;
    int32_t x6  = xbuf[(i16 - 6u) & 15u];
    int32_t x12 = xbuf[(i16 - 12u) & 15u];
    int32_t lp = xc - (x6 << 1) + x12 + (lp1 << 1) - lp2;
    lp2 = lp1;
    lp1 = lp;

    /* high-pass: ms += lp - lp[-32]; hp = lp[-16] - (ms >> 5) */
    lpbuf[i64] = lp;
    int32_t lp16 = lpbuf[(i64 - 16u) & 63u];
    int32_t lp32 = lpbuf[(i64 - 32u) & 63u];
    moving_sum = moving_sum + lp - lp32;
    int32_t hp = lp16 - (moving_sum >> 5);

    /* derivative: (2hp + hp[-1] - hp[-3] - 2hp[-4]) >> 3 */
    hpbuf[i8] = hp;
    int32_t h1 = hpbuf[(i8 - 1u) & 7u];
    int32_t h3 = hpbuf[(i8 - 3u) & 7u];
    int32_t h4 = hpbuf[(i8 - 4u) & 7u];
    int32_t num = (hp << 1) + h1 - h3 - (h4 << 1);
    int32_t d = num >> 3;

    /* square: the one multiplier (low 32 bits, as the HLS cast to ap_uint<32>) */
    uint32_t sq = (uint32_t)d * (uint32_t)d;

    /* moving-window integration: running sum over 54 samples (40 bits) */
    sqbuf[i64] = sq;
    uint32_t sq54 = sqbuf[(i64 - QRS_MWI_WINDOW) & 63u];
    mwi_sum = (mwi_sum + sq - sq54) & MASK40;

    i64 = (i64 + 1u) & 63u;
    i16 = (i16 + 1u) & 15u;
    i8  = (i8 + 1u) & 7u;

    o->hp = hp;
    o->dv = d;
    o->mwi = mwi_sum;
}

/* ======================= decision (src/qrs_hw_detector.py) ======================= */
#define LEARN    720
#define REFRACT  72
#define TWAVE    130
#define BP_DELAY 21

static int32_t n_cnt;
static int64_t lmax, lsum;
static int     learning = 1;
static int64_t spki, npki;
static int     rising = 1;
static int64_t prev_mwi, pk_val;
static int32_t pk_idx, pk_slope, pk_bp, pk_ridx;
static int     have_qrs;
static int32_t last_qrs, last_slope;
static int32_t rr_all[8], rr_ok[8];
static int     have_rr;
static int32_t avg1, avg2, rr_low, rr_high, rr_missed;
static int     irregular;
static int     pend_v;
static int64_t pend_val;
static int32_t pend_idx, pend_slope, pend_ridx;

static int64_t mul_learn_mean_half(int64_t s) { return ((s << 6) + (s << 4) + (s << 3) + (s << 1) + s) >> 17; }
static int32_t rr_low_of(int32_t a)    { return a - (a >> 4) - (a >> 6); }
static int32_t rr_high_of(int32_t a)   { return a + (a >> 3) + (a >> 5) + (a >> 8); }
static int32_t rr_missed_of(int32_t a) { return a + (a >> 1) + (a >> 3) + (a >> 5) + (a >> 7); }
static int32_t tenth_of(int32_t a)     { return (a >> 4) + (a >> 5) + (a >> 8) + (a >> 9); }

static int64_t thr1(void) {
    int64_t t = npki + ((spki - npki) >> 2);
    return irregular ? (t >> 1) : t;
}

static void reg_qrs(int64_t val, int32_t idx, int32_t slope, int32_t ridx, int searchback) {
    (void)ridx;
    if (searchback) spki = spki + ((val - spki) >> 2);
    else            spki = spki + ((val - spki) >> 3);
    if (have_qrs) {
        int32_t rr = idx - last_qrs;
        int k;
        if (!have_rr) {
            for (k = 0; k < 8; k++) { rr_all[k] = rr; rr_ok[k] = rr; }
            have_rr = 1;
        } else {
            for (k = 7; k > 0; k--) rr_all[k] = rr_all[k - 1];
            rr_all[0] = rr;
            if (rr_low <= rr && rr <= rr_high) {
                for (k = 7; k > 0; k--) rr_ok[k] = rr_ok[k - 1];
                rr_ok[0] = rr;
            }
        }
        int32_t s1 = 0, s2 = 0;
        for (k = 0; k < 8; k++) { s1 += rr_all[k]; s2 += rr_ok[k]; }
        avg1 = s1 >> 3;
        avg2 = s2 >> 3;
        int32_t diff = (avg1 >= avg2) ? (avg1 - avg2) : (avg2 - avg1);
        irregular = diff > tenth_of(avg2);
        rr_low = rr_low_of(avg2);
        rr_high = rr_high_of(avg2);
        rr_missed = rr_missed_of(avg2);
    }
    have_qrs = 1;
    last_qrs = idx;
    last_slope = slope;
    pend_v = 0;
}

/* returns 1 and sets ridx_o / sb_o when a QRS is decided at this sample */
__attribute__((noinline))
int qrs_decide(int32_t hp, int32_t dv, uint64_t mwi_u, int32_t *ridx_o, int *sb_o)
{
    int32_t n = n_cnt;
    int64_t mwi = (int64_t)(mwi_u & MASK40);
    int32_t abs_hp = hp < 0 ? -hp : hp;
    int32_t abs_dv = dv < 0 ? -dv : dv;
    int det = 0;

    if (learning) {
        if (mwi > lmax) lmax = mwi;
        lsum += mwi;
        if (n == LEARN - 1) {
            spki = lmax >> 2;
            npki = mul_learn_mean_half(lsum);
            learning = 0;
        }
    }
    /* MWI peak tracker: rise to a maximum, then fall to half of it */
    int cand = 0;
    int64_t c_val = 0;
    int32_t c_idx = 0, c_slope = 0, c_ridx = 0;
    if (rising) {
        if (mwi > pk_val) { pk_val = mwi; pk_idx = n; }
        if (abs_dv > pk_slope) pk_slope = abs_dv;
        if (abs_hp > pk_bp) { pk_bp = abs_hp; pk_ridx = n - BP_DELAY; }
        if (pk_val > 0 && mwi <= (pk_val >> 1)) {
            cand = 1; c_val = pk_val; c_idx = pk_idx; c_slope = pk_slope; c_ridx = pk_ridx;
            rising = 0;
        }
    } else if (mwi > prev_mwi) {          /* valley passed: a new rise starts */
        rising = 1;
        pk_val = mwi; pk_idx = n; pk_slope = abs_dv; pk_bp = abs_hp; pk_ridx = n - BP_DELAY;
    }
    prev_mwi = mwi;

    /* classify a candidate peak */
    if (cand && !learning && n >= LEARN) {
        int64_t t1 = thr1();
        int is_qrs = 0;
        int32_t since = c_idx - last_qrs;
        if (!have_qrs || since > REFRACT) {
            if (c_val > t1) {
                if (have_qrs && since < TWAVE) is_qrs = c_slope > (last_slope >> 1);
                else                           is_qrs = 1;
            }
        }
        if (is_qrs) {
            reg_qrs(c_val, c_idx, c_slope, c_ridx, 0);
            det = 1; *ridx_o = c_ridx; *sb_o = 0;
        } else {
            npki = npki + ((c_val - npki) >> 3);
            if ((!have_qrs || since > REFRACT) && (!pend_v || c_val > pend_val)) {
                pend_v = 1; pend_val = c_val; pend_idx = c_idx;
                pend_slope = c_slope; pend_ridx = c_ridx;
            }
        }
    }

    /* search-back with THR2 (checked every sample, causal) */
    if (!det && have_rr && pend_v && (n - last_qrs) > rr_missed) {
        int64_t thr2 = thr1() >> 1;
        if (pend_val > thr2) {
            int32_t r = pend_ridx;
            reg_qrs(pend_val, pend_idx, pend_slope, r, 1);
            det = 1; *ridx_o = r; *sb_o = 1;
        } else {
            pend_v = 0;
        }
    }
    n_cnt = n + 1;
    return det;
}

/* ================================ benchmark ================================ */
int main(void)
{
    uint32_t t0, t1, t2, i0, i1, i2;
    filt_out_t fo;
    int32_t ridx = 0;
    int sb = 0, det;
    uint32_t k;

    /* calibration: empty timed window (same read sequence as the real ones) */
    for (k = 0; k < 4; k++) {
        t0 = rdcycle(); i0 = rdinstret(); BARRIER();
        BARRIER(); t1 = rdcycle(); i1 = rdinstret();
        MB_DATA = 0xCA11B000u | k; MB_DATA = t1 - t0; MB_DATA = i1 - i0;
    }

    /* cost of one CPU read over XBUS -> APB bridge -> APB slave register */
    for (k = 0; k < 4; k++) {
        uint32_t v;
        t0 = rdcycle(); i0 = rdinstret(); BARRIER();
        v = APB_ID;
        BARRIER(); t1 = rdcycle(); i1 = rdinstret();
        MB_DATA = 0xA9B00000u | k; MB_DATA = t1 - t0; MB_DATA = i1 - i0; MB_DATA = v;
    }

    /* per-sample filter + decision */
    for (k = 0; k < NS; k++) {
        int32_t x = ecg_samples[k];
        t0 = rdcycle(); i0 = rdinstret(); BARRIER();
        qrs_filter(x, 1024, &fo);
        BARRIER(); t1 = rdcycle(); i1 = rdinstret(); BARRIER();
        det = qrs_decide(fo.hp, fo.dv, fo.mwi, &ridx, &sb);
        BARRIER(); t2 = rdcycle(); i2 = rdinstret();
        MB_DATA = (uint32_t)fo.hp;
        MB_DATA = (uint32_t)fo.dv;
        MB_DATA = (uint32_t)fo.mwi;
        MB_DATA = (uint32_t)(fo.mwi >> 32);
        MB_DATA = det ? (((uint32_t)ridx << 1) | (uint32_t)sb) : 0xFFFFFFFFu;
        MB_DATA = t1 - t0;
        MB_DATA = t2 - t1;
        MB_DATA = i1 - i0;
        MB_DATA = i2 - i1;
    }
    MB_DONE = 1;
    for (;;) { }
    return 0;
}
