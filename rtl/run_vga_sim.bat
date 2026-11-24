@echo off
rem P17 Phase 6 -- simulate the VGA sync timing.
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
cd /d "C:\Vivadoproject\P17_QRS_Pacemaker\rtl"
call xvlog vga_sync.v ecg_vga.v tb_vga_sync.v
if errorlevel 1 ( echo XVLOG_FAILED & exit /b 1 )
call xelab tb_vga_sync -s vga_sim -debug off
if errorlevel 1 ( echo XELAB_FAILED & exit /b 1 )
call xsim vga_sim -runall
echo XSIM_EXIT=%ERRORLEVEL%
