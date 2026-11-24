// ddd_sva.sv -- SystemVerilog assertions for the DDD controller and its APB slave.
// Bound into the unmodified RTL (no source edits):
//   bind ddd_pacemaker     ddd_sva     #(.W(W)) u_sva (.*);
//   bind ddd_pacemaker_apb ddd_apb_sva #(.W(W)) u_apb_sva (.*);
`timescale 1ns/1ps

module ddd_sva #(parameter W = 16) (
    input logic         clk, rst_n, enable, tick_en, a_sense_in, v_sense_in,
    input logic [W-1:0] lri, avi, uri, pvarp, vrp,
    input logic         ap, vp, as_evt, vs_evt, arrhythmia,
    input logic         phase,
    input logic [W-1:0] t_v, t_av
);
    // timer values the controller compares on this tick
    wire [W-1:0] tv_n  = (t_v >= lri) ? lri + 1'b1 : t_v + 1'b1;
    wire [W-1:0] tav_n = phase ? t_av + 1'b1 : '0;
    wire [W-1:0] aei   = lri - avi;
    wire         step  = tick_en && enable;

    // ticks since the last ventricular event (for the bounded-liveness check)
    logic [W:0] since_v;
    always_ff @(posedge clk)
        if (!rst_n || vp || vs_evt) since_v <= '0;
        else if (step)               since_v <= since_v + 1'b1;

    default clocking cb @(posedge clk); endclocking

    A01_no_ap_and_vp:      assert property (disable iff (!rst_n) !(ap && vp));
    A02_one_atrial_event:  assert property (disable iff (!rst_n) !(ap && as_evt));
    A03_one_vent_event:    assert property (disable iff (!rst_n) !(vp && vs_evt));
    A04_events_need_tick:  assert property (disable iff (!rst_n) (ap || vp || as_evt || vs_evt || arrhythmia) |-> $past(step));
    A05_no_vs_in_vrp:      assert property (disable iff (!rst_n) (step && tv_n < vrp) |=> !vs_evt);
    A06_no_as_in_pvarp:    assert property (disable iff (!rst_n) (step && !phase && tv_n < pvarp) |=> !as_evt);
    A07_no_vp_before_uri:  assert property (disable iff (!rst_n) (step && tv_n < uri) |=> !vp);
    A08_vp_only_after_avi: assert property (disable iff (!rst_n) (step && !(phase && tav_n >= avi)) |=> !vp);
    A09_no_ap_before_aei:  assert property (disable iff (!rst_n) (step && !phase && tv_n < aei) |=> !ap);
    A10_tv_bounded:        assert property (disable iff (!rst_n) (step && $stable(lri)) |=> t_v <= lri + 1'b1);  // saturates at LRI+1
    A11_tav_zero_in_aei:   assert property (disable iff (!rst_n) !phase |-> t_av == '0);
    A12_v_event_restarts:  assert property (disable iff (!rst_n) (vp || vs_evt) |-> (t_v == '0 && !phase));
    A13_a_event_opens_avi: assert property (disable iff (!rst_n) (ap || as_evt) |-> (phase && t_av == '0));
    A14_arr_with_v_event:  assert property (disable iff (!rst_n) arrhythmia |-> (vp || vs_evt));
    A15_v_within_lri:      assert property (disable iff (!rst_n) since_v <= lri + 1'b1);   // bounded liveness

    C01_vs_upper_rate:     cover property (disable iff (!rst_n) vs_evt && arrhythmia);
    C02_vp_upper_rate:     cover property (disable iff (!rst_n) vp && arrhythmia);
    C03_as_then_vp:        cover property (disable iff (!rst_n) as_evt ##[1:$] vp);
endmodule

module ddd_apb_sva #(parameter W = 16) (
    input logic        PCLK, PRESETn, PSEL, PENABLE, PWRITE,
    input logic [7:0]  PADDR,
    input logic [31:0] PWDATA,
    input logic        PREADY, PSLVERR, arr_pulse, arrhythmia_irq
);
    default clocking cb @(posedge PCLK); endclocking

    A16_apb_access_after_setup: assert property (disable iff (!PRESETn) $rose(PENABLE) |-> (PSEL && $past(PSEL && !PENABLE)));
    A17_irq_latches:            assert property (disable iff (!PRESETn) arr_pulse |=> arrhythmia_irq);
    A18_irq_w1c:                assert property (disable iff (!PRESETn) (PSEL && PENABLE && PWRITE && PADDR[7:2] == 6'h05
                                                  && PWDATA[1] && !arr_pulse) |=> !arrhythmia_irq);
    A19_no_wait_no_error:       assert property (disable iff (!PRESETn) PREADY && !PSLVERR);
endmodule

bind ddd_pacemaker     ddd_sva     #(.W(W)) u_sva     (.*);
bind ddd_pacemaker_apb ddd_apb_sva #(.W(W)) u_apb_sva (.*);
