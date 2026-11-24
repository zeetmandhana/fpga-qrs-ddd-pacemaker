// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2025.2 (win64) Build 6299465 Fri Nov 14 19:35:11 GMT 2025
// Date        : Fri Nov 20 18:04:12 2026
// Host        : Zeet running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode funcsim
//               C:/Vivadoproject/P17_QRS_Pacemaker/report/work/fsm_logic/vivado/../sim_ctrl/net/net_one_hot.v
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

  wire \FSM_onehot_ph[1]_i_1_n_0 ;
  wire \FSM_onehot_ph[1]_i_2_n_0 ;
  wire \FSM_onehot_ph[1]_i_3_n_0 ;
  wire \FSM_onehot_ph[3]_i_1_n_0 ;
  wire \FSM_onehot_ph[6]_i_1_n_0 ;
  wire \FSM_onehot_ph[7]_i_1_n_0 ;
  wire \FSM_onehot_ph_reg_n_0_[0] ;
  wire avg;
  wire clk;
  wire cls;
  wire cnt;
  wire f;
  wire i;
  wire ld;
  wire lim;
  wire rg;
  wire rst_n;
  wire s;
  wire sbk;
  wire trk;

  LUT1 #(
    .INIT(2'h1)) 
    \FSM_onehot_ph[1]_i_1 
       (.I0(rst_n),
        .O(\FSM_onehot_ph[1]_i_1_n_0 ));
  LUT5 #(
    .INIT(32'hFFFFFFFE)) 
    \FSM_onehot_ph[1]_i_2 
       (.I0(lim),
        .I1(avg),
        .I2(cnt),
        .I3(sbk),
        .I4(\FSM_onehot_ph[1]_i_3_n_0 ),
        .O(\FSM_onehot_ph[1]_i_2_n_0 ));
  LUT5 #(
    .INIT(32'hFFFFFEEE)) 
    \FSM_onehot_ph[1]_i_3 
       (.I0(cls),
        .I1(rg),
        .I2(\FSM_onehot_ph_reg_n_0_[0] ),
        .I3(i),
        .I4(trk),
        .O(\FSM_onehot_ph[1]_i_3_n_0 ));
  LUT3 #(
    .INIT(8'hEA)) 
    \FSM_onehot_ph[3]_i_1 
       (.I0(cls),
        .I1(s),
        .I2(sbk),
        .O(\FSM_onehot_ph[3]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair0" *) 
  LUT2 #(
    .INIT(4'h2)) 
    \FSM_onehot_ph[6]_i_1 
       (.I0(lim),
        .I1(f),
        .O(\FSM_onehot_ph[6]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair0" *) 
  LUT4 #(
    .INIT(16'h8F88)) 
    \FSM_onehot_ph[7]_i_1 
       (.I0(f),
        .I1(lim),
        .I2(s),
        .I3(sbk),
        .O(\FSM_onehot_ph[7]_i_1_n_0 ));
  (* FSM_ENCODED_STATES = "C_IDL:00000001,C_TRK:00000010,C_CLS:00000100,C_AVG:00010000,C_LIM:00100000,C_SBK:01000000,C_END:10000000,C_REG:00001000" *) 
  FDSE #(
    .INIT(1'b1)) 
    \FSM_onehot_ph_reg[0] 
       (.C(clk),
        .CE(\FSM_onehot_ph[1]_i_2_n_0 ),
        .D(cnt),
        .Q(\FSM_onehot_ph_reg_n_0_[0] ),
        .S(\FSM_onehot_ph[1]_i_1_n_0 ));
  (* FSM_ENCODED_STATES = "C_IDL:00000001,C_TRK:00000010,C_CLS:00000100,C_AVG:00010000,C_LIM:00100000,C_SBK:01000000,C_END:10000000,C_REG:00001000" *) 
  FDRE #(
    .INIT(1'b0)) 
    \FSM_onehot_ph_reg[1] 
       (.C(clk),
        .CE(\FSM_onehot_ph[1]_i_2_n_0 ),
        .D(\FSM_onehot_ph_reg_n_0_[0] ),
        .Q(trk),
        .R(\FSM_onehot_ph[1]_i_1_n_0 ));
  (* FSM_ENCODED_STATES = "C_IDL:00000001,C_TRK:00000010,C_CLS:00000100,C_AVG:00010000,C_LIM:00100000,C_SBK:01000000,C_END:10000000,C_REG:00001000" *) 
  FDRE #(
    .INIT(1'b0)) 
    \FSM_onehot_ph_reg[2] 
       (.C(clk),
        .CE(\FSM_onehot_ph[1]_i_2_n_0 ),
        .D(trk),
        .Q(cls),
        .R(\FSM_onehot_ph[1]_i_1_n_0 ));
  (* FSM_ENCODED_STATES = "C_IDL:00000001,C_TRK:00000010,C_CLS:00000100,C_AVG:00010000,C_LIM:00100000,C_SBK:01000000,C_END:10000000,C_REG:00001000" *) 
  FDRE #(
    .INIT(1'b0)) 
    \FSM_onehot_ph_reg[3] 
       (.C(clk),
        .CE(\FSM_onehot_ph[1]_i_2_n_0 ),
        .D(\FSM_onehot_ph[3]_i_1_n_0 ),
        .Q(rg),
        .R(\FSM_onehot_ph[1]_i_1_n_0 ));
  (* FSM_ENCODED_STATES = "C_IDL:00000001,C_TRK:00000010,C_CLS:00000100,C_AVG:00010000,C_LIM:00100000,C_SBK:01000000,C_END:10000000,C_REG:00001000" *) 
  FDRE #(
    .INIT(1'b0)) 
    \FSM_onehot_ph_reg[4] 
       (.C(clk),
        .CE(\FSM_onehot_ph[1]_i_2_n_0 ),
        .D(rg),
        .Q(avg),
        .R(\FSM_onehot_ph[1]_i_1_n_0 ));
  (* FSM_ENCODED_STATES = "C_IDL:00000001,C_TRK:00000010,C_CLS:00000100,C_AVG:00010000,C_LIM:00100000,C_SBK:01000000,C_END:10000000,C_REG:00001000" *) 
  FDRE #(
    .INIT(1'b0)) 
    \FSM_onehot_ph_reg[5] 
       (.C(clk),
        .CE(\FSM_onehot_ph[1]_i_2_n_0 ),
        .D(avg),
        .Q(lim),
        .R(\FSM_onehot_ph[1]_i_1_n_0 ));
  (* FSM_ENCODED_STATES = "C_IDL:00000001,C_TRK:00000010,C_CLS:00000100,C_AVG:00010000,C_LIM:00100000,C_SBK:01000000,C_END:10000000,C_REG:00001000" *) 
  FDRE #(
    .INIT(1'b0)) 
    \FSM_onehot_ph_reg[6] 
       (.C(clk),
        .CE(\FSM_onehot_ph[1]_i_2_n_0 ),
        .D(\FSM_onehot_ph[6]_i_1_n_0 ),
        .Q(sbk),
        .R(\FSM_onehot_ph[1]_i_1_n_0 ));
  (* FSM_ENCODED_STATES = "C_IDL:00000001,C_TRK:00000010,C_CLS:00000100,C_AVG:00010000,C_LIM:00100000,C_SBK:01000000,C_END:10000000,C_REG:00001000" *) 
  FDRE #(
    .INIT(1'b0)) 
    \FSM_onehot_ph_reg[7] 
       (.C(clk),
        .CE(\FSM_onehot_ph[1]_i_2_n_0 ),
        .D(\FSM_onehot_ph[7]_i_1_n_0 ),
        .Q(cnt),
        .R(\FSM_onehot_ph[1]_i_1_n_0 ));
  LUT2 #(
    .INIT(4'h8)) 
    ld_INST_0
       (.I0(\FSM_onehot_ph_reg_n_0_[0] ),
        .I1(i),
        .O(ld));
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
