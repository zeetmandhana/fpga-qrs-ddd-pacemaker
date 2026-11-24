// ddd_props.vh -- formal properties of ddd_pacemaker, included at the end of the
// module body (only under `ifdef FORMAL; the RTL logic itself is unchanged).
//
// f_since: an INDEPENDENT monitor that counts 1 ms ticks since the last
// ventricular event seen on the module's registered outputs. It gives the timing
// properties and the strengthening invariant (f_since == t_v) used by k-induction.
`ifdef FORMAL
    reg f_past_valid = 1'b0;
    always @(posedge clk) f_past_valid <= 1'b1;

    wire       f_tick = rst_n && enable && tick_en;   // a tick the controller processes
    reg  [W:0] f_since;     // ticks since the last V decision (incl. the newest tick)
    reg        f_seenV;     // a V event has happened since the controller was enabled
    reg        f_run;       // controller was running in the previous cycle
    wire [W:0] f_base = (vp || vs_evt) ? {(W+1){1'b0}} : f_since;
    localparam [W:0] F_SAT = {1'b0, {W{1'b1}}};   // saturation (never reached)
    always @(posedge clk) begin
        if (!rst_n || !enable) begin
            f_since <= {(W+1){1'b0}}; f_seenV <= 1'b0;
        end else begin
            f_since <= (f_base >= F_SAT) ? F_SAT : f_base + f_tick;
            if (vp || vs_evt) f_seenV <= 1'b1;
        end
        f_run <= rst_n && enable;
    end

    always @(posedge clk) if (f_past_valid && $past(rst_n) && rst_n) begin
        // A1 never pace both chambers
        A1: assert (!(ap && vp));
        // A2 no ventricular pace earlier than URI after the previous V event
        if (vp && f_seenV && f_run) A2: assert (f_since >= uri);
        // A3 an atrial sense is never accepted inside PVARP
        if (as_evt && f_seenV && f_run) A3: assert (f_since >= pvarp);
        // A4 a ventricular sense is never accepted inside VRP
        if (vs_evt && f_seenV && f_run) A4: assert (f_since >= vrp);
        // A5 the ventricle is never left without a beat for longer than LRI
        if (f_seenV && f_run) A5: assert (f_since <= lri);
        // A6 timer bounded (t_v saturates at LRI+1) -- while running (LRI may be
        //    reprogrammed while the controller is disabled)
        if (enable && f_run) A6: assert (t_v <= lri + 1'b1);
        // A7 phase / timer consistency
        if (phase == PH_AEI) A7a: assert (t_av == 0);
        if (phase == PH_AVI) A7b: assert (t_av <= t_v);
        // A8 start-up: the first cycle after enabling sees the PROGRAMMED LRI
        if (enable && !$past(enable)) A8: assert (t_v == lri);
        // ---- strengthening invariants for k-induction (each is itself proven) ----
        // I1 monitor == DUT timer
        if (f_seenV && f_run && !(vp || vs_evt)) I1: assert (f_since == {1'b0, t_v});
        // I2 a registered output event matches the state it produced
        if (ap || as_evt) I2a: assert (phase == PH_AVI && t_av == 0);
        if (vp || vs_evt) I2b: assert (phase == PH_AEI && t_v == 0 && t_av == 0);
        // I3 after the first V event, the AEI phase ends no later than t_v = AEI
        if (f_seenV && f_run && phase == PH_AEI) I3: assert (t_v < aei);
        // I4 the atrial event happened no later than t_v = AEI
        if (f_seenV && f_run && phase == PH_AVI) I4: assert (t_v <= aei + t_av);
        // I5 a stored AVI state never has both AVI and URI elapsed (it would have paced)
        if (f_run && enable && phase == PH_AVI) I5: assert (!(t_av >= avi && t_v >= uri));
    end
`endif
