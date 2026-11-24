@echo off
rem P17 board phase -- Vitis HLS (C-sim, C-synth, export + impl) for Zybo Z7-10.
call "C:\AMDDesignTools\2025.2\2025.2\Vitis\settings64.bat"
set "XILINX_VIVADO=C:\AMDDesignTools\2025.2\Vivado"
cd /d "C:\Vivadoproject\P17_QRS_Pacemaker\hls"
if exist qrs_stream_hls rmdir /s /q qrs_stream_hls
if exist qrs_filter_z7 rmdir /s /q qrs_filter_z7
vitis-run --mode hls --tcl run_hls_z7.tcl
echo VITIS_RUN_EXIT=%ERRORLEVEL%
