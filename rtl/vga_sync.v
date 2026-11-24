`timescale 1ns/1ps
//============================================================================
// vga_sync.v  --  P17 Phase 6: 640x480 @ 60 Hz VGA sync generator
//
// Standard VGA timing (25.175 MHz pixel clock):
//   horizontal: 640 visible + 16 front + 96 sync + 48 back  = 800
//   vertical:   480 visible + 10 front +  2 sync + 33 back   = 525
// hsync/vsync are active-low.
//============================================================================
module vga_sync (
    input  wire        pix_clk,     // ~25 MHz pixel clock
    input  wire        rst_n,
    output reg         hsync,
    output reg         vsync,
    output wire        video_on,    // inside the visible area
    output wire [9:0]  px,          // 0..639 pixel column
    output wire [9:0]  py           // 0..479 pixel row
);
    localparam H_VIS = 640, H_FP = 16, H_SYNC = 96, H_BP = 48, H_TOT = 800;
    localparam V_VIS = 480, V_FP = 10, V_SYNC = 2,  V_BP = 33, V_TOT = 525;

    reg [9:0] hcnt, vcnt;

    always @(posedge pix_clk) begin
        if (!rst_n) begin
            hcnt <= 0; vcnt <= 0;
        end else begin
            if (hcnt == H_TOT-1) begin
                hcnt <= 0;
                vcnt <= (vcnt == V_TOT-1) ? 10'd0 : (vcnt + 1'b1);
            end else begin
                hcnt <= hcnt + 1'b1;
            end
        end
    end

    // active-low syncs during the sync window
    always @(posedge pix_clk) begin
        hsync <= ~((hcnt >= H_VIS+H_FP) && (hcnt < H_VIS+H_FP+H_SYNC));
        vsync <= ~((vcnt >= V_VIS+V_FP) && (vcnt < V_VIS+V_FP+V_SYNC));
    end

    assign video_on = (hcnt < H_VIS) && (vcnt < V_VIS);
    assign px = (hcnt < H_VIS) ? hcnt : 10'd0;
    assign py = (vcnt < V_VIS) ? vcnt : 10'd0;
endmodule
