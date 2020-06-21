#!/bin/bash

#	initialize variables
action=""
chrootdir=""

#	messages
e1="This script must be run as root"
e2="No arguments given, exiting."
e3="Directory to chroot into not set, exiting."
e4="Directory to chroot into does not exist, exiting."
e5="Conflicting options given - cannot setup and cleanup at the same time."
h1="-s: Setup chrooted environment\n-c: Clean (un-chroot) environment\n-d: Directory to chroot into.\n-h: Show help message."
m1="Setting up chroot..."
m2="Cleaning chrooted environment (umount)"

#	general usage and help information
usage() {
	echo "Usage: $0 [-s | -c] [-d /foo/chroot] [-h]"
	exit 1
}

help() {
	echo -e "$h1"
}

message() {
	echo "${!1}"
}

error() {
	echo "${!1}"
	usage
	exit 1
}

setup() {
	mount -t proc none "$chrootdir/proc"
	mount -o bind /dev "$chrootdir/dev"
	mount -o bind /dev/pts "$chrootdir/dev/pts"
	mount -o bind /sys "$chrootdir/sys"
	mount -o bind /tmp "$chrootdir/tmp"
	mount -o bind /var/db/repos "$chrootdir/var/db/repos"
	mount -o bind /var/cache/distfiles "$chrootdir/var/cache/distfiles"
	cp /etc/resolv.conf "$chrootdir/etc/resolv.conf"
	chroot "$chrootdir" /bin/bash
	exit 0
}

clean() {
	umount "$chrootdir/tmp"
	umount "$chrootdir/var/cache/distfiles"
	umount "$chrootdir/var/db/repos"
	umount "$chrootdir/var/tmp"
	umount "$chrootdir/dev/pts"
	umount "$chrootdir/run"
	umount "$chrootdir/dev"
	umount "$chrootdir/proc"
	umount "$chrootdir/sys/fs/cgroup/portage"
	umount "$chrootdir/sys/fs/cgroup"
	umount "$chrootdir/sys"
	exit 0
}

#	check if we are root
if [ $EUID -ne 0 ]; then
	error e1
fi

#	check if any options were given
if [ -z "$1" ]; then
	error e2
fi

#	check options
while getopts "cd:sh" o; do
	case "${o}" in
		d)
			chrootdir=${OPTARG}
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
			help
			;;
		*)
			usage
			;;
	esac
done

#	start appropriate routine
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
