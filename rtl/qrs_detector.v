`timescale 1ns/1ps
//============================================================================
// qrs_detector.v  --  P17 board phase: complete Pan-Tompkins QRS detector
//
//   ADC sample --> qrs_stream (Vitis-HLS filter chain, ONE multiplier)
//              --> qrs_decision (hand RTL adaptive thresholds)
//
// sample_valid: one pulse per 360 Hz sample with `adc` (raw 11-bit code).
// det: 1-clock pulse when a QRS is decided; det_r = R-peak sample index.
// The HLS block is started once per sample (ap_ctrl_hs); its outputs are
// captured on their ap_vld strobes and handed to the decision FSM.
//============================================================================
module qrs_detector (
    input  wire        clk,
    input  wire        rst_n,          // full reset (filter + decision)
    input  wire        relearn_n,      // low pulse: restart the 2 s learning only
    input  wire        sample_valid,
    input  wire [10:0] adc,
    output wire        det,
    output wire [31:0] det_r,
    output wire        det_sb,
    output wire [31:0] n_cnt,
    output reg  [39:0] mwi_q,          // latest MWI (for the display)
    output wire [39:0] thr1,
    output wire [39:0] spki,
    output wire        learning
);
    // ---- HLS filter chain ----
    reg         ap_start;
    wire        ap_done, ap_idle, ap_ready;
    wire [31:0] hp_w, dv_w;
    wire [39:0] mwi_w;
    wire        hp_vld, dv_vld, mwi_vld;
    reg  [15:0] x_q;

    always @(posedge clk) begin
        if (!rst_n) begin
            ap_start <= 1'b0; x_q <= 16'd0;
        end else begin
            if (sample_valid) begin
                x_q <= {5'd0, adc};
                ap_start <= 1'b1;
            end else if (ap_ready) begin
                ap_start <= 1'b0;
            end
        end
    end

    qrs_stream u_hls (
        .ap_clk(clk), .ap_rst(~rst_n), .ap_start(ap_start),
        .ap_done(ap_done), .ap_idle(ap_idle), .ap_ready(ap_ready),
        .x(x_q), .baseline(32'd1024),
        .hp_out(hp_w), .hp_out_ap_vld(hp_vld),
        .dv_out(dv_w), .dv_out_ap_vld(dv_vld),
        .mwi_out(mwi_w), .mwi_out_ap_vld(mwi_vld)
    );

    // capture the three outputs (they may arrive on different cycles)
    reg [31:0] hp_q, dv_q;
    reg        got_hp, got_dv, got_mwi, dec_valid;
    always @(posedge clk) begin
        if (!rst_n) begin
            hp_q <= 0; dv_q <= 0; mwi_q <= 0;
            got_hp <= 0; got_dv <= 0; got_mwi <= 0; dec_valid <= 0;
        end else begin
            dec_valid <= 1'b0;
            if (hp_vld)  begin hp_q  <= hp_w;  got_hp  <= 1'b1; end
            if (dv_vld)  begin dv_q  <= dv_w;  got_dv  <= 1'b1; end
            if (mwi_vld) begin mwi_q <= mwi_w; got_mwi <= 1'b1; end
            if (got_hp && got_dv && got_mwi) begin
                dec_valid <= 1'b1;
                got_hp <= 1'b0; got_dv <= 1'b0; got_mwi <= 1'b0;
            end
        end
    end

    // ---- decision stage ----
    qrs_decision u_dec (
        .clk(clk), .rst_n(rst_n & relearn_n), .in_valid(dec_valid),
        .hp(hp_q), .dv(dv_q), .mwi(mwi_q),
        .det(det), .det_r(det_r), .det_sb(det_sb), .n_cnt(n_cnt),
        .thr1_o(thr1), .spki_o(spki), .learning_o(learning)
    );
endmodule
