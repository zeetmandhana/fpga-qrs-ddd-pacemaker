// tb_ddd_random.sv -- constrained-random regression of the DDD controller + APB slave.
// 60 random legal parameter sets x 5000 ticks of random lead activity
// (gen_random_vectors.py); every tick compares AS/VS/AP/VP/ARR with the Python
// golden model. Also checks APB read-back of every register and the W1C clear
// of the arrhythmia interrupt. Assertions are bound in ddd_sva.sv.
`timescale 1ns/1ps
module tb_ddd_random;
    localparam W = 16;
    logic PCLK = 0, PRESETn = 0, PSEL = 0, PENABLE = 0, PWRITE = 0;
    logic [7:0]  PADDR = 0;
    logic [31:0] PWDATA = 0;
    wire  [31:0] PRDATA;
    wire         PREADY, PSLVERR;
    logic tick_en = 0, a_in = 0, v_in = 0;
    wire  ap, vp, as_evt, vs_evt, irq;

    ddd_pacemaker_apb #(.W(W)) dut (
        .PCLK(PCLK), .PRESETn(PRESETn), .PSEL(PSEL), .PENABLE(PENABLE), .PWRITE(PWRITE),
        .PADDR(PADDR), .PWDATA(PWDATA), .PRDATA(PRDATA), .PREADY(PREADY), .PSLVERR(PSLVERR),
        .tick_en(tick_en), .a_sense_in(a_in), .v_sense_in(v_in),
        .ap(ap), .vp(vp), .as_evt(as_evt), .vs_evt(vs_evt), .arrhythmia_irq(irq));

    always #5 PCLK = ~PCLK;

    task automatic apb_write(input [7:0] a, input [31:0] d);
        @(negedge PCLK); PSEL = 1; PWRITE = 1; PADDR = a; PWDATA = d;
        @(negedge PCLK); PENABLE = 1;
        @(negedge PCLK); PSEL = 0; PENABLE = 0; PWRITE = 0;
    endtask
    task automatic apb_read(input [7:0] a, output [31:0] d);
        @(negedge PCLK); PSEL = 1; PWRITE = 0; PADDR = a;
        @(negedge PCLK); PENABLE = 1; #1 d = PRDATA;
        @(negedge PCLK); PSEL = 0; PENABLE = 0;
    endtask

    int fd, code, nsets, s, n, i, lri, avi, uri, pvarp, vrp;
    int ia, iv, eas, evs, eap, evp, earr;
    int mm[5], ticks, rb_err, w1c_err, irq_seen;
    logic [31:0] rd;
    string tag;

    initial begin
        foreach (mm[k]) mm[k] = 0;
        ticks = 0; rb_err = 0; w1c_err = 0; irq_seen = 0;
        fd = $fopen("C:/Vivadoproject/P17_QRS_Pacemaker/report/work/sim/rand_vectors.txt", "r");
        if (fd == 0) begin $display("ERROR: no vectors"); $finish; end
        code = $fscanf(fd, "%d\n", nsets);
        for (s = 0; s < nsets; s++) begin
            code = $fscanf(fd, "%s %d %d %d %d %d %d\n", tag, lri, avi, uri, pvarp, vrp, n);
            PRESETn = 0; tick_en = 0; a_in = 0; v_in = 0;
            repeat (3) @(negedge PCLK);
            PRESETn = 1;
            apb_write(8'h00, lri); apb_write(8'h04, avi); apb_write(8'h08, uri);
            apb_write(8'h0C, pvarp); apb_write(8'h10, vrp); apb_write(8'h14, 32'h1);
            // read back every programmed register
            apb_read(8'h00, rd); rb_err += (rd != lri);
            apb_read(8'h04, rd); rb_err += (rd != avi);
            apb_read(8'h08, rd); rb_err += (rd != uri);
            apb_read(8'h0C, rd); rb_err += (rd != pvarp);
            apb_read(8'h10, rd); rb_err += (rd != vrp);
            apb_read(8'h14, rd); rb_err += (rd != 1);
            apb_read(8'h18, rd); rb_err += (rd[4:1] != 0);       // STATUS: no event yet
            apb_read(8'h1C, rd); rb_err += (rd != 0);            // unmapped -> 0
            apb_write(8'h20, 32'hFFFF_FFFF);                     // unmapped write ignored
            apb_read(8'h00, rd); rb_err += (rd != lri);
            for (i = 0; i < n; i++) begin
                code = $fscanf(fd, "%d %d %d %d %d %d %d\n", ia, iv, eas, evs, eap, evp, earr);
                @(negedge PCLK); a_in = ia; v_in = iv; tick_en = 1;
                @(negedge PCLK); tick_en = 0;
                // outputs are registered: compare one cycle after the tick
                if (as_evt != eas) mm[0]++;
                if (vs_evt != evs) mm[1]++;
                if (ap != eap)     mm[2]++;
                if (vp != evp)     mm[3]++;
                if (dut.u_ctrl.arrhythmia != earr) mm[4]++;
                if ((as_evt != eas || vs_evt != evs || ap != eap || vp != evp ||
                     dut.u_ctrl.arrhythmia != earr) && (mm[0]+mm[1]+mm[2]+mm[3]+mm[4]) <= 8)
                    $display("  MISMATCH set %0d tick %0d (LRI %0d AVI %0d URI %0d PVARP %0d VRP %0d): got AS%0d VS%0d AP%0d VP%0d ARR%0d exp %0d%0d%0d%0d%0d",
                             s, i, lri, avi, uri, pvarp, vrp, as_evt, vs_evt, ap, vp,
                             dut.u_ctrl.arrhythmia, eas, evs, eap, evp, earr);
                @(negedge PCLK);
                ticks++;
                // exercise the interrupt: once latched, clear it with W1C and check
                if (irq) begin
                    irq_seen++;
                    apb_write(8'h14, 32'h3);
                    if (irq && !dut.u_ctrl.arrhythmia) w1c_err++;
                end
            end
        end
        $fclose(fd);
        $display("RANDOM: %0d sets, %0d ticks; mismatches AS %0d VS %0d AP %0d VP %0d ARR %0d; readback errors %0d; IRQ latched+cleared %0d times, W1C errors %0d",
                 nsets, ticks, mm[0], mm[1], mm[2], mm[3], mm[4], rb_err, irq_seen, w1c_err);
        if (mm[0]+mm[1]+mm[2]+mm[3]+mm[4]+rb_err+w1c_err == 0) $display("RANDOM REGRESSION PASS");
        else $display("RANDOM REGRESSION FAIL");
        $finish;
    end
endmodule
