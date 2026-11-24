`timescale 1ns/1ps
//============================================================================
// p17_jtag_debug.v  --  board test without a monitor: JTAG (VIO) visibility
//
// Sits between the board buttons/switches and the design, and next to a
// Vivado VIO core:
//   * virtual buttons / switches from the VIO (probe_out) are OR-ed with the
//     real buttons, or replace the real switches when vio_sw_en = 1;
//   * free-running event counters (QRS detected, AP, VP, AS, VS, arrhythmia
//     IRQ rising edges) and a millisecond up-time counter are presented to
//     the VIO probe inputs, so the laptop can read what the board is doing.
//============================================================================
module p17_jtag_debug (
    input  wire        clk,
    input  wire        rst_n,
    // real board inputs and VIO overrides
    input  wire [3:0]  btn_in,
    input  wire [3:0]  sw_in,
    input  wire [3:0]  vio_btn,
    input  wire [3:0]  vio_sw,
    input  wire        vio_sw_en,
    output wire [3:0]  btn_out,
    output wire [3:0]  sw_out,
    // events to count
    input  wire        tick_ms,
    input  wire        det,
    input  wire        ap,
    input  wire        vp,
    input  wire        as_evt,
    input  wire        vs_evt,
    input  wire        arr_irq,
    output reg  [31:0] cnt_qrs,
    output reg  [31:0] cnt_ap,
    output reg  [31:0] cnt_vp,
    output reg  [31:0] cnt_as,
    output reg  [31:0] cnt_vs,
    output reg  [15:0] cnt_irq,
    output reg  [31:0] uptime_ms
);
    assign btn_out = btn_in | vio_btn;
    assign sw_out  = vio_sw_en ? vio_sw : sw_in;

    reg irq_d;
    always @(posedge clk) begin
        if (!rst_n) begin
            cnt_qrs <= 0; cnt_ap <= 0; cnt_vp <= 0; cnt_as <= 0; cnt_vs <= 0;
            cnt_irq <= 0; uptime_ms <= 0; irq_d <= 1'b0;
        end else begin
            irq_d <= arr_irq;
            if (det)     cnt_qrs <= cnt_qrs + 1'b1;
            if (ap)      cnt_ap  <= cnt_ap + 1'b1;
            if (vp)      cnt_vp  <= cnt_vp + 1'b1;
            if (as_evt)  cnt_as  <= cnt_as + 1'b1;
            if (vs_evt)  cnt_vs  <= cnt_vs + 1'b1;
            if (arr_irq && !irq_d) cnt_irq <= cnt_irq + 1'b1;
            if (tick_ms) uptime_ms <= uptime_ms + 1'b1;
        end
    end
endmodule
