`timescale 1ns/1ps
// tb_qrs_baselines.v -- bit-exact check of B0 and B1 against baseline_eval.py
// (100,000 samples of MIT-BIH record 100, one sample every 64 clocks).
module tb_qrs_baselines;
    localparam NS = 100000;
    localparam SPACING = 64;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0, sv = 0;
    reg [10:0] adc = 0;
    wire d0, d1;
    wire [31:0] n0, n1;

    qrs_base_thr u_b0 (.clk(clk), .rst_n(rst_n), .sample_valid(sv), .adc(adc), .det(d0), .det_n(n0));
    qrs_base_mwi u_b1 (.clk(clk), .rst_n(rst_n), .sample_valid(sv), .adc(adc), .det(d1), .det_n(n1));

    reg [10:0] samples [0:NS-1];
    integer e0 [0:4095];
    integer e1 [0:4095];
    integer ne0, ne1, g0, g1, err0, err1;

    task load(input [8*200-1:0] f, output integer cnt, input integer which);
        integer fd, r, v;
        begin
            fd = $fopen(f, "r"); cnt = 0;
            if (fd == 0) begin $display("ERROR: cannot open %0s", f); $finish; end
            while (!$feof(fd)) begin
                r = $fscanf(fd, "%d\n", v);
                if (r == 1) begin
                    if (which == 0) e0[cnt] = v; else e1[cnt] = v;
                    cnt = cnt + 1;
                end
            end
            $fclose(fd);
        end
    endtask

    always @(posedge clk) begin
        if (d0) begin
            if (g0 >= ne0 || n0 != e0[g0]) begin
                if (err0 < 5) $display("  B0 MISMATCH #%0d got %0d exp %0d", g0, n0, e0[g0]);
                err0 = err0 + 1;
            end
            g0 = g0 + 1;
        end
        if (d1) begin
            if (g1 >= ne1 || n1 != e1[g1]) begin
                if (err1 < 5) $display("  B1 MISMATCH #%0d got %0d exp %0d", g1, n1, e1[g1]);
                err1 = err1 + 1;
            end
            g1 = g1 + 1;
        end
    end

    integer i;
    initial begin
        g0 = 0; g1 = 0; err0 = 0; err1 = 0;
        $readmemh("C:/Vivadoproject/P17_QRS_Pacemaker/rtl/tb_data/det_100_adc.hex", samples);
        load("C:/Vivadoproject/P17_QRS_Pacemaker/report/work/paper/tb/b0_expected.txt", ne0, 0);
        load("C:/Vivadoproject/P17_QRS_Pacemaker/report/work/paper/tb/b1_expected.txt", ne1, 1);
        repeat (5) @(posedge clk); rst_n = 1; repeat (5) @(posedge clk);
        for (i = 0; i < NS; i = i + 1) begin
            adc <= samples[i];
            sv <= 1; @(posedge clk); sv <= 0;
            repeat (SPACING - 1) @(posedge clk);
        end
        repeat (200) @(posedge clk);
        if (g0 != ne0) err0 = err0 + 1;
        if (g1 != ne1) err1 = err1 + 1;
        $display("B0: RTL %0d detections, model %0d, mismatches %0d", g0, ne0, err0);
        $display("B1: RTL %0d detections, model %0d, mismatches %0d", g1, ne1, err1);
        if (err0 == 0 && err1 == 0) $display("BASELINES BIT-EXACT PASS");
        else $display("BASELINES FAIL");
        $finish;
    end
endmodule
