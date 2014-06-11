#!/bin/bash

. ../t-dm-lib.sh

FIO=/root/okozina/fio-2.1.9/fio

function usage() {
	echo "$0 --dev <test_device> [--debug print debug info]" \
	     "[--debugx start script with set -vx ] [--keysize <num>] " \
	     "[--zerosize <num>] [--log <log_dir>] [--cipher <cryptsetup_cipher_string>]" \
	     "[--size <num>]" >&2
}

function dm_remove() {
	sync
	udevadm settle
	blockdev --flushbufs /dev/mapper/$1
	dmsetup remove --retry $1
}

function check_params() {

	lib_checkparams || {
		usage
		exit 100
	}

	KEY_SIZE=${KEY_SIZE:-256}
	pdebug "KEY_SIZE=$KEY_SIZE"

	DEV_ZERO_SIZE=${DEV_ZERO_SIZE:-$((1 * 1024 * 1024 * 1024 / 512))}
	pdebug "DEV_ZERO_SIZE=$DEV_ZERO_SIZE"

	CIPHER=${CIPHER:-aes-xts-plain64}
	pdebug "CIPHER=$CIPHER"

	LOGDIR=${LOGDIR:-$(pwd)/log}
	test -d $LOGDIR || mkdir $LOGDIR
	pdebug "LOGDIR=$LOGDIR"

	SIZE=${SIZE:-1G}
	pdebug "SIZE=$SIZE"
}


function _test() {
	dir="$2-$3"
	#pdebug "Running $dir, size:" $(blockdev --getsize64 $1)
	echo "Running $dir"
	[ -d $LOGDIR/$dir ] || install -d $LOGDIR/$dir
	cd $LOGDIR/$dir
	echo 3 > /proc/sys/vm/drop_caches
	DEV=$1 MODE=$3 $FIO $START_DIR/jobs/0000_job_default \
		--output=log --latency-log=log --bandwidth-log=log
	cd $START_DIR
}

function test_disk() {
	echo "pass" | cryptsetup create -c $CIPHER -s $KEY_SIZE tst_crypt $1
	_test $DM_PATH/tst_crypt $2 $3
	dm_remove tst_crypt
}

function test_zero() {
	dmsetup create tst_zero --table "0 $DEV_ZERO_SIZE zero"
	test_disk $DM_PATH/tst_zero $1 $2 $3
	dm_remove tst_zero
}

function generate_log() {
	echo "TEST:$(basename $2)" >> $1
	grep -e '\(READ\|WRITE\)' $2/log >>$FILE
}

function _cleanup() {
#	udevadm settle 2> /dev/null

	if [ -b "$DM_PATH/tst_crypt" ]; then
		dm_remove tst_crypt
	fi

	if [ -b "$DM_PATH/tst_zero" ]; then
		dm_remove tst_zero
	fi

	#remove temporary log directories?
#	for j in disk_nocrypt zero disk ; do
#		for i in $LIST ; do
#			rm -r "$j-$i" 2> /dev/null
#		done
#	done
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
		"--keysize")
			KEY_SIZE="$2"
			shift
			;;
		"--jobs")
			pdebug "Jobs param not implemented...TODO"
			;;
		"--zerosize")
			DEV_ZERO_SIZE="$2"
			shift
			;;
		"--log")
			LOGDIR="$2"
			shift
			;;
		"--cipher")
			CIPHER="$2"
			shift
			;;
		"--size")
			SIZE="$2"
			shift
			;;
		*)
			usage
			exit 1;
	esac
	shift
done

START_DIR=$(pwd)

check_params
if [ -n "$DEBUG" ]; then
	test "$DEBUG" -lt 2 || set -vx
fi

#DEV_SIZE=$(blockdev --getsize $DEV)

LIST="read write randread randwrite rw randrw"
FILE=$LOGDIR/agg_1k_128k.log

pdebug "FILE=$FILE"

set_cleanup "_cleanup"

#echo deadline>/sys/block/sdb/queue/scheduler

for i in $LIST ; do
	_test $DEV      disk_nocrypt $i
	test_zero      zero         $i
	test_disk $DEV disk         $i
done

for j in disk_nocrypt zero disk ; do
	for i in $LIST ; do
		generate_log $FILE "$LOGDIR/$j-$i"
	done
	echo >> $FILE
done

find "$LOGDIR" -type f \( -size 0 -or \! \( -name log -or -name agg_1k_128k.log \) \) \
	-exec rm -f {} \;
