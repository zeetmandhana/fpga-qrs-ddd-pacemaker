`timescale 1ns/1ps
//============================================================================
// tb_closed_loop.v  --  hardware heart model + DDD pacemaker in closed loop
//
// Unlike tb_ddd_pacemaker.v (which REPLAYS recorded lead inputs), here the
// lead inputs come from rtl/heart_model.v, which reacts to the pacemaker's own
// AP/VP outputs -- the loop is closed in hardware. Every tick is compared with
// the Python closed loop (rtl/gen_closed_loop_vectors.py): a_in, v_in, AS, VS,
// AP, VP must all match. Six cases: normal, brady, block, dual, PMT with
// PVARP 250 ms (tachycardia) and PMT with PVARP 320 ms (safe).
//============================================================================
`ifndef TB_DIR
`define TB_DIR "C:/Vivadoproject/P17_QRS_Pacemaker/rtl/tb_data/"
`endif
module tb_closed_loop;
    reg         clk = 0, rst_n = 0;
    always #5 clk = ~clk;
    reg         PSEL = 0, PENABLE = 0, PWRITE = 0;
    reg  [7:0]  PADDR = 0;
    reg  [31:0] PWDATA = 0;
    wire [31:0] PRDATA;
    wire        PREADY, PSLVERR;
    reg         tick = 0, upd = 0;
    reg  [2:0]  scen = 0;
    wire        ap, vp, as_evt, vs_evt, irq, a_in, v_in;

    ddd_pacemaker_apb #(.W(16)) pm (
        .PCLK(clk), .PRESETn(rst_n), .PSEL(PSEL), .PENABLE(PENABLE), .PWRITE(PWRITE),
        .PADDR(PADDR), .PWDATA(PWDATA), .PRDATA(PRDATA), .PREADY(PREADY), .PSLVERR(PSLVERR),
        .tick_en(tick), .a_sense_in(a_in), .v_sense_in(v_in),
        .ap(ap), .vp(vp), .as_evt(as_evt), .vs_evt(vs_evt), .arrhythmia_irq(irq));

    heart_model hm (
        .clk(clk), .rst_n(rst_n), .scen(scen), .update(upd),
        .a_act(a_in | ap), .v_act(v_in | vp), .a_in(a_in), .v_in(v_in));

    task apb_write(input [7:0] addr, input [31:0] data);
    begin
        @(negedge clk); PSEL = 1; PWRITE = 1; PADDR = addr; PWDATA = data;
        @(negedge clk); PENABLE = 1;
        @(negedge clk); PSEL = 0; PENABLE = 0; PWRITE = 0;
    end
    endtask

    integer fd, code, n, i, mm, total_mm, total_ticks;
    integer lri, avi, uri, pvarp, vrp, sc;
    integer ea, ev, eas, evs, eap, evp;
    reg     ga, gv;

    task run_case(input [8*200-1:0] fname);
    begin
        fd = $fopen(fname, "r");
        if (fd == 0) begin $display("ERROR: cannot open %0s", fname); $finish; end
        code = $fscanf(fd, "%d %d %d %d %d %d\n", lri, avi, uri, pvarp, vrp, sc);
        code = $fscanf(fd, "%d\n", n);
        scen = sc;
        rst_n = 0; repeat (4) @(negedge clk); rst_n = 1; @(negedge clk);
        apb_write(8'h00, lri); apb_write(8'h04, avi); apb_write(8'h08, uri);
        apb_write(8'h0C, pvarp); apb_write(8'h10, vrp); apb_write(8'h14, 32'h1);
        mm = 0;
        for (i = 0; i < n; i = i + 1) begin
            code = $fscanf(fd, "%d %d %d %d %d %d\n", ea, ev, eas, evs, eap, evp);
            @(negedge clk); tick = 1; ga = a_in; gv = v_in;   // intrinsic of this tick
            @(negedge clk); tick = 0;                          // pacemaker outputs valid
            if ((ga != (ea != 0)) || (gv != (ev != 0)) || (as_evt != (eas != 0)) ||
                (vs_evt != (evs != 0)) || (ap != (eap != 0)) || (vp != (evp != 0))) begin
                if (mm < 8)
                    $display("  MISMATCH tick=%0d got a v AS VS AP VP=%b%b%b%b%b%b exp=%0d%0d%0d%0d%0d%0d",
                             i, ga, gv, as_evt, vs_evt, ap, vp, ea, ev, eas, evs, eap, evp);
                mm = mm + 1;
            end
            upd = 1; @(negedge clk); upd = 0;                  // heart reacts (incl. paces)
        end
        $fclose(fd);
        total_mm = total_mm + mm; total_ticks = total_ticks + n;
        $display("  scen %0d PVARP %0d: %0d ticks, %0d mismatches, arrhythmia_irq=%0d",
                 sc, pvarp, n, mm, irq);
    end
    endtask

    initial begin
        total_mm = 0; total_ticks = 0;
        run_case({`TB_DIR, "cl_normal.txt"});
        run_case({`TB_DIR, "cl_brady.txt"});
        run_case({`TB_DIR, "cl_block.txt"});
        run_case({`TB_DIR, "cl_dual.txt"});
        run_case({`TB_DIR, "cl_pmt250.txt"});
        run_case({`TB_DIR, "cl_pmt320.txt"});
        if (total_mm == 0)
            $display("CLOSED-LOOP BIT-EXACT PASS: %0d ticks, hardware heart+pacemaker == Python", total_ticks);
        else
            $display("CLOSED-LOOP FAIL: %0d mismatches", total_mm);
        $finish;
    end
endmodule
