vlib work
vlog MemoryController.sv +acc
vsim work.MemoryController +debug=0 +TraceFile=t13.trace  +outputfilename=t13.out
run -all
quit -sim