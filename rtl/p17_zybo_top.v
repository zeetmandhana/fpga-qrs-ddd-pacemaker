`timescale 1ns/1ps
//============================================================================
// p17_zybo_top.v  --  P17 QRS Detector + DDD Pacemaker: Zybo Z7-10 board top
//                     (xc7z010clg400-1, programmable logic only)
//
// Pure structural top: every box in Vivado's top-level schematic is one
// sub-system of the design.
//
//   u_clk    p17_clocking      125 MHz -> MMCM -> 25 MHz system + 125 MHz TMDS
//   u_time   p17_timebase      1 ms pacemaker tick, 360 Hz ECG sample tick
//   u_io     p17_board_io      switches/buttons, LEDs, RGB LED
//   u_cpu    neorv32_p17       RV32I NEORV32 + firmware (range check, IRQ, status)
//   u_br     xbus_apb_bridge   CPU external bus -> APB3
//   u_pm     ddd_pacemaker_apb DDD timers LRI/AVI/URI/PVARP/VRP (APB slave 0)
//   u_ctl    demo_ctrl_apb     scenario select + counters      (APB slave 1)
//   u_disp   ecg_display       ECG monitor screen + text RAM   (APB slave 2)
//   u_heart  heart_model       closed-loop heart (normal/brady/block/dual/PMT)
//   u_ecg    ecg_source        MIT-BIH 100 replay BRAM / synthesised ECG
//   u_det    qrs_detector      Vitis-HLS filter chain (qrs_stream) + RTL decision
//   u_route  p17_event_router  sense/activation wiring of the closed loop
//   u_hdmi   hdmi_tx           TMDS/DVI output to the HDMI TX port
//
// LD0 = AP pace, LD1 = VP pace, LD2 = QRS detected, LD3 = arrhythmia IRQ,
// LD6 (RGB) = scenario colour. Pmod VGA: J1 on JC, J2 on JD.
//============================================================================
module p17_zybo_top #(
    parameter SIM_DIV = 1                 // >1 only in simulation: faster ticks
)(
    input  wire       sysclk,             // 125 MHz (K17)
    input  wire [3:0] btn,                // btn0 = reset
    input  wire [3:0] sw,
    output wire [3:0] led,
    output wire       led6_r, led6_g, led6_b,
    output wire       hdmi_tx_clk_p, hdmi_tx_clk_n,
    output wire [2:0] hdmi_tx_p, hdmi_tx_n,
    output wire [7:0] jc,                 // Pmod VGA J1: R0-3 (1-4), B0-3 (7-10)
    output wire [7:0] jd                  // Pmod VGA J2: G0-3 (1-4), HS (7), VS (8)
);
    // ---------------- clocks, reset, time base, board I/O ----------------
    wire clk, clk125, rst_n, rst;
    p17_clocking u_clk (.sysclk(sysclk), .btn_rst(btn[0]), .clk(clk), .clk125(clk125),
                        .rst_n(rst_n), .rst(rst));

    wire tick_ms, tick_360;
    p17_timebase #(.SIM_DIV(SIM_DIV)) u_time (.clk(clk), .rst_n(rst_n),
                        .tick_ms(tick_ms), .tick_360(tick_360));

    wire [7:0] in_db;
    wire [7:0] gpio_o;
    wire       ap, vp, det, arr_irq;
    p17_board_io #(.SIM_DIV(SIM_DIV)) u_io (
        .clk(clk), .rst_n(rst_n), .btn(btn), .sw(sw), .in_db(in_db),
        .ap(ap), .vp(vp), .det(det), .arr_irq(arr_irq), .rgb(gpio_o[2:0]),
        .led(led), .led6_r(led6_r), .led6_g(led6_g), .led6_b(led6_b));

    // ---------------- RV32 processor + XBUS->APB bridge ----------------
    wire [31:0] x_adr, x_dw, x_dr;
    wire        x_we, x_stb, x_cyc, x_ack, x_err;
    neorv32_p17 u_cpu (
        .clk_i(clk), .rstn_i(rst_n), .gpio_o(gpio_o), .gpio_i(in_db), .irq_mei_i(arr_irq),
        .xbus_adr_o(x_adr), .xbus_dat_o(x_dw), .xbus_we_o(x_we), .xbus_stb_o(x_stb),
        .xbus_cyc_o(x_cyc), .xbus_dat_i(x_dr), .xbus_ack_i(x_ack), .xbus_err_i(x_err));

    wire [15:0] PADDR;
    wire [31:0] PWDATA, PRDATA0, PRDATA1;
    wire        PWRITE, PENABLE;
    wire [2:0]  PSEL;
    xbus_apb_bridge u_br (
        .clk(clk), .rst_n(rst_n), .xbus_adr(x_adr), .xbus_dat_w(x_dw), .xbus_we(x_we),
        .xbus_stb(x_stb), .xbus_dat_r(x_dr), .xbus_ack(x_ack), .xbus_err(x_err),
        .PADDR(PADDR), .PWDATA(PWDATA), .PWRITE(PWRITE), .PENABLE(PENABLE), .PSEL(PSEL),
        .PRDATA0(PRDATA0), .PRDATA1(PRDATA1), .PRDATA2(32'd0));

    // ---------------- APB slaves: DDD pacemaker, demo control ----------------
    wire as_evt, vs_evt, a_sense, v_sense;
    ddd_pacemaker_apb #(.W(16)) u_pm (
        .PCLK(clk), .PRESETn(rst_n), .PSEL(PSEL[0]), .PENABLE(PENABLE), .PWRITE(PWRITE),
        .PADDR(PADDR[7:0]), .PWDATA(PWDATA), .PRDATA(PRDATA0), .PREADY(), .PSLVERR(),
        .tick_en(tick_ms), .a_sense_in(a_sense), .v_sense_in(v_sense),
        .ap(ap), .vp(vp), .as_evt(as_evt), .vs_evt(vs_evt), .arrhythmia_irq(arr_irq));

    wire [2:0]  mode;
    wire        mode_wr, learning;
    wire [31:0] last_rr;
    demo_ctrl_apb u_ctl (
        .PCLK(clk), .PRESETn(rst_n), .PSEL(PSEL[1]), .PENABLE(PENABLE), .PWRITE(PWRITE),
        .PADDR(PADDR[7:0]), .PWDATA(PWDATA), .PRDATA(PRDATA1), .mode(mode), .mode_wr(mode_wr),
        .qrs_evt(det), .ap_evt(ap), .vp_evt(vp), .as_evt(as_evt), .vs_evt(vs_evt),
        .last_rr(last_rr), .learning(learning));

    // ---------------- closed loop: router + heart model ----------------
    wire        scen_rst_n, heart_update, a_in, v_in, a_act, v_act, ecg_a_act, ecg_v_intr;
    wire        txt_we, det_sb;
    wire [31:0] det_r, n_cnt, qrs_delay;
    p17_event_router u_route (
        .clk(clk), .rst_n(rst_n), .mode(mode), .mode_wr(mode_wr), .scen_rst_n(scen_rst_n),
        .tick_ms(tick_ms), .heart_update(heart_update),
        .a_in(a_in), .v_in(v_in), .ap(ap), .vp(vp), .a_act(a_act), .v_act(v_act),
        .a_sense(a_sense), .v_sense(v_sense), .ecg_a_act(ecg_a_act), .ecg_v_intr(ecg_v_intr),
        .det(det), .det_r(det_r), .n_cnt(n_cnt), .last_rr(last_rr), .qrs_delay(qrs_delay),
        .psel_txt(PSEL[2]), .penable(PENABLE), .pwrite(PWRITE), .txt_we(txt_we));

    heart_model u_heart (
        .clk(clk), .rst_n(scen_rst_n), .scen(mode), .update(heart_update),
        .a_act(a_act), .v_act(v_act), .a_in(a_in), .v_in(v_in));

    // ---------------- ECG source + Pan-Tompkins detector ----------------
    wire [10:0] adc;
    wire        adc_valid;
    ecg_source u_ecg (
        .clk(clk), .rst_n(scen_rst_n), .mode(mode), .tick_360(tick_360),
        .a_act(ecg_a_act), .v_intr(ecg_v_intr), .ap(ap), .vp(vp),
        .adc(adc), .adc_valid(adc_valid));

    wire [39:0] mwi_q, thr1, spki;
    qrs_detector u_det (
        .clk(clk), .rst_n(rst_n), .relearn_n(scen_rst_n), .sample_valid(adc_valid), .adc(adc),
        .det(det), .det_r(det_r), .det_sb(det_sb), .n_cnt(n_cnt), .mwi_q(mwi_q),
        .thr1(thr1), .spki(spki), .learning(learning));

    // ---------------- display: HDMI + Pmod VGA ----------------
    wire [7:0] vr, vg, vb;
    wire       vhs, vvs, vde;
    ecg_display u_disp (
        .clk(clk), .rst_n(rst_n), .freeze(in_db[2]),
        .smp_valid(adc_valid), .smp_adc(adc), .smp_mwi(mwi_q), .smp_thr(thr1), .smp_spki(spki),
        .qrs_det(det), .qrs_delay(qrs_delay),
        .ev_ap(ap), .ev_vp(vp), .ev_as(as_evt), .ev_vs(vs_evt),
        .txt_we(txt_we), .txt_addr(PADDR[13:2]), .txt_data(PWDATA[6:0]),
        .red(vr), .green(vg), .blue(vb), .hsync(vhs), .vsync(vvs), .de(vde));

    hdmi_tx u_hdmi (
        .pix_clk(clk), .ser_clk(clk125), .rst(rst),
        .red(vr), .green(vg), .blue(vb), .hsync(vhs), .vsync(vvs), .de(vde),
        .tmds_clk_p(hdmi_tx_clk_p), .tmds_clk_n(hdmi_tx_clk_n),
        .tmds_p(hdmi_tx_p), .tmds_n(hdmi_tx_n));

    assign jc = {vb[7:4], vr[7:4]};               // J1: pins 1-4 R, 7-10 B
    assign jd = {2'b00, vvs, vhs, vg[7:4]};       // J2: pins 1-4 G, 7 HS, 8 VS
endmodule
