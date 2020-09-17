# easy-chroot for gentoo installs
### A stressless Install over several days can take multiple chroots.  
Into the environment, out of the environment, good night - and the next day: different day, same procedure.  

This script helps to ease the process: By default, it automatically mounts the required direcories,
with respect to bind mounts, --make-rslave, /proc
The list can be easily extended to suit your needs.

By default it also copies /etc/resolv.conf to give you internet/network access.
The list of files to copy into the chroot can also be extended easliy for your case.

#### Any bugs, bad style or other ideas of improvement are welcome.
I'm not a professional programmer, but willing to improve

####Usage:
#### easy-chroot.sh
-s (as in setup):			Set up a chrooted environment  
-c (as in clean):			Clean a chrooted environment  
-d (as in directory):	Directory to chroot into or clean  
-h (as in help):      Show this help message
