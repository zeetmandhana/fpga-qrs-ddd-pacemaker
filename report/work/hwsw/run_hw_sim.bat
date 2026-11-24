@echo off
rem HW side: cycles per sample of the on-chip detector (HLS qrs_stream + RTL qrs_decision) in xsim.
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
if not exist "%~dp0hw_sim" mkdir "%~dp0hw_sim"
cd /d "%~dp0hw_sim"
set "R=..\..\..\..\rtl"
call xvlog %R%\hls_qrs_stream\qrs_stream.v %R%\hls_qrs_stream\qrs_stream_hpbuf_RAM_2P_LUTRAM_1R1W.v %R%\hls_qrs_stream\qrs_stream_lpbuf_RAM_2P_LUTRAM_1R1W.v %R%\hls_qrs_stream\qrs_stream_sqbuf_RAM_2P_LUTRAM_1R1W.v %R%\hls_qrs_stream\qrs_stream_xbuf_RAM_2P_LUTRAM_1R1W.v %R%\hls_qrs_stream\qrs_stream_mul_29s_29s_32_2_1.v %R%\qrs_decision.v %R%\qrs_detector.v ..\tb_hw_cycles.v
call xelab tb_hw_cycles -s tb_hwcyc_snap -timescale 1ns/1ps
call xsim tb_hwcyc_snap -runall
echo SIM_EXIT=%ERRORLEVEL%
