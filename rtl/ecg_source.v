`timescale 1ns/1ps
//============================================================================
// ecg_source.v  --  P17 board phase: the ECG fed to the detector and screen
//
// mode 0   : MIT-BIH record 100 (MLII), 32768 samples = 91 s, replayed from
//            BRAM at 360 Hz in a loop (raw 11-bit ADC codes).
// mode 1-5 : ECG synthesised from the closed-loop heart model: every atrial
//            activation plays a P-wave template, every intrinsic ventricular
//            activation a QRS-T template (both ensemble-averaged from real
//            record-100 beats), every paced ventricular beat a wide paced
//            complex; pace pulses add a one-sample pacing spike.
// One output sample per tick_360 (adc_valid pulses one clock later).
//============================================================================
module ecg_source #(
    parameter MEM_DIR = "C:/Vivadoproject/P17_QRS_Pacemaker/rtl/mem/"
)(
    input  wire        clk,
    input  wire        rst_n,         // also pulsed on a mode change
    input  wire [2:0]  mode,
    input  wire        tick_360,
    input  wire        a_act,         // atrial activation (intrinsic or paced)
    input  wire        v_intr,        // intrinsic ventricular activation
    input  wire        ap,            // atrial pace pulse
    input  wire        vp,            // ventricular pace pulse
    output reg  [10:0] adc,
    output reg         adc_valid
);
    // ---------------- MIT-BIH replay BRAM ----------------
    (* ram_style = "block" *) reg [10:0] rec_rom [0:32767];
    initial $readmemh({MEM_DIR, "ecg_rec100_32k.mem"}, rec_rom);
    reg [14:0] rptr;
    reg [10:0] rec_q;
    always @(posedge clk) rec_q <= rec_rom[rptr];      // registered BRAM read

    // ---------------- beat templates (LUT ROM) ----------------
    localparam NP = 57, NQ = 201, NV = 187;
    reg [11:0] tp [0:NP-1];
    reg [11:0] tq [0:NQ-1];
    reg [11:0] tv [0:NV-1];
    initial begin
        $readmemh({MEM_DIR, "tpl_p.mem"}, tp);
        $readmemh({MEM_DIR, "tpl_qrst.mem"}, tq);
        $readmemh({MEM_DIR, "tpl_paced.mem"}, tv);
    end

    reg        p_on, v_on, v_paced;
    reg [7:0]  pi, vi;
    reg        req_p, req_v, req_vpaced, req_spike;

    wire signed [12:0] p_val = p_on ? {tp[pi][11], tp[pi]} : 13'sd0;
    wire signed [12:0] v_val = !v_on ? 13'sd0 :
                               (v_paced ? {tv[vi][11], tv[vi]} : {tq[vi][11], tq[vi]});
    wire signed [12:0] spike = req_spike ? 13'sd400 : 13'sd0;   // ~2 mV pacing spike
    wire signed [13:0] synth = 14'sd1024 + p_val + v_val + spike;
    wire        [10:0] synth_c = (synth < 0) ? 11'd0 : ((synth > 14'sd2047) ? 11'd2047 : synth[10:0]);

    reg tick_d;
    always @(posedge clk) begin
        if (!rst_n) begin
            rptr <= 0; adc <= 11'd1024; adc_valid <= 1'b0; tick_d <= 1'b0;
            p_on <= 0; v_on <= 0; v_paced <= 0; pi <= 0; vi <= 0;
            req_p <= 0; req_v <= 0; req_vpaced <= 0; req_spike <= 0;
        end else begin
            adc_valid <= 1'b0;
            tick_d <= tick_360;
            // latch events from the 1 ms domain until the next sample
            if (a_act) req_p <= 1'b1;
            if (v_intr) begin req_v <= 1'b1; req_vpaced <= 1'b0; end
            if (vp)     begin req_v <= 1'b1; req_vpaced <= 1'b1; end
            if (ap | vp) req_spike <= 1'b1;

            if (tick_360) begin
                if (mode == 3'd0) begin
                    rptr <= rptr + 1'b1;               // rec_q holds rec_rom[rptr]
                end else begin
                    // advance / restart the template players
                    if (req_p) begin p_on <= 1'b1; pi <= 0; req_p <= 1'b0; end
                    else if (p_on) begin
                        if (pi == NP-1) p_on <= 1'b0; else pi <= pi + 1'b1;
                    end
                    if (req_v) begin v_on <= 1'b1; vi <= 0; v_paced <= req_vpaced; req_v <= 1'b0; end
                    else if (v_on) begin
                        if (vi == (v_paced ? NV-1 : NQ-1)) v_on <= 1'b0; else vi <= vi + 1'b1;
                    end
                end
            end
            if (tick_d) begin
                adc <= (mode == 3'd0) ? rec_q : synth_c;
                adc_valid <= 1'b1;
                if (mode != 3'd0) req_spike <= 1'b0;
            end
        end
    end
endmodule
