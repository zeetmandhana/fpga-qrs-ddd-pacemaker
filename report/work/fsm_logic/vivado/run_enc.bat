@echo off
rem usage: run_enc.bat qd|ctrl
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
cd /d "%~dp0"
call vivado -mode batch -nojournal -log vivado_enc_%1.log -source run_enc.tcl -tclargs %1
echo ENC_EXIT=%ERRORLEVEL%
