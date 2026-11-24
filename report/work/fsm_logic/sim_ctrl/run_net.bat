@echo off
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
cd /d "%~dp0"
call xvlog qd_ctrl_net_one_hot.v tb_qd_ctrl.v "C:\AMDDesignTools\2025.2\Vivado\data\verilog\src\glbl.v"
call xelab tb_qd_ctrl glbl -L unisims_ver -s tbnet_one_hot
call xsim tbnet_one_hot -runall
