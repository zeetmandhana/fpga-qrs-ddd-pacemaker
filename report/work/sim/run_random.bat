@echo off
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
cd /d "C:\Vivadoproject\P17_QRS_Pacemaker\report\work\sim"
set R=C:\Vivadoproject\P17_QRS_Pacemaker\rtl
call xvlog %R%\ddd_pacemaker.v %R%\ddd_pacemaker_apb.v
call xvlog -sv ddd_sva.sv tb_ddd_random.sv
call xelab tb_ddd_random -s tb_rand_snap -timescale 1ns/1ps -cc_type sbct -cov_db_name rand_cov -cov_db_dir ./cov
call xsim tb_rand_snap -runall -cov_db_name rand_cov -cov_db_dir ./cov
call xcrg -cc_db rand_cov -cc_dir ./cov/xsim.codecov -report_format text -report_dir ./cov_rpt
