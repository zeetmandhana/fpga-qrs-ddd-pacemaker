@echo off
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
cd /d "C:\Vivadoproject\P17_QRS_Pacemaker\report\work\hand_hls\impl"
call vivado -mode batch -source impl.tcl -nojournal -log impl.log
echo VIVADO_EXIT=%ERRORLEVEL%
