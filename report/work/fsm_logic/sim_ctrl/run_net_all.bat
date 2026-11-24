@echo off
rem simulate every post-synthesis netlist of qd_ctrl and compare its trace with the RTL trace
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
cd /d "%~dp0"
for %%V in (as_written auto sequential gray johnson one_hot custom_min) do (
  call xvlog net\net_%%V.v tb_qd_ctrl.v "C:\AMDDesignTools\2025.2\Vivado\data\verilog\src\glbl.v" >nul
  call xelab tb_qd_ctrl glbl -L unisims_ver -s tbn_%%V >nul
  call xsim tbn_%%V -runall >nul
  fc /b trace.txt trace_rtl.txt >nul && echo NETLIST %%V TRACE_EQUAL || echo NETLIST %%V TRACE_DIFFERS
)
