`timescale 1ns/1ps
//============================================================================
// tb_hw_cycles.v -- clock cycles per sample of the on-chip detector path
// (rtl/qrs_detector.v = Vitis-HLS qrs_stream + RTL qrs_decision), the same
// RTL that runs on the Zybo at 25 MHz.
//
// For every sample it measures, at clock-edge resolution:
//   A  sample accepted (sample_valid sampled)      -> ap_start seen high
//   H  HLS: ap_start seen                          -> ap_done seen
//   C  filter outputs captured                     -> dec_valid seen
//   D  decision FSM: dec_valid seen                -> FSM back in P_IDLE
// and checks every detection against the golden events (bit-exact), so the
// counted run is a correct run.
//============================================================================
`ifndef TB_DIR
`define TB_DIR "C:/Vivadoproject/P17_QRS_Pacemaker/rtl/tb_data/"
`endif

module tb_hw_cycles;
    localparam SPACING = 64;
    localparam NS = 100000;

    reg clk = 0;
    always #20 clk = ~clk;                       // 25 MHz, as on the board

    reg         rst_n = 0;
    reg         sv = 0;
    reg  [10:0] adc = 0;
    wire        det, det_sb, learning;
    wire [31:0] det_r, n_cnt;
    wire [39:0] mwi_q, thr1, spki;

    qrs_detector dut (
        .clk(clk), .rst_n(rst_n), .relearn_n(1'b1), .sample_valid(sv), .adc(adc),
        .det(det), .det_r(det_r), .det_sb(det_sb), .n_cnt(n_cnt), .mwi_q(mwi_q),
        .thr1(thr1), .spki(spki), .learning(learning)
    );

    // ---------------- cycle counting (pre-edge values) ----------------
    integer cyc = 0;
    integer t_start, t_done, t_dv;
    reg     st_prev = 0, busy_dec = 0, in_hls = 0;
    integer nsmp = 0;
    integer h_sum = 0, h_max = 0, h_min = 1 << 30;      // ap_start -> ap_done
    integer f_sum = 0, f_max = 0, f_min = 1 << 30;      // accepted -> dec_valid
    integer d_sum = 0, d_max = 0, d_min = 1 << 30;      // dec_valid -> idle
    integer t_sum = 0, t_max = 0, t_min = 1 << 30;      // accepted -> idle
    integer d_det_sum = 0, d_det_max = 0, n_det_s = 0;  // decision cycles on samples that detect
    reg     det_seen = 0;
    integer h, f, d, t;

    always @(posedge clk) begin
        cyc = cyc + 1;
        if (rst_n) begin
            // HLS start (ap_start is registered one edge after sample_valid)
            if (dut.ap_start && !st_prev && !in_hls) begin t_start = cyc; in_hls = 1; end
            if (in_hls && dut.ap_done) begin
                h = cyc - t_start;
                h_sum = h_sum + h; if (h > h_max) h_max = h; if (h < h_min) h_min = h;
                t_done = cyc; in_hls = 0;
            end
            if (dut.dec_valid) begin t_dv = cyc; busy_dec = 1; det_seen = 0; end
            else if (busy_dec) begin
                if (dut.det) det_seen = 1;
                if (dut.u_dec.ph == 3'd0) begin
                    f = t_dv - t_start + 1;                 // +1: the sample_valid -> ap_start register
                    d = cyc - t_dv;
                    t = f + d;
                    f_sum = f_sum + f; if (f > f_max) f_max = f; if (f < f_min) f_min = f;
                    d_sum = d_sum + d; if (d > d_max) d_max = d; if (d < d_min) d_min = d;
                    t_sum = t_sum + t; if (t > t_max) t_max = t; if (t < t_min) t_min = t;
                    if (det_seen) begin
                        d_det_sum = d_det_sum + d; n_det_s = n_det_s + 1;
                        if (d > d_det_max) d_det_max = d;
                    end
                    nsmp = nsmp + 1;
                    busy_dec = 0;
                end
            end
            st_prev = dut.ap_start;
        end
    end

    // ---------------- bit-exact detection check ----------------
    reg [10:0] samples [0:NS-1];
    integer exp_n [0:4095];
    integer exp_r [0:4095];
    integer exp_s [0:4095];
    integer n_exp = 0, n_got = 0, errors = 0;
    always @(posedge clk) begin
        if (det) begin
            if (n_got >= n_exp || n_cnt != exp_n[n_got] || $signed(det_r) != exp_r[n_got] ||
                det_sb != exp_s[n_got]) errors = errors + 1;
            n_got = n_got + 1;
        end
    end

    integer fd, i, a, b, c, r;
    initial begin
        $readmemh({`TB_DIR, "det_100_adc.hex"}, samples);
        fd = $fopen({`TB_DIR, "det_100_events.txt"}, "r");
        while (!$feof(fd)) begin
            r = $fscanf(fd, "%d %d %d\n", a, b, c);
            if (r == 3) begin exp_n[n_exp] = a; exp_r[n_exp] = b; exp_s[n_exp] = c; n_exp = n_exp + 1; end
        end
        $fclose(fd);
        repeat (5) @(posedge clk); rst_n = 1; repeat (5) @(posedge clk);
        for (i = 0; i < NS; i = i + 1) begin
            adc = samples[i];
            sv = 1; @(posedge clk); sv = 0;
            repeat (SPACING - 1) @(posedge clk);
        end
        repeat (200) @(posedge clk);
        if (n_got != n_exp) errors = errors + 1;
        $display("HWCYC samples=%0d detections RTL=%0d golden=%0d mismatches=%0d", nsmp, n_got, n_exp, errors);
        $display("HWCYC hls_start_to_done  min=%0d mean=%0.3f max=%0d", h_min, h_sum * 1.0 / nsmp, h_max);
        $display("HWCYC filter_accept_to_decvalid min=%0d mean=%0.3f max=%0d", f_min, f_sum * 1.0 / nsmp, f_max);
        $display("HWCYC decision_decvalid_to_idle min=%0d mean=%0.3f max=%0d", d_min, d_sum * 1.0 / nsmp, d_max);
        $display("HWCYC decision_on_detect_samples n=%0d mean=%0.3f max=%0d", n_det_s,
                 (n_det_s > 0) ? d_det_sum * 1.0 / n_det_s : 0.0, d_det_max);
        $display("HWCYC total_accept_to_idle   min=%0d mean=%0.3f max=%0d", t_min, t_sum * 1.0 / nsmp, t_max);
        $finish;
    end
endmodule
