```
 ________  ________  ________  ________  ___  ___  _______      
|\   ___ \|\   ____\|\   __  \|\   ____\|\  \|\  \|\  ___ \     
\ \  \_|\ \ \  \___|\ \  \|\  \ \  \___|\ \  \\\  \ \   __/|    
 \ \  \ \\ \ \  \    \ \   __  \ \  \    \ \   __  \ \  \_|/__  
  \ \  \_\\ \ \  \____\ \  \ \  \ \  \____\ \  \ \  \ \  \_|\ \ 
   \ \_______\ \_______\ \__\ \__\ \_______\ \__\ \__\ \_______\
    \|_______|\|_______|\|__|\|__|\|_______|\|__|\|__|\|_______|
                                                                
 ________     ___    ___ _______                                
|\   __  \   |\  \  /  /|\  ___ \                               
\ \  \|\  \  \ \  \/  / | \   __/|                              
 \ \   __  \  \ \    / / \ \  \_|/__                            
  \ \  \ \  \  /     \/   \ \  \_|\ \                           
   \ \__\ \__\/  /\   \    \ \_______\                          
    \|__|\|__/__/ /\ __\    \|_______|                          
             |__|/ \|__|                                        
 _________  _______   ________  _________                       
|\___   ___\\  ___ \ |\   ____\|\___   ___\                     
\|___ \  \_\ \   __/|\ \  \___|\|___ \  \_|                     
     \ \  \ \ \  \_|/_\ \_____  \   \ \  \                      
      \ \  \ \ \  \_|\ \|____|\  \   \ \  \                     
       \ \__\ \ \_______\____\_\  \   \ \__\                    
        \|__|  \|_______|\_________\   \|__|                    
                        \|_________|                    
```

- make sure that axe is installed, and `axe` binary is in $PATH.
  - https://github.com/CTSRD-CHERI/axe

- Run `make` to run the simulation
  - `make NUM_LCE_P={2|4|8|16}` to vary the number of LCEs.
  - optionally, `make SEED_P=123` to set the random seed. By default, system clock is used for seed.
  - optionally, `make NUM_INSTR_P=5000` to set the number of instruction for each cache. By default, it is set to be 10000.

- After running `make`, run `make axe` to run the axe test. 
  - it should print out "OK" at the end.
  - it creates "trace.axe" file, which has all the traces from the simulation.
