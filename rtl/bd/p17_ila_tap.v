`timescale 1ns/1ps
//============================================================================
// p17_ila_tap.v  --  one ILA record per 360 Hz ECG sample (board demo without a monitor)
//
// The system runs at 25 MHz but the ECG has only 360 samples/s, so an ILA
// sampling every clock would fill its memory in a fraction of a millisecond.
// This block builds one record per ECG sample and pulses rec_stb with it; the
// ILA uses rec_stb as its CAPTURE QUALIFIER, so 8192 ILA entries = 8192 ECG
// samples = 22.7 s.
//
// A record emitted with sample k holds
//   rec_ecg       raw 11-bit ECG code of sample k (what the detector and HDMI see)
//   rec_qrs ...   1 if that event (QRS detected, AP, VP, AS, VS) happened since
//                 the previous record (the 1-clock event pulses are latched)
//   rec_qrs_delay at a QRS: how many samples before sample k-1 the R peak was
//                 (the detector decides ~210 ms after the R peak), so the R peak
//                 is at record index k-1-rec_qrs_delay
//   rec_mode      demo scenario (0 = MIT-BIH replay, 1..5 heart model)
//   rec_mwi/thr   Pan-Tompkins moving-window integral and adaptive threshold
//                 THR1, both >>4 and saturated to 24 bits
//   rec_n         16-bit record counter (continuity check)
//============================================================================
module p17_ila_tap (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        adc_valid,
    input  wire [10:0] adc,
    input  wire        det,
    input  wire [31:0] qrs_delay,
    input  wire        ap,
    input  wire        vp,
    input  wire        as_evt,
    input  wire        vs_evt,
    input  wire [2:0]  mode,
    input  wire [39:0] mwi_q,
    input  wire [39:0] thr1,
    output reg         rec_stb,
    output reg  [10:0] rec_ecg,
    output reg         rec_qrs,
    output reg         rec_ap,
    output reg         rec_vp,
    output reg         rec_as,
    output reg         rec_vs,
    output reg  [11:0] rec_qrs_delay,
    output reg  [2:0]  rec_mode,
    output reg  [23:0] rec_mwi,
    output reg  [23:0] rec_thr,
    output reg  [15:0] rec_n
);
    reg        s_qrs, s_ap, s_vp, s_as, s_vs;
    reg [11:0] s_dly;

    function [23:0] sat24(input [39:0] x);
        sat24 = (|x[39:28]) ? 24'hFFFFFF : x[27:4];
    endfunction

    always @(posedge clk) begin
        if (!rst_n) begin
            rec_stb <= 1'b0; rec_ecg <= 0; rec_qrs <= 0; rec_ap <= 0; rec_vp <= 0;
            rec_as <= 0; rec_vs <= 0; rec_qrs_delay <= 0; rec_mode <= 0;
            rec_mwi <= 0; rec_thr <= 0; rec_n <= 0;
            s_qrs <= 0; s_ap <= 0; s_vp <= 0; s_as <= 0; s_vs <= 0; s_dly <= 0;
        end else begin
            rec_stb <= 1'b0;
            if (adc_valid) begin
                // emit the record for this sample with the events seen since the last one
                rec_stb <= 1'b1;
                rec_ecg <= adc;
                rec_qrs <= s_qrs | det;   rec_ap <= s_ap | ap;   rec_vp <= s_vp | vp;
                rec_as  <= s_as | as_evt; rec_vs <= s_vs | vs_evt;
                rec_qrs_delay <= det ? qrs_delay[11:0] : s_dly;
                rec_mode <= mode;
                rec_mwi  <= sat24(mwi_q);
                rec_thr  <= sat24(thr1);
                rec_n    <= rec_n + 1'b1;
                s_qrs <= 0; s_ap <= 0; s_vp <= 0; s_as <= 0; s_vs <= 0; s_dly <= 0;
            end else begin
                if (det)    begin s_qrs <= 1'b1; s_dly <= qrs_delay[11:0]; end
                if (ap)     s_ap <= 1'b1;
                if (vp)     s_vp <= 1'b1;
                if (as_evt) s_as <= 1'b1;
                if (vs_evt) s_vs <= 1'b1;
            end
        end
    end
endmodule
