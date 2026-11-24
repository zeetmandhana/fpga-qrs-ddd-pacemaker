@echo off
rem P17 board phase -- xsim: hardware closed loop (heart model + DDD) vs Python.
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
cd /d "C:\Vivadoproject\P17_QRS_Pacemaker\rtl"
call xvlog ddd_pacemaker.v ddd_pacemaker_apb.v heart_model.v tb_closed_loop.v
call xelab tb_closed_loop -s tb_cl_snap -timescale 1ns/1ps
call xsim tb_cl_snap -runall
echo SIM_EXIT=%ERRORLEVEL%
