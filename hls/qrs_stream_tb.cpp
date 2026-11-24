// P17 board phase -- C testbench for the streaming HLS filter chain.
// Feeds record-100 samples one call at a time and checks hp, dv and mwi
// BIT-EXACT against the Python fixed-point golden model.

#include <cstdio>
#include "qrs_stream.h"

#define TB_DATA "C:/Vivadoproject/P17_QRS_Pacemaker/hls/tb_data"
#define BASELINE 1024

int main() {
    FILE *fin = fopen(TB_DATA "/stream_rec100_input.txt", "r");
    FILE *fex = fopen(TB_DATA "/stream_rec100_expected.txt", "r");
    if (!fin || !fex) { printf("ERROR: cannot open stream test vectors in %s\n", TB_DATA); return 1; }

    int n = 0, mism = 0;
    long long v, eh, ed, em;
    while (fscanf(fin, "%lld", &v) == 1 && fscanf(fex, "%lld %lld %lld", &eh, &ed, &em) == 3) {
        filt_t hp, dv;
        mwi_t mwi;
        qrs_stream((sample_t)v, (filt_t)BASELINE, &hp, &dv, &mwi);
        long long gh = (long long)hp, gd = (long long)dv, gm = (long long)mwi;
        if (gh != eh || gd != ed || gm != em) {
            if (mism < 10)
                printf("  MISMATCH i=%d hp %lld/%lld dv %lld/%lld mwi %lld/%lld\n",
                       n, gh, eh, gd, ed, gm, em);
            mism++;
        }
        n++;
    }
    fclose(fin);
    fclose(fex);
    printf("Checked %d samples (hp, dv, mwi), %d mismatches\n", n, mism);
    if (n > 0 && mism == 0) {
        printf("BIT-EXACT PASS: streaming HLS filter matches the Python golden model\n");
        return 0;
    }
    printf("BIT-EXACT FAIL\n");
    return 1;
}
