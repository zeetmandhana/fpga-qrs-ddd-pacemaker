`timescale 1ns/1ps
//============================================================================
// tb_vga_sync.v  --  P17 Phase 6: verify the 640x480@60 VGA timing in sim.
// Counts over one full frame period (800*525 clocks): the visible-pixel count
// and the hsync/vsync low durations must match the standard.
//============================================================================
module tb_vga_sync;
    reg        pix_clk = 0, rst_n = 0;
    wire       hsync, vsync, video_on;
    wire [9:0] px, py;

    vga_sync dut (.pix_clk(pix_clk), .rst_n(rst_n), .hsync(hsync), .vsync(vsync),
                  .video_on(video_on), .px(px), .py(py));

    always #20 pix_clk = ~pix_clk;      // 25 MHz pixel clock

    integer i, von, hlow, vlow, errors;
    localparam FRAME = 800 * 525;        // 420000 pixel clocks

    initial begin
        rst_n = 0; repeat (8) @(posedge pix_clk); rst_n = 1;
        repeat (2000) @(posedge pix_clk);          // settle one+ partial frame

        von = 0; hlow = 0; vlow = 0; errors = 0;
        for (i = 0; i < FRAME; i = i + 1) begin
            @(posedge pix_clk);
            if (video_on) von = von + 1;
            if (!hsync)   hlow = hlow + 1;
            if (!vsync)   vlow = vlow + 1;
        end

        $display("visible pixels/frame = %0d (expect 307200 = 640x480)", von);
        $display("hsync-low/frame      = %0d (expect 50400 = 96*525)", hlow);
        $display("vsync-low/frame      = %0d (expect 1600  = 2*800)", vlow);
        if (von  != 307200) errors = errors + 1;
        if (hlow != 96*525) errors = errors + 1;
        if (vlow != 1600)   errors = errors + 1;

        if (errors == 0) $display("VGA TIMING PASS (640x480 @ 60 Hz)");
        else             $display("VGA TIMING FAIL (%0d errors)", errors);
        $finish;
    end
endmodule
