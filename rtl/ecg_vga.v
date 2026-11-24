`timescale 1ns/1ps
//============================================================================
// ecg_vga.v  --  P17 Phase 6: ECG-on-VGA display with beat / pace markers
//
// Scrolls the ECG waveform across a 640x480 screen. Each incoming sample is a
// precomputed screen row (sample_y) plus a detected-beat flag (sample_beat).
// Detected beats are drawn as red vertical lines; a pace pulse flashes a top
// band; the ECG trace is green on a dim grid.  (The demo/board piece of
// Phase 6 -- visual output needs the physical monitor.)
//============================================================================
module ecg_vga (
    input  wire       pix_clk,
    input  wire       rst_n,
    input  wire       sample_valid,  // strobe: one new ECG column
    input  wire [9:0] sample_y,      // 0..479 screen row for this sample
    input  wire       sample_beat,   // 1 = detected beat at this column
    input  wire       pace_active,   // show the pace band (AP/VP pulse)
    output reg  [3:0] vga_r,
    output reg  [3:0] vga_g,
    output reg  [3:0] vga_b,
    output wire       hsync,
    output wire       vsync
);
    wire        video_on;
    wire [9:0]  px, py;

    vga_sync u_sync (
        .pix_clk(pix_clk), .rst_n(rst_n), .hsync(hsync), .vsync(vsync),
        .video_on(video_on), .px(px), .py(py)
    );

    // scrolling column buffers (distributed RAM): ECG row + beat flag per column
    reg [9:0] ecg_col  [0:639];
    reg       beat_col [0:639];
    reg [9:0] wptr;

    always @(posedge pix_clk) begin
        if (!rst_n) begin
            wptr <= 10'd0;
        end else if (sample_valid) begin
            ecg_col[wptr]  <= sample_y;
            beat_col[wptr] <= sample_beat;
            wptr <= (wptr == 10'd639) ? 10'd0 : (wptr + 1'b1);
        end
    end

    wire [9:0] col_y    = ecg_col[px];
    wire       col_beat = beat_col[px];
    wire on_trace  = video_on && (py >= ((col_y >= 1) ? col_y-1 : 10'd0))
                              && (py <= col_y+1);
    wire on_grid   = video_on && ((px[5:0] == 6'd0) || (py[5:0] == 6'd0));
    wire on_beat   = video_on && col_beat;
    wire on_paceby = video_on && pace_active && (py < 10'd12);

    always @(*) begin
        if      (!video_on)  {vga_r,vga_g,vga_b} = 12'h000;
        else if (on_paceby)  {vga_r,vga_g,vga_b} = 12'hFF0;  // yellow pace band
        else if (on_beat)    {vga_r,vga_g,vga_b} = 12'hF22;  // red beat marker
        else if (on_trace)   {vga_r,vga_g,vga_b} = 12'h2F4;  // green ECG trace
        else if (on_grid)    {vga_r,vga_g,vga_b} = 12'h112;  // dim grid
        else                 {vga_r,vga_g,vga_b} = 12'h001;  // near-black bg
    end
endmodule
