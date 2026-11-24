@echo off
rem xsim: both hand-written FSMDs vs the Python golden model (20,000 samples, record 100)
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
cd /d "C:\Vivadoproject\P17_QRS_Pacemaker\report\work\hand_hls\sim"
call xvlog ..\rtl\qrs_fsmd_area.v ..\rtl\qrs_fsmd_lat.v tbA.v
call xelab tb_fsmd -s snapA -timescale 1ns/1ps
call xsim snapA -runall
call xvlog tbB.v
call xelab tb_fsmd -s snapB -timescale 1ns/1ps
call xsim snapB -runall
echo SIM_EXIT=%ERRORLEVEL%
