`timescale 1ns/1ps
//============================================================================
// tb_replay.v -- replay a NuSMV counterexample on the DDD controller RTL.
//
// One NuSMV state = one clock cycle. Before the edge the TB drives tick_en,
// a_sense_in, v_sense_in from the trace and checks the RTL registers
// (phase, t_v, t_av) against the trace; after the edge it checks the
// registered outputs (ap, vp, as_evt, vs_evt) against the trace's AP/VP/AS/VS.
// The property monitors flag the same violations the model checker found:
//   P3  AS accepted inside PVARP     P4  VS accepted inside VRP
//   P11 every V beat at the upper rate (no slow beat) once the loop is entered
// Timer parameters = the abstract model: LRI 10 AVI 2 URI 5 PVARP 4 VRP 3.
//============================================================================
module tb_replay;
    reg [8*300-1:0] STIM;
    reg clk = 0, rst_n = 0, tick_en = 0, a_in = 0, v_in = 0;
    wire ap, vp, as_evt, vs_evt, arr;
    always #5 clk = ~clk;

    ddd_pacemaker_bug2 #(.W(16)) dut (
        .clk(clk), .rst_n(rst_n), .enable(1'b1), .tick_en(tick_en),
        .a_sense_in(a_in), .v_sense_in(v_in),
        .lri(16'd10), .avi(16'd2), .uri(16'd5), .pvarp(16'd4), .vrp(16'd3),
        .ap(ap), .vp(vp), .as_evt(as_evt), .vs_evt(vs_evt), .arrhythmia(arr));

    integer fd, n, k, r, mism, reg_mism;
    integer t_tick, t_a, t_v_in, t_phase, t_tv, t_tav, e_ap, e_vp, e_as, e_vs;
    integer tv_now, viol_p3, viol_p4, vbeats, upper_beats, first_mism;
    reg [15:0] tv_inc;
    integer ph_r, tv_r, tav_r;

    initial begin
        mism = 0; reg_mism = 0; viol_p3 = 0; viol_p4 = 0; vbeats = 0; upper_beats = 0;
        first_mism = -1;
        if (!$value$plusargs("STIM=%s", STIM)) STIM = "stim.txt";
        fd = $fopen(STIM, "r");
        if (fd == 0) begin $display("cannot open %s", STIM); $finish; end
        r = $fscanf(fd, "%d\n", n);
        repeat (3) @(posedge clk);
        rst_n = 1;
        $display(" cyc tick a v | RTL phase t_v t_av | out AP VP AS VS arr | trace AP VP AS VS");
        for (k = 0; k < n; k = k + 1) begin
            r = $fscanf(fd, "%d %d %d %d %d %d %d %d %d %d\n",
                        t_tick, t_a, t_v_in, t_phase, t_tv, t_tav, e_ap, e_vp, e_as, e_vs);
            @(negedge clk);
            tick_en = t_tick; a_in = t_a; v_in = t_v_in;
            ph_r = dut.phase; tv_r = dut.t_v; tav_r = dut.t_av;
            if (dut.phase !== t_phase[0] || dut.t_v !== t_tv || dut.t_av !== t_tav) begin
                reg_mism = reg_mism + 1;
                if (first_mism < 0) first_mism = k;
                $display("      reg mismatch @%0d: RTL phase %0d t_v %0d t_av %0d  vs trace %0d %0d %0d",
                         k, dut.phase, dut.t_v, dut.t_av, t_phase, t_tv, t_tav);
            end
            tv_inc = (dut.t_v >= 16'd10) ? 16'd11 : dut.t_v + 16'd1;   // value used this tick
            @(posedge clk); #1;
            if ({ap, vp, as_evt, vs_evt} !== {e_ap[0], e_vp[0], e_as[0], e_vs[0]}) begin
                mism = mism + 1;
                if (first_mism < 0) first_mism = k;
            end
            if (as_evt && tv_inc < 4)  viol_p3 = viol_p3 + 1;
            if (vs_evt && tv_inc < 3)  viol_p4 = viol_p4 + 1;
            if (vp || vs_evt) begin
                vbeats = vbeats + 1;
                if (arr) upper_beats = upper_beats + 1;
            end
            $display("%4d   %0d  %0d %0d |     %0d  %3d  %3d  |      %0d  %0d  %0d  %0d  %0d  |        %0d  %0d  %0d  %0d%s",
                     k, t_tick, t_a, t_v_in, ph_r, tv_r, tav_r, ap, vp, as_evt, vs_evt, arr,
                     e_ap, e_vp, e_as, e_vs,
                     ({ap, vp, as_evt, vs_evt} !== {e_ap[0], e_vp[0], e_as[0], e_vs[0]}) ? "   <-- MISMATCH" : "");
        end
        $fclose(fd);
        $display("REPLAY %0s: %0d cycles, output mismatches %0d, register mismatches %0d, first mismatch at cycle %0d",
                 STIM, n, mism, reg_mism, first_mism);
        $display("MONITORS: AS inside PVARP = %0d, VS inside VRP = %0d, V beats = %0d of which at upper rate = %0d",
                 viol_p3, viol_p4, vbeats, upper_beats);
        $finish;
    end
endmodule
