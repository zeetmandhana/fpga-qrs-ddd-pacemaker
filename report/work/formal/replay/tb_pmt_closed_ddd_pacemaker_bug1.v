`timescale 1ns/1ps
//============================================================================
// tb_pmt_closed.v -- closed loop: DDD RTL + the PMT heart of the NuSMV model
// (complete AV block, retrograde V->A conduction VA = 3 ticks after each V event).
// One tick per clock. Same timer values as the abstract model:
// LRI 10, AVI 2, URI 5, PVARP 4, VRP 3. Prints the same table as tb_replay.v
// (RTL register values sampled before each edge).
//============================================================================
module tb_pmt_closed;
    reg clk = 0, rst_n = 0;
    wire tick_en = 1'b1;
    wire ap, vp, as_evt, vs_evt, arr;
    always #5 clk = ~clk;

    reg  [7:0] cnt;        // index of the upcoming tick after the last V decision
    reg        armed;      // a retrograde P wave is pending
    wire [7:0] idx  = (vp || vs_evt) ? 8'd1 : cnt;
    wire       a_in = rst_n && armed && (idx == 8'd3);   // retrograde P, VA = 3 ticks after V

    ddd_pacemaker_bug1 #(.W(16)) dut (
        .clk(clk), .rst_n(rst_n), .enable(1'b1), .tick_en(tick_en),
        .a_sense_in(a_in), .v_sense_in(1'b0),
        .lri(16'd10), .avi(16'd2), .uri(16'd5), .pvarp(16'd4), .vrp(16'd3),
        .ap(ap), .vp(vp), .as_evt(as_evt), .vs_evt(vs_evt), .arrhythmia(arr));

    always @(posedge clk) begin
        if (!rst_n) begin cnt <= 8'd99; armed <= 1'b0; end
        else begin
            cnt <= (vp || vs_evt) ? 8'd2 : (cnt == 8'd99 ? cnt : cnt + 8'd1);
            if (vp || vs_evt) armed <= 1'b1;
            else if (a_in)    armed <= 1'b0;
        end
    end

    integer k, ph, tv, tav, aa, vbeats, upper;
    initial begin
        vbeats = 0; upper = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
        $display(" cyc tick a v | RTL phase t_v t_av | out AP VP AS VS arr | trace AP VP AS VS");
        for (k = 0; k < 40; k = k + 1) begin
            @(negedge clk);
            ph = dut.phase; tv = dut.t_v; tav = dut.t_av; aa = a_in;
            @(posedge clk); #1;
            if (vp || vs_evt) begin vbeats = vbeats + 1; if (arr) upper = upper + 1; end
            $display("%4d   %0d  %0d %0d |     %0d  %3d  %3d  |      %0d  %0d  %0d  %0d  %0d  |        0  0  0  0",
                     k, 1, aa, 0, ph, tv, tav, ap, vp, as_evt, vs_evt, arr);
        end
        $display("CLOSED LOOP: V beats %0d, at the upper rate %0d", vbeats, upper);
        $finish;
    end
endmodule
