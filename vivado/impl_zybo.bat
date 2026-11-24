@echo off
rem P17 -- batch synth + impl + power + bitstream for the Zybo Z7-10 design.
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
cd /d "C:\Vivadoproject\P17_QRS_Pacemaker\vivado"
call vivado -mode batch -source impl_zybo.tcl -nojournal -log impl_zybo.log
echo VIVADO_EXIT=%ERRORLEVEL%
