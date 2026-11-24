@echo off
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
cd /d "C:\Vivadoproject\P17_QRS_Pacemaker\vivado"
call vivado -mode batch -nojournal -log rebuild_fixed.log -source rebuild_fixed.tcl
