set on_failure_script_quits
read_model -i ddd_oa_bug2.smv
go
check_ctlspec -P P4
show_traces -p 4 -o cex/bug2_oa_P4.xml
show_traces -p 1 -o cex/bug2_oa_P4.txt
quit
