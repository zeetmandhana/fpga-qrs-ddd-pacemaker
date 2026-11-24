@echo off
rem P17 board phase -- xsim: complete hardware QRS detector vs Python model.
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
cd /d "C:\Vivadoproject\P17_QRS_Pacemaker\rtl"
call xvlog hls_qrs_stream\qrs_stream.v hls_qrs_stream\qrs_stream_hpbuf_RAM_2P_LUTRAM_1R1W.v hls_qrs_stream\qrs_stream_lpbuf_RAM_2P_LUTRAM_1R1W.v hls_qrs_stream\qrs_stream_sqbuf_RAM_2P_LUTRAM_1R1W.v hls_qrs_stream\qrs_stream_xbuf_RAM_2P_LUTRAM_1R1W.v hls_qrs_stream\qrs_stream_mul_29s_29s_32_2_1.v qrs_decision.v qrs_detector.v tb_qrs_detector.v
call xelab tb_qrs_detector -s tb_det_snap -timescale 1ns/1ps
call xsim tb_det_snap -runall
echo SIM_EXIT=%ERRORLEVEL%
