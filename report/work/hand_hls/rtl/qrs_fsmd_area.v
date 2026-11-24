`timescale 1ns/1ps
//============================================================================
// qrs_fsmd_area.v -- hand-HLS FSMD, MIN-AREA design point
// Per-sample Pan-Tompkins filter chain (same function as hls/qrs_stream.cpp),
// written by hand from the 1-ALU + 1-MUL list schedule (13 control steps)
// and the left-edge register binding (3 temporaries R0..R2) of hand_hls.py.
//
//  step  ALU (40-bit add/sub)              MUL            writes
//   1    u1 = 2*lp1 - lp2      -> R0
//   2    u2 = x12 - 2*x6       -> R1
//   3    xc = x - baseline     -> R2                      xbuf[p16]
//   4    u3 = R0 + R1          -> R0
//   5    lp = R2 + R0          -> lp1 (lp2<=lp1)          lpbuf[p64]
//   6    v1 = ms - lp32        -> R0
//   7    ms = R0 + lp1         -> ms
//   8    w1 = h1 - h3          -> R0
//   9    hp = lp16 - (ms>>>5)  -> hp_out                  hpbuf[p8]
//  10    w2 = R0 - 2*h4        -> R0
//  11    dv = (2*hp + R0)>>>3  -> dv_out
//  12    m1 = mwi - sq54       -> R1       sq = dv*dv -> R0
//  13    mwi = R1 + R0         -> mwi_out                 sqbuf[p64], ptr++
//
// All arithmetic is modulo 2^32 (2^40 for the MWI), so the re-associated
// order gives exactly the same bits as the C++ / Python golden model.
//============================================================================
module qrs_fsmd_area (
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
    // ---------------- storage (circular buffers in LUT-RAM) ----------------
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
    reg signed [31:0] lp1, lp2, ms;           // loop-carried state
    reg        [39:0] R1;                     // temporaries (left-edge binding)
    reg signed [31:0] R0, R2;
    reg        [3:0]  st;                     // 0 = idle, 1..13 = control steps

    // ---------------- memory read ports (async LUT-RAM reads) ----------------
    wire signed [31:0] x6   = xbuf[p16 - 4'd6];
    wire signed [31:0] x12  = xbuf[p16 - 4'd12];
    wire        [5:0]  lpa  = (st == 4'd6) ? (p64 - 6'd32) : (p64 - 6'd16);  // one port, shared
    wire signed [31:0] lpq  = lpbuf[lpa];                                     // lp32 (s6) / lp16 (s9)
    wire        [2:0]  hpa  = (st == 4'd8) ? (p8 - 3'd1) : (p8 - 3'd4);       // h1 (s8) / h4 (s10)
    wire signed [31:0] hpqa = hpbuf[hpa];
    wire signed [31:0] h3   = hpbuf[p8 - 3'd3];
    wire        [31:0] sq54 = sqbuf[p64 - 6'd54];

    // ---------------- the single ALU: operand multiplexers + 40-bit add/sub ----------------
    reg  [39:0] alu_a, alu_b;
    reg         alu_sub;
    always @* begin
        alu_a = 40'd0; alu_b = 40'd0; alu_sub = 1'b0;
        case (st)
            4'd1:  begin alu_a = {{8{lp1[31]}}, lp1 <<< 1}; alu_b = {{8{lp2[31]}}, lp2};      alu_sub = 1; end
            4'd2:  begin alu_a = {{8{x12[31]}}, x12};       alu_b = {{8{x6[31]}}, x6 <<< 1};  alu_sub = 1; end
            4'd3:  begin alu_a = {{24{x[15]}}, x};          alu_b = {{8{baseline[31]}}, baseline}; alu_sub = 1; end
            4'd4:  begin alu_a = {{8{R0[31]}}, R0};         alu_b = {{8{R1[31]}}, R1[31:0]};  end
            4'd5:  begin alu_a = {{8{R2[31]}}, R2};         alu_b = {{8{R0[31]}}, R0};        end
            4'd6:  begin alu_a = {{8{ms[31]}}, ms};         alu_b = {{8{lpq[31]}}, lpq};      alu_sub = 1; end
            4'd7:  begin alu_a = {{8{R0[31]}}, R0};         alu_b = {{8{lp1[31]}}, lp1};      end
            4'd8:  begin alu_a = {{8{hpqa[31]}}, hpqa};     alu_b = {{8{h3[31]}}, h3};        alu_sub = 1; end
            4'd9:  begin alu_a = {{8{lpq[31]}}, lpq};       alu_b = {{8{ms[31]}}, ms >>> 5};  alu_sub = 1; end
            4'd10: begin alu_a = {{8{R0[31]}}, R0};         alu_b = {{8{hpqa[31]}}, hpqa <<< 1}; alu_sub = 1; end
            4'd11: begin alu_a = {{8{hp_out[31]}}, hp_out <<< 1}; alu_b = {{8{R0[31]}}, R0};   end
            4'd12: begin alu_a = mwi_out;                   alu_b = {8'd0, sq54};             alu_sub = 1; end
            4'd13: begin alu_a = R1;                        alu_b = {8'd0, R0};               end
            default: ;
        endcase
    end
    wire [39:0] alu_y  = alu_sub ? (alu_a - alu_b) : (alu_a + alu_b);
    wire signed [31:0] alu_y32 = alu_y[31:0];

    // ---------------- the single multiplier (squarer, low 32 bits) ----------------
    wire [31:0] mul_y = dv_out * dv_out;

    // ---------------- controller + register transfers ----------------
    always @(posedge clk) begin
        if (!rst_n) begin
            st <= 4'd0; done <= 1'b0;
            p64 <= 6'd0; p16 <= 4'd0; p8 <= 3'd0;
            lp1 <= 0; lp2 <= 0; ms <= 0;
            R0 <= 0; R1 <= 0; R2 <= 0;
            hp_out <= 0; dv_out <= 0; mwi_out <= 40'd0;
        end else begin
            done <= 1'b0;
            case (st)
                4'd0:  if (start) st <= 4'd1;
                4'd1:  begin R0 <= alu_y32;                                  st <= 4'd2;  end
                4'd2:  begin R1 <= alu_y;                                    st <= 4'd3;  end
                4'd3:  begin R2 <= alu_y32; xbuf[p16] <= alu_y32;            st <= 4'd4;  end
                4'd4:  begin R0 <= alu_y32;                                  st <= 4'd5;  end
                4'd5:  begin lp1 <= alu_y32; lp2 <= lp1; lpbuf[p64] <= alu_y32; st <= 4'd6; end
                4'd6:  begin R0 <= alu_y32;                                  st <= 4'd7;  end
                4'd7:  begin ms <= alu_y32;                                  st <= 4'd8;  end
                4'd8:  begin R0 <= alu_y32;                                  st <= 4'd9;  end
                4'd9:  begin hp_out <= alu_y32; hpbuf[p8] <= alu_y32;        st <= 4'd10; end
                4'd10: begin R0 <= alu_y32;                                  st <= 4'd11; end
                4'd11: begin dv_out <= alu_y32 >>> 3;                        st <= 4'd12; end
                4'd12: begin R1 <= alu_y; R0 <= mul_y;                       st <= 4'd13; end
                4'd13: begin
                    mwi_out <= alu_y; sqbuf[p64] <= R0;
                    p64 <= p64 + 1'b1; p16 <= p16 + 1'b1; p8 <= p8 + 1'b1;
                    done <= 1'b1; st <= 4'd0;
                end
                default: st <= 4'd0;
            endcase
        end
    end
endmodule
