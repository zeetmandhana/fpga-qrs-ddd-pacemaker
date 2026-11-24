`timescale 1ns/1ps
//============================================================================
// ddd_pacemaker.v  --  P17 Phase 6: synthesizable DDD timing controller
//
// One state update per tick_en (a 1 ms strobe). This is a direct hardware
// port of src/pacemaker.py::DDDPacemaker.step and is checked bit-for-bit
// against that golden model in tb_ddd_pacemaker.v.
//
// Timers (LRI/AVI/URI/PVARP/VRP) are supplied as inputs (set by the RV32 over
// APB). AEI = LRI - AVI. Event priority each tick: VS > VP > AS > AP.
//============================================================================
module ddd_pacemaker #(
    parameter W = 16                 // timer width in ms (handles up to 2000)
)(
    input  wire          clk,
    input  wire          rst_n,
    input  wire          enable,     // controller running
    input  wire          tick_en,    // 1 ms strobe
    input  wire          a_sense_in, // raw intrinsic atrial depolarisation
    input  wire          v_sense_in, // raw intrinsic ventricular depolarisation
    input  wire [W-1:0]  lri,
    input  wire [W-1:0]  avi,
    input  wire [W-1:0]  uri,
    input  wire [W-1:0]  pvarp,
    input  wire [W-1:0]  vrp,
    output reg           ap,         // atrial pace        (1-tick pulse)
    output reg           vp,         // ventricular pace   (1-tick pulse)
    output reg           as_evt,     // atrial sense accepted
    output reg           vs_evt,     // ventricular sense accepted
    output reg           arrhythmia  // upper-rate V event (1-tick pulse)
);
    localparam PH_AEI = 1'b0;        // awaiting an atrial event (V-A interval)
    localparam PH_AVI = 1'b1;        // atrial event seen; awaiting ventricle

    reg          phase;
    reg [W-1:0]  t_v, t_av;
    wire [W-1:0] aei = lri - avi;    // atrial escape interval

    // combinational working variables (recomputed every tick)
    reg [W-1:0]  tv, tav, ntv, ntav;
    reg          nphase, vs_c, vp_c, as_c, ap_c, arr_c, blanked;

    always @(posedge clk) begin
        if (!rst_n) begin
            phase  <= PH_AEI;
            t_v    <= lri;           // matches the Python init (t_v = LRI)
            t_av   <= {W{1'b0}};
            ap <= 0; vp <= 0; as_evt <= 0; vs_evt <= 0; arrhythmia <= 0;
        end else begin
            ap <= 0; vp <= 0; as_evt <= 0; vs_evt <= 0; arrhythmia <= 0;
            if (!enable) begin
                // held in the start state while disabled, so the first cycle
                // after enabling uses the PROGRAMMED LRI (golden model: t_v = LRI).
                // Found by constrained-random simulation (VL401 report, Sec. 7).
                phase <= PH_AEI; t_v <= lri; t_av <= {W{1'b0}};
            end else if (tick_en) begin
                // --- increment timers (t_v saturates at LRI+1: "longer than LRI";
                //     saturating at LRI made a V event after >LRI look like an
                //     upper-rate event when URI = LRI -- found by random sim) ---
                tv  = (t_v >= lri) ? (lri + 1'b1) : (t_v + 1'b1);
                tav = (phase == PH_AVI) ? (t_av + 1'b1) : {W{1'b0}};

                vs_c = 0; vp_c = 0; as_c = 0; ap_c = 0; arr_c = 0;
                ntv = tv; ntav = tav; nphase = phase;

                // (1) ventricular sensing -- blanked during VRP
                if (v_sense_in) vs_c = 1;            // BUG 2: VRP blanking removed

                if (vs_c) begin
                    nphase = PH_AEI; ntv = 0; ntav = 0;
                    if (tv <= uri) arr_c = 1;            // fast V-V interval
                end else begin
                    // (2) ventricular pacing -- AVI elapsed and URI satisfied
                    if ((phase == PH_AVI) && (tav >= avi) && (tv >= uri)) begin
                        vp_c = 1; nphase = PH_AEI; ntv = 0; ntav = 0;
                        if (tv <= uri) arr_c = 1;        // paced at the URI limit
                    end
                    // (3) atrial side -- only while awaiting an atrial event
                    if (!vp_c && (phase == PH_AEI)) begin
                        blanked = (tv < pvarp);
                        if (a_sense_in && !blanked) begin
                            as_c = 1; nphase = PH_AVI; ntav = 0;
                        end else if (tv >= aei) begin
                            ap_c = 1; nphase = PH_AVI; ntav = 0;
                        end
                    end
                end

                t_v <= ntv; t_av <= ntav; phase <= nphase;
                ap <= ap_c; vp <= vp_c; as_evt <= as_c; vs_evt <= vs_c;
                arrhythmia <= arr_c;
            end
        end
    end
`include "ddd_props.vh"     // formal properties only (ifdef FORMAL)
endmodule
