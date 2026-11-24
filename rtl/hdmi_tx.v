`timescale 1ns/1ps
//============================================================================
// hdmi_tx.v  --  P17 board phase: DVI/HDMI transmitter for the Zybo Z7 HDMI TX
//
// The Zybo Z7 has no VGA connector, so the 640x480@60 picture is sent as DVI
// (accepted by every HDMI monitor): three TMDS-encoded colour channels plus a
// TMDS clock. Each 10-bit symbol is serialised with an OSERDESE2 master/slave
// pair in 10:1 DDR mode (pix_clk 25 MHz, ser_clk 125 MHz = 5x) and driven
// out through TMDS_33 differential buffers.
//============================================================================
module tmds_encoder (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] d,
    input  wire       c0,
    input  wire       c1,
    input  wire       de,
    output reg  [9:0] q
);
    // DVI 1.0 transition-minimised / DC-balanced coding
    function [3:0] ones8(input [7:0] v);
        integer i;
        begin
            ones8 = 0;
            for (i = 0; i < 8; i = i + 1) ones8 = ones8 + v[i];
        end
    endfunction

    wire [3:0] n1d = ones8(d);
    wire       use_xnor = (n1d > 4'd4) || ((n1d == 4'd4) && (d[0] == 1'b0));
    wire [8:0] qm;
    assign qm[0] = d[0];
    genvar g;
    generate for (g = 1; g < 8; g = g + 1) begin : g_qm
        assign qm[g] = use_xnor ? ~(qm[g-1] ^ d[g]) : (qm[g-1] ^ d[g]);
    end endgenerate
    assign qm[8] = ~use_xnor;

    wire [3:0] n1q = ones8(qm[7:0]);
    wire [3:0] n0q = 4'd8 - n1q;
    reg signed [5:0] cnt;
    wire signed [5:0] diff = $signed({2'b00, n1q}) - $signed({2'b00, n0q});   // n1 - n0

    always @(posedge clk) begin
        if (rst) begin
            q <= 10'b1101010100; cnt <= 0;
        end else if (!de) begin
            cnt <= 0;
            case ({c1, c0})
                2'b00: q <= 10'b1101010100;
                2'b01: q <= 10'b0010101011;
                2'b10: q <= 10'b0101010100;
                default: q <= 10'b1010101011;
            endcase
        end else if ((cnt == 0) || (n1q == n0q)) begin
            q <= {~qm[8], qm[8], qm[8] ? qm[7:0] : ~qm[7:0]};
            cnt <= qm[8] ? (cnt + diff) : (cnt - diff);
        end else if (((cnt > 0) && (n1q > n0q)) || ((cnt < 0) && (n0q > n1q))) begin
            q <= {1'b1, qm[8], ~qm[7:0]};
            cnt <= cnt + $signed({4'd0, qm[8], 1'b0}) - diff;
        end else begin
            q <= {1'b0, qm[8], qm[7:0]};
            cnt <= cnt - $signed({4'd0, ~qm[8], 1'b0}) + diff;
        end
    end
endmodule

module tmds_serializer (
    input  wire       pix_clk,
    input  wire       ser_clk,
    input  wire       rst,
    input  wire [9:0] sym,
    output wire       out_p,
    output wire       out_n
);
    wire s1, s2, ser;
    OSERDESE2 #(.DATA_RATE_OQ("DDR"), .DATA_RATE_TQ("SDR"), .DATA_WIDTH(10),
                .SERDES_MODE("MASTER"), .TRISTATE_WIDTH(1), .TBYTE_CTL("FALSE"),
                .TBYTE_SRC("FALSE")) u_m (
        .OQ(ser), .OFB(), .TQ(), .TFB(), .SHIFTOUT1(), .SHIFTOUT2(), .TBYTEOUT(),
        .CLK(ser_clk), .CLKDIV(pix_clk),
        .D1(sym[0]), .D2(sym[1]), .D3(sym[2]), .D4(sym[3]),
        .D5(sym[4]), .D6(sym[5]), .D7(sym[6]), .D8(sym[7]),
        .OCE(1'b1), .RST(rst), .SHIFTIN1(s1), .SHIFTIN2(s2),
        .T1(1'b0), .T2(1'b0), .T3(1'b0), .T4(1'b0), .TBYTEIN(1'b0), .TCE(1'b0));
    OSERDESE2 #(.DATA_RATE_OQ("DDR"), .DATA_RATE_TQ("SDR"), .DATA_WIDTH(10),
                .SERDES_MODE("SLAVE"), .TRISTATE_WIDTH(1), .TBYTE_CTL("FALSE"),
                .TBYTE_SRC("FALSE")) u_s (
        .OQ(), .OFB(), .TQ(), .TFB(), .SHIFTOUT1(s1), .SHIFTOUT2(s2), .TBYTEOUT(),
        .CLK(ser_clk), .CLKDIV(pix_clk),
        .D1(1'b0), .D2(1'b0), .D3(sym[8]), .D4(sym[9]),
        .D5(1'b0), .D6(1'b0), .D7(1'b0), .D8(1'b0),
        .OCE(1'b1), .RST(rst), .SHIFTIN1(1'b0), .SHIFTIN2(1'b0),
        .T1(1'b0), .T2(1'b0), .T3(1'b0), .T4(1'b0), .TBYTEIN(1'b0), .TCE(1'b0));
    OBUFDS #(.IOSTANDARD("TMDS_33")) u_ob (.I(ser), .O(out_p), .OB(out_n));
endmodule

module hdmi_tx (
    input  wire       pix_clk,
    input  wire       ser_clk,
    input  wire       rst,          // synchronous to pix_clk
    input  wire [7:0] red, green, blue,
    input  wire       hsync, vsync, de,
    output wire       tmds_clk_p, tmds_clk_n,
    output wire [2:0] tmds_p, tmds_n
);
    wire [9:0] s0, s1, s2;
    tmds_encoder e0 (.clk(pix_clk), .rst(rst), .d(blue),  .c0(hsync), .c1(vsync), .de(de), .q(s0));
    tmds_encoder e1 (.clk(pix_clk), .rst(rst), .d(green), .c0(1'b0),  .c1(1'b0),  .de(de), .q(s1));
    tmds_encoder e2 (.clk(pix_clk), .rst(rst), .d(red),   .c0(1'b0),  .c1(1'b0),  .de(de), .q(s2));
    tmds_serializer z0 (.pix_clk(pix_clk), .ser_clk(ser_clk), .rst(rst), .sym(s0), .out_p(tmds_p[0]), .out_n(tmds_n[0]));
    tmds_serializer z1 (.pix_clk(pix_clk), .ser_clk(ser_clk), .rst(rst), .sym(s1), .out_p(tmds_p[1]), .out_n(tmds_n[1]));
    tmds_serializer z2 (.pix_clk(pix_clk), .ser_clk(ser_clk), .rst(rst), .sym(s2), .out_p(tmds_p[2]), .out_n(tmds_n[2]));
    tmds_serializer zc (.pix_clk(pix_clk), .ser_clk(ser_clk), .rst(rst), .sym(10'b0000011111),
                        .out_p(tmds_clk_p), .out_n(tmds_clk_n));
endmodule
