#!/bin/bash

. ./t-test-dm-lib.sh

DEFAULT_LIST="read write randread randwrite rw randrw"

function generate_log() {
	echo "TEST:$(basename $2)" >> $1
	grep -e '\(READ\|WRITE\)' $2/log >>$FILE
}

function _cleanup() {
	if [ -b "$DM_PATH/tst_crypt" ]; then
		tdm_dm_remove tst_crypt
	fi

	if [ -b "$DM_PATH/tst_zero" ]; then
		tdm_dm_remove tst_zero
	fi
}

function check_params() {
	
	DEV="/tmp/dummy"

        lib_checkparams || {
                usage
                exit 100
        }

	tdm_checkparams || {
		usage
		exit 100
	}

	unset DEV

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

	BSIZE=${BSIZE:-512}
	pdebug "BSIZE=$BSIZE"

	BALIGN=${BALIGN:-512}
	pdebug "BALIGN=$BALIGN"

	MODELIST=${MODELIST:-$DEFAULT_LIST}
	pdebug "MODELIST='$MODELIST'"

	ITERATIONS=${ITERATIONS:-3}
	pdebug "ITERATIONS=$ITERATIONS"

	RAMP_TIME=${RAMPTIME:-1s}
	pdebug "RAMP_TIME=$RAMP_TIME"

	RANDSEED=${RANDSEED:-$RANDOM}
	pdebug "RANDSEED=$RANDSEED"
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
		"--bsize")
			BSIZE="$2"
			shift
			;;
		"--balign")
			BALIGN="$2"
			shift
			;;
		"--modelist")
			LIST="$2"
			shift
			;;
		"--iterations")
			ITERATIONS="$2"
			shift
			;;
		"--job")
			JOB="$2"
			shift
			;;
		"--jobdir")
			JOBSDIR="$2"
			shift
			;;
		"--ramp_time")
			RAMP_TIME="$2"
			shift
			;;
		"--randseed")
			RANDSEED="$2"
			shift
			;;
		*)
			usage
			exit 1;
	esac
	shift
done

check_params
if [ -n "$DEBUG" ]; then
	test "$DEBUG" -lt 2 || set -vx
fi

FILE=$LOGDIR/agg_1k_128k.log

pdebug "FILE=$FILE"

set_cleanup "_cleanup"

run=0
while [ $run -lt $ITERATIONS ] ; do
	for i in $MODELIST ; do
		tdm_test_zero $i $DEV_ZERO_SIZE $JOB $LOGDIR/run_$run
	done
	run=$[run+1]
done

run=0
while [ $run -lt $ITERATIONS ] ; do
	for i in $MODELIST ; do
		generate_log $FILE "$LOGDIR/run_$run/zero-$i"
	done
	echo >> $FILE
	run=$[run+1]
done

test -z "$LOGDIR" || tdm_remove_tmp_log_files $LOGDIR
