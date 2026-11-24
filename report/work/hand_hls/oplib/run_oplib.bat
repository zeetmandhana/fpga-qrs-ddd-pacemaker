@echo off
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
cd /d "C:\Vivadoproject\P17_QRS_Pacemaker\report\work\hand_hls\oplib"
call vivado -mode batch -source oplib.tcl -nojournal -log oplib.log
echo VIVADO_EXIT=%ERRORLEVEL%
