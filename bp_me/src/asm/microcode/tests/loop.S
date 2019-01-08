#define N 10
movi 0 r0
movi N r1
loop_top: bge r0 r1 end
inc r0
bi loop_top
end: stall
