`timescale 1ns/1ps
//============================================================================
// qrs_fsmd_lat.v -- hand-HLS FSMD, MIN-LATENCY design point
// Same function as hls/qrs_stream.cpp, written by hand from the 2-ALU + 1-MUL
// schedule (8 control steps = the critical path; the ILP proves 2 ALUs are the
// minimum for 8 steps), clique-partitioning FU binding and left-edge register
// binding (2 temporaries R0, R1) of hand_hls.py.
//
//  step  ALU0 (32-bit)                 ALU1 (40-bit)            MUL         writes
//   1    u1 = 2*lp1 - lp2   -> R0      u2 = x12 - 2*x6 -> R1
//   2    xc = x - baseline  -> R0      u3 = R0 + R1    -> R1                xbuf[p16]
//   3    lp = R0 + R1       -> lp1     v1 = ms - lp32  -> R0                lpbuf[p64]
//   4    ms = R0 + lp1      -> ms      w1 = h1 - h3    -> R0
//   5    hp = lp16-(ms>>>5) -> hp_out  w2 = R0 - 2*h4  -> R0                hpbuf[p8]
//   6    dv = (2hp+R0)>>>3  -> dv_out  m1 = mwi - sq54 -> R0
//   7                                                           sq -> R1
//   8                                  mwi = R0 + R1   -> mwi_out          sqbuf[p64], ptr++
//
// Step 2 reads R0 (u1) on ALU1 and writes xc into R0 in the same step: legal,
// the register is read in the step and overwritten at its end (left-edge).
//============================================================================
module qrs_fsmd_lat (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               start,
    input  wire signed [15:0] x,
    input  wire signed [31:0] baseline,
    output reg                done,
    output reg  signed [31:0] hp_out,
    output reg  signed [31:0] dv_out,
    output reg         [39:0] mwi_out
);
    reg signed [31:0] xbuf  [0:15];
    reg signed [31:0] lpbuf [0:63];
    reg signed [31:0] hpbuf [0:7];
    reg        [31:0] sqbuf [0:63];
    integer k;
    initial begin
        for (k = 0; k < 16; k = k + 1) xbuf[k]  = 0;
        for (k = 0; k < 64; k = k + 1) lpbuf[k] = 0;
        for (k = 0; k < 8;  k = k + 1) hpbuf[k] = 0;
        for (k = 0; k < 64; k = k + 1) sqbuf[k] = 0;
    end

    reg        [5:0]  p64;
    reg        [3:0]  p16;
    reg        [2:0]  p8;
    reg signed [31:0] lp1, lp2, ms;
    reg        [39:0] R0;                     // u1, xc, v1, w1, w2, m1 (m1 needs 40 bits)
    reg signed [31:0] R1;                     // u2, u3, sq
    reg        [3:0]  st;                     // 0 = idle, 1..8 = control steps

    // memory read ports
    wire signed [31:0] x6   = xbuf[p16 - 4'd6];
    wire signed [31:0] x12  = xbuf[p16 - 4'd12];
    wire        [5:0]  lpa  = (st == 4'd3) ? (p64 - 6'd32) : (p64 - 6'd16);  // lp32 (s3) / lp16 (s5)
    wire signed [31:0] lpq  = lpbuf[lpa];
    wire        [2:0]  hpa  = (st == 4'd4) ? (p8 - 3'd1) : (p8 - 3'd4);       // h1 (s4) / h4 (s5)
    wire signed [31:0] hpqa = hpbuf[hpa];
    wire signed [31:0] h3   = hpbuf[p8 - 3'd3];
    wire        [31:0] sq54 = sqbuf[p64 - 6'd54];
    wire signed [31:0] R0s  = R0[31:0];

    // ALU0: 32-bit add/sub
    reg  signed [31:0] a0, b0;
    reg                s0;
    always @* begin
        a0 = 0; b0 = 0; s0 = 1'b0;
        case (st)
            4'd1: begin a0 = lp1 <<< 1;    b0 = lp2;       s0 = 1; end
            4'd2: begin a0 = x;            b0 = baseline;  s0 = 1; end
            4'd3: begin a0 = R0s;          b0 = R1;                end
            4'd4: begin a0 = R0s;          b0 = lp1;               end
            4'd5: begin a0 = lpq;          b0 = ms >>> 5;  s0 = 1; end
            4'd6: begin a0 = hp_out <<< 1; b0 = R0s;               end
            default: ;
        endcase
    end
    wire signed [31:0] y0 = s0 ? (a0 - b0) : (a0 + b0);

    // ALU1: 40-bit add/sub (the only unit that needs the MWI width)
    reg  [39:0] a1, b1;
    reg         s1;
    always @* begin
        a1 = 40'd0; b1 = 40'd0; s1 = 1'b0;
        case (st)
            4'd1: begin a1 = {8'd0, x12};          b1 = {8'd0, x6 <<< 1};   s1 = 1; end
            4'd2: begin a1 = {8'd0, R0s};          b1 = {8'd0, R1};                 end
            4'd3: begin a1 = {8'd0, ms};           b1 = {8'd0, lpq};        s1 = 1; end
            4'd4: begin a1 = {8'd0, hpqa};         b1 = {8'd0, h3};         s1 = 1; end
            4'd5: begin a1 = {8'd0, R0s};          b1 = {8'd0, hpqa <<< 1}; s1 = 1; end
            4'd6: begin a1 = mwi_out;              b1 = {8'd0, sq54};       s1 = 1; end
            4'd8: begin a1 = R0;                   b1 = {8'd0, R1};                 end
            default: ;
        endcase
    end
    wire [39:0] y1 = s1 ? (a1 - b1) : (a1 + b1);

    // the single multiplier
    wire [31:0] mul_y = dv_out * dv_out;

    always @(posedge clk) begin
        if (!rst_n) begin
            st <= 4'd0; done <= 1'b0;
            p64 <= 6'd0; p16 <= 4'd0; p8 <= 3'd0;
            lp1 <= 0; lp2 <= 0; ms <= 0;
            R0 <= 40'd0; R1 <= 0;
            hp_out <= 0; dv_out <= 0; mwi_out <= 40'd0;
        end else begin
            done <= 1'b0;
            case (st)
                4'd0: if (start) st <= 4'd1;
                4'd1: begin R0 <= {8'd0, y0}; R1 <= y1[31:0];                 st <= 4'd2; end
                4'd2: begin R0 <= {8'd0, y0}; R1 <= y1[31:0]; xbuf[p16] <= y0; st <= 4'd3; end
                4'd3: begin lp1 <= y0; lp2 <= lp1; lpbuf[p64] <= y0; R0 <= {8'd0, y1[31:0]}; st <= 4'd4; end
                4'd4: begin ms <= y0; R0 <= {8'd0, y1[31:0]};                 st <= 4'd5; end
                4'd5: begin hp_out <= y0; hpbuf[p8] <= y0; R0 <= {8'd0, y1[31:0]}; st <= 4'd6; end
                4'd6: begin dv_out <= y0 >>> 3; R0 <= y1;                     st <= 4'd7; end
                4'd7: begin R1 <= mul_y;                                       st <= 4'd8; end
                4'd8: begin
                    mwi_out <= y1; sqbuf[p64] <= R1;
                    p64 <= p64 + 1'b1; p16 <= p16 + 1'b1; p8 <= p8 + 1'b1;
                    done <= 1'b1; st <= 4'd0;
                end
                default: st <= 4'd0;
            endcase
        end
    end
endmodule
