@echo off
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
cd /d "%~dp0"
call vivado -mode batch -nojournal -log vivado_inspect.log -source inspect_ff.tcl
