@echo off
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
cd /d "C:\Vivadoproject\P17_QRS_Pacemaker\report\work\paper\tb"
set H=C:\Vivadoproject\P17_QRS_Pacemaker\rtl\hls_qrs_stream
call xvlog %H%\qrs_stream.v %H%\qrs_stream_hpbuf_RAM_2P_LUTRAM_1R1W.v %H%\qrs_stream_lpbuf_RAM_2P_LUTRAM_1R1W.v %H%\qrs_stream_sqbuf_RAM_2P_LUTRAM_1R1W.v %H%\qrs_stream_xbuf_RAM_2P_LUTRAM_1R1W.v %H%\qrs_stream_mul_29s_29s_32_2_1.v ..\rtl\qrs_baselines.v ..\rtl\tb_qrs_baselines.v
call xelab tb_qrs_baselines -s tb_base_snap -timescale 1ns/1ps
call xsim tb_base_snap -runall
