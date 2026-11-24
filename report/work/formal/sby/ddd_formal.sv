// ddd_formal.sv -- SymbiYosys top for rtl/ddd_pacemaker.v (P17, VL401 Sec. 8.5)
//
// All DUT inputs are free (solver-chosen) except for these assumptions, which
// mirror the firmware range check (ddd_driver.c: avi < lri, avi <= uri <= lri)
// on 8-bit timers, and the bus protocol (parameters are only rewritten while the
// controller is disabled, as the firmware does). The properties themselves are
// in ddd_props.vh, included inside the module copy under `ifdef FORMAL.
module ddd_formal (
    input wire       clk,
    input wire       rst_n,
    input wire       enable,
    input wire       tick_en,
    input wire       a_in,
    input wire       v_in,
    input wire [7:0] lri, avi, uri, pvarp, vrp
);
    wire ap, vp, as_evt, vs_evt, arr;
    ddd_pacemaker #(.W(8)) dut (
        .clk(clk), .rst_n(rst_n), .enable(enable), .tick_en(tick_en),
        .a_sense_in(a_in), .v_sense_in(v_in),
        .lri(lri), .avi(avi), .uri(uri), .pvarp(pvarp), .vrp(vrp),
        .ap(ap), .vp(vp), .as_evt(as_evt), .vs_evt(vs_evt), .arrhythmia(arr));

    reg f_past_valid = 1'b0;
    always @(posedge clk) f_past_valid <= 1'b1;
    always @(*) if (!f_past_valid) assume(!rst_n);              // start in reset

    always @(*) begin                                          // legal parameter set
        assume(lri >= 8'd2 && lri <= 8'd60);
        assume(avi >= 8'd1 && avi < lri);
        assume(uri >= avi && uri <= lri);
        assume(pvarp >= 8'd1 && pvarp <= 8'd60);
        assume(vrp >= 8'd1 && vrp <= 8'd60);
    end
    // parameters change only while the controller is (and was) disabled
    always @(posedge clk)
        if (f_past_valid && (enable || $past(enable))) begin
            assume(lri == $past(lri));   assume(avi == $past(avi));
            assume(uri == $past(uri));   assume(pvarp == $past(pvarp));
            assume(vrp == $past(vrp));
        end
endmodule
