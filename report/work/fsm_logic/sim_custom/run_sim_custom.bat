@echo off
rem bit-exact detector testbench (records 100 and 208) with the CUSTOM-encoded qrs_decision FSM
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
cd /d "%~dp0"
set R=C:\Vivadoproject\P17_QRS_Pacemaker\rtl
call xvlog %R%\hls_qrs_stream\qrs_stream.v %R%\hls_qrs_stream\qrs_stream_hpbuf_RAM_2P_LUTRAM_1R1W.v %R%\hls_qrs_stream\qrs_stream_lpbuf_RAM_2P_LUTRAM_1R1W.v %R%\hls_qrs_stream\qrs_stream_sqbuf_RAM_2P_LUTRAM_1R1W.v %R%\hls_qrs_stream\qrs_stream_xbuf_RAM_2P_LUTRAM_1R1W.v %R%\hls_qrs_stream\qrs_stream_mul_29s_29s_32_2_1.v qrs_decision.v %R%\qrs_detector.v %R%\tb_qrs_detector.v
call xelab tb_qrs_detector -s tb_det_custom -timescale 1ns/1ps
call xsim tb_det_custom -runall
echo SIM_EXIT=%ERRORLEVEL%
