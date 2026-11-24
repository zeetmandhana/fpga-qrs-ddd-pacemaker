@echo off
rem P17 Phase 6 -- compile + simulate the DDD pacemaker RTL in Vivado xsim.
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
cd /d "C:\Vivadoproject\P17_QRS_Pacemaker\rtl"
if exist xsim.dir rmdir /s /q xsim.dir
del /q webtalk*.jou webtalk*.log xvlog*.log xelab*.log xsim*.log 2>nul
call xvlog ddd_pacemaker.v ddd_pacemaker_apb.v tb_ddd_pacemaker.v
if errorlevel 1 ( echo XVLOG_FAILED & exit /b 1 )
call xelab tb_ddd_pacemaker -s tb_sim -debug off
if errorlevel 1 ( echo XELAB_FAILED & exit /b 1 )
call xsim tb_sim -runall
echo XSIM_EXIT=%ERRORLEVEL%
