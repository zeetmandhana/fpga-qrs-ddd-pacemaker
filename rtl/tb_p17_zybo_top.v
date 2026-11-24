`timescale 1ns/1ps
//============================================================================
// tb_p17_zybo_top.v  --  whole-board simulation of the Zybo Z7-10 design
//
// Runs the real top (MMCM, NEORV32 executing the compiled firmware from IMEM,
// APB, pacemaker, heart model, ECG source, HLS+RTL detector, display) with
// SIM_DIV=100, i.e. ticks 100x faster than real time so a full sweep fits in a
// short simulation. Checks that the firmware programmed the pacemaker over
// APB, presses BTN1 to change scenarios, and dumps two screen frames as PPM
// images (replay mode and AV-block mode) for visual inspection.
//============================================================================
`ifndef OUT_DIR
`define OUT_DIR "C:/Vivadoproject/P17_QRS_Pacemaker/results/"
`endif
module tb_p17_zybo_top;
    reg sysclk = 0;
    always #4 sysclk = ~sysclk;                 // 125 MHz
    reg  [3:0] btn = 4'b0000;
    reg  [3:0] sw  = 4'b0011;                   // pacing on, PMT guard on
    wire [3:0] led;
    wire       r6, g6, b6, ck_p, ck_n;
    wire [2:0] tp, tn;
    wire [7:0] jc, jd;

    p17_zybo_top #(.SIM_DIV(100)) dut (
        .sysclk(sysclk), .btn(btn), .sw(sw), .led(led),
        .led6_r(r6), .led6_g(g6), .led6_b(b6),
        .hdmi_tx_clk_p(ck_p), .hdmi_tx_clk_n(ck_n), .hdmi_tx_p(tp), .hdmi_tx_n(tn),
        .jc(jc), .jd(jd));

    // event counters seen at the top level
    integer n_det = 0, n_ap = 0, n_vp = 0, n_as = 0, n_vs = 0, n_apb = 0;
    always @(posedge dut.clk) begin
        if (dut.det) n_det = n_det + 1;
        if (dut.ap) n_ap = n_ap + 1;
        if (dut.vp) n_vp = n_vp + 1;
        if (dut.as_evt) n_as = n_as + 1;
        if (dut.vs_evt) n_vs = n_vs + 1;
        if (dut.PSEL[0] & dut.PENABLE & dut.PWRITE) n_apb = n_apb + 1;
    end

    task dump_frame(input [8*200-1:0] fname);
        integer fd, k;
        begin
            fd = $fopen(fname, "w");
            $fwrite(fd, "P3\n640 480\n255\n");
            @(negedge dut.vvs);                 // start of vertical sync
            @(posedge dut.vvs);
            k = 0;
            while (k < 640 * 480) begin
                @(posedge dut.clk);
                if (dut.vde) begin
                    $fwrite(fd, "%0d %0d %0d\n", dut.vr, dut.vg, dut.vb);
                    k = k + 1;
                end
            end
            $fclose(fd);
            $display("  frame written: %0s", fname);
        end
    endtask

    task press_btn1;
        begin
            btn[1] = 1; repeat (12000) @(posedge dut.clk);
            btn[1] = 0; repeat (12000) @(posedge dut.clk);
        end
    endtask

    initial begin
        wait (dut.u_clk.locked == 1'b1);
        $display("MMCM locked at %0t ns", $time);
        repeat (300000) @(posedge dut.clk);
        $display("after firmware init: LRI=%0d AVI=%0d URI=%0d PVARP=%0d VRP=%0d enable=%0d mode=%0d (APB writes %0d)",
                 dut.u_pm.lri, dut.u_pm.avi, dut.u_pm.uri, dut.u_pm.pvarp, dut.u_pm.vrp,
                 dut.u_pm.enable, dut.mode, n_apb);
        // replay mode: let ~2 sweeps of ECG through, then grab a frame
        repeat (2400000) @(posedge dut.clk);
        $display("replay mode: QRS detected=%0d  AP=%0d VP=%0d AS=%0d VS=%0d  LED=%b",
                 n_det, n_ap, n_vp, n_as, n_vs, led);
        dump_frame({`OUT_DIR, "sim_frame_replay.ppm"});

        // three presses: 0 -> 1 -> 2 -> 3 (complete AV block)
        press_btn1; press_btn1; press_btn1;
        repeat (200000) @(posedge dut.clk);
        $display("after BTN1 x3: mode=%0d LRI=%0d PVARP=%0d enable=%0d",
                 dut.mode, dut.u_pm.lri, dut.u_pm.pvarp, dut.u_pm.enable);
        n_det = 0; n_ap = 0; n_vp = 0; n_as = 0; n_vs = 0;
        repeat (2400000) @(posedge dut.clk);
        $display("AV-block mode: QRS detected=%0d  AP=%0d VP=%0d AS=%0d VS=%0d",
                 n_det, n_ap, n_vp, n_as, n_vs);
        dump_frame({`OUT_DIR, "sim_frame_avblock.ppm"});
        $display("TOP-LEVEL SIM DONE");
        $finish;
    end
endmodule
