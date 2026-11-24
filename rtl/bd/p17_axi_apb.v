`timescale 1ns/1ps
//============================================================================
// p17_axi_apb.v  --  AXI4-Lite slave -> APB3 bridge with three APB masters
//
// Used in the IP-Integrator block design: NEORV32 m_axi -> AXI SmartConnect
// -> this bridge -> APB peripherals. Address offsets inside the 64 KB window
// (base 0x9000_0000 in the address editor, same as the firmware):
//   0x0000-0x00FF  APB_M0  DDD pacemaker registers
//   0x0100-0x01FF  APB_M1  demo control (scenario, counters)
//   0x4000-0x7FFF  APB_M2  screen text RAM
// One APB transfer per AXI access: SETUP, ACCESS (wait for PREADY), respond.
//============================================================================
module p17_axi_apb (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXI:APB_M0:APB_M1:APB_M2, ASSOCIATED_RESET aresetn" *)
    input  wire        aclk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 aresetn RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire        aresetn,
    // ---- AXI4-Lite slave ----
    input  wire [15:0] s_axi_awaddr,
    input  wire [2:0]  s_axi_awprot,
    input  wire        s_axi_awvalid,
    output reg         s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output reg         s_axi_wready,
    output reg  [1:0]  s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [15:0] s_axi_araddr,
    input  wire [2:0]  s_axi_arprot,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready,
    output reg  [31:0] s_axi_rdata,
    output reg  [1:0]  s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready,
    // ---- APB master 0: DDD pacemaker ----
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_M0 PADDR" *)   output wire [31:0] m0_paddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_M0 PSEL" *)    output wire        m0_psel,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_M0 PENABLE" *) output wire        m0_penable,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_M0 PWRITE" *)  output wire        m0_pwrite,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_M0 PWDATA" *)  output wire [31:0] m0_pwdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_M0 PRDATA" *)  input  wire [31:0] m0_prdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_M0 PREADY" *)  input  wire        m0_pready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_M0 PSLVERR" *) input  wire        m0_pslverr,
    // ---- APB master 1: demo control ----
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_M1 PADDR" *)   output wire [31:0] m1_paddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_M1 PSEL" *)    output wire        m1_psel,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_M1 PENABLE" *) output wire        m1_penable,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_M1 PWRITE" *)  output wire        m1_pwrite,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_M1 PWDATA" *)  output wire [31:0] m1_pwdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_M1 PRDATA" *)  input  wire [31:0] m1_prdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_M1 PREADY" *)  input  wire        m1_pready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_M1 PSLVERR" *) input  wire        m1_pslverr,
    // ---- APB master 2: screen text RAM ----
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_M2 PADDR" *)   output wire [31:0] m2_paddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_M2 PSEL" *)    output wire        m2_psel,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_M2 PENABLE" *) output wire        m2_penable,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_M2 PWRITE" *)  output wire        m2_pwrite,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_M2 PWDATA" *)  output wire [31:0] m2_pwdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_M2 PRDATA" *)  input  wire [31:0] m2_prdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_M2 PREADY" *)  input  wire        m2_pready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 APB_M2 PSLVERR" *) input  wire        m2_pslverr
);
    // shared APB signals
    reg  [31:0] paddr, pwdata;
    reg         pwrite, penable;
    reg  [2:0]  psel;
    assign m0_paddr = paddr;  assign m1_paddr = paddr;  assign m2_paddr = paddr;
    assign m0_pwdata = pwdata; assign m1_pwdata = pwdata; assign m2_pwdata = pwdata;
    assign m0_pwrite = pwrite; assign m1_pwrite = pwrite; assign m2_pwrite = pwrite;
    assign m0_penable = penable; assign m1_penable = penable; assign m2_penable = penable;
    assign m0_psel = psel[0]; assign m1_psel = psel[1]; assign m2_psel = psel[2];

    wire [31:0] prdata  = psel[0] ? m0_prdata  : (psel[1] ? m1_prdata  : m2_prdata);
    wire        pready  = psel[0] ? m0_pready  : (psel[1] ? m1_pready  : m2_pready);
    wire        pslverr = psel[0] ? m0_pslverr : (psel[1] ? m1_pslverr : m2_pslverr);

    function [2:0] decode(input [15:0] a);
        decode = a[14] ? 3'b100 : (a[8] ? 3'b010 : 3'b001);
    endfunction

    localparam S_IDLE = 3'd0, S_WSETUP = 3'd1, S_WACC = 3'd2, S_BRESP = 3'd3,
               S_RSETUP = 3'd4, S_RACC = 3'd5, S_RRESP = 3'd6;
    reg [2:0]  st;
    reg        aw_got, w_got;
    reg [15:0] awaddr_q;
    reg [31:0] wdata_q;

    always @(posedge aclk) begin
        if (!aresetn) begin
            st <= S_IDLE; aw_got <= 1'b0; w_got <= 1'b0;
            s_axi_awready <= 1'b0; s_axi_wready <= 1'b0; s_axi_bvalid <= 1'b0; s_axi_bresp <= 2'b00;
            s_axi_arready <= 1'b0; s_axi_rvalid <= 1'b0; s_axi_rresp <= 2'b00; s_axi_rdata <= 32'd0;
            paddr <= 32'd0; pwdata <= 32'd0; pwrite <= 1'b0; penable <= 1'b0; psel <= 3'b000;
            awaddr_q <= 16'd0; wdata_q <= 32'd0;
        end else begin
            s_axi_awready <= 1'b0; s_axi_wready <= 1'b0; s_axi_arready <= 1'b0;
            case (st)
            S_IDLE: begin
                // collect write address and data (either order); reads when no write pending
                if (s_axi_awvalid && !aw_got && !s_axi_awready) begin
                    awaddr_q <= s_axi_awaddr; aw_got <= 1'b1; s_axi_awready <= 1'b1;
                end
                if (s_axi_wvalid && !w_got && !s_axi_wready) begin
                    wdata_q <= s_axi_wdata; w_got <= 1'b1; s_axi_wready <= 1'b1;
                end
                if (aw_got && w_got) begin
                    paddr <= {16'd0, awaddr_q}; pwdata <= wdata_q; pwrite <= 1'b1;
                    psel <= decode(awaddr_q); penable <= 1'b0;
                    aw_got <= 1'b0; w_got <= 1'b0;
                    st <= S_WACC;
                end else if (!aw_got && !w_got && s_axi_arvalid && !s_axi_awvalid && !s_axi_wvalid) begin
                    s_axi_arready <= 1'b1;
                    paddr <= {16'd0, s_axi_araddr}; pwrite <= 1'b0;
                    psel <= decode(s_axi_araddr); penable <= 1'b0;
                    st <= S_RACC;
                end
            end
            S_WACC: begin                         // SETUP phase was the previous cycle
                penable <= 1'b1;
                if (penable && pready) begin
                    psel <= 3'b000; penable <= 1'b0; pwrite <= 1'b0;
                    s_axi_bvalid <= 1'b1; s_axi_bresp <= pslverr ? 2'b10 : 2'b00;
                    st <= S_BRESP;
                end
            end
            S_BRESP: if (s_axi_bready) begin s_axi_bvalid <= 1'b0; st <= S_IDLE; end
            S_RACC: begin
                penable <= 1'b1;
                if (penable && pready) begin
                    s_axi_rdata <= prdata; s_axi_rresp <= pslverr ? 2'b10 : 2'b00;
                    psel <= 3'b000; penable <= 1'b0;
                    s_axi_rvalid <= 1'b1;
                    st <= S_RRESP;
                end
            end
            S_RRESP: if (s_axi_rready) begin s_axi_rvalid <= 1'b0; st <= S_IDLE; end
            default: st <= S_IDLE;
            endcase
        end
    end
endmodule
