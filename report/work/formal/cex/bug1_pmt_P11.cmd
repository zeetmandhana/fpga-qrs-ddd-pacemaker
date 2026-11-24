set on_failure_script_quits
read_model -i ddd_pmt_bug1.smv
go
check_ctlspec -P P11
show_traces -p 4 -o cex/bug1_pmt_P11.xml
show_traces -p 1 -o cex/bug1_pmt_P11.txt
quit
