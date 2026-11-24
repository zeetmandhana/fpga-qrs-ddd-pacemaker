@echo off
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
cd /d "C:\Vivadoproject\P17_QRS_Pacemaker\report\work\sim"
call xcrg -cc_db rand_cov -cc_dir ./cov/xsim.codeCov -report_format text -report_dir ./cov_rpt
