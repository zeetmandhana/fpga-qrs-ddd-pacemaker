@echo off
rem P17 Phase 6 -- out-of-context synthesis of the DDD pacemaker RTL.
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
cd /d "C:\Vivadoproject\P17_QRS_Pacemaker\rtl"
call vivado -mode batch -source synth.tcl -nojournal -log ddd_synth.log
echo VIVADO_EXIT=%ERRORLEVEL%
