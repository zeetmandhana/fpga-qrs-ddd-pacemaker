@echo off
call "C:\Vivadoproject\P17_QRS_Pacemaker\tools\oss-cad-suite\environment.bat"
cd /d "%~dp0"
yosys -V
yosys -q -l yosys_ep.log ep_gates.ys
yosys-abc -f ep_abc.script > abc_ep.log 2>&1
echo YOSYS_DONE
