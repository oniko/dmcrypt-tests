#!/bin/bash

. ./t-test-dm-lib.sh

DEFAULT_LIST="write randwrite"

function usage() {
	printf	'usage:\n%s\t' $(basename $0) >&2
	printf	'%s\n' $'--job <job_name> --jobdir <jobs_dir> --fio <full fio path> --dev <device>' \
		$'\t\t[--debug print debug info] [--debugx start script with set -vx ]' \
		$'\t\t[--log <log_dir>] [--size <num>]' \
		$'\t\t[--bsize <num> test block size] [--balign <num> test offset]' \
		$'\t\t[--modelist <\"mode1 mode2 mode3 ...\"> list of fio i/o modes]' \
		$'\t\t[--iterations <num> number of iterations per \'modelist\']' \
		$'\t\t[--numjobs <num> number of jobs] [--ioengine <engine> fio ioengine]' \
		$'\t\t[--number_ios <num> number of bsized i/os to perform] [--iodepth <num>]' \
		$'\t\t[--iodepth_batch_complete <num>] [--iodepth_batch_submit <num>]' \
		$'\t\t[--rq_affinity <0-2>] [--io_limit <num>] [--nr_requests <num>]' \
		$'\t\t[--runtime secs]' >&2
}

function check_params() {

        lib_checkparams || {
                usage
                exit 100
        }

	tdm_checkparams || {
		usage
		exit 100
	}

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

	RAMP_TIME=${RAMP_TIME:-1s}
	pdebug "RAMP_TIME=$RAMP_TIME"

	RANDSEED=${RANDSEED:-$RANDOM}
	pdebug "RANDSEED=$RANDSEED"

	NUMJOBS=${NUMJOBS:-10}
	pdebug "NUMJOBS=$NUMJOBS"

	IOENGINE=${IOENGINE:-sync}
	pdebug "IOENGINE=$IOENGINE"

	IODEPTH=${IODEPTH:-1}
	pdebug "IODEPTH=$IODEPTH"

	pdebug "NUMBER_IOS=${NUMBER_IOS:-'not set'}"

	pdebug "NR_REQUESTS=${NR_REQUESTS:-'not set'}"

	IODEPTH_BATCH_SUBMIT=${IODEPTH_BATCH_SUBMIT:-1}
	pdebug "IODEPTH_BATCH_SUBMIT=$IODEPTH_BATCH_SUBMIT"

	IODEPTH_BATCH_COMPLETE=${IODEPTH_BATCH_COMPLETE:-1}
	pdebug "IODEPTH_BATCH_COMPLETE=$IODEPTH_BATCH_COMPLETE"

	pdebug "RQAFFINITY=${RQAFFINITY:-'not set'}"

	IO_LIMIT=${IO_LIMIT:-$SIZE}
	pdebug "IO_LIMIT=$IO_LIMIT"

	RUNTIME=${RUNTIME:-'not set'}
	pdebug "RUNTIME=$RUNTIME"
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
		"--log")
			LOGDIR="$2"
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
			MODELIST="$2"
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
		"--numjobs")
			NUMJOBS="$2"
			shift
			;;
		"--fio")
			FIO="$2"
			shift
			;;
		"--ioengine")
			IOENGINE="$2"
			shift
			;;
		"--number_ios")
			NUMBER_IOS="$2"
			shift
			;;
		"--iodepth")
			IODEPTH="$2"
			shift
			;;
		"--nr_requests")
			NR_REQUESTS="$2"
			shift
			;;
		"--iodepth_batch_submit")
			IODEPTH_BATCH_SUBMIT="$2"
			shift
			;;
		"--iodepth_batch_complete")
			IODEPTH_BATCH_COMPLETE="$2"
			shift
			;;
		"--rq_affinity")
			RQAFFINITY="$2"
			shift
			;;
		"--io_limit")
			IO_LIMIT="$2"
			shift
			;;
		"--runtime")
			RUNTIME="$2"
			shift
			;;
		*)
			echo "uknown option $1" >&2
			usage
			exit 1;
	esac
	shift
done

check_params
if [ -n "$DEBUG" ]; then
	test "$DEBUG" -lt 2 || set -vx
fi


run=0
while [ $run -lt $ITERATIONS ] ; do
	for i in $MODELIST ; do 
		tdm_test 	$DEV disk_striped $i $JOB $LOGDIR/run_$run
	done
	run=$[run+1]
done

run=0
while [ $run -lt $ITERATIONS ] ; do
	FILE=$LOGDIR/run_$run/agg_1k_128k.log
	pdebug "FILE=$FILE"

	for i in $MODELIST ; do
		tdm_generate_log $FILE "$LOGDIR/run_$run/disk_striped-$i"
	done
	echo >> $FILE

	run=$[run+1]
done

test -z "$LOGDIR" || tdm_remove_tmp_log_files $LOGDIR
