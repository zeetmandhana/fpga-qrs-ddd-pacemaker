`timescale 1ns/1ps
//============================================================================
// qrs_baselines.v  --  VL401 report Section 9: the two non-adaptive baselines
//
//   qrs_base_thr  B0: fixed threshold on the raw ECG (x = adc - 1024 > T0),
//                 rising crossing + 200 ms (72-sample) refractory period.
//                 This is the Phase-6 demo detector, made streaming.
//   qrs_base_mwi  B1: Pan-Tompkins filter chain (the same Vitis-HLS qrs_stream
//                 IP as the board) + a FIXED threshold T1 on the moving-window
//                 integral instead of the paper's adaptive dual thresholds.
//
// Both report det (1-clock pulse) and det_n = index of the sample that
// crossed. Bit-exact with report/work/paper/baseline_eval.py::crossings().
//============================================================================

// shared rising-crossing + refractory rule (one update per sample)
module qrs_cross_refract #(
    parameter REFRACT = 72
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        step,        // one pulse per sample
    input  wire        above,       // sample > threshold
    output reg         det,
    output reg  [31:0] det_n
);
    reg        above_q;             // previous sample above? (1 at reset: no rise at n=0)
    reg  [6:0] since;               // samples since the last detection, saturating
    reg [31:0] n;                   // index of the current sample
    wire [7:0] d = {1'b0, since} + 8'd1;
    always @(posedge clk) begin
        if (!rst_n) begin
            above_q <= 1'b1; since <= REFRACT[6:0]; n <= 32'd0; det <= 1'b0; det_n <= 32'd0;
        end else begin
            det <= 1'b0;
            if (step) begin
                above_q <= above;
                n <= n + 32'd1;
                if (above && !above_q && d >= REFRACT) begin
                    det <= 1'b1; det_n <= n; since <= 7'd0;
                end else begin
                    since <= (d >= REFRACT) ? REFRACT[6:0] : d[6:0];
                end
            end
        end
    end
endmodule

module qrs_base_thr #(
    parameter signed [11:0] T0 = 12'sd55
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sample_valid,
    input  wire [10:0] adc,
    output wire        det,
    output wire [31:0] det_n
);
    wire signed [11:0] x = $signed({1'b0, adc}) - 12'sd1024;
    qrs_cross_refract u_cr (.clk(clk), .rst_n(rst_n), .step(sample_valid),
                            .above(x > T0), .det(det), .det_n(det_n));
endmodule

module qrs_base_mwi #(
    parameter [39:0] T1 = 40'd476144
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sample_valid,
    input  wire [10:0] adc,
    output wire        det,
    output wire [31:0] det_n
);
    reg         ap_start;
    wire        ap_done, ap_idle, ap_ready;
    wire [31:0] hp_w, dv_w;
    wire [39:0] mwi_w;
    wire        hp_vld, dv_vld, mwi_vld;
    reg  [15:0] x_q;
    always @(posedge clk) begin
        if (!rst_n) begin
            ap_start <= 1'b0; x_q <= 16'd0;
        end else if (sample_valid) begin
            x_q <= {5'd0, adc}; ap_start <= 1'b1;
        end else if (ap_ready) begin
            ap_start <= 1'b0;
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
    qrs_cross_refract u_cr (.clk(clk), .rst_n(rst_n), .step(mwi_vld),
                            .above(mwi_w > T1), .det(det), .det_n(det_n));
endmodule
