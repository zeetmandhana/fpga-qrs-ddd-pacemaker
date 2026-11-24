`timescale 1ns/1ps
//============================================================================
// ecg_display.v  --  P17 board phase: 640x480 ECG monitor screen
//
// Sweep display like a bedside monitor: 3 samples per column, 640 columns =
// 5.3 s per sweep, an 8-column erase gap ahead of the write cursor.
//
//   y   0- 47  status text (written by the RV32 firmware over APB)
//   y  48-351  ECG trace (green) on a grid; detected QRS = red marker at the
//              R peak (band at the top + faint full-height line)
//   y 352-367  atrial marker channel: AP yellow, AS white
//   y 368-383  ventricular marker channel: VP cyan, VS white
//   y 384-399  label text
//   y 400-463  Pan-Tompkins MWI (orange) + adaptive threshold THR1 (magenta),
//              auto-scaled by the signal-peak estimate SPKI
//   y 464-479  legend text
//
// The R-peak marker is placed RETROACTIVELY: the detector reports a QRS
// ~210 ms after the R peak together with how many samples ago it was, and the
// marker is written into that earlier column.
// Text: 80x30 characters of 8x16 pixels; text RAM written via txt_we.
//============================================================================
module ecg_display #(
    parameter MEM_DIR = "C:/Vivadoproject/P17_QRS_Pacemaker/rtl/mem/"
)(
    input  wire        clk,            // 25 MHz pixel clock (= system clock)
    input  wire        rst_n,
    input  wire        freeze,         // hold the picture
    // one pulse per 360 Hz sample
    input  wire        smp_valid,
    input  wire [10:0] smp_adc,
    input  wire [39:0] smp_mwi,
    input  wire [39:0] smp_thr,
    input  wire [39:0] smp_spki,
    // events
    input  wire        qrs_det,
    input  wire [31:0] qrs_delay,      // samples between the latest sample and the R peak
    input  wire        ev_ap, ev_vp, ev_as, ev_vs,
    // text RAM write port
    input  wire        txt_we,
    input  wire [11:0] txt_addr,       // {row[4:0], col[6:0]}
    input  wire [6:0]  txt_data,
    // video
    output reg  [7:0]  red, green, blue,
    output reg         hsync, vsync, de
);
    //------------------------------------------------------------------
    // writer: sweep position, per-column min/max, event flags
    //------------------------------------------------------------------
    reg [10:0] S;          // position of the latest sample, 0..1919
    reg [9:0]  col;        // its column, 0..639
    reg [1:0]  sub;        // its index inside the column, 0..2
    reg [8:0]  prev_y, ymin, ymax;
    reg [5:0]  prev_m, mmin, mmax;

    // ECG row: y = 210 - (adc-1024)/2, clamped to the panel
    wire signed [11:0] d_adc = {1'b0, smp_adc} - 12'sd1024;
    wire signed [11:0] y_raw = 12'sd210 - (d_adc >>> 1);
    wire [8:0] y_new = (y_raw < 12'sd48) ? 9'd48 : ((y_raw > 12'sd351) ? 9'd351 : y_raw[8:0]);

    // MWI scaling: shift so SPKI lands in 32..63 pixels
    reg [5:0] msb;
    integer bi;
    always @(*) begin
        msb = 0;
        for (bi = 0; bi < 40; bi = bi + 1) if (smp_spki[bi]) msb = bi;
    end
    wire [5:0]  sh   = (msb > 6'd5) ? (msb - 6'd5) : 6'd0;
    wire [39:0] m_s  = smp_mwi >> sh;
    wire [39:0] t_s  = smp_thr >> sh;
    wire [5:0]  m_new = (m_s > 40'd63) ? 6'd63 : m_s[5:0];
    wire [5:0]  t_new = (t_s > 40'd63) ? 6'd63 : t_s[5:0];

    wire [10:0] S_n   = (S == 11'd1919) ? 11'd0 : (S + 1'b1);
    wire        newc  = (sub == 2'd2);
    wire [9:0]  col_n = newc ? ((col == 10'd639) ? 10'd0 : col + 1'b1) : col;
    wire [8:0]  lo_y  = newc ? ((prev_y < y_new) ? prev_y : y_new) : ((ymin < y_new) ? ymin : y_new);
    wire [8:0]  hi_y  = newc ? ((prev_y > y_new) ? prev_y : y_new) : ((ymax > y_new) ? ymax : y_new);
    wire [5:0]  lo_m  = newc ? ((prev_m < m_new) ? prev_m : m_new) : ((mmin < m_new) ? mmin : m_new);
    wire [5:0]  hi_m  = newc ? ((prev_m > m_new) ? prev_m : m_new) : ((mmax > m_new) ? mmax : m_new);

    // column RAM: {ymin, ymax, mmin, mmax, thr}
    (* ram_style = "block" *) reg [35:0] colram [0:639];
    reg        cw_en;
    reg [9:0]  cw_a;
    reg [35:0] cw_d;
    always @(posedge clk) if (cw_en) colram[cw_a] <= cw_d;

    // QRS column: pos = S - delay (mod 1920), col = pos / 3 = (pos * 683) >> 11
    wire [31:0] dly   = qrs_delay;
    wire [11:0] pos_a = {1'b0, S} - dly[11:0];
    wire [10:0] pos   = (dly[11:0] > {1'b0, S}) ? (pos_a[10:0] + 11'd1920) : pos_a[10:0];
    wire [21:0] p683  = ({11'd0, pos} << 9) + ({11'd0, pos} << 7) + ({11'd0, pos} << 5) +
                        ({11'd0, pos} << 3) + ({11'd0, pos} << 1) + {11'd0, pos};
    wire [9:0]  qcol  = p683[20:11];

    // event-flag RAMs (1 bit per column), one write per clock via a small queue
    reg f_qrs [0:639];
    reg f_ap  [0:639];
    reg f_vp  [0:639];
    reg f_as  [0:639];
    reg f_vs  [0:639];
    reg        q_clr, q_ap, q_vp, q_as, q_vs, q_q0, q_q1;
    reg [9:0]  a_clr, a_ap, a_vp, a_as, a_vs, a_q;

    always @(posedge clk) begin
        if (!rst_n) begin
            S <= 11'd1919; col <= 10'd639; sub <= 2'd2;
            prev_y <= 9'd210; ymin <= 9'd210; ymax <= 9'd210;
            prev_m <= 0; mmin <= 0; mmax <= 0;
            cw_en <= 1'b0;
            q_clr <= 0; q_ap <= 0; q_vp <= 0; q_as <= 0; q_vs <= 0; q_q0 <= 0; q_q1 <= 0;
        end else begin
            cw_en <= 1'b0;
            if (smp_valid && !freeze) begin
                S <= S_n; col <= col_n; sub <= newc ? 2'd0 : sub + 1'b1;
                ymin <= lo_y; ymax <= hi_y; mmin <= lo_m; mmax <= hi_m;
                prev_y <= y_new; prev_m <= m_new;
                cw_en <= 1'b1; cw_a <= col_n; cw_d <= {lo_y, hi_y, lo_m, hi_m, t_new};
                if (newc) begin q_clr <= 1'b1; a_clr <= col_n; end
            end
            if (!freeze) begin
                if (ev_ap) begin q_ap <= 1'b1; a_ap <= col; end
                if (ev_vp) begin q_vp <= 1'b1; a_vp <= col; end
                if (ev_as) begin q_as <= 1'b1; a_as <= col; end
                if (ev_vs) begin q_vs <= 1'b1; a_vs <= col; end
                if (qrs_det && (dly < 32'd1900)) begin q_q0 <= 1'b1; q_q1 <= 1'b1; a_q <= qcol; end
            end
            // serve one flag write per clock (clear first)
            if (q_clr) begin
                f_qrs[a_clr] <= 1'b0; f_ap[a_clr] <= 1'b0; f_vp[a_clr] <= 1'b0;
                f_as[a_clr] <= 1'b0; f_vs[a_clr] <= 1'b0; q_clr <= 1'b0;
            end else if (q_ap) begin f_ap[a_ap] <= 1'b1; q_ap <= 1'b0; end
            else if (q_vp) begin f_vp[a_vp] <= 1'b1; q_vp <= 1'b0; end
            else if (q_as) begin f_as[a_as] <= 1'b1; q_as <= 1'b0; end
            else if (q_vs) begin f_vs[a_vs] <= 1'b1; q_vs <= 1'b0; end
            else if (q_q0) begin f_qrs[a_q] <= 1'b1; q_q0 <= 1'b0; end
            else if (q_q1) begin
                f_qrs[(a_q == 10'd639) ? 10'd0 : a_q + 1'b1] <= 1'b1; q_q1 <= 1'b0;
            end
        end
    end

    //------------------------------------------------------------------
    // text RAM (80 x 30, stride 128) and font ROM
    //------------------------------------------------------------------
    (* ram_style = "block" *) reg [6:0] tram [0:4095];
    integer ti;
    initial for (ti = 0; ti < 4096; ti = ti + 1) tram[ti] = 7'd32;
    always @(posedge clk) if (txt_we) tram[txt_addr] <= txt_data;

    reg [7:0] font [0:1535];
    initial $readmemh({MEM_DIR, "font8x16.mem"}, font);

    //------------------------------------------------------------------
    // renderer: t0 sync -> t1 RAM data -> t2 font row -> t3 pixel out
    //------------------------------------------------------------------
    wire       v_on, hs0, vs0;
    wire [9:0] px, py;
    vga_sync u_sync (.pix_clk(clk), .rst_n(rst_n), .hsync(hs0), .vsync(vs0),
                     .video_on(v_on), .px(px), .py(py));

    reg [35:0] cd1, cd2;
    reg        fq1, fa1, fv1, fas1, fvs1, fq2, fa2, fv2, fas2, fvs2;
    reg [6:0]  ch1;
    reg [7:0]  fr2;
    reg [9:0]  px1, py1, px2, py2;
    reg        on1, on2, hs1, hs2, vs1, vs2;
    reg [9:0]  cur1, cur2;

    always @(posedge clk) begin
        // t1
        cd1 <= colram[px];
        fq1 <= f_qrs[px]; fa1 <= f_ap[px]; fv1 <= f_vp[px]; fas1 <= f_as[px]; fvs1 <= f_vs[px];
        ch1 <= tram[{py[8:4], px[9:3]}];
        px1 <= px; py1 <= py; on1 <= v_on; hs1 <= hs0; vs1 <= vs0; cur1 <= col;
        // t2
        fr2 <= font[{ch1 - 7'd32, py1[3:0]}];
        cd2 <= cd1;
        fq2 <= fq1; fa2 <= fa1; fv2 <= fv1; fas2 <= fas1; fvs2 <= fvs1;
        px2 <= px1; py2 <= py1; on2 <= on1; hs2 <= hs1; vs2 <= vs1; cur2 <= cur1;
    end

    // t2 combinational pixel colour
    wire [8:0] c_ymin = cd2[35:27], c_ymax = cd2[26:18];
    wire [5:0] c_mmin = cd2[17:12], c_mmax = cd2[11:6], c_thr = cd2[5:0];
    wire [9:0] x = px2, y = py2;
    wire [9:0] dgap = (x >= cur2) ? (x - cur2) : (x + 10'd640 - cur2);
    wire gap      = (dgap >= 10'd1) && (dgap <= 10'd8);
    wire ecg_p    = (y >= 10'd48) && (y <= 10'd351);
    wire a_ch     = (y >= 10'd352) && (y <= 10'd367);
    wire v_ch     = (y >= 10'd368) && (y <= 10'd383);
    wire mwi_p    = (y >= 10'd400) && (y <= 10'd463);
    wire [9:0] my = 10'd463 - y;                     // MWI height of this row
    wire text_on  = fr2[3'd7 - x[2:0]];
    wire trace    = ecg_p && !gap && ({1'b0, y} + 10'd1 >= {1'b0, c_ymin}) && (y <= {1'b0, c_ymax} + 10'd1);
    wire qband    = ecg_p && !gap && fq2 && (y >= 10'd52) && (y <= 10'd72);
    wire qline    = ecg_p && !gap && fq2;
    wire grid_maj = ecg_p && ((x[6:0] == 7'd0) || (((y - 10'd48) & 10'h7F) == 10'd0));
    wire grid_min = ecg_p && ((x[4:0] == 5'd0) || (((y - 10'd48) & 10'h1F) == 10'd0));
    wire mtrace   = mwi_p && !gap && (my >= {4'd0, c_mmin}) && (my <= {4'd0, c_mmax});
    wire mthr     = mwi_p && !gap && (my == {4'd0, c_thr});
    wire sep      = (y == 10'd351) || (y == 10'd367) || (y == 10'd383) || (y == 10'd399) || (y == 10'd463);

    reg [23:0] rgb;
    always @(*) begin
        if (!on2)                                  rgb = 24'h000000;
        else if (text_on)                          rgb = (y < 10'd16) ? 24'hFFE040 : 24'hFFFFFF;
        else if (trace)                            rgb = 24'h30FF50;
        else if (qband)                            rgb = 24'hFF2020;
        else if (a_ch && !gap && fa2)              rgb = 24'hFFE000;
        else if (a_ch && !gap && fas2 && y >= 10'd360) rgb = 24'hE0E0E0;
        else if (v_ch && !gap && fv2)              rgb = 24'h00E0FF;
        else if (v_ch && !gap && fvs2 && y >= 10'd376) rgb = 24'hE0E0E0;
        else if (mthr)                             rgb = 24'hFF30FF;
        else if (mtrace)                           rgb = 24'hFF9020;
        else if (qline)                            rgb = 24'h601010;
        else if (sep)                              rgb = 24'h404850;
        else if (grid_maj)                         rgb = 24'h1C3A24;
        else if (grid_min)                         rgb = 24'h0E1E12;
        else                                       rgb = 24'h000008;
    end

    always @(posedge clk) begin
        {red, green, blue} <= rgb;
        hsync <= hs2; vsync <= vs2; de <= on2;
    end
endmodule
