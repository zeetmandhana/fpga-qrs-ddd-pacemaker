`timescale 1ns/1ps
//============================================================================
// qrs_decision.v  --  P17 board phase: streaming Pan-Tompkins decision stage
//
// Hardware port of src/qrs_hw_detector.py::HwQrsDecision.step, checked bit for
// bit by tb_qrs_detector.v. One update per input sample (in_valid pulse); the
// Python step() is executed as a short sequence of FSM phases (there are
// ~69,000 clocks per 360 Hz sample, so the extra cycles cost nothing and keep
// every combinational path short).
//
//   P_TRACK : learning (first 2 s) + MWI peak tracker ("rise, then fall to 1/2")
//   P_CLASS : classify a candidate peak against THR1 (+ refractory, T-wave)
//   P_REG   : register a QRS  -> SPKI update, RR buffers
//   P_AVG   : RR averages
//   P_LIM   : irregular flag, RR limits, emit the detection
//   P_SB    : search-back with THR2 (only when no QRS was found this sample)
//
// Only adds, subtracts, compares and shifts: no multiplier, no divider.
//============================================================================
module qrs_decision_custom (
    input  wire               clk,
    input  wire               rst_n,       // also pulsed low to re-learn
    input  wire               in_valid,    // one pulse per sample
    input  wire signed [31:0] hp,          // band-pass output
    input  wire signed [31:0] dv,          // derivative output
    input  wire        [39:0] mwi,         // moving-window integral (sum)
    output reg                det,         // 1-clock pulse: QRS decided
    output reg         [31:0] det_r,       // R-peak sample index
    output reg                det_sb,      // found by search-back
    output reg         [31:0] n_cnt,       // samples processed so far
    output wire        [39:0] thr1_o,      // current THR1 (for the display)
    output wire        [39:0] spki_o,
    output wire               learning_o
);
    localparam [31:0] LEARN    = 32'd720;
    localparam [31:0] REFRACT  = 32'd72;
    localparam [31:0] TWAVE    = 32'd130;
    localparam [31:0] BP_DELAY = 32'd21;

    localparam [2:0] P_IDLE=3'b000, P_TRACK=3'b001, P_CLASS=3'b010, P_REG=3'b100, P_AVG=3'b011,
                     P_LIM=3'b110, P_SB=3'b111, P_END=3'b101;   // custom (exhaustive-search) codes
    (* fsm_encoding = "none" *) reg [2:0] ph;

    // ---------------- state (names follow the Python model) ----------------
    reg        [39:0] lmax;
    reg        [59:0] lsum;
    reg               learning;
    reg        [39:0] spki, npki;
    reg               rising;
    reg        [39:0] prev_mwi, pk_val;
    reg        [31:0] pk_idx, pk_slope, pk_bp, pk_ridx;
    reg               have_qrs;
    reg        [31:0] last_qrs, last_slope;
    reg        [31:0] rr_all [0:7];
    reg        [31:0] rr_ok  [0:7];
    reg               have_rr;
    reg        [31:0] avg1, avg2;
    reg        [33:0] rr_low, rr_high, rr_missed;
    reg               irregular;
    reg               pend_v;
    reg        [39:0] pend_val;
    reg        [31:0] pend_idx, pend_slope, pend_ridx;

    // per-sample working registers
    reg        [39:0] s_mwi;
    reg        [31:0] s_ahp, s_adv;
    reg               cand_v;
    reg        [39:0] cand_val;
    reg        [31:0] cand_idx, cand_slope, cand_ridx;
    reg               r_go, r_sb, r_upd;            // register request
    reg        [39:0] r_val;
    reg        [31:0] r_idx, r_slope, r_ridx;
    reg               det_now;                      // a QRS was found this sample
    reg               sb_done;                      // search-back already used

    // ---------------- helpers ----------------
    // THR1 = NPKI + (SPKI-NPKI)/4, halved when irregular (arithmetic shifts)
    wire signed [41:0] spki_s = {2'b00, spki};
    wire signed [41:0] npki_s = {2'b00, npki};
    wire signed [41:0] thr1_full = npki_s + ((spki_s - npki_s) >>> 2);
    wire        [39:0] thr1 = irregular ? thr1_full[40:1] : thr1_full[39:0];
    assign thr1_o = thr1;
    assign spki_o = spki;
    assign learning_o = learning;

    wire [31:0] abs_hp = hp[31] ? (~hp + 32'd1) : hp;
    wire [31:0] abs_dv = dv[31] ? (~dv + 32'd1) : dv;

    // learning: lmax/lsum including the current sample
    wire [39:0] lmax_n = (s_mwi > lmax) ? s_mwi : lmax;
    wire [59:0] lsum_n = lsum + {20'd0, s_mwi};
    // NPKI init = lsum * 91 >> 17  (91 = 64+16+8+2+1)
    wire [66:0] lsum91 = ({7'd0, lsum_n} << 6) + ({7'd0, lsum_n} << 4) +
                         ({7'd0, lsum_n} << 3) + ({7'd0, lsum_n} << 1) + {7'd0, lsum_n};
    wire [49:0] npki_init = lsum91[66:17];

    // RR averages and limits
    wire [34:0] sum_all = rr_all[0] + rr_all[1] + rr_all[2] + rr_all[3] +
                          rr_all[4] + rr_all[5] + rr_all[6] + rr_all[7];
    wire [34:0] sum_ok  = rr_ok[0] + rr_ok[1] + rr_ok[2] + rr_ok[3] +
                          rr_ok[4] + rr_ok[5] + rr_ok[6] + rr_ok[7];
    wire [33:0] a2 = {2'b00, avg2};
    wire [33:0] tenth   = (a2 >> 4) + (a2 >> 5) + (a2 >> 8) + (a2 >> 9);
    wire [33:0] low_n   = a2 - (a2 >> 4) - (a2 >> 6);
    wire [33:0] high_n  = a2 + (a2 >> 3) + (a2 >> 5) + (a2 >> 8);
    wire [33:0] miss_n  = a2 + (a2 >> 1) + (a2 >> 3) + (a2 >> 5) + (a2 >> 7);
    wire [31:0] avg_dif = (avg1 >= avg2) ? (avg1 - avg2) : (avg2 - avg1);

    // classification of the candidate
    wire [31:0] since    = cand_idx - last_qrs;
    wire        refr_ok  = (!have_qrs) || (since > REFRACT);
    wire        above1   = (cand_val > thr1);
    wire        tw_test  = have_qrs && (since < TWAVE);
    wire        is_qrs   = refr_ok && above1 &&
                           (tw_test ? (cand_slope > (last_slope >> 1)) : 1'b1);
    wire        cls_en   = cand_v && (n_cnt >= LEARN);
    // noise-peak update NPKI += (peak - NPKI)/8 (all operands signed -> arithmetic shift)
    wire signed [41:0] cval_s   = {2'b00, cand_val};
    wire signed [41:0] npki_upd = npki_s + ((cval_s - npki_s) >>> 3);

    // register: SPKI update and the new RR interval
    wire signed [41:0] rval_s = {2'b00, r_val};
    wire signed [41:0] spki_upd = spki_s + (r_sb ? ((rval_s - spki_s) >>> 2)
                                                 : ((rval_s - spki_s) >>> 3));
    wire        [31:0] rr     = r_idx - last_qrs;
    wire               rr_in  = ({2'b00, rr} >= rr_low) && ({2'b00, rr} <= rr_high);

    // search-back
    wire [31:0] gap   = n_cnt - last_qrs;
    wire        sb_en = have_rr && pend_v && ({2'b00, gap} > rr_missed);
    wire [39:0] thr2  = thr1 >> 1;

    integer k;
    always @(posedge clk) begin
        if (!rst_n) begin
            ph <= P_IDLE; det <= 1'b0; det_r <= 32'd0; det_sb <= 1'b0; n_cnt <= 32'd0;
            lmax <= 0; lsum <= 0; learning <= 1'b1; spki <= 0; npki <= 0;
            rising <= 1'b1; prev_mwi <= 0; pk_val <= 0; pk_idx <= 0; pk_slope <= 0;
            pk_bp <= 0; pk_ridx <= 0;
            have_qrs <= 1'b0; last_qrs <= 0; last_slope <= 0;
            for (k = 0; k < 8; k = k + 1) begin rr_all[k] <= 0; rr_ok[k] <= 0; end
            have_rr <= 1'b0; avg1 <= 0; avg2 <= 0; rr_low <= 0; rr_high <= 0;
            rr_missed <= 0; irregular <= 1'b0;
            pend_v <= 1'b0; pend_val <= 0; pend_idx <= 0; pend_slope <= 0; pend_ridx <= 0;
            s_mwi <= 0; s_ahp <= 0; s_adv <= 0; cand_v <= 1'b0; cand_val <= 0;
            cand_idx <= 0; cand_slope <= 0; cand_ridx <= 0;
            r_go <= 1'b0; r_sb <= 1'b0; r_upd <= 1'b0; r_val <= 0; r_idx <= 0;
            r_slope <= 0; r_ridx <= 0; det_now <= 1'b0; sb_done <= 1'b0;
        end else begin
            det <= 1'b0;
            case (ph)
            P_IDLE: if (in_valid) begin
                s_mwi <= mwi; s_ahp <= abs_hp; s_adv <= abs_dv;
                det_now <= 1'b0; sb_done <= 1'b0; r_go <= 1'b0;
                ph <= P_TRACK;
            end
            // ---- learning + MWI peak tracker ----
            P_TRACK: begin
                if (learning) begin
                    lmax <= lmax_n;
                    lsum <= lsum_n;
                    if (n_cnt == LEARN - 1) begin
                        spki <= lmax_n >> 2;
                        npki <= npki_init[39:0];
                        learning <= 1'b0;
                    end
                end
                cand_v <= 1'b0;
                if (rising) begin : rise
                    reg [39:0] pv;
                    pv = pk_val;
                    if (s_mwi > pk_val) begin pv = s_mwi; pk_val <= s_mwi; pk_idx <= n_cnt; end
                    if (s_adv > pk_slope) pk_slope <= s_adv;
                    if (s_ahp > pk_bp) begin pk_bp <= s_ahp; pk_ridx <= n_cnt - BP_DELAY; end
                    if ((pv != 0) && (s_mwi <= (pv >> 1))) begin
                        cand_v     <= 1'b1;
                        cand_val   <= pv;
                        cand_idx   <= (s_mwi > pk_val) ? n_cnt : pk_idx;
                        cand_slope <= (s_adv > pk_slope) ? s_adv : pk_slope;
                        cand_ridx  <= (s_ahp > pk_bp) ? (n_cnt - BP_DELAY) : pk_ridx;
                        rising <= 1'b0;
                    end
                end else if (s_mwi > prev_mwi) begin
                    rising <= 1'b1;
                    pk_val <= s_mwi; pk_idx <= n_cnt; pk_slope <= s_adv;
                    pk_bp <= s_ahp; pk_ridx <= n_cnt - BP_DELAY;
                end
                prev_mwi <= s_mwi;
                ph <= P_CLASS;
            end
            // ---- classify the candidate ----
            P_CLASS: begin
                if (cls_en) begin
                    if (is_qrs) begin
                        r_go <= 1'b1; r_sb <= 1'b0; r_val <= cand_val; r_idx <= cand_idx;
                        r_slope <= cand_slope; r_ridx <= cand_ridx;
                        det_now <= 1'b1;
                    end else begin
                        npki <= npki_upd[39:0];
                        if (refr_ok && ((!pend_v) || (cand_val > pend_val))) begin
                            pend_v <= 1'b1; pend_val <= cand_val; pend_idx <= cand_idx;
                            pend_slope <= cand_slope; pend_ridx <= cand_ridx;
                        end
                    end
                end
                ph <= P_REG;
            end
            // ---- register a QRS (SPKI, RR buffers) ----
            P_REG: begin
                r_upd <= 1'b0;
                if (r_go) begin
                    spki <= spki_upd[39:0];
                    if (have_qrs) begin
                        r_upd <= 1'b1;
                        if (!have_rr) begin
                            for (k = 0; k < 8; k = k + 1) begin rr_all[k] <= rr; rr_ok[k] <= rr; end
                            have_rr <= 1'b1;
                        end else begin
                            rr_all[0] <= rr;
                            for (k = 1; k < 8; k = k + 1) rr_all[k] <= rr_all[k-1];
                            if (rr_in) begin
                                rr_ok[0] <= rr;
                                for (k = 1; k < 8; k = k + 1) rr_ok[k] <= rr_ok[k-1];
                            end
                        end
                    end
                    have_qrs <= 1'b1; last_qrs <= r_idx; last_slope <= r_slope;
                    pend_v <= 1'b0;
                end
                ph <= P_AVG;
            end
            P_AVG: begin
                if (r_upd) begin
                    avg1 <= sum_all[34:3];
                    avg2 <= sum_ok[34:3];
                end
                ph <= P_LIM;
            end
            P_LIM: begin
                if (r_upd) begin
                    irregular <= ({2'b00, avg_dif} > tenth);
                    rr_low <= low_n; rr_high <= high_n; rr_missed <= miss_n;
                end
                if (r_go) begin
                    det <= 1'b1; det_r <= r_ridx; det_sb <= r_sb;
                end
                r_go <= 1'b0; r_upd <= 1'b0;
                ph <= (det_now || sb_done) ? P_END : P_SB;
            end
            // ---- search-back with THR2 ----
            P_SB: begin
                ph <= P_END;
                if (sb_en) begin
                    if (pend_val > thr2) begin
                        r_go <= 1'b1; r_sb <= 1'b1; r_val <= pend_val; r_idx <= pend_idx;
                        r_slope <= pend_slope; r_ridx <= pend_ridx;
                        sb_done <= 1'b1;
                        ph <= P_REG;
                    end else begin
                        pend_v <= 1'b0;
                    end
                end
            end
            P_END: begin
                n_cnt <= n_cnt + 32'd1;
                ph <= P_IDLE;
            end
            default: ph <= P_IDLE;
            endcase
        end
    end
endmodule
