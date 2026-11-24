@echo off
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
cd /d "C:\Vivadoproject\P17_QRS_Pacemaker\vivado"
call vivado -mode batch -nojournal -nolog -source probe_board.tcl
