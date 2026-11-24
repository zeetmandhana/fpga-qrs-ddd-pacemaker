`timescale 1ns/1ps
//============================================================================
// tb_event_priority.v  --  P17 Phase 6: exhaustive check of event_priority.v
// Drives all 256 input combinations and compares to the Python truth table.
//============================================================================
`ifndef TB_DIR
`define TB_DIR "C:/Vivadoproject/P17_QRS_Pacemaker/rtl/tb_data/"
`endif
module tb_event_priority;
    reg  p, a, v, r, m, u, e, b;
    wire vs, vp, as_o, ap;

    event_priority dut (.p(p), .a(a), .v(v), .r(r), .m(m), .u(u), .e(e), .b(b),
                        .vs(vs), .vp(vp), .as_o(as_o), .ap(ap));

    integer fd, code, i, mm;
    integer ip, ia, iv, ir, im, iu, ie, ib, ovs, ovp, oas, oap;

    initial begin
        fd = $fopen({`TB_DIR, "ev_truth.txt"}, "r");
        if (fd == 0) begin $display("ERROR: no ev_truth.txt"); $finish; end
        mm = 0;
        for (i = 0; i < 256; i = i + 1) begin
            code = $fscanf(fd, "%d %d %d %d %d %d %d %d %d %d %d %d\n",
                           ip, ia, iv, ir, im, iu, ie, ib, ovs, ovp, oas, oap);
            p=(ip!=0); a=(ia!=0); v=(iv!=0); r=(ir!=0);
            m=(im!=0); u=(iu!=0); e=(ie!=0); b=(ib!=0);
            #1;
            if ((vs!=(ovs!=0)) || (vp!=(ovp!=0)) ||
                (as_o!=(oas!=0)) || (ap!=(oap!=0))) begin
                if (mm < 10) $display("  MISMATCH row %0d", i);
                mm = mm + 1;
            end
        end
        $fclose(fd);
        $display("event_priority: 256 combinations, %0d mismatches", mm);
        if (mm == 0) $display("EVENT_PRIORITY RTL == truth table : PASS");
        else         $display("EVENT_PRIORITY RTL : FAIL");
        $finish;
    end
endmodule
