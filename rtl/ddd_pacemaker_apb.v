`timescale 1ns/1ps
//============================================================================
// ddd_pacemaker_apb.v  --  P17 Phase 6: APB3 slave around the DDD controller
//
// The RV32 writes the (range-checked) timing parameters and control bits over
// APB; reads status and the arrhythmia flag. Sense events and the 1 ms tick
// come from the SoC (ECG detector / replay); pace outputs drive LEDs; the
// latched arrhythmia bit is a level interrupt to the RV32.
//
// Register map (word addresses):
//   0x00 LRI    (RW)   0x04 AVI (RW)   0x08 URI (RW)
//   0x0C PVARP  (RW)   0x10 VRP (RW)
//   0x14 CONTROL(RW)   bit0 = enable, bit1 = write-1-to-clear arrhythmia
//   0x18 STATUS (RO)   bit0 arrhythmia, bit1 ap, bit2 vp, bit3 as, bit4 vs
//============================================================================
module ddd_pacemaker_apb #(
    parameter W = 16
)(
    input  wire        PCLK,
    input  wire        PRESETn,
    input  wire        PSEL,
    input  wire        PENABLE,
    input  wire        PWRITE,
    input  wire [7:0]  PADDR,
    input  wire [31:0] PWDATA,
    output reg  [31:0] PRDATA,
    output wire        PREADY,
    output wire        PSLVERR,
    // SoC-side I/O
    input  wire        tick_en,
    input  wire        a_sense_in,
    input  wire        v_sense_in,
    output wire        ap,
    output wire        vp,
    output wire        as_evt,
    output wire        vs_evt,
    output wire        arrhythmia_irq
);
    assign PREADY  = 1'b1;           // no wait states
    assign PSLVERR = 1'b0;

    // programmable registers (reset to the default DDD settings)
    reg [W-1:0] lri, avi, uri, pvarp, vrp;
    reg         enable;
    reg         arr_latch;

    wire apb_write = PSEL & PENABLE & PWRITE;
    wire apb_read  = PSEL & ~PWRITE;

    wire arr_pulse;                  // from the controller

    always @(posedge PCLK) begin
        if (!PRESETn) begin
            lri   <= 16'd1000; avi <= 16'd180; uri <= 16'd500;
            pvarp <= 16'd320;  vrp <= 16'd250;
            enable <= 1'b0;    arr_latch <= 1'b0;
        end else begin
            if (apb_write) begin
                case (PADDR[7:2])
                    6'h00: lri   <= PWDATA[W-1:0];
                    6'h01: avi   <= PWDATA[W-1:0];
                    6'h02: uri   <= PWDATA[W-1:0];
                    6'h03: pvarp <= PWDATA[W-1:0];
                    6'h04: vrp   <= PWDATA[W-1:0];
                    6'h05: begin
                        enable <= PWDATA[0];
                        if (PWDATA[1]) arr_latch <= 1'b0;   // W1C
                    end
                    default: ;
                endcase
            end
            // latch arrhythmia pulse (cleared via CONTROL bit1 above)
            if (arr_pulse) arr_latch <= 1'b1;
        end
    end

    always @(*) begin
        PRDATA = 32'b0;
        if (apb_read) begin
            case (PADDR[7:2])
                6'h00: PRDATA = {{(32-W){1'b0}}, lri};
                6'h01: PRDATA = {{(32-W){1'b0}}, avi};
                6'h02: PRDATA = {{(32-W){1'b0}}, uri};
                6'h03: PRDATA = {{(32-W){1'b0}}, pvarp};
                6'h04: PRDATA = {{(32-W){1'b0}}, vrp};
                6'h05: PRDATA = {31'b0, enable};
                6'h06: PRDATA = {27'b0, vs_evt, as_evt, vp, ap, arr_latch};
                default: PRDATA = 32'b0;
            endcase
        end
    end

    assign arrhythmia_irq = arr_latch;

    ddd_pacemaker #(.W(W)) u_ctrl (
        .clk(PCLK), .rst_n(PRESETn), .enable(enable), .tick_en(tick_en),
        .a_sense_in(a_sense_in), .v_sense_in(v_sense_in),
        .lri(lri), .avi(avi), .uri(uri), .pvarp(pvarp), .vrp(vrp),
        .ap(ap), .vp(vp), .as_evt(as_evt), .vs_evt(vs_evt),
        .arrhythmia(arr_pulse)
    );
endmodule
