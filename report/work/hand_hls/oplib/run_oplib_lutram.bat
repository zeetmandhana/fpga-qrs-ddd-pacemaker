@echo off
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
cd /d "C:\Vivadoproject\P17_QRS_Pacemaker\report\work\hand_hls\oplib"
call vivado -mode batch -source oplib_lutram.tcl -nojournal -log oplib_lutram.log
echo VIVADO_EXIT=%ERRORLEVEL%
