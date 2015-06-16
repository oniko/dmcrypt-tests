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

# $1 chunk size
# $2 target name (not only striped but experimental variants as well)
# $@ devs
function calculate_striped_table() {
	local chsize=$1
	shift
	local tgt=$1
	shift
	local min_dev_size=$(blockdev --getsz $1)
	local table_args="$1 0"
	shift
	local striped_dev_size=""
	local tmp_size=""
	local num_devs=1

	for i in $@; do
		tmp_size=$(blockdev --getsz $i)
		test $tmp_size -ge $min_dev_size || min_dev_size=$tmp_size
		table_args="$table_args $i 0"
		num_devs=$((num_devs+1))
	done

	striped_dev_size=$[min_dev_size*num_devs]
	striped_dev_size=$[striped_dev_size-(striped_dev_size%(chsize*num_devs))]

	echo -n "0 $striped_dev_size $tgt $num_devs $chsize $table_args"
}

# $1 striped dev dm name
# $2 striped target name (striped or striped-nomerge for our experiments)
# $3 chunk size
# $@ devices
function map_striped() {
	local dmname=$1
	shift
	local tgt=$1
	shift
	local chsize=$1
	shift
	local table=$(calculate_striped_table $chsize $tgt $@)
	pdebug "creating $tgt device $dmname with table: $table"

	dmsetup create $dmname --table "$table"
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
