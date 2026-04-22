database -open dump -shm
probe -create testbench.wrapper -depth all -all -shm -database dump
run
exit
