// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2025.2 (win64) Build 6299465 Fri Nov 14 19:35:11 GMT 2025
// Date        : Fri Nov 20 18:02:59 2026
// Host        : Zeet running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode funcsim
//               C:/Vivadoproject/P17_QRS_Pacemaker/report/work/fsm_logic/vivado/../sim_ctrl/net/net_johnson.v
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

  wire \FSM_johnson_ph[0]_i_1_n_0 ;
  wire \FSM_johnson_ph[1]_i_1_n_0 ;
  wire \FSM_johnson_ph[2]_i_1_n_0 ;
  wire \FSM_johnson_ph[3]_i_1_n_0 ;
  wire \FSM_johnson_ph[3]_i_2_n_0 ;
  wire \FSM_johnson_ph[3]_i_3_n_0 ;
  wire \FSM_johnson_ph_reg_n_0_[0] ;
  wire \FSM_johnson_ph_reg_n_0_[1] ;
  wire \FSM_johnson_ph_reg_n_0_[2] ;
  wire \FSM_johnson_ph_reg_n_0_[3] ;
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

  (* SOFT_HLUTNM = "soft_lutpair0" *) 
  LUT5 #(
    .INIT(32'h88808A80)) 
    \FSM_johnson_ph[0]_i_1 
       (.I0(\FSM_johnson_ph_reg_n_0_[1] ),
        .I1(\FSM_johnson_ph_reg_n_0_[2] ),
        .I2(\FSM_johnson_ph_reg_n_0_[3] ),
        .I3(\FSM_johnson_ph_reg_n_0_[0] ),
        .I4(s),
        .O(\FSM_johnson_ph[0]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'hCC74CC000000CC00)) 
    \FSM_johnson_ph[1]_i_1 
       (.I0(f),
        .I1(\FSM_johnson_ph_reg_n_0_[2] ),
        .I2(s),
        .I3(\FSM_johnson_ph_reg_n_0_[3] ),
        .I4(\FSM_johnson_ph_reg_n_0_[0] ),
        .I5(\FSM_johnson_ph_reg_n_0_[1] ),
        .O(\FSM_johnson_ph[1]_i_1_n_0 ));
  LUT5 #(
    .INIT(32'h84B080B0)) 
    \FSM_johnson_ph[2]_i_1 
       (.I0(\FSM_johnson_ph_reg_n_0_[2] ),
        .I1(\FSM_johnson_ph_reg_n_0_[1] ),
        .I2(\FSM_johnson_ph_reg_n_0_[3] ),
        .I3(\FSM_johnson_ph_reg_n_0_[0] ),
        .I4(s),
        .O(\FSM_johnson_ph[2]_i_1_n_0 ));
  LUT1 #(
    .INIT(2'h1)) 
    \FSM_johnson_ph[3]_i_1 
       (.I0(rst_n),
        .O(\FSM_johnson_ph[3]_i_1_n_0 ));
  LUT5 #(
    .INIT(32'hACAC3534)) 
    \FSM_johnson_ph[3]_i_2 
       (.I0(\FSM_johnson_ph_reg_n_0_[2] ),
        .I1(\FSM_johnson_ph_reg_n_0_[0] ),
        .I2(\FSM_johnson_ph_reg_n_0_[3] ),
        .I3(i),
        .I4(\FSM_johnson_ph_reg_n_0_[1] ),
        .O(\FSM_johnson_ph[3]_i_2_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair0" *) 
  LUT5 #(
    .INIT(32'h30083033)) 
    \FSM_johnson_ph[3]_i_3 
       (.I0(s),
        .I1(\FSM_johnson_ph_reg_n_0_[0] ),
        .I2(\FSM_johnson_ph_reg_n_0_[3] ),
        .I3(\FSM_johnson_ph_reg_n_0_[2] ),
        .I4(\FSM_johnson_ph_reg_n_0_[1] ),
        .O(\FSM_johnson_ph[3]_i_3_n_0 ));
  (* FSM_ENCODED_STATES = "C_IDL:0000,C_TRK:1000,C_CLS:1100,C_AVG:1111,C_LIM:0111,C_SBK:0011,C_END:0001,C_REG:1110" *) 
  FDRE \FSM_johnson_ph_reg[0] 
       (.C(clk),
        .CE(\FSM_johnson_ph[3]_i_2_n_0 ),
        .D(\FSM_johnson_ph[0]_i_1_n_0 ),
        .Q(\FSM_johnson_ph_reg_n_0_[0] ),
        .R(\FSM_johnson_ph[3]_i_1_n_0 ));
  (* FSM_ENCODED_STATES = "C_IDL:0000,C_TRK:1000,C_CLS:1100,C_AVG:1111,C_LIM:0111,C_SBK:0011,C_END:0001,C_REG:1110" *) 
  FDRE \FSM_johnson_ph_reg[1] 
       (.C(clk),
        .CE(\FSM_johnson_ph[3]_i_2_n_0 ),
        .D(\FSM_johnson_ph[1]_i_1_n_0 ),
        .Q(\FSM_johnson_ph_reg_n_0_[1] ),
        .R(\FSM_johnson_ph[3]_i_1_n_0 ));
  (* FSM_ENCODED_STATES = "C_IDL:0000,C_TRK:1000,C_CLS:1100,C_AVG:1111,C_LIM:0111,C_SBK:0011,C_END:0001,C_REG:1110" *) 
  FDRE \FSM_johnson_ph_reg[2] 
       (.C(clk),
        .CE(\FSM_johnson_ph[3]_i_2_n_0 ),
        .D(\FSM_johnson_ph[2]_i_1_n_0 ),
        .Q(\FSM_johnson_ph_reg_n_0_[2] ),
        .R(\FSM_johnson_ph[3]_i_1_n_0 ));
  (* FSM_ENCODED_STATES = "C_IDL:0000,C_TRK:1000,C_CLS:1100,C_AVG:1111,C_LIM:0111,C_SBK:0011,C_END:0001,C_REG:1110" *) 
  FDRE \FSM_johnson_ph_reg[3] 
       (.C(clk),
        .CE(\FSM_johnson_ph[3]_i_2_n_0 ),
        .D(\FSM_johnson_ph[3]_i_3_n_0 ),
        .Q(\FSM_johnson_ph_reg_n_0_[3] ),
        .R(\FSM_johnson_ph[3]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'h8000)) 
    avg_INST_0
       (.I0(\FSM_johnson_ph_reg_n_0_[3] ),
        .I1(\FSM_johnson_ph_reg_n_0_[2] ),
        .I2(\FSM_johnson_ph_reg_n_0_[0] ),
        .I3(\FSM_johnson_ph_reg_n_0_[1] ),
        .O(avg));
  LUT4 #(
    .INIT(16'h1000)) 
    cls_INST_0
       (.I0(\FSM_johnson_ph_reg_n_0_[0] ),
        .I1(\FSM_johnson_ph_reg_n_0_[1] ),
        .I2(\FSM_johnson_ph_reg_n_0_[3] ),
        .I3(\FSM_johnson_ph_reg_n_0_[2] ),
        .O(cls));
  LUT4 #(
    .INIT(16'h0010)) 
    cnt_INST_0
       (.I0(\FSM_johnson_ph_reg_n_0_[3] ),
        .I1(\FSM_johnson_ph_reg_n_0_[2] ),
        .I2(\FSM_johnson_ph_reg_n_0_[0] ),
        .I3(\FSM_johnson_ph_reg_n_0_[1] ),
        .O(cnt));
  LUT5 #(
    .INIT(32'h00000002)) 
    ld_INST_0
       (.I0(i),
        .I1(\FSM_johnson_ph_reg_n_0_[2] ),
        .I2(\FSM_johnson_ph_reg_n_0_[1] ),
        .I3(\FSM_johnson_ph_reg_n_0_[3] ),
        .I4(\FSM_johnson_ph_reg_n_0_[0] ),
        .O(ld));
  LUT4 #(
    .INIT(16'h2000)) 
    lim_INST_0
       (.I0(\FSM_johnson_ph_reg_n_0_[2] ),
        .I1(\FSM_johnson_ph_reg_n_0_[3] ),
        .I2(\FSM_johnson_ph_reg_n_0_[0] ),
        .I3(\FSM_johnson_ph_reg_n_0_[1] ),
        .O(lim));
  LUT4 #(
    .INIT(16'h2000)) 
    rg_INST_0
       (.I0(\FSM_johnson_ph_reg_n_0_[2] ),
        .I1(\FSM_johnson_ph_reg_n_0_[0] ),
        .I2(\FSM_johnson_ph_reg_n_0_[3] ),
        .I3(\FSM_johnson_ph_reg_n_0_[1] ),
        .O(rg));
  LUT4 #(
    .INIT(16'h1000)) 
    sbk_INST_0
       (.I0(\FSM_johnson_ph_reg_n_0_[3] ),
        .I1(\FSM_johnson_ph_reg_n_0_[2] ),
        .I2(\FSM_johnson_ph_reg_n_0_[0] ),
        .I3(\FSM_johnson_ph_reg_n_0_[1] ),
        .O(sbk));
  LUT4 #(
    .INIT(16'h0010)) 
    trk_INST_0
       (.I0(\FSM_johnson_ph_reg_n_0_[0] ),
        .I1(\FSM_johnson_ph_reg_n_0_[2] ),
        .I2(\FSM_johnson_ph_reg_n_0_[3] ),
        .I3(\FSM_johnson_ph_reg_n_0_[1] ),
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
