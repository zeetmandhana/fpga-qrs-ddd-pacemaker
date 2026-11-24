@echo off
rem P17 Phase 4 -- launch Vitis HLS (C-sim + C-synth) for the filter chain.
call "C:\AMDDesignTools\2025.2\2025.2\Vitis\settings64.bat"
rem point HLS at the Vivado part database (Artix-7 etc.)
set "XILINX_VIVADO=C:\AMDDesignTools\2025.2\Vivado"
cd /d "C:\Vivadoproject\P17_QRS_Pacemaker\hls"
if exist qrs_filter_hls rmdir /s /q qrs_filter_hls
vitis-run --mode hls --tcl run_hls.tcl
echo VITIS_RUN_EXIT=%ERRORLEVEL%
