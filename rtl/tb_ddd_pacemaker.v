`timescale 1ns/1ps
//============================================================================
// tb_ddd_pacemaker.v  --  P17 Phase 6 testbench
//
// Programs the DDD timing parameters over APB, replays the per-tick lead
// inputs recorded from the Python golden model (rtl/gen_ddd_vectors.py), and
// checks that the RTL's AS/VS/AP/VP outputs match bit-for-bit.
//============================================================================
// Absolute path so the vectors are found from any simulator run directory
// (batch run_sim.bat or a Vivado project's behavioral simulation).
`ifndef TB_DIR
`define TB_DIR "C:/Vivadoproject/P17_QRS_Pacemaker/rtl/tb_data/"
`endif
module tb_ddd_pacemaker;
    localparam W = 16;

    reg         PCLK = 0, PRESETn = 0;
    reg         PSEL = 0, PENABLE = 0, PWRITE = 0;
    reg  [7:0]  PADDR = 0;
    reg  [31:0] PWDATA = 0;
    wire [31:0] PRDATA;
    wire        PREADY, PSLVERR;
    reg         tick_en = 0, a_sense_in = 0, v_sense_in = 0;
    wire        ap, vp, as_evt, vs_evt, arrhythmia_irq;

    ddd_pacemaker_apb #(.W(W)) dut (
        .PCLK(PCLK), .PRESETn(PRESETn), .PSEL(PSEL), .PENABLE(PENABLE),
        .PWRITE(PWRITE), .PADDR(PADDR), .PWDATA(PWDATA), .PRDATA(PRDATA),
        .PREADY(PREADY), .PSLVERR(PSLVERR),
        .tick_en(tick_en), .a_sense_in(a_sense_in), .v_sense_in(v_sense_in),
        .ap(ap), .vp(vp), .as_evt(as_evt), .vs_evt(vs_evt),
        .arrhythmia_irq(arrhythmia_irq)
    );

    always #5 PCLK = ~PCLK;              // 100 MHz

    integer lri, avi, uri, pvarp, vrp;
    integer fd, code, n, i, mm, total_mm;
    integer a_in, v_in, eas, evs, eap, evp;

    task apb_write(input [7:0] addr, input [31:0] data);
    begin
        @(negedge PCLK); PSEL = 1; PWRITE = 1; PADDR = addr; PWDATA = data;
        @(negedge PCLK); PENABLE = 1;                 // access phase
        @(negedge PCLK); PSEL = 0; PENABLE = 0; PWRITE = 0;
    end
    endtask

    task program_params;
    begin
        apb_write(8'h00, lri);
        apb_write(8'h04, avi);
        apb_write(8'h08, uri);
        apb_write(8'h0C, pvarp);
        apb_write(8'h10, vrp);
        apb_write(8'h14, 32'h1);        // CONTROL: enable = 1
    end
    endtask

    task run_scenario(input [8*128-1:0] fname);
    begin
        PRESETn = 0; tick_en = 0; a_sense_in = 0; v_sense_in = 0;
        repeat (4) @(negedge PCLK);
        PRESETn = 1;
        @(negedge PCLK);
        program_params;

        fd = $fopen(fname, "r");
        if (fd == 0) begin $display("ERROR: cannot open %0s", fname); $finish; end
        code = $fscanf(fd, "%d\n", n);
        mm = 0;
        for (i = 0; i < n; i = i + 1) begin
            code = $fscanf(fd, "%d %d %d %d %d %d\n",
                           a_in, v_in, eas, evs, eap, evp);
            @(negedge PCLK);
            a_sense_in = (a_in != 0); v_sense_in = (v_in != 0); tick_en = 1;
            @(posedge PCLK);            // DUT updates on this edge
            @(negedge PCLK);
            tick_en = 0;
            if ((as_evt != (eas != 0)) || (vs_evt != (evs != 0)) ||
                (ap != (eap != 0)) || (vp != (evp != 0))) begin
                if (mm < 10)
                    $display("  MISMATCH %0s tick=%0d got as/vs/ap/vp=%b%b%b%b exp=%b%b%b%b",
                             fname, i, as_evt, vs_evt, ap, vp,
                             (eas!=0), (evs!=0), (eap!=0), (evp!=0));
                mm = mm + 1;
            end
        end
        $fclose(fd);
        total_mm = total_mm + mm;
        $display("  %0s : %0d ticks, %0d mismatches", fname, n, mm);
    end
    endtask

    initial begin
        fd = $fopen({`TB_DIR, "ddd_params.txt"}, "r");
        if (fd == 0) begin $display("ERROR: no params file"); $finish; end
        code = $fscanf(fd, "%d %d %d %d %d", lri, avi, uri, pvarp, vrp);
        $fclose(fd);
        $display("DDD params: LRI=%0d AVI=%0d URI=%0d PVARP=%0d VRP=%0d",
                 lri, avi, uri, pvarp, vrp);

        total_mm = 0;
        run_scenario({`TB_DIR, "ddd_normal.txt"});
        run_scenario({`TB_DIR, "ddd_block.txt"});
        run_scenario({`TB_DIR, "ddd_dual.txt"});

        $display("\nTOTAL mismatches: %0d", total_mm);
        if (total_mm == 0)
            $display("RTL BIT-EXACT PASS vs Python golden model");
        else
            $display("RTL MISMATCH -- FAIL");
        $finish;
    end
endmodule
