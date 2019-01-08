#define N 10
movi 0 r0
movi N r1
do: inc r0
blt r0 r1 do
stall
