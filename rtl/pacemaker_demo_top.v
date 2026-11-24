`timescale 1ns/1ps
//============================================================================
// pacemaker_demo_top.v  --  P17 Phase 6: board demo top (Arty A7, 100 MHz)
//
// Integrates the verified pieces into a self-contained, synthesizable demo:
//   * an APB-init FSM that programs the DDD timing registers and enables the
//     core  (a hardware stand-in for the RV32 firmware in ddd_driver.c);
//   * the DDD pacemaker (ddd_pacemaker_apb), bit-exact vs the golden model;
//   * an ECG replay BRAM (record 100) + a simple threshold beat detector
//     (placeholder for the Phase-4 HLS detector IP);
//   * the ECG-on-VGA display (ecg_vga) with beat/pace markers;
//   * LEDs for pace pulses and the arrhythmia flag.
//
// On the real board: RGB -> VGA pmod, led[3:0] -> LEDs. The full SoC (NEORV32
// + packaged HLS detector) is assembled in a Vivado block design; this top
// shows the datapath and builds stand-alone.
//============================================================================
module pacemaker_demo_top (
    input  wire       clk100,         // 100 MHz board clock
    input  wire       rst_btn,        // active-high reset button
    output wire [3:0] led,            // led0=AP led1=VP led2=sense led3=arrhythmia
    output wire       vga_hsync,
    output wire       vga_vsync,
    output wire [3:0] vga_r,
    output wire [3:0] vga_g,
    output wire [3:0] vga_b
);
    wire rst_n = ~rst_btn;

    // ---------------- clock / strobe generation ----------------
    reg [1:0]  pixdiv = 0;            // /4 -> 25 MHz pixel clock
    always @(posedge clk100) pixdiv <= pixdiv + 1'b1;
    wire pix_clk = pixdiv[1];

    reg [16:0] ms_cnt = 0;            // 1 ms tick (100e6/1000 = 100000)
    reg        tick_1ms = 0;
    always @(posedge clk100) begin
        if (ms_cnt == 17'd99999) begin ms_cnt <= 0; tick_1ms <= 1'b1; end
        else                     begin ms_cnt <= ms_cnt + 1'b1; tick_1ms <= 1'b0; end
    end

    reg [18:0] sm_cnt = 0;            // ~360 Hz sample tick (100e6/360 ~= 277778)
    reg        tick_360 = 0;
    always @(posedge clk100) begin
        if (sm_cnt == 19'd277777) begin sm_cnt <= 0; tick_360 <= 1'b1; end
        else                      begin sm_cnt <= sm_cnt + 1'b1; tick_360 <= 1'b0; end
    end

    // ---------------- APB init FSM (RV32 stand-in) ----------------
    // Sequence of (addr,data) register writes, then enable.
    reg [31:0] PWDATA; reg [7:0] PADDR; reg PSEL, PENABLE, PWRITE;
    wire [31:0] PRDATA; wire PREADY, PSLVERR;
    reg [3:0] ist = 0;               // init step
    reg [1:0] pst = 0;               // apb phase
    always @(posedge clk100) begin
        if (!rst_n) begin ist<=0; pst<=0; PSEL<=0; PENABLE<=0; PWRITE<=0; end
        else if (ist <= 4'd5) begin
            case (pst)
              0: begin
                   PWRITE<=1; PSEL<=1; PENABLE<=0;
                   case (ist)
                     0:begin PADDR<=8'h00; PWDATA<=32'd1000; end // LRI
                     1:begin PADDR<=8'h04; PWDATA<=32'd180;  end // AVI
                     2:begin PADDR<=8'h08; PWDATA<=32'd500;  end // URI
                     3:begin PADDR<=8'h0C; PWDATA<=32'd320;  end // PVARP
                     4:begin PADDR<=8'h10; PWDATA<=32'd250;  end // VRP
                     5:begin PADDR<=8'h14; PWDATA<=32'd1;    end // CONTROL enable
                   endcase
                   pst<=1;
                 end
              1: begin PENABLE<=1; pst<=2; end
              2: begin PSEL<=0; PENABLE<=0; PWRITE<=0; pst<=0; ist<=ist+1'b1; end
            endcase
        end else begin PSEL<=0; PENABLE<=0; PWRITE<=0; end
    end

    // ---------------- ECG replay BRAM (record 100) ----------------
    (* ram_style="block" *) reg [7:0] ecg_rom [0:639];
    initial $readmemh("ecg_samples.mem", ecg_rom);
    reg [9:0] rptr = 0;
    reg [7:0] ecg8 = 0;
    always @(posedge clk100) if (tick_360) begin
        ecg8 <= ecg_rom[rptr];
        rptr <= (rptr == 10'd639) ? 10'd0 : rptr + 1'b1;
    end

    // ---------------- simple threshold beat detector (placeholder) ----------
    // The real detector is the Phase-4 HLS Pan-Tompkins IP; here a rising-edge
    // threshold crossing drives v_sense and the beat marker for the demo.
    localparam [7:0] THRESH = 8'd200;
    reg prev_above = 0;
    wire above = (ecg8 > THRESH);
    reg beat_pending = 0, beat_mark = 0, v_sense_lat = 0;
    always @(posedge clk100) begin
        beat_mark <= 1'b0;
        if (tick_360) begin
            if (above && !prev_above) begin beat_pending <= 1'b1; beat_mark <= 1'b1; end
            prev_above <= above;
        end
        if (tick_1ms) v_sense_lat <= beat_pending;   // present the beat for one tick
        else          v_sense_lat <= 1'b0;
        if (tick_1ms) beat_pending <= 1'b0;
    end

    // ---------------- DDD pacemaker (verified core) ----------------
    wire ap, vp, as_evt, vs_evt, arrhythmia_irq;
    ddd_pacemaker_apb #(.W(16)) u_pm (
        .PCLK(clk100), .PRESETn(rst_n), .PSEL(PSEL), .PENABLE(PENABLE),
        .PWRITE(PWRITE), .PADDR(PADDR), .PWDATA(PWDATA), .PRDATA(PRDATA),
        .PREADY(PREADY), .PSLVERR(PSLVERR),
        .tick_en(tick_1ms), .a_sense_in(1'b0), .v_sense_in(v_sense_lat),
        .ap(ap), .vp(vp), .as_evt(as_evt), .vs_evt(vs_evt),
        .arrhythmia_irq(arrhythmia_irq)
    );

    // ---------------- VGA ECG display ----------------
    wire [9:0] sample_y = 10'd470 - ({2'b0, ecg8} * 10'd440) / 10'd255;
    ecg_vga u_vga (
        .pix_clk(pix_clk), .rst_n(rst_n),
        .sample_valid(tick_360), .sample_y(sample_y), .sample_beat(beat_mark),
        .pace_active(ap | vp),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b),
        .hsync(vga_hsync), .vsync(vga_vsync)
    );

    // ---------------- LED pulse stretchers (make 1 ms pulses visible) -------
    reg [21:0] ap_s = 0, vp_s = 0, sn_s = 0;
    always @(posedge clk100) begin
        if (ap)            ap_s <= 22'h3FFFFF; else if (|ap_s) ap_s <= ap_s - 1'b1;
        if (vp)            vp_s <= 22'h3FFFFF; else if (|vp_s) vp_s <= vp_s - 1'b1;
        if (as_evt|vs_evt) sn_s <= 22'h3FFFFF; else if (|sn_s) sn_s <= sn_s - 1'b1;
    end
    assign led = {arrhythmia_irq, (|sn_s), (|vp_s), (|ap_s)};
endmodule
