@echo off
rem TA demo: SymbiYosys k-induction proof of the fixed RTL (16-bit, firmware ranges)
rem and the failing check on the pre-fix copy (start-up LRI bug).
call "C:\Vivadoproject\P17_QRS_Pacemaker\tools\oss-cad-suite\environment.bat"
cd /d "C:\Vivadoproject\P17_QRS_Pacemaker\report\work\formal\sby"
sby -f ddd.sby prove16 before_fix
