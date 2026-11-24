@echo off
rem P17 Phase 6 -- exhaustive sim of the event-priority block.
call "C:\AMDDesignTools\2025.2\Vivado\settings64.bat"
cd /d "C:\Vivadoproject\P17_QRS_Pacemaker\rtl"
call xvlog event_priority.v tb_event_priority.v
if errorlevel 1 ( echo XVLOG_FAILED & exit /b 1 )
call xelab tb_event_priority -s ev_sim -debug off
if errorlevel 1 ( echo XELAB_FAILED & exit /b 1 )
call xsim ev_sim -runall
echo XSIM_EXIT=%ERRORLEVEL%
