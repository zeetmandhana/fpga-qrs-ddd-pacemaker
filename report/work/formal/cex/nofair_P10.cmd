set on_failure_script_quits
read_model -i ddd_oa_nofair.smv
go
check_ctlspec -P P10
show_traces -p 4 -o cex/nofair_P10.xml
show_traces -p 1 -o cex/nofair_P10.txt
quit
