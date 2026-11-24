`timescale 1ns/1ps
// Drives qd_ctrl (RTL or a post-synthesis netlist) with a fixed pseudo-random
// input sequence and prints the outputs each cycle; the printed trace of every
// netlist is compared with the RTL trace (same file format).
// Reset is released after 150 ns so the 100 ns netlist GSR pulse is over.
module tb_qd_ctrl;
    reg clk = 0, rst_n = 0, i = 0, f = 0, s = 0;
    wire ld, trk, cls, rg, avg, lim, sbk, cnt;
    qd_ctrl dut(.clk(clk), .rst_n(rst_n), .i(i), .f(f), .s(s), .ld(ld), .trk(trk), .cls(cls), .rg(rg),
                .avg(avg), .lim(lim), .sbk(sbk), .cnt(cnt));
    always #5 clk = ~clk;
    integer k, fd;
    reg [15:0] lfsr = 16'hACE1;
    initial begin
        fd = $fopen("trace.txt", "w");
        #152 rst_n = 1;
        for (k = 0; k < 400; k = k + 1) begin
            lfsr = {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
            i = lfsr[0]; f = lfsr[3]; s = lfsr[7];
            @(negedge clk);
            $fdisplay(fd, "%0d %b%b%b %b%b%b%b%b%b%b%b", k, i, f, s, ld, trk, cls, rg, avg, lim, sbk, cnt);
        end
        $fclose(fd);
        $display("TRACE_DONE");
        $finish;
    end
endmodule
