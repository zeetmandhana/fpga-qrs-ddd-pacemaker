@echo off
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
cd /d "C:\Vivadoproject\P17_QRS_Pacemaker\rtl\bd"
set R=C:\Vivadoproject\P17_QRS_Pacemaker\rtl
call xvlog %R%\ddd_pacemaker.v %R%\ddd_pacemaker_apb.v %R%\demo_ctrl_apb.v p17_axi_apb.v p17_bd_blocks.v tb_p17_axi_apb.v
call xelab tb_p17_axi_apb -s bridge_sim -debug off
call xsim bridge_sim -runall
