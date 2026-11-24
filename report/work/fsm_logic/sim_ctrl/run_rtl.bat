@echo off
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
cd /d "%~dp0"
call xvlog ..\vivado\qd_ctrl.v tb_qd_ctrl.v
call xelab tb_qd_ctrl -s tbq
call xsim tbq -runall
copy /y trace.txt trace_rtl.txt >nul
