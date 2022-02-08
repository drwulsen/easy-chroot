#!/bin/bash

#initialize variables
action=""
chrootdir="Directory not specified"

##messages
#errors
e_empty=""
e_mount_1="Source mount directory does not exist:"
e_mount_2="Target mountpoint does not exist:"
e_mount_3="--make-r* requested, for it, but nothing is mounted under:"
e_mount_4="There is already something mounted under:"
e_perm_1="This script must be run as root"
e_arg_1="No arguments given, exiting."
e_arg_2="Conflicting arguments given (clean and setup at the same time), exiting."
e_arg_3="Unknown argument given:"
e_dir_1="Directory to chroot into not set or does not exist:"
e_sub_1="Subroutine error:"
e_user_1="User abort"
e_file_1="File to copy does not exist:"
e_file_2="Error copying file:"
#status
m_action_setup_1="Setting up chroot..."
m_action_clean_1="Cleaning chrooted environment (umount)..."
#help
m_usage_1="Usage: $0 [-s | -c | -h] -d /foo/chroot\n-s: Setup chrooted environment\n-c: Clean (un-chroot) environment\n-d: Directory to chroot into.\n-h: Show this help message."
#custom
i_cust_1="Custom command called: "
i_cust_2="Custom command failed: "

#check if we are root
if [[ $EUID -ne 0 ]]; then
	error "e_perm_1"
fi

#check if any options were given
if [[ -z "$1" ]]; then
	error "e_arg_1"
fi

#check options
#	{%/} removes trailing slash
while getopts ":cd:sh" o; do
	case "${o}" in
		c)
			action="clean"
			;;
		d)
			chrootdir=${OPTARG%/}
			;;
		s)
			if [[ -z "$action" ]]; then
				action="setup"
			else
				error "e_arg_2"
			fi
			;;
		h)
			message "m_usage_1"
			;;
		:)
			error "e_empty" "option -$OPTARG requires an argument"
			;;
		*)
			message "m_usage_1"
			error "e_arg_3" "option \"-$OPTARG\" does not exist."
			exit 1
			;;
	esac
done
shift "$((OPTIND-1))"

#mountpoints in order of mounting, comma-separated mount option. One option per line
#--bind and --make-rslave for example have to be two consecutive lines
#Use double quotes for safety
#gentoo documentation says, that /usr/src/linux and /lib/modules should be included
#i don't do that, as i use it for an install and need a clean kernel directory for my fresh system
mountpoints=(
	"/proc,types=proc"
	"/dev,rbind"
	"/dev,make-rslave"
	"/sys,rbind"
	"/sys,make-rslave"
	"/var/db/repos/gentoo,rbind"
	"/tmp,rbind"
	"/var/tmp,rbind"
	"/var/tmp/portage,type=tmpfs"
	"/run,rbind"
	"run,make-rslave"
	)


#files to copy, will be copied to the chroot-prefixed path
file_copy=(
	"/etc/resolv.conf"
)

#arbitrary custom commands to run before chrooting
#there is no safety net!
custcommands=(
	"mount -o rbind /mnt/data/portage/distfiles/ ${chrootdir}/var/cache/distfiles"
	)

#write a message, ${!1} allows us to pass variable names
#for example, "e_arg_1" will print the value of variable "e_arg_1"
message() {
	echo -e "${!1} ${2} ${3}"
}

#throw an error message and exit
error() {
	echo -ne "\nERROR: "
	message "$1" "$2"
	exit 1
}

#check for and in case of errors, exit
#"$1" is the return code handed over from the caller, "$2" an additional message to print.
checkfail() {
	if [[ "$1" -ne 0 ]]; then
		error "e_sub_1" "$2"
	fi
}

#check directories and if desired, ask to create them
#invocation: checkdir "directory" "message" "ask to create (has to be "y")"
checkdir() {
	yesno=""
	message="$2"
	if [[ ! -d "$1" ]] && [[ "$3" == "y" ]]; then
		message "$message" "$1"
		read  -n1 -s -p "Create ${1}? [y/n]" yesno
		echo ''
		if [[ "${yesno,,}" != "y" ]] ; then
			error "$message" "$1"
			exit 1
		else
			mkdir -p "$1"
			checkfail "$?" "mkdir -p $1"
		fi
	fi
}

#mount specified directories and devices into the chroot-prefixed path
#checks the specified source and target do exist, source missing = error, target missing = ask to create
#checks nothing is already mounted under the target for normal and bind mounts.
#checks if --make-r* is requested, something IS mounted under the target
chrootmount() {
	for i in "${mountpoints[@]}"; do
		mountsrc_=$(echo "$i" | cut -d ',' -f 1)
		mountsrc="${mountsrc_%/}"
		mountpoint="${chrootdir}${mountsrc}"
		mountopts=$(echo "$i" | cut -d ',' -f 2)
#check for --make-r* mounts
		if [[ ! "$mountopts" =~ make-r.* ]]; then
			checkdir "$mountsrc" "e_mount_1" "n"
			checkdir "$mountpoint" "e_mount_2" "y"
#check for directory to not be taken by another mount already
			grep -q "$mountpoint" "/proc/mounts"
			if [[ "$?" != 0 ]]; then
				mount "--${mountopts}" "$mountsrc" "$mountpoint"
				checkfail "$?" "mount --${mountopts} $mountsrc $mountpoint"
			else
				error "e_mount_4" "$mountpoint"
			fi
		else
#check for something to be mounted in case of a --make-r* mount
			grep -q "$mountpoint" "/proc/mounts"
			if [[ "$?" != 0 ]]; then
				error "e_mount_3" "$mountpoint"
			else
				mount "--${mountopts}" "$mountpoint"
				checkfail "$?" "mount --${mountopts} $mountpoint"
			fi
		fi
	done
}

#copies all specified files to the chroot-prefixed path
#if a source file does not exist, throw an error and exit.
chrootcopy() {
	for filesrc in "${file_copy[@]}"; do
		filedest="${chrootdir}${filesrc}"
	if [[ ! -e ${filesrc%/} ]]; then
		error e_file_1 "$filesrc"
	fi
	cp -d "$filesrc" "$filedest"
	checkfail "$?" "cp -d ${filesrc} ${filedest}"
	done

	}

#runs all custom commands after confirmation
runcustcommands() {
	for command in "${custcommands[@]}"; do
		read  -n1 -s -p "${i_cust_1} ${command} - run it? [y/n]" yesno
		echo ''
		if [[ "${yesno,,}" != "y" ]] ; then
			message i_cust_2
		else
			${command}
			checkfail "$?" "$command"
		fi
	done
}

#call all functions necessary to chroot
setup() {
	yesno="n"
	chrootmount
	chrootcopy
	runcustcommands
#time to chroot
	read  -n1 -s -p "Chroot into ${chrootdir}? [y/n]" yesno
	echo ''
	if [[ "${yesno,,}" != "y" ]] ; then
		error e_user_1
	else
		chroot "$chrootdir" /bin/bash
	fi
}

#cleanup the chroot mounts
#--make-rprivate is a workaround for "device or resource busy" on --make-rslave mounts
#since this only happens after exiting the chroot, it will be fine for systemd setups as well
clean() {
for i in $(grep "$chrootdir" "/proc/mounts" | cut -d ' ' -f 2 | sort -r); do
	mount --make-rprivate "$i"
	umount -r -n "$i"
done
}

#check if chrootdir does exist.
checkdir "$chrootdir" "e_dir_1"

#start appropriate routine
case "$action" in
	setup)
		message "m_action_setup_1"
		setup
		;;
	clean)
		message "m_action_clean_1"
		clean
		;;
esac
