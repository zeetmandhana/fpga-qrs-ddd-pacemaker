/*
 * ddd_pacemaker.h  --  P17 Phase 6: RV32 driver for the DDD pacemaker APB slave
 *
 * Register map (byte offsets from DDD_BASE); see rtl/ddd_pacemaker_apb.v.
 */
#ifndef DDD_PACEMAKER_H
#define DDD_PACEMAKER_H

#include <stdint.h>

/* APB base address of the DDD peripheral (set to match the block design). */
#ifndef DDD_BASE
#define DDD_BASE 0x90000000u
#endif

#define DDD_REG(off) (*(volatile uint32_t *)(DDD_BASE + (off)))
#define DDD_LRI      DDD_REG(0x00)
#define DDD_AVI      DDD_REG(0x04)
#define DDD_URI      DDD_REG(0x08)
#define DDD_PVARP    DDD_REG(0x0C)
#define DDD_VRP      DDD_REG(0x10)
#define DDD_CONTROL  DDD_REG(0x14)   /* bit0 enable, bit1 clear-arrhythmia (W1C) */
#define DDD_STATUS   DDD_REG(0x18)   /* bit0 arrhythmia, b1 ap, b2 vp, b3 as, b4 vs */

#define DDD_CTRL_ENABLE      (1u << 0)
#define DDD_CTRL_CLR_ARRH    (1u << 1)
#define DDD_STAT_ARRHYTHMIA  (1u << 0)

/* Return codes for ddd_set_params(). */
typedef enum {
    DDD_OK = 0,
    DDD_ERR_LRI, DDD_ERR_AVI, DDD_ERR_URI, DDD_ERR_PVARP, DDD_ERR_VRP,
    DDD_ERR_ORDER
} ddd_status_t;

ddd_status_t ddd_set_params(uint32_t lri, uint32_t avi, uint32_t uri,
                            uint32_t pvarp, uint32_t vrp);
void ddd_enable(void);
void ddd_disable(void);
int  ddd_arrhythmia(void);          /* 1 if the latched flag is set */
void ddd_clear_arrhythmia(void);

#endif /* DDD_PACEMAKER_H */
