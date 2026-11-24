`timescale 1ns/1ps
//============================================================================
// p17_board_glue.v  --  the small board-level helper blocks of p17_zybo_top
//
// Split out of the top so that the top-level RTL schematic is a clean block
// diagram of the system (CPU, bus bridge, pacemaker, detector, ...). The
// logic is unchanged from the original single-file top.
//
//   p17_clocking     125 MHz -> MMCM -> 25 MHz system/pixel + 125 MHz TMDS, reset
//   p17_timebase     1 ms tick and exact 360 Hz sample tick
//   p17_board_io     switch/button debounce, LED pulse stretchers, RGB PWM
//   p17_event_router closed-loop wiring: senses for the pacemaker, heart-model
//                    activations, ECG template triggers, scenario restart,
//                    R-R interval, QRS marker delay, text-RAM write strobe
//============================================================================

module p17_clocking (
    input  wire sysclk,          // 125 MHz board clock
    input  wire btn_rst,         // BTN0
    output wire clk,             // 25 MHz system / pixel clock
    output wire clk125,          // 125 MHz TMDS serialiser clock
    output wire rst_n,           // synchronous active-low reset (clk domain)
    output wire rst              // active-high copy (HDMI serialisers)
);
    wire clk25_u, clk125_u, fb_u, fb, locked;
    MMCME2_BASE #(
        .CLKIN1_PERIOD(8.0), .DIVCLK_DIVIDE(1), .CLKFBOUT_MULT_F(8.0),   // VCO 1000 MHz
        .CLKOUT0_DIVIDE_F(40.0),                                          // 25 MHz
        .CLKOUT1_DIVIDE(8)                                                // 125 MHz
    ) u_mmcm (
        .CLKIN1(sysclk), .CLKFBIN(fb), .CLKFBOUT(fb_u), .CLKFBOUTB(),
        .CLKOUT0(clk25_u), .CLKOUT0B(), .CLKOUT1(clk125_u), .CLKOUT1B(),
        .CLKOUT2(), .CLKOUT2B(), .CLKOUT3(), .CLKOUT3B(), .CLKOUT4(), .CLKOUT5(), .CLKOUT6(),
        .LOCKED(locked), .PWRDWN(1'b0), .RST(1'b0)
    );
    BUFG u_bfb  (.I(fb_u),     .O(fb));
    BUFG u_b25  (.I(clk25_u),  .O(clk));
    BUFG u_b125 (.I(clk125_u), .O(clk125));

    reg [3:0] rst_sh = 4'h0;
    always @(posedge clk or negedge locked)
        if (!locked) rst_sh <= 4'h0;
        else         rst_sh <= {rst_sh[2:0], ~btn_rst};
    assign rst_n = &rst_sh;
    assign rst   = ~rst_n;
endmodule


module p17_timebase #(
    parameter SIM_DIV = 1
)(
    input  wire clk,
    input  wire rst_n,
    output reg  tick_ms,         // 1 ms strobe (25,000 clocks)
    output reg  tick_360         // exactly 360 Hz on average (phase accumulator)
);
    reg [15:0] ms_cnt;
    always @(posedge clk) begin
        if (!rst_n) begin ms_cnt <= 0; tick_ms <= 0; end
        else if (ms_cnt == 25000 / SIM_DIV - 1) begin ms_cnt <= 0; tick_ms <= 1'b1; end
        else begin ms_cnt <= ms_cnt + 1'b1; tick_ms <= 1'b0; end
    end
    reg [24:0] ph360;
    always @(posedge clk) begin
        if (!rst_n) begin ph360 <= 0; tick_360 <= 0; end
        else if (ph360 + 25'd360 >= 25'd25000000 / SIM_DIV) begin
            ph360 <= ph360 + 25'd360 - 25'd25000000 / SIM_DIV; tick_360 <= 1'b1;
        end else begin ph360 <= ph360 + 25'd360; tick_360 <= 1'b0; end
    end
endmodule


module p17_board_io #(
    parameter SIM_DIV = 1
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [3:0] btn,
    input  wire [3:0] sw,
    output reg  [7:0] in_db,          // {btn, sw}, synchronised + 10 ms debounce
    output wire       freeze,         // SW2: freeze the screen
    input  wire       ap, vp, det, arr_irq,
    input  wire [2:0] rgb,            // from the CPU GPIO
    output wire [3:0] led,
    output wire       led6_r, led6_g, led6_b
);
    reg [7:0]  in_s1, in_s2;
    reg [17:0] db_cnt;
    assign freeze = in_db[2];
    always @(posedge clk) begin
        in_s1 <= {btn, sw}; in_s2 <= in_s1;
        if (!rst_n) begin db_cnt <= 0; in_db <= 0; end
        else if (in_s2 != in_db) begin
            if (db_cnt == 18'd250000 / SIM_DIV) begin in_db <= in_s2; db_cnt <= 0; end
            else db_cnt <= db_cnt + 1'b1;
        end else db_cnt <= 0;
    end

    // stretch the 1-clock events to 120 ms so they are visible on the LEDs
    localparam [21:0] STRETCH = 22'd3000000 / SIM_DIV;
    reg [21:0] s_ap, s_vp, s_q;
    always @(posedge clk) begin
        if (!rst_n) begin s_ap <= 0; s_vp <= 0; s_q <= 0; end
        else begin
            s_ap <= ap  ? STRETCH : (s_ap != 0 ? s_ap - 1'b1 : 22'd0);
            s_vp <= vp  ? STRETCH : (s_vp != 0 ? s_vp - 1'b1 : 22'd0);
            s_q  <= det ? STRETCH : (s_q  != 0 ? s_q  - 1'b1 : 22'd0);
        end
    end
    assign led = {arr_irq, (s_q != 0), (s_vp != 0), (s_ap != 0)};

    // RGB LED at 1/8 brightness
    reg [2:0] pwm;
    always @(posedge clk) pwm <= pwm + 1'b1;
    wire pwm_on = (pwm == 3'd0);
    assign led6_r = rgb[0] & pwm_on;
    assign led6_g = rgb[1] & pwm_on;
    assign led6_b = rgb[2] & pwm_on;
endmodule


module p17_event_router (
    input  wire        clk,
    input  wire        rst_n,
    // scenario control (demo_ctrl_apb)
    input  wire [2:0]  mode,
    input  wire        mode_wr,
    output wire        scen_rst_n,     // restart heart model / ECG / detector learning
    // time base
    input  wire        tick_ms,
    output reg         heart_update,   // one clock after the pacemaker tick
    // heart model <-> pacemaker
    input  wire        a_in, v_in,     // intrinsic depolarisations (heart model)
    input  wire        ap, vp,         // pace pulses (pacemaker)
    output wire        a_act, v_act,   // chambers that fired (intrinsic or paced)
    output wire        a_sense, v_sense,
    output wire        ecg_a_act, ecg_v_intr,
    // detector
    input  wire        det,
    input  wire [31:0] det_r,
    input  wire [31:0] n_cnt,
    output reg  [31:0] last_rr,
    output wire [31:0] qrs_delay,
    // APB text-RAM strobe
    input  wire        psel_txt, penable, pwrite,
    output wire        txt_we
);
    reg [3:0] restart_sh;
    always @(posedge clk) restart_sh <= {restart_sh[2:0], mode_wr};
    assign scen_rst_n = rst_n & ~(|restart_sh);

    always @(posedge clk) heart_update <= tick_ms;
    assign a_act = a_in | ap;
    assign v_act = v_in | vp;
    assign ecg_a_act  = heart_update & (a_in | ap);
    assign ecg_v_intr = heart_update & v_in;

    // replay mode: the detected QRS is the ventricular sense (held to the next tick)
    reg det_pend;
    always @(posedge clk) begin
        if (!rst_n) det_pend <= 1'b0;
        else if (det) det_pend <= 1'b1;
        else if (tick_ms) det_pend <= 1'b0;
    end
    assign a_sense = (mode == 3'd0) ? 1'b0 : a_in;
    assign v_sense = (mode == 3'd0) ? det_pend : v_in;

    reg [31:0] prev_r;
    always @(posedge clk) begin
        if (!scen_rst_n) begin last_rr <= 0; prev_r <= 0; end
        else if (det) begin
            last_rr <= (prev_r != 0) ? (det_r - prev_r) : 32'd0;
            prev_r  <= det_r;
        end
    end
    assign qrs_delay = n_cnt - det_r;
    assign txt_we = psel_txt & penable & pwrite;
endmodule
