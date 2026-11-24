@echo off
rem P17 -- create the Vivado project, run its simulations and synthesis (batch).
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
cd /d "C:\Vivadoproject\P17_QRS_Pacemaker\vivado"
call vivado -mode batch -source build_project.tcl -nojournal -log build_project.log
echo VIVADO_EXIT=%ERRORLEVEL%
