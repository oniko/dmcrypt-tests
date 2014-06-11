#!/bin/bash

. ../t-dm-lib.sh

CTEST_NULL=crypt-seeker-null
CTEST=crypt-seeker

function usage() {
	echo "$0 --dev <test_device_path> [--debug] [--debugx (set -vx)] " \
	"[--seed <num> predefined seed to all lseeks] [--log <path> log dir]" >&2
}

function check_params() {

	lib_checkparams || {
		usage
		exit 100;
	}

	if [ ! -x "./seeker.bin" ]; then
		echo "Compile seeker first"
		exit 100
	fi
}

function _cleanup() {
	udevadm settle 2> /dev/null
	cryptsetup remove $CTEST 2> /dev/null
	dmsetup remove $CRYPT_NULL 2> /dev/null
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		"--debug")
			DEBUG=1
			;;
		"--dverbose")
			DEBUG_VERB=1
			;;
		"--dev")
			DEV="$2"
			shift
			;;
		"--seed")
			RSEED="$2"
			shift
			;;
		"--log")
			LOGDIR="$2"
			shift
			;;
		*)
			echo "Wrong parameter: $1"
			exit 1;
	esac
	shift
done

if [ -n "$DEBUG" ]; then
	[ -z "$DEBUG_VERB" ] || set -vx
fi

set_cleanup "_cleanup"

check_params


echo -n "Seeker test: " >> $LOGDIR/seeker-test.log
date >> $LOGDIR/seeker-test.log

sync
echo 3 > /proc/sys/vm/drop_caches
echo "Going to run seeker test on raw block device"
echo "RAW BLOCK DEVICE" >> $LOGDIR/seeker-test.log
./seeker.bin $DEV $RSEED >> $LOGDIR/seeker-test.log

sync
echo 3 > /proc/sys/vm/drop_caches
echo "Going to run seeker test on crypt device with a null cipher"
echo "CRYPT WITH CIPHER_NULL" >> $LOGDIR/seeker-test.log
dmsetup create $CTEST_NULL --table "0 `blockdev --getsz $DEV` crypt cipher_null-ecb-null - 0 $DEV 0"
./seeker.bin $DM_PATH/$CTEST_NULL $RSEED >> $LOGDIR/seeker-test.log

udevadm settle
dmsetup remove $CTEST_NULL

sync
echo 3 > /proc/sys/vm/drop_caches
echo "Going to run seeker test on crypt device with the usual cipher"
echo "CRYPT WITH CIPHER AES-XTS-PLAIN64" >> $LOGDIR/seeker-test.log
echo xxx | cryptsetup create -c aes-xts-plain64 -s 256 $CTEST $DEV
./seeker.bin $DM_PATH/$CTEST $RSEED >> $LOGDIR/seeker-test.log

