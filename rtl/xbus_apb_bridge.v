`timescale 1ns/1ps
//============================================================================
// xbus_apb_bridge.v  --  NEORV32 external bus (XBUS, Wishbone-style) -> APB3
//
// Window 0x9000_0000 - 0x9000_7FFF (other addresses get a bus error):
//   0x9000_0000  DDD pacemaker      (ddd_pacemaker_apb, PSEL[0])
//   0x9000_0100  demo control       (demo_ctrl_apb,     PSEL[1])
//   0x9000_4000  screen text RAM    (write-only,        PSEL[2])
// One APB transfer per XBUS access: SETUP, ACCESS, then XBUS ack.
//============================================================================
module xbus_apb_bridge (
    input  wire        clk,
    input  wire        rst_n,
    // XBUS (from neorv32_top)
    input  wire [31:0] xbus_adr,
    input  wire [31:0] xbus_dat_w,
    input  wire        xbus_we,
    input  wire        xbus_stb,
    output reg  [31:0] xbus_dat_r,
    output reg         xbus_ack,
    output reg         xbus_err,
    // APB3
    output reg  [15:0] PADDR,
    output reg  [31:0] PWDATA,
    output reg         PWRITE,
    output reg         PENABLE,
    output reg  [2:0]  PSEL,
    input  wire [31:0] PRDATA0,
    input  wire [31:0] PRDATA1,
    input  wire [31:0] PRDATA2
);
    localparam S_IDLE = 2'd0, S_SETUP = 2'd1, S_ACCESS = 2'd2;
    reg [1:0] st;
    wire in_win = (xbus_adr[31:15] == 17'h12000);          // 0x9000_0000 >> 15

    always @(posedge clk) begin
        xbus_ack <= 1'b0; xbus_err <= 1'b0;
        if (!rst_n) begin
            st <= S_IDLE; PSEL <= 3'b000; PENABLE <= 1'b0; PWRITE <= 1'b0;
            PADDR <= 16'd0; PWDATA <= 32'd0; xbus_dat_r <= 32'd0;
        end else begin
            case (st)
            S_IDLE: if (xbus_stb) begin
                if (in_win) begin
                    PADDR <= xbus_adr[15:0]; PWDATA <= xbus_dat_w; PWRITE <= xbus_we;
                    PSEL  <= xbus_adr[14] ? 3'b100 : (xbus_adr[8] ? 3'b010 : 3'b001);
                    PENABLE <= 1'b0;
                    st <= S_SETUP;
                end else begin
                    xbus_err <= 1'b1;
                end
            end
            S_SETUP: begin PENABLE <= 1'b1; st <= S_ACCESS; end
            S_ACCESS: begin
                xbus_dat_r <= PSEL[0] ? PRDATA0 : (PSEL[1] ? PRDATA1 : PRDATA2);
                xbus_ack <= 1'b1;
                PSEL <= 3'b000; PENABLE <= 1'b0; PWRITE <= 1'b0;
                st <= S_IDLE;
            end
            default: st <= S_IDLE;
            endcase
        end
    end
endmodule
