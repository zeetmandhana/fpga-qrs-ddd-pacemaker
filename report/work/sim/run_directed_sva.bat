@echo off
rem Directed DDD testbenches re-run with the 19 SVA assertions bound (ddd_sva.sv compiled with each TB)
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
mkdir "C:\Vivadoproject\P17_QRS_Pacemaker\report\work\sim\dir_sva" 2>nul
cd /d "C:\Vivadoproject\P17_QRS_Pacemaker\report\work\sim\dir_sva"
set R=C:\Vivadoproject\P17_QRS_Pacemaker\rtl
call xvlog -sv %R%\ddd_pacemaker.v %R%\ddd_pacemaker_apb.v %R%\tb_ddd_pacemaker.v ..\ddd_sva.sv
call xelab tb_ddd_pacemaker -s dir_sva_snap -timescale 1ns/1ps
call xsim dir_sva_snap -runall
call xvlog -sv %R%\ddd_pacemaker.v %R%\ddd_pacemaker_apb.v %R%\heart_model.v %R%\tb_closed_loop.v ..\ddd_sva.sv
call xelab tb_closed_loop -s cl_sva_snap -timescale 1ns/1ps
call xsim cl_sva_snap -runall
