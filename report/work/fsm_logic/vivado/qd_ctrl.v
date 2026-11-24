`timescale 1ns/1ps
// qd_ctrl.v -- the 8-phase control FSM of rtl/qrs_decision.v on its own
// (same transitions; datapath conditions are inputs, phase enables are outputs).
// Used only for the state-encoding study (VL401 report Sec. 5.2).
//   i = in_valid, f = det_now|sb_done, s = sb_en & (pend_val > THR2)
// Two-process style (state register + one combinational next-state/output
// block), so Vivado's FSM extraction owns every use of the state register.
// (A first version decoded the outputs with 'assign' outside the FSM block;
// Vivado then kept a second copy of the state register, see RESULTS.md.)
module qd_ctrl #(
    parameter [2:0] C_IDL = 3'd0,
    parameter [2:0] C_TRK = 3'd1,
    parameter [2:0] C_CLS = 3'd2,
    parameter [2:0] C_REG = 3'd3,
    parameter [2:0] C_AVG = 3'd4,
    parameter [2:0] C_LIM = 3'd5,
    parameter [2:0] C_SBK = 3'd6,
    parameter [2:0] C_END = 3'd7
)(
    input  wire clk, rst_n, i, f, s,
    output reg  ld, trk, cls, rg, avg, lim, sbk, cnt
);
    reg [2:0] ph, ph_n;
    always @(posedge clk) begin
        if (!rst_n) ph <= C_IDL;
        else        ph <= ph_n;
    end
    always @* begin
        ph_n = ph;
        {ld, trk, cls, rg, avg, lim, sbk, cnt} = 8'b0;
        case (ph)
            C_IDL: begin ld  = i; if (i) ph_n = C_TRK; end
            C_TRK: begin trk = 1'b1; ph_n = C_CLS; end
            C_CLS: begin cls = 1'b1; ph_n = C_REG; end
            C_REG: begin rg  = 1'b1; ph_n = C_AVG; end
            C_AVG: begin avg = 1'b1; ph_n = C_LIM; end
            C_LIM: begin lim = 1'b1; ph_n = f ? C_END : C_SBK; end
            C_SBK: begin sbk = 1'b1; ph_n = s ? C_REG : C_END; end
            C_END: begin cnt = 1'b1; ph_n = C_IDL; end
            default: ph_n = C_IDL;
        endcase
    end
endmodule
