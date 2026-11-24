`timescale 1ns/1ps
//============================================================================
// heart_model.v  --  P17 board phase: closed-loop heart model in hardware
//
// Line-for-line port of src/heart_model.py::HeartModel (sinus node, antegrade
// AV conduction, retrograde VA conduction, ventricular escape), so the DDD
// pacemaker runs in a real closed loop on the FPGA. Checked per tick against
// the Python closed-loop simulator by tb_closed_loop.v.
//
// Protocol (1 ms resolution):
//   tick   : a_in / v_in are the intrinsic depolarisations of the CURRENT
//            tick (combinational, like HeartModel.intrinsic(tick));
//   update : pulse >= 1 clock after tick, with the chambers that actually
//            fired (intrinsic OR paced) = HeartModel.update(tick, ...);
//            the tick counter then advances.
// scen: 1 normal, 2 brady, 3 AV block, 4 dual (block+brady), 5 PMT substrate,
//       anything else = no heart activity.
//============================================================================
module heart_model (
    input  wire       clk,
    input  wire       rst_n,         // also used to restart a scenario
    input  wire [2:0] scen,
    input  wire       update,
    input  wire       a_act,
    input  wire       v_act,
    output wire       a_in,
    output wire       v_in
);
    // ---- scenario table (ms); 0 = "None" in the Python model ----
    reg [15:0] sinus, av, va, esc;
    always @(*) begin
        case (scen)
            3'd1: begin sinus = 16'd800;  av = 16'd150; va = 16'd0;   esc = 16'd0;    end // normal
            3'd2: begin sinus = 16'd1500; av = 16'd150; va = 16'd0;   esc = 16'd0;    end // brady
            3'd3: begin sinus = 16'd800;  av = 16'd0;   va = 16'd0;   esc = 16'd1500; end // block
            3'd4: begin sinus = 16'd1500; av = 16'd0;   va = 16'd0;   esc = 16'd1500; end // dual
            3'd5: begin sinus = 16'd900;  av = 16'd0;   va = 16'd280; esc = 16'd1500; end // pmt
            default: begin sinus = 16'd0; av = 16'd0;   va = 16'd0;   esc = 16'd0;    end
        endcase
    end
    wire has_sinus = (sinus != 0), has_av = (av != 0), has_va = (va != 0), has_esc = (esc != 0);

    reg [31:0] t;                               // current tick index
    reg [31:0] next_sinus, next_escape, pending_av, pending_va;
    reg        sinus_v, escape_v, av_v, va_v;   // "is not None"
    reg [2:0]  scen_q;

    assign a_in = (sinus_v && (t == next_sinus)) || (va_v && (t == pending_va));
    assign v_in = (av_v && (t == pending_av)) || (escape_v && (t == next_escape));

    reg        n_sv, n_ev, n_av, n_vv;
    reg [31:0] n_s, n_e, n_a, n_r;
    always @(posedge clk) begin
        if (!rst_n || (scen != scen_q)) begin
            // HeartModel.__init__(params, start_sinus_ms=300)
            scen_q      <= scen;
            t           <= 32'd0;
            sinus_v     <= has_sinus;  next_sinus  <= 32'd300;
            escape_v    <= has_esc;    next_escape <= {16'd0, esc};
            av_v        <= 1'b0;       pending_av  <= 32'd0;
            va_v        <= 1'b0;       pending_va  <= 32'd0;
        end else if (update) begin
            n_sv = sinus_v; n_s = next_sinus;
            n_ev = escape_v; n_e = next_escape;
            n_av = av_v;    n_a = pending_av;
            n_vv = va_v;    n_r = pending_va;
            if (a_act) begin
                if (has_sinus) begin n_sv = 1'b1; n_s = t + sinus; end
                n_vv = 1'b0;
                if (has_av) begin n_av = 1'b1; n_a = t + av; end
            end
            if (v_act) begin
                if (has_esc) begin n_ev = 1'b1; n_e = t + esc; end
                n_av = 1'b0;
                if (has_va) begin n_vv = 1'b1; n_r = t + va; end
                else        n_vv = 1'b0;
            end
            sinus_v <= n_sv; next_sinus <= n_s;
            escape_v <= n_ev; next_escape <= n_e;
            av_v <= n_av; pending_av <= n_a;
            va_v <= n_vv; pending_va <= n_r;
            t <= t + 32'd1;
        end
    end
endmodule
