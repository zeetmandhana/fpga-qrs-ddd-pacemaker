/*
 * p17_main.c  --  P17 board firmware for the NEORV32 (RV32I) on the Zybo Z7-10
 *
 * The RV32 is the pacemaker's "programmer/supervisor":
 *   - programs the DDD timing parameters over APB through ddd_set_params()
 *     (range-checked; a rejected set is NEVER written to the hardware);
 *   - selects the demo scenario (MIT-BIH replay or closed-loop heart model);
 *   - services the arrhythmia interrupt (machine external IRQ): when the
 *     PMT guard (SW1) is on it lengthens PVARP by 50 ms (ddd_isr) to break a
 *     pacemaker-mediated tachycardia, then clears the latched flag;
 *   - writes the status lines (mode, rates, parameters, counters) into the
 *     screen text RAM.
 *
 * Board I/O (GPIO in): sw[3:0] = bits 3..0, btn[3:0] = bits 7..4 (debounced)
 *   SW0 pacing enable   SW1 PMT guard (arrhythmia ISR)   SW2 freeze screen (HW)
 *   BTN0 reset (HW)     BTN1 next scenario   BTN2 lower rate 60/70/80 bpm
 *   BTN3 try an out-of-range LRI (shows the range check rejecting it)
 * GPIO out[2:0] = RGB LED (LD6) colour of the current scenario.
 */
#include <neorv32.h>
#include "ddd_pacemaker.h"

#define CLK_HZ       25000000u
#define CTRL_BASE    0x90000100u
#define CTRL(off)    (*(volatile uint32_t *)(CTRL_BASE + (off)))
#define CTRL_MODE    CTRL(0x00)
#define CNT_QRS      CTRL(0x08)
#define CNT_AP       CTRL(0x0C)
#define CNT_VP       CTRL(0x10)
#define CNT_AS       CTRL(0x14)
#define CNT_VS       CTRL(0x18)
#define LAST_RR      CTRL(0x1C)
#define DET_STATUS   CTRL(0x20)
#define CTRL_ID      CTRL(0x24)
#define TXT          ((volatile uint32_t *)0x90004000u)

#define SW_PACE   (1u << 0)
#define SW_GUARD  (1u << 1)
#define BTN_MODE  (1u << 5)
#define BTN_RATE  (1u << 6)
#define BTN_BAD   (1u << 7)

void ddd_isr(void);                          /* ddd_driver.c */
extern volatile uint32_t ddd_arrhythmia_events;

#define N_MODES 6
static const char *const mode_name[N_MODES] = {
    "MIT-BIH RECORD 100 REPLAY (OPEN LOOP)",
    "HEART MODEL: NORMAL SINUS 75 BPM",
    "HEART MODEL: SINUS BRADYCARDIA 40 BPM",
    "HEART MODEL: COMPLETE AV BLOCK",
    "HEART MODEL: AV BLOCK + BRADYCARDIA",
    "HEART MODEL: RETROGRADE VA (PMT RISK)"
};
static const uint32_t mode_rgb[N_MODES] = { 7, 2, 4, 1, 5, 3 };   /* bit0 R bit1 G bit2 B */
static const uint32_t lri_tab[3] = { 1000, 857, 750 };            /* 60 / 70 / 80 bpm */

static int mode = 0, rate_sel = 0;
static uint32_t msg_until = 0;
static volatile int irq_parked = 0;

/* ---------------- screen text helpers (80 x 30, stride 128) ---------------- */
static void txt_puts(int row, int col, const char *s) {
    while (*s && col < 80) TXT[row * 128 + col++] = (uint32_t)(uint8_t)*s++;
}
static void txt_fill(int row, int col, int n) {
    while (n-- > 0 && col < 80) TXT[row * 128 + col++] = ' ';
}
static void txt_num(int row, int col, uint32_t v, int width) {   /* right-aligned */
    char b[11];
    int i = 10;
    b[i] = 0;
    do { b[--i] = (char)('0' + (v % 10u)); v /= 10u; } while (v && i > 0);
    while ((10 - i) < width && i > 0) b[--i] = ' ';
    txt_puts(row, col, &b[i]);
}

static uint32_t now_ms(void) { return (uint32_t)(neorv32_cpu_get_cycle() / (CLK_HZ / 1000u)); }

static uint32_t switches(void) { return neorv32_gpio_port_get() & 0xFFu; }

static void set_enable(void) {
    DDD_CONTROL = (switches() & SW_PACE) ? DDD_CTRL_ENABLE : 0u;
}

/* program the parameter set of the current scenario (range-checked) */
static void apply_mode(void) {
    uint32_t lri   = (mode == 0) ? 1200u : lri_tab[rate_sel];   /* replay: 50 bpm floor */
    uint32_t pvarp = (mode == 5) ? 250u : 320u;                 /* PMT demo: PVARP < VA time */
    DDD_CONTROL = DDD_CTRL_CLR_ARRH;                            /* stop + clear the flag */
    CTRL_MODE = (uint32_t)mode;                                 /* restart heart/ECG/detector */
    ddd_set_params(lri, 180u, 500u, pvarp, 250u);
    set_enable();
    neorv32_gpio_port_set(mode_rgb[mode]);
    irq_parked = 0;
    neorv32_cpu_csr_set(CSR_MIE, 1u << CSR_MIE_MEIE);
}

/* machine external interrupt = DDD arrhythmia flag (level, latched in HW) */
static void arrhythmia_irq_handler(void) {
    if (switches() & SW_GUARD) {
        ddd_isr();                      /* PVARP += 50 ms (max 400), count, clear */
        set_enable();
    } else {
        /* guard off: leave the flag latched (LD3 stays on), mask until SW1 */
        neorv32_cpu_csr_clr(CSR_MIE, 1u << CSR_MIE_MEIE);
        irq_parked = 1;
    }
}

static void draw_static(void) {
    for (int r = 0; r < 30; r++) txt_fill(r, 0, 80);
    txt_puts(0, 1, "P17 PAN-TOMPKINS QRS DETECTOR + DDD PACEMAKER   ZYBO Z7-10   RV32 = NEORV32");
    txt_puts(22, 0, "A");
    txt_puts(23, 0, "V");
    txt_puts(24, 1, "PAN-TOMPKINS MWI (ORANGE) + ADAPTIVE THRESHOLD THR1 (MAGENTA)");
    txt_puts(29, 0, "GREEN ECG  RED QRS  YELLOW A-PACE  CYAN V-PACE  WHITE SENSE | BTN1 MODE BTN2 RATE");
}

static void draw_status(void) {
    uint32_t sw = switches();
    uint32_t rr = LAST_RR;
    txt_fill(1, 0, 80);
    txt_puts(1, 1, "MODE ");
    txt_num(1, 6, (uint32_t)mode + 1u, 1);
    txt_puts(1, 7, "/6 ");
    txt_puts(1, 10, mode_name[mode]);
    txt_puts(1, 49, "HR");
    if ((DET_STATUS & 1u) || rr == 0u) txt_puts(1, 52, "---");
    else txt_num(1, 52, 21600u / rr, 3);                 /* 60 s * 360 Hz / RR */
    txt_puts(1, 56, "BPM");
    txt_puts(1, 61, (sw & SW_PACE) ? "PACING ON " : "PACING OFF");
    txt_puts(1, 72, (sw & SW_GUARD) ? "GUARD ON" : "GUARD --");

    txt_fill(2, 0, 80);
    txt_puts(2, 1, "LRI");   txt_num(2, 5, DDD_LRI, 4);
    txt_puts(2, 10, "AVI");  txt_num(2, 14, DDD_AVI, 3);
    txt_puts(2, 18, "URI");  txt_num(2, 22, DDD_URI, 3);
    txt_puts(2, 26, "PVARP"); txt_num(2, 32, DDD_PVARP, 3);
    txt_puts(2, 36, "VRP");  txt_num(2, 40, DDD_VRP, 3);
    txt_puts(2, 44, "| AP");  txt_num(2, 49, CNT_AP, 4);
    txt_puts(2, 54, "VP");    txt_num(2, 57, CNT_VP, 4);
    txt_puts(2, 62, "QRS");   txt_num(2, 66, CNT_QRS, 4);
    txt_puts(2, 71, "IRQ");   txt_num(2, 75, ddd_arrhythmia_events, 3);
    if (DDD_STATUS & DDD_STAT_ARRHYTHMIA) txt_puts(2, 79, "!");
}

static void message(const char *s) {
    txt_fill(21, 0, 80);
    txt_puts(21, 1, s);
    msg_until = now_ms() + 4000u;
}

int main(void) {
    neorv32_rte_setup();
    neorv32_rte_handler_install(TRAP_CODE_MEI, arrhythmia_irq_handler);
    neorv32_cpu_csr_set(CSR_MSTATUS, 1u << CSR_MSTATUS_MIE);

    draw_static();
    if (CTRL_ID != 0x50170001u) txt_puts(21, 1, "APB DEMO-CONTROL NOT FOUND");
    apply_mode();
    message("RV32 READY: PARAMETERS RANGE-CHECKED AND WRITTEN OVER APB");

    uint32_t prev = switches(), next_draw = 0;
    for (;;) {
        uint32_t cur = switches();
        uint32_t pressed = cur & ~prev;
        if ((cur ^ prev) & SW_PACE) set_enable();
        if ((cur & SW_GUARD) && irq_parked) {             /* guard switched on: service now */
            irq_parked = 0;
            neorv32_cpu_csr_set(CSR_MIE, 1u << CSR_MIE_MEIE);
        }
        if (pressed & BTN_MODE) {
            mode = (mode + 1) % N_MODES;
            apply_mode();
            message("SCENARIO CHANGED: DETECTOR RE-LEARNING THRESHOLDS (2 S)");
        }
        if (pressed & BTN_RATE) {
            rate_sel = (rate_sel + 1) % 3;
            if (mode == 0) message("RATE BUTTON: REPLAY MODE KEEPS LRI 1200 MS");
            else if (ddd_set_params(lri_tab[rate_sel], DDD_AVI, DDD_URI, DDD_PVARP, DDD_VRP) == DDD_OK)
                message("NEW LOWER RATE ACCEPTED (RANGE CHECK OK) AND WRITTEN OVER APB");
        }
        if (pressed & BTN_BAD) {
            ddd_status_t st = ddd_set_params(300u, DDD_AVI, DDD_URI, DDD_PVARP, DDD_VRP);
            message(st == DDD_OK ? "ERROR: BAD LRI WAS ACCEPTED"
                                 : "RANGE CHECK: LRI 300 MS REJECTED (400-2000) - NOT WRITTEN");
        }
        prev = cur;

        uint32_t t = now_ms();
        if ((int32_t)(t - next_draw) >= 0) {
            draw_status();
            if (msg_until && (int32_t)(t - msg_until) >= 0) { txt_fill(21, 0, 80); msg_until = 0; }
            next_draw = t + 200u;
        }
    }
    return 0;
}
