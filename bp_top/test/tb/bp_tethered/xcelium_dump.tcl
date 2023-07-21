database -open dump -shm
probe -create testbench.wrapper.processor -depth all -all -shm -database dump
run
exit
