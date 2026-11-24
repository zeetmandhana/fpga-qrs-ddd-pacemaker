/*
 * ddd_driver.c  --  P17 Phase 6: RV32 firmware for the DDD pacemaker
 *
 * Range-checks the timing parameters (the software guard the project spec asks
 * for) and programs them into the APB peripheral; handles the arrhythmia
 * interrupt. Mirrors the range check in src/pacemaker.py::DDDParameters.validate.
 *
 * Bare-metal C for a RISC-V (e.g. NEORV32) soft core. No OS assumed.
 */

#include "ddd_pacemaker.h"

/* Program the (range-checked) timing parameters. Returns DDD_OK or an error. */
ddd_status_t ddd_set_params(uint32_t lri, uint32_t avi, uint32_t uri,
                            uint32_t pvarp, uint32_t vrp)
{
    if (lri   < 400u || lri   > 2000u) return DDD_ERR_LRI;
    if (avi   <  30u || avi   >  350u) return DDD_ERR_AVI;
    if (uri   < 300u || uri   > lri)   return DDD_ERR_URI;
    if (pvarp < 150u || pvarp >  500u) return DDD_ERR_PVARP;
    if (vrp   < 150u || vrp   >  400u) return DDD_ERR_VRP;
    if (avi >= lri || uri < avi)       return DDD_ERR_ORDER;

    DDD_LRI   = lri;
    DDD_AVI   = avi;
    DDD_URI   = uri;
    DDD_PVARP = pvarp;
    DDD_VRP   = vrp;
    return DDD_OK;
}

void ddd_enable(void)  { DDD_CONTROL = DDD_CTRL_ENABLE; }
void ddd_disable(void) { DDD_CONTROL = 0u; }

int ddd_arrhythmia(void) { return (DDD_STATUS & DDD_STAT_ARRHYTHMIA) ? 1 : 0; }

void ddd_clear_arrhythmia(void)
{
    /* keep running (enable) and write-1-to-clear the latched flag */
    DDD_CONTROL = DDD_CTRL_ENABLE | DDD_CTRL_CLR_ARRH;
    DDD_CONTROL = DDD_CTRL_ENABLE;
}

/*
 * Arrhythmia interrupt handler. The hardware raises the IRQ when the ventricle
 * is driven at the upper-rate limit (possible pacemaker-mediated tachycardia).
 * A real device would mode-switch / extend PVARP here; we log and clear.
 */
volatile uint32_t ddd_arrhythmia_events = 0;

void ddd_isr(void)
{
    if (ddd_arrhythmia()) {
        ddd_arrhythmia_events++;
        /* PMT response: lengthen PVARP once to break 1:1 retrograde tracking */
        if (DDD_PVARP < 400u) DDD_PVARP = DDD_PVARP + 50u;
        ddd_clear_arrhythmia();
    }
}

/* Demo entry point: program the default DDD settings and start pacing.
 * (The Zybo board firmware p17_main.c has its own main and builds this file
 * with -DDDD_NO_MAIN.) */
#ifndef DDD_NO_MAIN
int main(void)
{
    ddd_status_t st = ddd_set_params(/*LRI*/1000, /*AVI*/180, /*URI*/500,
                                     /*PVARP*/320, /*VRP*/250);
    if (st != DDD_OK) {
        /* bad parameters were rejected -- do not program unsafe timing */
        for (;;) { /* fault: halt (a real device keeps the previous safe set) */ }
    }
    ddd_enable();
    for (;;) {
        /* main loop: the pacemaker runs in hardware; the CPU services the
         * arrhythmia IRQ and any host/telemetry commands. */
    }
    return 0;
}
#endif /* DDD_NO_MAIN */
