#!/bin/bash

DM_PATH="/dev/mapper"

function lib_checkparams() {

	test -n "$DEV" || {
		echo "--dev parameter is mandatory" >&2
		return 100
	}
	pdebug "DEV=$DEV"

	LOGDIR=${LOGDIR:-$(pwd)/log}
	test -d $LOGDIR || install -d $LOGDIR
	pdebug "LOGDIR=$LOGDIR"
}

function pdebug() {
	test -z "$DEBUG" || echo "$@"
}

function cleanup() {
	trap - EXIT INT TERM ERR
	set +eE
	pdebug "going to run cleanup: $LIBV_CLEANUP"
	test -n "$LIBV_CLEANUP" && "$LIBV_CLEANUP"
}

function set_cleanup() { #1 _cleanup function
	type "$1" | grep -q "function" && {
		pdebug "registering cleanup function: '$1'"
		LIBV_CLEANUP="$1"
	}
}

# credits to LVM2
function STACKTRACE() {
	trap - ERR
	i=0;

	while FUNC=${FUNCNAME[$i]}; test "$FUNC" != "main"; do
		echo "## $i ${FUNC}() called from ${BASH_SOURCE[$i+1]}:${BASH_LINENO[$i]}"
		i=$(($i + 1));
	done
}

set -eE

trap 'ret=$?;cleanup;exit $ret' EXIT INT TERM
trap 'set +vx;STACKTRACE;' ERR
trap 'ret=$?;STACKTRACE;exit $ret' ERR
