@echo off
rem Replay the NuSMV counterexamples on the RTL (mutated copies + the original),
rem and run the PMT closed loop (same heart as the NuSMV pmt model) on both.
call C:\AMDDesignTools\2025.2\Vivado\settings64.bat
set R=C:\Vivadoproject\P17_QRS_Pacemaker\report\work\formal\replay
set RTL=C:\Vivadoproject\P17_QRS_Pacemaker\rtl

for %%D in (ddd_pacemaker_bug1 ddd_pacemaker_bug2 ddd_pacemaker) do (
  if not exist %R%\sim_%%D mkdir %R%\sim_%%D
)

cd /d %R%\sim_ddd_pacemaker_bug1
call xvlog %R%\ddd_pacemaker_bug1.v %R%\tb_replay_ddd_pacemaker_bug1.v %R%\tb_pmt_closed_ddd_pacemaker_bug1.v > comp_out.txt 2>&1
call xelab tb_replay -s snap >> comp_out.txt 2>&1
call xelab tb_pmt_closed -s snap_closed >> comp_out.txt 2>&1
cd /d %R%\sim_ddd_pacemaker_bug2
call xvlog %R%\ddd_pacemaker_bug2.v %R%\tb_replay_ddd_pacemaker_bug2.v > comp_out.txt 2>&1
call xelab tb_replay -s snap >> comp_out.txt 2>&1
cd /d %R%\sim_ddd_pacemaker
call xvlog %RTL%\ddd_pacemaker.v %R%\tb_replay_ddd_pacemaker.v %R%\tb_pmt_closed_ddd_pacemaker.v > comp_out.txt 2>&1
call xelab tb_replay -s snap >> comp_out.txt 2>&1
call xelab tb_pmt_closed -s snap_closed >> comp_out.txt 2>&1

call :run ddd_pacemaker_bug1 bug1_pmt_P11 bug1
call :run ddd_pacemaker_bug1 bug1_oa_P3   bug1
call :run ddd_pacemaker_bug2 bug2_oa_P4   bug2
call :run ddd_pacemaker      bug1_pmt_P11 original
call :run ddd_pacemaker      bug1_oa_P3   original
call :run ddd_pacemaker      bug2_oa_P4   original

cd /d %R%\sim_ddd_pacemaker_bug1
call xsim snap_closed -runall > %R%\closed_pmt_bug1.log 2>&1
cd /d %R%\sim_ddd_pacemaker
call xsim snap_closed -runall > %R%\closed_pmt_original.log 2>&1
echo REPLAY DONE
goto :eof

:run
cd /d %R%\sim_%1
copy /y %R%\stim_%2.txt stim.txt > nul
call xsim snap -runall > %R%\replay_%2_on_%3.log 2>&1
goto :eof
