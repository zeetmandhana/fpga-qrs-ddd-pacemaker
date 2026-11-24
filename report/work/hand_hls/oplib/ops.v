// Operator library characterisation modules (registered in -> op -> registered out)
module op_add32 (input clk, input [31:0] a_i, b_i, output reg [31:0] s_o);
    reg [31:0] a, b;
    always @(posedge clk) begin a <= a_i; b <= b_i; s_o <= a + b; end
endmodule

module op_addsub40 (input clk, input sub_i, input [39:0] a_i, b_i, output reg [39:0] s_o);
    reg [39:0] a, b; reg sub;
    always @(posedge clk) begin a <= a_i; b <= b_i; sub <= sub_i; s_o <= sub ? a - b : a + b; end
endmodule

// 32x32 -> low 32 bits (what the squarer needs: (d*d) mod 2^32)
module op_mul_lo32 (input clk, input signed [31:0] a_i, b_i, output reg [31:0] p_o);
    reg signed [31:0] a, b;
    always @(posedge clk) begin a <= a_i; b <= b_i; p_o <= a * b; end
endmodule

// the squarer itself: d*d, low 32 bits
module op_sq_lo32 (input clk, input signed [31:0] a_i, output reg [31:0] p_o);
    reg signed [31:0] a;
    always @(posedge clk) begin a <= a_i; p_o <= a * a; end
endmodule

// squarer with one internal pipeline register (2-cycle latency)
module op_sq_lo32_p2 (input clk, input signed [31:0] a_i, output reg [31:0] p_o);
    reg signed [31:0] a; reg [31:0] m;
    always @(posedge clk) begin a <= a_i; m <= a * a; p_o <= m; end
endmodule

// full 33x33 signed product (reference)
module op_mul33_full (input clk, input signed [32:0] a_i, b_i, output reg signed [65:0] p_o);
    reg signed [32:0] a, b;
    always @(posedge clk) begin a <= a_i; b <= b_i; p_o <= a * b; end
endmodule

// 64 x 32 distributed RAM: registered write, asynchronous read, registered output
module op_lutram64 (input clk, input we_i, input [5:0] wa_i, ra_i, input [31:0] d_i, output reg [31:0] q_o);
    (* ram_style = "distributed" *) reg [31:0] mem [0:63];
    reg [5:0] ra;
    always @(posedge clk) begin
        if (we_i) mem[wa_i] <= d_i;
        ra <= ra_i;
        q_o <= mem[ra];
    end
endmodule

// 4:1 x 32-bit operand multiplexer
module op_mux4_32 (input clk, input [1:0] s_i, input [31:0] a_i, b_i, c_i, d_i, output reg [31:0] y_o);
    reg [31:0] a, b, c, d; reg [1:0] s;
    always @(posedge clk) begin
        a <= a_i; b <= b_i; c <= c_i; d <= d_i; s <= s_i;
        case (s) 2'd0: y_o <= a; 2'd1: y_o <= b; 2'd2: y_o <= c; default: y_o <= d; endcase
    end
endmodule
