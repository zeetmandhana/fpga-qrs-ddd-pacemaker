`timescale 1ns/1ps
//============================================================================
// tb_sw_bench.v -- runs firmware fw/hwsw_bench.c on the board's NEORV32
// configuration (neorv32_p17: rv32i + Zicntr, 16 KB IMEM, 8 KB DMEM, XBUS)
// at 25 MHz, with the board's real XBUS->APB bridge and demo_ctrl_apb slave
// on the external bus, plus a testbench mailbox at 0xA000_0000:
//   0xA000_0000  data word  -> appended to sw_dump.txt (one hex word per line)
//   0xA000_0004  done       -> end of simulation
//============================================================================
module tb_sw_bench;
    reg clk = 0;
    always #20 clk = ~clk;                 // 25 MHz, as on the Zybo
    reg rst_n = 0;

    wire [7:0]  gpio_o;
    wire [31:0] adr, dat_w;
    wire        we, stb, cyc;
    wire [31:0] dat_r;
    wire        ack, err;

    neorv32_p17 u_cpu (
        .clk_i(clk), .rstn_i(rst_n),
        .gpio_o(gpio_o), .gpio_i(8'd0), .irq_mei_i(1'b0),
        .xbus_adr_o(adr), .xbus_dat_o(dat_w), .xbus_we_o(we),
        .xbus_stb_o(stb), .xbus_cyc_o(cyc),
        .xbus_dat_i(dat_r), .xbus_ack_i(ack), .xbus_err_i(err)
    );

    // ---- mailbox (0xA...) ----
    wire is_mb = (adr[31:28] == 4'hA);
    reg  mb_ack = 0;
    integer fd, nwords = 0;
    reg done = 0;
    always @(posedge clk) begin
        mb_ack <= 1'b0;
        if (stb && is_mb) begin
            mb_ack <= 1'b1;
            if (we) begin
                if (adr[3:0] == 4'h0) begin
                    $fwrite(fd, "%08x\n", dat_w);
                    nwords = nwords + 1;
                end else if (adr[3:0] == 4'h4) begin
                    done <= 1'b1;
                end
            end
        end
    end

    // ---- the board's XBUS -> APB bridge + demo control slave ----
    wire [15:0] PADDR;
    wire [31:0] PWDATA, PRDATA1;
    wire        PWRITE, PENABLE;
    wire [2:0]  PSEL;
    wire [31:0] br_dat;
    wire        br_ack, br_err;
    wire [2:0]  mode;
    wire        mode_wr;

    xbus_apb_bridge u_br (
        .clk(clk), .rst_n(rst_n),
        .xbus_adr(adr), .xbus_dat_w(dat_w), .xbus_we(we), .xbus_stb(stb & ~is_mb),
        .xbus_dat_r(br_dat), .xbus_ack(br_ack), .xbus_err(br_err),
        .PADDR(PADDR), .PWDATA(PWDATA), .PWRITE(PWRITE), .PENABLE(PENABLE), .PSEL(PSEL),
        .PRDATA0(32'd0), .PRDATA1(PRDATA1), .PRDATA2(32'd0)
    );
    demo_ctrl_apb u_ctrl (
        .PCLK(clk), .PRESETn(rst_n), .PSEL(PSEL[1]), .PENABLE(PENABLE), .PWRITE(PWRITE),
        .PADDR(PADDR[7:0]), .PWDATA(PWDATA), .PRDATA(PRDATA1),
        .mode(mode), .mode_wr(mode_wr),
        .qrs_evt(1'b0), .ap_evt(1'b0), .vp_evt(1'b0), .as_evt(1'b0), .vs_evt(1'b0),
        .last_rr(32'd0), .learning(1'b0)
    );

    assign dat_r = mb_ack ? 32'd0 : br_dat;
    assign ack   = mb_ack | br_ack;
    assign err   = br_err;

    // ---- run ----
    integer cycles = 0;
    always @(posedge clk) cycles = cycles + 1;

    initial begin
        fd = $fopen("sw_dump.txt", "w");
        repeat (10) @(posedge clk);
        rst_n = 1;
        wait (done);
        repeat (5) @(posedge clk);
        $fclose(fd);
        $display("SW BENCH DONE: %0d mailbox words, %0d clock cycles simulated", nwords, cycles);
        $finish;
    end

    initial begin
        #(64'd40 * 64'd60_000_000);         // watchdog: 60 M cycles
        $display("SW BENCH TIMEOUT after %0d cycles, %0d words", cycles, nwords);
        $fclose(fd);
        $finish;
    end
endmodule
