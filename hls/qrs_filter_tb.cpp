// P17 Phase 4 -- C testbench for the HLS filter chain.
// Reads the record-100 ADC input and the expected MWI produced by the Python
// fixed-point golden model, runs the HLS filter, and checks BIT-EXACT equality.

#include <cstdio>
#include "qrs_filter.h"

// Absolute path so csim finds the vectors regardless of its build directory.
#define TB_DATA "C:/Vivadoproject/P17_QRS_Pacemaker/hls/tb_data"
#define BASELINE 1024

static sample_t x[QRS_MAX_N];
static acc_t    mwi[QRS_MAX_N];

int main() {
    FILE *fin = fopen(TB_DATA "/rec100_input.txt", "r");
    if (!fin) { printf("ERROR: cannot open %s/rec100_input.txt\n", TB_DATA); return 1; }
    int n = 0;
    long long v;
    while (n < QRS_MAX_N && fscanf(fin, "%lld", &v) == 1) x[n++] = (sample_t)v;
    fclose(fin);
    printf("Loaded %d input samples\n", n);

    qrs_filter(x, mwi, n, (filt_t)BASELINE);

    FILE *fexp = fopen(TB_DATA "/rec100_expected_mwi.txt", "r");
    if (!fexp) { printf("ERROR: cannot open expected MWI\n"); return 1; }

    int mismatches = 0, i = 0;
    for (i = 0; i < n; i++) {
        long long expected;
        if (fscanf(fexp, "%lld", &expected) != 1) break;
        long long got = (long long)mwi[i];
        if (got != expected) {
            if (mismatches < 10)
                printf("  MISMATCH i=%d got=%lld expected=%lld\n", i, got, expected);
            mismatches++;
        }
    }
    fclose(fexp);

    printf("Checked %d samples, %d mismatches\n", i, mismatches);
    if (mismatches == 0) {
        printf("BIT-EXACT PASS: HLS filter chain matches the Python golden model\n");
        return 0;
    }
    printf("BIT-EXACT FAIL\n");
    return 1;
}
