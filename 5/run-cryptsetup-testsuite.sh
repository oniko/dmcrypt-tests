#!/bin/bash

. ../t-dm-lib.sh

function usage() {
	printf	'usage:\n%s\t' $(basename $0) >&2
	printf	'%s\n' $'--cryptsetup-dir <sources_dir> --log <log_dir>' >&2
}

function check_params() {
	DEV=dummy

	lib_checkparams || {
		usage 
		exit 100
	}

	unset DEV

	test -n $CSDIR || {
		usage
		exit 100
	}

	pdebug "CSDIR=$CSDIR"
}

function _cleanup() {
	cd $CSDIR
	make -C tests clean
	cd $WORK_DIR
}

WORK_DIR=$(pwd)

while [ "$#" -gt 0 ]; do
	case "$1" in
		"--debug")
			DEBUG=1
			;;
		"--debugx")
			DEBUG=2
			;;
		"--cryptsetup-dir")
			CSDIR="$2"
			shift
			;;
		"--log")
			LOGDIR="$2"
			shift
			;;
		*)
			echo "Wrong parameter: $1" >&2
			usage
			exit 1;
	esac
	shift
done

check_params

set_cleanup "_cleanup"

cd $CSDIR/tests

echo "going to run loopaes-test" >> $LOGDIR/cryptsetup-testsuite.log 2>&1
./loopaes-test >> $LOGDIR/cryptsetup-testsuite.log 2>&1

echo "going to run mode-test" >> $LOGDIR/cryptsetup-testsuite.log 2>&1
./mode-test >> $LOGDIR/cryptsetup-testsuite.log 2>&1

echo "going to run password-hash-test" >> $LOGDIR/cryptsetup-testsuite.log 2>&1
./password-hash-test >> $LOGDIR/cryptsetup-testsuite.log 2>&1
 
echo "going to run tcrypt-compat-test" >> $LOGDIR/cryptsetup-testsuite.log 2>&1
./tcrypt-compat-test >> $LOGDIR/cryptsetup-testsuite.log 2>&1
