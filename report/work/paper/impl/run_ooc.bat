@echo off
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
cd /d "C:\Vivadoproject\P17_QRS_Pacemaker\report\work\paper\impl"
call vivado -mode batch -nojournal -nolog -source ooc_three.tcl
