#!/bin/bash

. ../t-dm-lib.sh

function tdm_checkparams {
	test -n "$JOB" || {
		echo "--job parameter is mandatory" >&2
		return 100
	}

	test -n "$JOBSDIR" || {
		echo "--jobdir parameter is mandatory" >&2
		return 100
	}

	test -n "$FIO" || {
		echo "--fio parameter is mandatory"
		return 100
	}

	test -n "$IOENGINE" || {
		echo "--ioengine parameter is mandatory"
		return 100
	}
}

function tdm_dm_remove() {
	sync
	udevadm settle
	blockdev --flushbufs /dev/mapper/$1
	dmsetup remove --retry $1
}

# $1 device
# $2 test name 
# $3 fio i/o mode
# $4 job file
# $5 run dir
function tdm_test() {
	local old_dir=$(pwd)

	dir="$2-$3"
	_print "test $dir, ioengine:$IOENGINE, iodepth:$IODEPTH, iolimit:$IO_LIMIT, size:$SIZE, dev_size:" $(blockdev --getsz $1)
	[ -d $5/$dir ] || install -d $5/$dir
	cd $5/$dir

	{
		echo "DEV=${1:-unset}"
		echo "MODE=${3:-unset}"
		echo "BALIGN=${BALIGN:-unset}"
		echo "BSIZE=${BSIZE:-unset}"
		echo "RAMP_TIME=${RAMP_TIME:-unset}"
		echo "RANDSEED=${RANDSEED:-unset}"
		echo "SIZE=${SIZE:-unset}"
		echo "IO_LIMIT=${IO_LIMIT:-unset}"
		echo "NUMJOBS=${NUMJOBS:-unset}"
		echo "IOENGINE=${IOENGINE:-unset}"
		echo "FIO=${FIO:-unset}"
		echo "NUMBER_IOS=${NUMBER_IOS:-unset}"
		echo "IODEPTH=${IODEPTH:-unset}"
		echo "IODEPTH_BATCH_SUBMIT=${IODEPTH_BATCH_SUBMIT:-unset}"
		echo "IODEPTH_BATCH_COMPLETE=${IODEPTH_BATCH_COMPLETE:-unset}"
		echo "RUNTIME=${RUNTIME:-unset}"
		echo "--- job file ---"
		cat $JOBSDIR/$4
	} > ./job.params

	echo 3 > /proc/sys/vm/drop_caches

	DEV=$1 MODE=$3 BALIGN=$BALIGN BSIZE=$BSIZE RAMP_TIME=$RAMP_TIME \
		RANDSEED=$RANDSEED SIZE=$SIZE NUMJOBS=$NUMJOBS \
		IOENGINE=$IOENGINE NUMBER_IOS=$NUMBER_IOS IODEPTH=$IODEPTH \
		IODEPTH_BATCH_SUBMIT=$IODEPTH_BATCH_SUBMIT \
		IODEPTH_BATCH_COMPLETE=$IODEPTH_BATCH_COMPLETE IO_LIMIT=$IO_LIMIT \
		RUNTIME=$RUNTIME \
		$FIO $JOBSDIR/$4 --output=log --bandwidth-log=log
	cd $old_dir
}

# $1 dev path
# $2 rq_affinity value
function set_rq_affinity() {
	test -n "$2" || return 0

	local kname=$1

	test -L $kname && kname=$(readlink $1)
	kname=$(basename $kname)

	pdebug "going to set /sys/block/$kname/queue/rq_affinity to $2"
	echo $2 > /sys/block/$kname/queue/rq_affinity
}

# $1 dev path
# $2 nr_requets value
function set_nr_requests() {
	test -n "$2" || return 0

	local kname=$1

	test -L $kname && kname=$(readlink $1)
	kname=$(basename $kname)

	pdebug "going to set /sys/block/$kname/queue/nr_requests to $2"
	echo $2 > /sys/block/$kname/queue/nr_requests
}

# $1 backing device
# $2 test name
# $3 fio i/o mode
# $4 job file
# $5 run dir
function tdm_test_disk() {
	set_rq_affinity $1 $RQAFFINITY
	set_nr_requests $1 $NR_REQUESTS
	echo "pass" | cryptsetup create -c $CIPHER -s $KEY_SIZE tst_crypt $1
	tdm_test $DM_PATH/tst_crypt $2 $3 $4 $5
	tdm_dm_remove tst_crypt
}

# $1 fio i/o mode
# $2 dm-zero dev bsize
# $3 job name
# $4 run dir
function tdm_test_zero() {
	dmsetup create tst_zero --table "0 $2 zero"
	tdm_test_disk $DM_PATH/tst_zero zero $1 $3 $4
	tdm_dm_remove tst_zero
}

# $1 log dir
function tdm_remove_tmp_log_files() {
	find "$1" -type f \
		\( -size 0 -or \! \( -name log -or -name agg_1k_128k.log -or -name job.params \) \) \
		-exec rm -f {} \;
}

# $1 agg file to append
# $2 source dir
function tdm_generate_log() {
	echo "TEST:$(basename $2)" >> $1
	grep -e '\(READ\|WRITE\)' $2/log >>$1
}
