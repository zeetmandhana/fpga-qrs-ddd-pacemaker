`timescale 1ns/1ps
// Bit-exact check of a hand-written FSMD against the Python golden model
// (hls/tb_data: 20,000 samples of MIT-BIH record 100, "hp dv mwi" per sample).
// DUT selected with +define+DUT=<module>.
module tb_fsmd;
    reg clk = 0, rst_n = 0, start = 0;
    reg  signed [15:0] x = 0;
    reg  signed [31:0] baseline = 32'sd1024;
    wire done;
    wire signed [31:0] hp, dv;
    wire [39:0] mwi;
    `DUT dut (.clk(clk), .rst_n(rst_n), .start(start), .x(x), .baseline(baseline),
              .done(done), .hp_out(hp), .dv_out(dv), .mwi_out(mwi));
    always #5 clk = ~clk;                       // 100 MHz

    integer fin, fex, n, mism, r1, r2, v, cyc, lat_min, lat_max;
    reg signed [63:0] eh, ed, em;
    initial begin
        fin = $fopen("C:/Vivadoproject/P17_QRS_Pacemaker/report/work/hand_hls/sim/stream_rec100_input.txt", "r");
        fex = $fopen("C:/Vivadoproject/P17_QRS_Pacemaker/report/work/hand_hls/sim/stream_rec100_expected.txt", "r");
        n = 0; mism = 0; lat_min = 1000; lat_max = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk); #1;
        while (!$feof(fin)) begin
            r1 = $fscanf(fin, "%d\n", v);
            r2 = $fscanf(fex, "%d %d %d\n", eh, ed, em);
            if (r1 == 1 && r2 == 3) begin
                x = v; start = 1'b1;           // driven 1 ns after a clock edge
                @(posedge clk); #1; start = 1'b0; cyc = 1;
                while (!done) begin @(posedge clk); #1; cyc = cyc + 1; end
                if (cyc < lat_min) lat_min = cyc;
                if (cyc > lat_max) lat_max = cyc;
                if (hp !== eh[31:0] || dv !== ed[31:0] || mwi !== em[39:0]) begin
                    if (mism < 10)
                        $display("MISMATCH i=%0d hp %0d/%0d dv %0d/%0d mwi %0d/%0d",
                                 n, hp, eh, dv, ed, mwi, em);
                    mism = mism + 1;
                end
                n = n + 1;
                @(posedge clk); #1;             // one idle cycle between samples
            end
        end
        $display("DUT %s: checked %0d samples (hp, dv, mwi), %0d mismatches, start->done %0d..%0d cycles",
                 `DUT_NAME, n, mism, lat_min, lat_max);
        if (n == 20000 && mism == 0) $display("BIT-EXACT PASS");
        else                         $display("BIT-EXACT FAIL");
        $finish;
    end
endmodule
