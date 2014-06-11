#!/bin/bash

. ./t-dm-lib.sh

function usage() {
	echo "$0 --dev <test_dev> --log <log_dir> --testdir <path_to_test_mount_dir>" >&2
}

function check_params() {

	if [ -d "$LOGDIR" ]; then
		echo "Logdir exists. Previous results would have been overwritten" >&2
		return 100
	fi

	lib_checkparams || {
		return 100;
	}

	if [ -z "$TESTDIR" ]; then 
		echo "--testdir parameter is mandatory for dmcrypt-all-verify.sh" >&2
		return 100
	fi


	pdebug "TESTDIR=$TESTDIR"
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		"--dev")
			DEV=$2;
			shift;
			;;
		"--debug")
			DEBUG=1
			;;
		"--debugv")
			DEBUG=2
			;;
		"--log")
			LOGDIR="$2"
			shift
			;;
		"--testdir")
			TESTDIR="$2"
			shift
			;;
		*)
			usage;
			exit 1;
	esac
	shift
done

check_params || { usage; exit 100; }

if [ -n "$DEBUG" ]; then
	test $DEBUG -lt 2 || set -vx;
fi

cd 1

pdebug "Starting: ./test-dm.sh --dev $DEV --log $LOGDIR/1"
./test-dm.sh --dev $DEV --log $LOGDIR/1
mv $LOGDIR/1/agg_1k_128k.log $LOGDIR/

cd ..
