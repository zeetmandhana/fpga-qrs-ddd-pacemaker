@echo off
rem P17 Phase 6 -- synthesize the full demo top (build check + resources).
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
cd /d "C:\Vivadoproject\P17_QRS_Pacemaker\rtl"
call vivado -mode batch -source synth_top.tcl -nojournal -log top_synth.log
echo VIVADO_EXIT=%ERRORLEVEL%
