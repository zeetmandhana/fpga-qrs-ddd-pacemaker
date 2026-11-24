// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2025.2 (win64) Build 6299465 Fri Nov 14 19:35:11 GMT 2025
// Date        : Fri Nov 20 17:59:49 2026
// Host        : Zeet running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode funcsim
//               C:/Vivadoproject/P17_QRS_Pacemaker/report/work/fsm_logic/vivado/../sim_ctrl/net/net_auto.v
// Design      : qd_ctrl
// Purpose     : This verilog netlist is a functional simulation representation of the design and should not be modified
//               or synthesized. This netlist cannot be used for SDF annotated simulation.
// Device      : xc7z010clg400-1
// --------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* C_AVG = "3'b100" *) (* C_CLS = "3'b010" *) (* C_END = "3'b111" *) 
(* C_IDL = "3'b000" *) (* C_LIM = "3'b101" *) (* C_REG = "3'b011" *) 
(* C_SBK = "3'b110" *) (* C_TRK = "3'b001" *) 
(* NotValidForBitStream *)
module qd_ctrl
   (clk,
    rst_n,
    i,
    f,
    s,
    ld,
    trk,
    cls,
    rg,
    avg,
    lim,
    sbk,
    cnt);
  input clk;
  input rst_n;
  input i;
  input f;
  input s;
  output ld;
  output trk;
  output cls;
  output rg;
  output avg;
  output lim;
  output sbk;
  output cnt;

  wire \FSM_sequential_ph[0]_i_1_n_0 ;
  wire \FSM_sequential_ph[1]_i_1_n_0 ;
  wire \FSM_sequential_ph[2]_i_1_n_0 ;
  wire avg;
  wire clk;
  wire cls;
  wire cnt;
  wire f;
  wire i;
  wire ld;
  wire lim;
  wire [2:0]ph;
  wire rg;
  wire rst_n;
  wire s;
  wire sbk;
  wire trk;

  LUT6 #(
    .INIT(64'h7372333200000000)) 
    \FSM_sequential_ph[0]_i_1 
       (.I0(ph[1]),
        .I1(ph[0]),
        .I2(ph[2]),
        .I3(i),
        .I4(f),
        .I5(rst_n),
        .O(\FSM_sequential_ph[0]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair0" *) 
  LUT3 #(
    .INIT(8'h60)) 
    \FSM_sequential_ph[1]_i_1 
       (.I0(ph[1]),
        .I1(ph[0]),
        .I2(rst_n),
        .O(\FSM_sequential_ph[1]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair0" *) 
  LUT5 #(
    .INIT(32'h58780000)) 
    \FSM_sequential_ph[2]_i_1 
       (.I0(ph[1]),
        .I1(ph[0]),
        .I2(ph[2]),
        .I3(s),
        .I4(rst_n),
        .O(\FSM_sequential_ph[2]_i_1_n_0 ));
  (* FSM_ENCODED_STATES = "C_IDL:000,C_TRK:001,C_CLS:010,C_AVG:100,C_LIM:101,C_SBK:110,C_END:111,C_REG:011" *) 
  FDRE \FSM_sequential_ph_reg[0] 
       (.C(clk),
        .CE(1'b1),
        .D(\FSM_sequential_ph[0]_i_1_n_0 ),
        .Q(ph[0]),
        .R(1'b0));
  (* FSM_ENCODED_STATES = "C_IDL:000,C_TRK:001,C_CLS:010,C_AVG:100,C_LIM:101,C_SBK:110,C_END:111,C_REG:011" *) 
  FDRE \FSM_sequential_ph_reg[1] 
       (.C(clk),
        .CE(1'b1),
        .D(\FSM_sequential_ph[1]_i_1_n_0 ),
        .Q(ph[1]),
        .R(1'b0));
  (* FSM_ENCODED_STATES = "C_IDL:000,C_TRK:001,C_CLS:010,C_AVG:100,C_LIM:101,C_SBK:110,C_END:111,C_REG:011" *) 
  FDRE \FSM_sequential_ph_reg[2] 
       (.C(clk),
        .CE(1'b1),
        .D(\FSM_sequential_ph[2]_i_1_n_0 ),
        .Q(ph[2]),
        .R(1'b0));
  LUT3 #(
    .INIT(8'h02)) 
    avg_INST_0
       (.I0(ph[2]),
        .I1(ph[0]),
        .I2(ph[1]),
        .O(avg));
  LUT3 #(
    .INIT(8'h02)) 
    cls_INST_0
       (.I0(ph[1]),
        .I1(ph[0]),
        .I2(ph[2]),
        .O(cls));
  LUT3 #(
    .INIT(8'h80)) 
    cnt_INST_0
       (.I0(ph[1]),
        .I1(ph[0]),
        .I2(ph[2]),
        .O(cnt));
  LUT4 #(
    .INIT(16'h0010)) 
    ld_INST_0
       (.I0(ph[0]),
        .I1(ph[2]),
        .I2(i),
        .I3(ph[1]),
        .O(ld));
  LUT3 #(
    .INIT(8'h40)) 
    lim_INST_0
       (.I0(ph[1]),
        .I1(ph[0]),
        .I2(ph[2]),
        .O(lim));
  LUT3 #(
    .INIT(8'h40)) 
    rg_INST_0
       (.I0(ph[2]),
        .I1(ph[0]),
        .I2(ph[1]),
        .O(rg));
  LUT3 #(
    .INIT(8'h40)) 
    sbk_INST_0
       (.I0(ph[0]),
        .I1(ph[2]),
        .I2(ph[1]),
        .O(sbk));
  LUT3 #(
    .INIT(8'h02)) 
    trk_INST_0
       (.I0(ph[0]),
        .I1(ph[2]),
        .I2(ph[1]),
        .O(trk));
endmodule
`ifndef GLBL
`define GLBL
`timescale  1 ps / 1 ps

module glbl ();

    parameter ROC_WIDTH = 100000;
    parameter TOC_WIDTH = 0;
    parameter GRES_WIDTH = 10000;
    parameter GRES_START = 10000;

//--------   STARTUP Globals --------------
    wire GSR;
    wire GTS;
    wire GWE;
    wire PRLD;
    wire GRESTORE;
    tri1 p_up_tmp;
    tri (weak1, strong0) PLL_LOCKG = p_up_tmp;

    wire PROGB_GLBL;
    wire CCLKO_GLBL;
    wire FCSBO_GLBL;
    wire [3:0] DO_GLBL;
    wire [3:0] DI_GLBL;
   
    reg GSR_int;
    reg GTS_int;
    reg PRLD_int;
    reg GRESTORE_int;

//--------   JTAG Globals --------------
    wire JTAG_TDO_GLBL;
    wire JTAG_TCK_GLBL;
    wire JTAG_TDI_GLBL;
    wire JTAG_TMS_GLBL;
    wire JTAG_TRST_GLBL;

    reg JTAG_CAPTURE_GLBL;
    reg JTAG_RESET_GLBL;
    reg JTAG_SHIFT_GLBL;
    reg JTAG_UPDATE_GLBL;
    reg JTAG_RUNTEST_GLBL;

    reg JTAG_SEL1_GLBL = 0;
    reg JTAG_SEL2_GLBL = 0 ;
    reg JTAG_SEL3_GLBL = 0;
    reg JTAG_SEL4_GLBL = 0;

    reg JTAG_USER_TDO1_GLBL = 1'bz;
    reg JTAG_USER_TDO2_GLBL = 1'bz;
    reg JTAG_USER_TDO3_GLBL = 1'bz;
    reg JTAG_USER_TDO4_GLBL = 1'bz;

    assign (strong1, weak0) GSR = GSR_int;
    assign (strong1, weak0) GTS = GTS_int;
    assign (weak1, weak0) PRLD = PRLD_int;
    assign (strong1, weak0) GRESTORE = GRESTORE_int;

    initial begin
	GSR_int = 1'b1;
	PRLD_int = 1'b1;
	#(ROC_WIDTH)
	GSR_int = 1'b0;
	PRLD_int = 1'b0;
    end

    initial begin
	GTS_int = 1'b1;
	#(TOC_WIDTH)
	GTS_int = 1'b0;
    end

    initial begin 
	GRESTORE_int = 1'b0;
	#(GRES_START);
	GRESTORE_int = 1'b1;
	#(GRES_WIDTH);
	GRESTORE_int = 1'b0;
    end

endmodule
`endif
