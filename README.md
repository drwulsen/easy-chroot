# easy-chroot for gentoo installs
## A stressless Install over several days can take multiple chroots.  
Into the environment, out of the environment, good night - and the next day: different day, same procedure.  

This script helps to ease the process: It automatically bind mounts the required direcories and /proc,  
it copies resolv.conf by default and asks if you want to chroot before executing it.

## Usage:  
### easy-chroot.sh
-s (as in setup):			Set up a chrooted environment  
-c (as in clean):			Clean a chrooted environment  
-d (as in directory):	Directory to chroot into or clean 
