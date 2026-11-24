`timescale 1ns/1ps
// tb_p17_axi_apb.v -- AXI4-Lite -> APB bridge with the real DDD and control slaves.
// Writes/reads the pacemaker timing registers, the scenario register and the
// ID register through AXI, and checks a text-RAM write strobe reaches slave 2.
module tb_p17_axi_apb;
    reg clk = 0, rstn = 0;
    always #20 clk = ~clk;
    reg  [15:0] awaddr = 0, araddr = 0;
    reg         awvalid = 0, wvalid = 0, bready = 0, arvalid = 0, rready = 0;
    reg  [31:0] wdata = 0;
    wire        awready, wready, bvalid, arready, rvalid;
    wire [1:0]  bresp, rresp;
    wire [31:0] rdata;
    wire [31:0] p0a, p1a, p2a, p0w, p1w, p2w, p0r, p1r, p2r;
    wire        p0s, p1s, p2s, p0e, p1e, p2e, p0wr, p1wr, p2wr, p0y, p1y, p2y, p0x, p1x, p2x;

    p17_axi_apb br (.aclk(clk), .aresetn(rstn),
        .s_axi_awaddr(awaddr), .s_axi_awprot(3'd0), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(4'hF), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arprot(3'd0), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready),
        .m0_paddr(p0a), .m0_psel(p0s), .m0_penable(p0e), .m0_pwrite(p0wr), .m0_pwdata(p0w),
        .m0_prdata(p0r), .m0_pready(p0y), .m0_pslverr(p0x),
        .m1_paddr(p1a), .m1_psel(p1s), .m1_penable(p1e), .m1_pwrite(p1wr), .m1_pwdata(p1w),
        .m1_prdata(p1r), .m1_pready(p1y), .m1_pslverr(p1x),
        .m2_paddr(p2a), .m2_psel(p2s), .m2_penable(p2e), .m2_pwrite(p2wr), .m2_pwdata(p2w),
        .m2_prdata(32'd0), .m2_pready(1'b1), .m2_pslverr(1'b0));

    wire ap, vp, ase, vse, irq, mwr;
    wire [2:0] mode;
    p17_ddd_slave dd (.clk(clk), .rst_n(rstn), .s_paddr(p0a), .s_psel(p0s), .s_penable(p0e),
        .s_pwrite(p0wr), .s_pwdata(p0w), .s_prdata(p0r), .s_pready(p0y), .s_pslverr(p0x),
        .tick_ms(1'b0), .a_sense(1'b0), .v_sense(1'b0), .ap(ap), .vp(vp), .as_evt(ase),
        .vs_evt(vse), .arrhythmia_irq(irq));
    p17_ctrl_slave cs (.clk(clk), .rst_n(rstn), .s_paddr(p1a), .s_psel(p1s), .s_penable(p1e),
        .s_pwrite(p1wr), .s_pwdata(p1w), .s_prdata(p1r), .s_pready(p1y), .s_pslverr(p1x),
        .mode(mode), .mode_wr(mwr), .qrs_evt(1'b0), .ap_evt(1'b0), .vp_evt(1'b0),
        .as_evt(1'b0), .vs_evt(1'b0), .last_rr(32'd777), .learning(1'b1));

    integer txt_writes = 0, errors = 0;
    reg [31:0] txt_last;
    always @(posedge clk) if (p2s & p2e & p2wr) begin txt_writes = txt_writes + 1; txt_last = {p2a[15:0], p2w[15:0]}; end

    task axi_write(input [15:0] a, input [31:0] d);
        begin
            @(negedge clk); awaddr = a; wdata = d; awvalid = 1; wvalid = 1; bready = 1;
            while (!(awvalid == 0 && wvalid == 0)) begin
                @(posedge clk);
                if (awready) awvalid = 0;
                if (wready)  wvalid = 0;
                @(negedge clk);
            end
            while (!bvalid) @(negedge clk);
            @(negedge clk); bready = 0;
        end
    endtask
    task axi_read(input [15:0] a, output [31:0] d);
        begin
            @(negedge clk); araddr = a; arvalid = 1; rready = 1;
            @(posedge clk); while (!arready) @(posedge clk);
            @(negedge clk); arvalid = 0;
            while (!rvalid) @(negedge clk);
            d = rdata;
            @(negedge clk); rready = 0;
        end
    endtask
    task check(input [8*24-1:0] what, input [31:0] got, input [31:0] exp);
        begin
            if (got !== exp) begin errors = errors + 1; $display("  FAIL %0s: got %h exp %h", what, got, exp); end
            else $display("  ok   %0s = %0d (0x%h)", what, got, got);
        end
    endtask

    reg [31:0] v;
    initial begin
        repeat (4) @(posedge clk); rstn = 1;
        axi_write(16'h0000, 1200); axi_write(16'h0004, 170); axi_write(16'h000C, 250);
        axi_write(16'h0014, 1);
        axi_read(16'h0000, v); check("DDD LRI", v, 1200);
        axi_read(16'h0004, v); check("DDD AVI", v, 170);
        axi_read(16'h000C, v); check("DDD PVARP", v, 250);
        axi_read(16'h0014, v); check("DDD CONTROL", v, 1);
        check("pacemaker enable", dd.u_pm.enable, 1);
        axi_write(16'h0100, 3);
        axi_read(16'h0100, v); check("CTRL MODE", v, 3);
        axi_read(16'h0124, v); check("CTRL ID", v, 32'h50170001);
        axi_read(16'h011C, v); check("CTRL LAST_RR", v, 777);
        axi_write(16'h4000 + 4*(1*128 + 5), "A");
        check("text writes", txt_writes, 1);
        check("text addr/data", txt_last, {16'h4000 + 16'd4*(16'd128 + 16'd5), 16'h0041});
        if (errors == 0) $display("AXI-APB BRIDGE PASS"); else $display("AXI-APB BRIDGE FAIL (%0d)", errors);
        $finish;
    end
endmodule
