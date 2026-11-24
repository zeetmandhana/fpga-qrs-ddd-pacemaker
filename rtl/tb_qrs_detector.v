`timescale 1ns/1ps
//============================================================================
// tb_qrs_detector.v  --  bit-exact check of the complete hardware detector
//
// Streams 100,000 MIT-BIH samples (records 100 and 208) through
// qrs_detector (HLS filter + RTL decision) and compares every detection
// (decision sample, R-peak index, search-back flag) with the Python golden
// model src/qrs_hw_detector.py (vectors from hls/gen_stream_vectors.py).
// A new sample is offered every SPACING clocks (the board uses ~69,444).
//============================================================================
`ifndef TB_DIR
`define TB_DIR "C:/Vivadoproject/P17_QRS_Pacemaker/rtl/tb_data/"
`endif

module tb_qrs_detector;
    localparam SPACING = 64;
    localparam NS = 100000;

    reg clk = 0;
    always #5 clk = ~clk;

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

    reg [10:0] samples [0:NS-1];
    integer exp_n [0:4095];
    integer exp_r [0:4095];
    integer exp_s [0:4095];
    integer n_exp, n_got, errors, total_err, total_det;

    // compare every detection as it happens
    always @(posedge clk) begin
        if (det) begin
            if (n_got >= n_exp) begin
                if (errors < 10) $display("  EXTRA detection n=%0d r=%0d", n_cnt, det_r);
                errors = errors + 1;
            end else if ((n_cnt != exp_n[n_got]) || ($signed(det_r) != exp_r[n_got]) ||
                         (det_sb != exp_s[n_got])) begin
                if (errors < 10)
                    $display("  MISMATCH #%0d got n=%0d r=%0d sb=%0d  exp n=%0d r=%0d sb=%0d",
                             n_got, n_cnt, $signed(det_r), det_sb,
                             exp_n[n_got], exp_r[n_got], exp_s[n_got]);
                errors = errors + 1;
            end
            n_got = n_got + 1;
        end
    end

    task run_record(input [8*200-1:0] adc_file, input [8*200-1:0] ev_file, input [8*8-1:0] rec);
        integer fd, i, a, b, c, r;
        begin
            $readmemh(adc_file, samples);
            fd = $fopen(ev_file, "r");
            if (fd == 0) begin $display("ERROR: cannot open events for %0s", rec); $finish; end
            n_exp = 0;
            while (!$feof(fd)) begin
                r = $fscanf(fd, "%d %d %d\n", a, b, c);
                if (r == 3) begin exp_n[n_exp] = a; exp_r[n_exp] = b; exp_s[n_exp] = c; n_exp = n_exp + 1; end
            end
            $fclose(fd);
            n_got = 0; errors = 0;
            rst_n = 0; repeat (5) @(posedge clk); rst_n = 1; repeat (5) @(posedge clk);
            for (i = 0; i < NS; i = i + 1) begin
                adc = samples[i];
                sv = 1; @(posedge clk); sv = 0;
                repeat (SPACING - 1) @(posedge clk);
            end
            repeat (200) @(posedge clk);
            if (n_got != n_exp) errors = errors + 1;
            $display("record %0s: %0d samples, detections RTL=%0d model=%0d, mismatches=%0d",
                     rec, NS, n_got, n_exp, errors);
            total_err = total_err + errors;
            total_det = total_det + n_got;
        end
    endtask

    initial begin
        total_err = 0; total_det = 0;
        run_record({`TB_DIR, "det_100_adc.hex"}, {`TB_DIR, "det_100_events.txt"}, "100");
        run_record({`TB_DIR, "det_208_adc.hex"}, {`TB_DIR, "det_208_events.txt"}, "208");
        if (total_err == 0)
            $display("BIT-EXACT PASS: %0d detections match the Python hardware model", total_det);
        else
            $display("FAIL: %0d mismatches", total_err);
        $finish;
    end
endmodule
