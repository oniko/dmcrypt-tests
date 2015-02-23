#!/bin/bash

# #define like check
if [ -z "$_T_DM_LIB_SH" ]; then

_T_DM_LIB_SH=1

DM_PATH="/dev/mapper"

KEY="e6ffcfdf2e7310ecf7b03d7a0af10e42d5457f42583ae394c62ff644d50bdd95"

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

function _print() {
	echo "$(date +%F\ %H:%M:%S) $@"
}

function pdebug() {
	test -z "$DEBUG" || _print "$@"
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

# $1 backing device
# $2 crypt dev name
# $3 cipher
# $4 key
# $5 dm-crypt switches
function map_dmcrypt() {
	local table="0 `blockdev --getsz $1` crypt $3 $4 0 $1 0 $5"
	pdebug "creating dm-crypt device with table: $table"

	dmsetup create $2 --table "$table"
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

fi
