#!/bin/bash

. ../t-dm-lib.sh

function usage() {
	echo "$0 --dev <test_device_path> [--debug] [--debugx (set -vx)] " \
	"[--num <num> Nr. of stacked devices default: 15] [--bsize <num> block size. default: 512]" \
	"[--count <num> Nr of --bsize writes to stacked devices] [--log <logdir> default: ./log]" >&2
}

function check_params() {

	lib_checkparams || {
		usage
		exit 100
	}
	
	NUM=${NUM:-15}
	BSIZE=${BSIZE:-512}
	COUNT=${COUNT:-102400}
}

function _cleanup() {

	if [ -n "$NUM" ]; then
		if [ "$NUM" -gt 0 ]; then
			udevadm settle 2> /dev/null
			for i in $(seq $(($NUM+1)) -1 1); do
				pdebug "remove CTEST$i..."
				dmsetup remove CTEST$i 2> /dev/null
			done
		fi
	fi

}

while [ "$#" -gt 0 ]; do
	case "$1" in
		"--debug")
			DEBUG=1
			;;
		"--debugx")
			DEBUG=2
			;;
		"--dev")
			DEV="$2"
			shift
			;;
		"--bsize")
			BSIZE="$2"
			shift
			;;
		"--count")
			COUNT="$2"
			shift
			;;
		"--num")
			NUM="$2"
			shift
			;;
		"--log")
			LOGDIR="$2"
			shift
			;;
		*)
			echo "Wrong parameter: $1"
			usage
			exit 1;
	esac
	shift
done

set_cleanup "_cleanup"

if [ -n "$DEBUG" ]; then 
	[ "$DEBUG" -lt 2 ] || set -vx
fi

check_params

BDEV=$(blockdev --getsize64 $DEV)
if [ $BDEV -lt $[$BSIZE * $COUNT] ]; then
	echo "Test device $DEV is too small"
	exit 200
fi

for switch in "0" "1 same_cpu_crypt" "1 submit_from_crypt_cpus" "2 same_cpu_crypt submit_from_crypt_cpus" ; do

	map_dmcrypt $DEV CTEST1 aes-xts-plain64 $KEY "$switch"
	for i in $(seq 1 $NUM); do
		j=$i
		i=$(($i + 1))
		map_dmcrypt $DM_PATH/CTEST$j CTEST$i aes-xts-plain64 $KEY "$switch"
	done

	echo "Test write to $(($NUM + 1)) stacked dmcrypt devices: bsize=$BSIZE, count=$COUNT"
	dd if=/dev/zero of=$DM_PATH/CTEST$(($NUM + 1)) bs=$BSIZE count=$COUNT
	echo "Test complete"

	_cleanup
done

