#!/bin/bash

#initialize variables
action=""
chrootdir=""

#proc mountpoint(s)
proc_mounts=(
	/proc
)

#bind mountpoints
bind_mounts=(
	/dev
	/dev/pts
	/sys
	/var/db/repos/gentoo
	/var/cache/binpkgs
	/var/cache/distfiles
	/usr/src/linux
	/lib/modules
	/var/tmp/portage
	/tmp
)

#create reverse array of mountpoints for unmounting later on
	min=0
	max=$(( ${#bind_mounts[@]} -1 ))

	while [[ min -lt max ]]
	do
		# Swap current first and last elements
		x="${bind_mounts[$min]}"
		bind_mounts_r[$min]="${bind_mounts[$max]}"
		bind_mounts_r[$max]="$x"

		# Move closer
		(( min++, max-- ))
	done

#files to copy
file_copy=(
	/etc/resolv.conf
)


#messages
e1="This script must be run as root"
e2="No arguments given, exiting."
e3="Directory to chroot into not set, exiting."
e4="Directory to chroot into does not exist, exiting."
e5="Conflicting options given - cannot setup and cleanup at the same time."
e6="Error mounting"
e7="Directory does not exist: "
e8=" error unmounting, continuing."
e9=" User abort."
e10="Error copying"
h1="-s: Setup chrooted environment\n-c: Clean (un-chroot) environment\n-d: Directory to chroot into.\n-h: Show help message."
m1="Setting up chroot..."
m2="Cleaning chrooted environment (umount)"
m3=" successfully mounted."
m4=" successfully unmounted."
m5=" successfully copied."
m6="Usage: $0 [-s | -c] [-d /foo/chroot] [-h]"

#general usage and help information
message() {
	echo -e "${!1}"
}

error() {
	echo "${!1}" "${2}"
	exit 1
}

checkfail() {
	if [ $1 -ne 0 ]; then
		echo -ne "${chrootdir}${2}:"
		error "${3}"
	else
		echo -ne "${chrootdir}${2}:"
		message "${4}"
	fi
}

checkdir() {
	if [ ! -d "$1" ]; then
		error e7 "$1"
		exit 1
	fi
}

setup() {
	yesno=""
	
	for i in ${proc_mounts[@]}; do
		checkdir "${chrootdir}${i}"
		mount -t proc "none" "${chrootdir}${i}"
		checkfail_mount "$?" "$i" "e6" "m3"
	done

	for i in ${bind_mounts[@]}; do
		checkdir "${chrootdir}${i}"
		mount -o bind "${i}" "${chrootdir}${i}"
		checkfail_mount "$?" "$i" "e6" "m3"
	done
	
	for i in ${file_copy[@]}; do
		checkdir "${chrootdir}$(dirname ${i})"
		echo cp -d "${i}" "${chrootdir}${i}"
		checkfail "$?" "$i" "e10" "m5"
	done

	read  -n1 -s -p "Chroot into ${chrootdir}? [y/n]" yesno
	if [ "${yesno,,}" != "y" ] ; then
		error e9
	else
		chroot "$chrootdir" /bin/bash
	fi
	exit 0
}

clean() {
	for i in ${bind_mounts_r[@]}; do
		umount "${chrootdir}${i}"
#		checkfail "$?" "$i" "e8" "m4"
	done

	for i in ${proc_mounts[@]}; do
		umount "${chrootdir}${i}"
#		checkfail "$?" "$i" "e8" "m4"
	done
	exit 0
}

#check if we are root
if [ $EUID -ne 0 ]; then
	error e1
fi

#check if any options were given
if [ -z "$1" ]; then
	error e2
fi

#check options
while getopts "cd:sh" o; do
	case "${o}" in
		d)	#	%/ removes trailing slash
			chrootdir=${OPTARG%/}
			if [ ! -d "$chrootdir" ]; then
				error e4
			fi
			;;
		s)
			action="setup"
			;;
		c)
			if [ -z "$action" ]; then
				action="clean"
			else
				error e5
			fi
			;;
		h)
			message h1
			;;
		*)
			message m6
			exit 1
			;;
	esac
done

#start appropriate routine
case "$action" in
	setup)
		message m1
		setup
		;;
	clean)
		message m2
		clean
		;;
esac
