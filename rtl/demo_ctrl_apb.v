`timescale 1ns/1ps
//============================================================================
// demo_ctrl_apb.v  --  APB slave: demo scenario select + event counters
//
// Offsets (base 0x9000_0100):
//   0x00 MODE     RW  [2:0] 0 MIT-BIH replay, 1 normal, 2 brady, 3 AV block,
//                     4 block+brady, 5 PMT. A write restarts the heart model,
//                     the ECG source and the detector's learning phase.
//   0x08 CNT_QRS  RO  detected QRS complexes     (counters clear on MODE write)
//   0x0C CNT_AP   RO  atrial paces
//   0x10 CNT_VP   RO  ventricular paces
//   0x14 CNT_AS   RO  atrial senses
//   0x18 CNT_VS   RO  ventricular senses
//   0x1C LAST_RR  RO  last detected R-R interval in samples (360 Hz)
//   0x20 STATUS   RO  bit0 detector learning
//   0x24 ID       RO  0x5017_0001
//============================================================================
module demo_ctrl_apb (
    input  wire        PCLK,
    input  wire        PRESETn,
    input  wire        PSEL,
    input  wire        PENABLE,
    input  wire        PWRITE,
    input  wire [7:0]  PADDR,
    input  wire [31:0] PWDATA,
    output reg  [31:0] PRDATA,
    output reg  [2:0]  mode,
    output reg         mode_wr,       // 1-clock pulse on a MODE write
    input  wire        qrs_evt, ap_evt, vp_evt, as_evt, vs_evt,
    input  wire [31:0] last_rr,
    input  wire        learning
);
    reg [31:0] c_qrs, c_ap, c_vp, c_as, c_vs;
    wire wr = PSEL & PENABLE & PWRITE;

    always @(posedge PCLK) begin
        mode_wr <= 1'b0;
        if (!PRESETn) begin
            mode <= 3'd0; c_qrs <= 0; c_ap <= 0; c_vp <= 0; c_as <= 0; c_vs <= 0;
        end else begin
            if (qrs_evt) c_qrs <= c_qrs + 1'b1;
            if (ap_evt)  c_ap  <= c_ap + 1'b1;
            if (vp_evt)  c_vp  <= c_vp + 1'b1;
            if (as_evt)  c_as  <= c_as + 1'b1;
            if (vs_evt)  c_vs  <= c_vs + 1'b1;
            if (wr && (PADDR[7:2] == 6'h00)) begin
                mode <= PWDATA[2:0]; mode_wr <= 1'b1;
                c_qrs <= 0; c_ap <= 0; c_vp <= 0; c_as <= 0; c_vs <= 0;
            end
        end
    end

    always @(*) begin
        case (PADDR[7:2])
            6'h00: PRDATA = {29'd0, mode};
            6'h02: PRDATA = c_qrs;
            6'h03: PRDATA = c_ap;
            6'h04: PRDATA = c_vp;
            6'h05: PRDATA = c_as;
            6'h06: PRDATA = c_vs;
            6'h07: PRDATA = last_rr;
            6'h08: PRDATA = {31'd0, learning};
            6'h09: PRDATA = 32'h5017_0001;
            default: PRDATA = 32'd0;
        endcase
    end
endmodule
