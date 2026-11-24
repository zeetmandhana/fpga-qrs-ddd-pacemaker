`timescale 1ns/1ps
//============================================================================
// p17_bd_blocks.v  --  thin block-design wrappers (IP Integrator module refs)
//
// They only add standard APB / clock / reset interface tags (so the block
// design draws proper bus connections) around the verified RTL blocks:
//   p17_ddd_slave         ddd_pacemaker_apb as an APB slave (32-bit PADDR)
//   p17_ctrl_slave        demo_ctrl_apb as an APB slave
//   p17_display           ecg_display + APB text-RAM slave + Pmod VGA pins
//   p17_qrs_hls_decision  drives the Vitis-HLS qrs_stream IP once per sample,
//                         captures hp/dv/mwi and runs qrs_decision
//============================================================================

module p17_ddd_slave (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF APB_S, ASSOCIATED_RESET rst_n" *)
    input  wire        clk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst_n RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire        rst_n,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_S PADDR" *)   input  wire [31:0] s_paddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_S PSEL" *)    input  wire        s_psel,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_S PENABLE" *) input  wire        s_penable,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_S PWRITE" *)  input  wire        s_pwrite,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_S PWDATA" *)  input  wire [31:0] s_pwdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_S PRDATA" *)  output wire [31:0] s_prdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_S PREADY" *)  output wire        s_pready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_S PSLVERR" *) output wire        s_pslverr,
    input  wire        tick_ms,
    input  wire        a_sense,
    input  wire        v_sense,
    output wire        ap,
    output wire        vp,
    output wire        as_evt,
    output wire        vs_evt,
    (* X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 arrhythmia_irq INTERRUPT" *)
    (* X_INTERFACE_PARAMETER = "SENSITIVITY LEVEL_HIGH" *)
    output wire        arrhythmia_irq
);
    ddd_pacemaker_apb #(.W(16)) u_pm (
        .PCLK(clk), .PRESETn(rst_n), .PSEL(s_psel), .PENABLE(s_penable), .PWRITE(s_pwrite),
        .PADDR(s_paddr[7:0]), .PWDATA(s_pwdata), .PRDATA(s_prdata), .PREADY(s_pready),
        .PSLVERR(s_pslverr), .tick_en(tick_ms), .a_sense_in(a_sense), .v_sense_in(v_sense),
        .ap(ap), .vp(vp), .as_evt(as_evt), .vs_evt(vs_evt), .arrhythmia_irq(arrhythmia_irq));
endmodule


module p17_ctrl_slave (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF APB_S, ASSOCIATED_RESET rst_n" *)
    input  wire        clk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst_n RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire        rst_n,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_S PADDR" *)   input  wire [31:0] s_paddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_S PSEL" *)    input  wire        s_psel,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_S PENABLE" *) input  wire        s_penable,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_S PWRITE" *)  input  wire        s_pwrite,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_S PWDATA" *)  input  wire [31:0] s_pwdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_S PRDATA" *)  output wire [31:0] s_prdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_S PREADY" *)  output wire        s_pready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_S PSLVERR" *) output wire        s_pslverr,
    output wire [2:0]  mode,
    output wire        mode_wr,
    input  wire        qrs_evt,
    input  wire        ap_evt,
    input  wire        vp_evt,
    input  wire        as_evt,
    input  wire        vs_evt,
    input  wire [31:0] last_rr,
    input  wire        learning
);
    assign s_pready = 1'b1;
    assign s_pslverr = 1'b0;
    demo_ctrl_apb u_ctl (
        .PCLK(clk), .PRESETn(rst_n), .PSEL(s_psel), .PENABLE(s_penable), .PWRITE(s_pwrite),
        .PADDR(s_paddr[7:0]), .PWDATA(s_pwdata), .PRDATA(s_prdata), .mode(mode), .mode_wr(mode_wr),
        .qrs_evt(qrs_evt), .ap_evt(ap_evt), .vp_evt(vp_evt), .as_evt(as_evt), .vs_evt(vs_evt),
        .last_rr(last_rr), .learning(learning));
endmodule


module p17_display (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF APB_S, ASSOCIATED_RESET rst_n" *)
    input  wire        clk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst_n RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire        rst_n,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_S PADDR" *)   input  wire [31:0] s_paddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_S PSEL" *)    input  wire        s_psel,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_S PENABLE" *) input  wire        s_penable,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_S PWRITE" *)  input  wire        s_pwrite,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_S PWDATA" *)  input  wire [31:0] s_pwdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_S PRDATA" *)  output wire [31:0] s_prdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_S PREADY" *)  output wire        s_pready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_S PSLVERR" *) output wire        s_pslverr,
    input  wire        freeze,
    input  wire        smp_valid,
    input  wire [10:0] smp_adc,
    input  wire [39:0] smp_mwi,
    input  wire [39:0] smp_thr,
    input  wire [39:0] smp_spki,
    input  wire        qrs_det,
    input  wire [31:0] qrs_delay,
    input  wire        ev_ap,
    input  wire        ev_vp,
    input  wire        ev_as,
    input  wire        ev_vs,
    output wire [7:0]  red,
    output wire [7:0]  green,
    output wire [7:0]  blue,
    output wire        hsync,
    output wire        vsync,
    output wire        de,
    output wire [7:0]  jc,             // Pmod VGA J1: R0-3, B0-3
    output wire [7:0]  jd              // Pmod VGA J2: G0-3, HS, VS
);
    assign s_prdata = 32'd0;
    assign s_pready = 1'b1;
    assign s_pslverr = 1'b0;
    wire txt_we = s_psel & s_penable & s_pwrite;
    ecg_display u_disp (
        .clk(clk), .rst_n(rst_n), .freeze(freeze),
        .smp_valid(smp_valid), .smp_adc(smp_adc), .smp_mwi(smp_mwi), .smp_thr(smp_thr),
        .smp_spki(smp_spki), .qrs_det(qrs_det), .qrs_delay(qrs_delay),
        .ev_ap(ev_ap), .ev_vp(ev_vp), .ev_as(ev_as), .ev_vs(ev_vs),
        .txt_we(txt_we), .txt_addr(s_paddr[13:2]), .txt_data(s_pwdata[6:0]),
        .red(red), .green(green), .blue(blue), .hsync(hsync), .vsync(vsync), .de(de));
    assign jc = {blue[7:4], red[7:4]};
    assign jd = {2'b00, vsync, hsync, green[7:4]};
endmodule


module p17_qrs_hls_decision (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        relearn_n,
    input  wire        sample_valid,
    input  wire [10:0] adc,
    // to / from the Vitis-HLS qrs_stream IP (ap_ctrl_hs + ap_none/ap_vld ports)
    (* X_INTERFACE_INFO = "xilinx.com:interface:acc_handshake:1.0 ap_ctrl start" *) output reg  hls_ap_start,
    (* X_INTERFACE_INFO = "xilinx.com:interface:acc_handshake:1.0 ap_ctrl ready" *) input  wire hls_ap_ready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:acc_handshake:1.0 ap_ctrl done" *)  input  wire hls_ap_done,
    (* X_INTERFACE_INFO = "xilinx.com:interface:acc_handshake:1.0 ap_ctrl idle" *)  input  wire hls_ap_idle,
    output reg  [15:0] hls_x,
    output wire [31:0] hls_baseline,
    input  wire [31:0] hls_hp,
    input  wire        hls_hp_vld,
    input  wire [31:0] hls_dv,
    input  wire        hls_dv_vld,
    input  wire [39:0] hls_mwi,
    input  wire        hls_mwi_vld,
    output wire        hls_rst,
    // detector outputs
    output wire        det,
    output wire [31:0] det_r,
    output wire        det_sb,
    output wire [31:0] n_cnt,
    output reg  [39:0] mwi_q,
    output wire [39:0] thr1,
    output wire [39:0] spki,
    output wire        learning
);
    assign hls_baseline = 32'd1024;
    assign hls_rst = ~rst_n;
    always @(posedge clk) begin
        if (!rst_n) begin
            hls_ap_start <= 1'b0; hls_x <= 16'd0;
        end else begin
            if (sample_valid) begin hls_x <= {5'd0, adc}; hls_ap_start <= 1'b1; end
            else if (hls_ap_ready) hls_ap_start <= 1'b0;
        end
    end
    reg [31:0] hp_q, dv_q;
    reg        got_hp, got_dv, got_mwi, dec_valid;
    always @(posedge clk) begin
        if (!rst_n) begin
            hp_q <= 0; dv_q <= 0; mwi_q <= 0;
            got_hp <= 0; got_dv <= 0; got_mwi <= 0; dec_valid <= 0;
        end else begin
            dec_valid <= 1'b0;
            if (hls_hp_vld)  begin hp_q  <= hls_hp;  got_hp  <= 1'b1; end
            if (hls_dv_vld)  begin dv_q  <= hls_dv;  got_dv  <= 1'b1; end
            if (hls_mwi_vld) begin mwi_q <= hls_mwi; got_mwi <= 1'b1; end
            if (got_hp && got_dv && got_mwi) begin
                dec_valid <= 1'b1; got_hp <= 1'b0; got_dv <= 1'b0; got_mwi <= 1'b0;
            end
        end
    end
    qrs_decision u_dec (
        .clk(clk), .rst_n(rst_n & relearn_n), .in_valid(dec_valid),
        .hp(hp_q), .dv(dv_q), .mwi(mwi_q),
        .det(det), .det_r(det_r), .det_sb(det_sb), .n_cnt(n_cnt),
        .thr1_o(thr1), .spki_o(spki), .learning_o(learning));
endmodule
