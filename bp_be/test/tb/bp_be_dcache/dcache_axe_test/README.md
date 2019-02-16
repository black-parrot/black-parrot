________  _________     _____  _________   ___ ______________
\______ \ \_   ___ \   /  _  \ \_   ___ \ /   |   \_   _____/
 |    |  \/    \  \/  /  /_\  \/    \  \//    ~    \    __)_ 
 |    `   \     \____/    |    \     \___\    Y    /        \
/_______  /\______  /\____|__  /\______  /\___|_  /_______  /
        \/        \/         \/        \/       \/        \/ 
   _____  ____  ______________                               
  /  _  \ \   \/  /\_   _____/                               
 /  /_\  \ \     /  |    __)_                                
/    |    \/     \  |        \                               
\____|__  /___/\  \/_______  /                               
        \/      \_/        \/                                
______________________ ____________________                  
\__    ___/\_   _____//   _____/\__    ___/                  
  |    |    |    __)_ \_____  \   |    |                     
  |    |    |        \/        \  |    |                     
  |____|   /_______  /_______  /  |____|                     
                   \/        \/    

- make sure that axe is installed, and 'axe' binary is in $PATH.
  - https://github.com/CTSRD-CHERI/axe

- Run "make" to run the simulation
  - "make NUM_LCE_P={2|4|8|16}" to vary the number of LCEs.

- After running "make", run "make axe" to run the axe test. 
  - it should print out "OK" at the end.
