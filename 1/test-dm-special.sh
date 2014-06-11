#!/bin/bash

. ../t-dm-lib.sh

FIO=/root/okozina/fio-2.1.7/fio.orig

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
	DEV=/dev/null

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
	local dev0
	local job=$3
	local mode=$2

	dir="$1-$2-$3"
	shift 3
	dev0=$1
	shift 1
	#pdebug "Running $dir, size:" $(blockdev --getsize64 $1)
	pdebug "Running $dir"
	pdebug "devs: $1, $2, $3, $4, $5, $6, $7, $8"

	[ -d $LOGDIR/$dir ] || install -d $LOGDIR/$dir
	cd $LOGDIR/$dir
	echo 3 > /proc/sys/vm/drop_caches
	#fio --output=log --latency-log=log --bandwidth-log=log \
	#--name=global --rw=$3 --size=1G --bsrange=1k-128k \
	#--filename=$1 \
	#--name=job1 --name=job2 --name=job3 --name=job4 \
	#--end_fsync=1
	DIRECT=0 IODEPTH=1 NUMJOBS=1 DEV0=$dev0 DEV1=$1 DEV2=$2 DEV3=$3 DEV4=$4 DEV5=$5 DEV6=$6 DEV7=$7 DEV8=$8 DEV9=$9 MODE=$mode SIZE=$SIZE $FIO $START_DIR/jobs/$job \
		--output=log --latency-log=log --bandwidth-log=log
	cd $START_DIR
}

function setup_crypt()
{
	echo "pass" | cryptsetup create -c $CIPHER -s $KEY_SIZE crypt_$2 $1
}

function test_disk() {
	local name mode job dev

	name=$1
	mode=$2
	job=$3
	
	shift 3
	
	dev0=$1
	
	shift 1

	pdebug "name=$name, mode=$mode, job=$job"

	setup_crypt $dev0 0
	setup_crypt $1 1
	setup_crypt $2 2
	setup_crypt $3 3
	setup_crypt $4 4
	setup_crypt $5 5
	setup_crypt $6 6
	setup_crypt $7 7
	setup_crypt $8 8
	setup_crypt $9 9

	_test $name $mode $job $DM_PATH/crypt_0 $DM_PATH/crypt_1 $DM_PATH/crypt_2 $DM_PATH/crypt_3 $DM_PATH/crypt_4 $DM_PATH/crypt_5 $DM_PATH/crypt_6 $DM_PATH/crypt_7 $DM_PATH/crypt_8 $DM_PATH/crypt_9




	dm_remove crypt_0
	dm_remove crypt_1
	dm_remove crypt_2
	dm_remove crypt_3
	dm_remove crypt_4
	dm_remove crypt_5
	dm_remove crypt_6
	dm_remove crypt_7
	dm_remove crypt_8
	dm_remove crypt_9
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

	if [ -b "$DM_PATH/crypt_0" ]; then
		dm_remove crypt_0
	fi

	if [ -b "$DM_PATH/crypt_1" ]; then
		dm_remove crypt_1
	fi

	if [ -b "$DM_PATH/crypt_2" ]; then
		dm_remove crypt_2
	fi

	if [ -b "$DM_PATH/crypt_3" ]; then
		dm_remove crypt_3
	fi

	if [ -b "$DM_PATH/crypt_4" ]; then
		dm_remove crypt_4
	fi

	if [ -b "$DM_PATH/crypt_5" ]; then
		dm_remove crypt_5
	fi

	if [ -b "$DM_PATH/crypt_6" ]; then
		dm_remove crypt_6
	fi

	if [ -b "$DM_PATH/crypt_7" ]; then
		dm_remove crypt_7
	fi

	if [ -b "$DM_PATH/crypt_8" ]; then
		dm_remove crypt_8
	fi

	if [ -b "$DM_PATH/crypt_9" ]; then
		dm_remove crypt_9
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
		"--keysize")
			KEY_SIZE="$2"
			shift
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

#JOBS="1300_job_multi_io_multi_device_idle 1310_job_multi_io_multi_device_burn"
JOBS="1400_numa_migration_experiment"

pdebug "FILE=$FILE"

#DEVS="/mnt/ram0/file /mnt/ram1/file /mnt/ram2/file /mnt/ram3/file /mnt/ram4/file /mnt/ram5/file /mnt/ram6/file /mnt/ram7/file"
DEVS="/dev/loop0 /dev/loop1 /dev/loop2 /dev/loop3 /dev/loop4 /dev/loop5 /dev/loop6 /dev/loop7 /dev/loop8 /dev/loop9" 

set_cleanup "_cleanup"

#echo deadline>/sys/block/sdb/queue/scheduler

for i in $LIST ; do
	for job in $JOBS ; do
		_test		disk_nocrypt $i $job $DEVS
		#test_zero      zero         $i $job
		test_disk	disk         $i $job $DEVS
	done
done

exit 0

for j in disk_nocrypt disk ; do
#for j in disk_nocrypt zero disk ; do
	for i in $LIST ; do
		for job in $JOBS ; do
			generate_log $FILE "$LOGDIR/$j-$i-$job"
		done
	done
	echo >> $FILE
done
