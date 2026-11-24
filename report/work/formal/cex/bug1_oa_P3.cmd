set on_failure_script_quits
read_model -i ddd_oa_bug1.smv
go
check_ctlspec -P P3
show_traces -p 4 -o cex/bug1_oa_P3.xml
show_traces -p 1 -o cex/bug1_oa_P3.txt
quit
