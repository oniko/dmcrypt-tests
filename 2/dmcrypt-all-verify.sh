#!/bin/bash

# Some basic tests for dmcrypt
# mbroz@redhat.com
#
# dt utility can't handle relative paths

. ../t-dm-lib.sh

test "$(cryptsetup --version | cut -d ' ' -f 2 | tr -d '.')" -lt 150 || FORCEPASS=--force-password

KEY="e6ffcfdf2e7310ecf7b03d7a0af10e42d5457f42583ae394c62ff644d50bdd95"

function usage() {
	echo "$0 --dev <test_device_path> --testdir <test_directory_for_mounting_dev> " \
	"[--debug print debug info] [--debugx to set -vx ] [--source <test_data_source> /usr by default] " \
	"[--log <log_dir> ./log by default] [--dt-limit <num[gmk]> dt _limit_ parameter. default: 200m] " \
	"[--dt-capacity dt _capacity_ parameter. default: 1g] [--checksums reference checksum file]" \
	"[--archive archive with reference files]" >&2
}

function check_params() {

	lib_checkparams || {
		usage 
		exit 100
	}

	# TESTDIR check
	test -n "$TESTDIR" || {
		echo "--testdir parameter is mandatory"
		usage
		exit 100
	}
	pdebug "TESTDIR=$TESTDIR"
	case $TESTDIR in
		/*)
			;;
		*)
			echo "--testdir parameter needs to be an absolute path"
			usage
			exit 100
	esac
	[ -d "$TESTDIR" ] || install -d "$TESTDIR"

	
	# aditional LOGDIR check
	case $LOGDIR in
		/*)
			;;
		*)
			echo "--log parameter needs to be an absolute path (dt fails otherwise)"
			usage
		 	exit 100
	esac

	SOURCE=${SOURCE:-/usr}
	pdebug "SOURCE=$SOURCE"
	case $SOURCE in
		/*)
			;;
		*)
			echo "--source parameter needs to be an absolute path"
			usage
			exit 100
	esac

	test -n "$ARCHIVE" || {
		echo "--archive is mandatory"
		usage
		exit 100
	}

	test -n "$CHKSUMSREF" || {
		echo "--checksums is mandatory"
		usage
		exit 100
	}


	DT_LIMIT=${DT_LIMIT:-200m}
	pdebug "DT_LIMIT=$DT_LIMIT"
	DT_CAP=${DT_CAP:-1g}
	pdebug "DT_CAP=$DT_CAP"

	pdebug "ARCHIVE=$ARCHIVE"
	pdebug "CHKSUMSREF=$CHKSUMSREF"
}

function cmount() {
	cd $TESTDIR
	if [ ! -d $TESTDIR/tst ]; then 
		mkdir $TESTDIR/tst
	fi

	case "$1" in
	xfs)
		if [ "$2" = "mkfs" ]; then
			mkfs -t $1 -f -q $DM_PATH/$CDEV
		fi
		mount -o barrier -t $1 $DM_PATH/$CDEV $TESTDIR/tst
		;;
	ext3|ext4)
		if [ "$2" = "mkfs" ]; then 
			mkfs -t $1 -F -q $DM_PATH/$CDEV
		fi
		mount -o barrier=1 -t $1 $DM_PATH/$CDEV $TESTDIR/tst
		;;
	*)
		pdebug "unknown fs: $1"
		;;
	esac
}

function cumount() {
	cd $TESTDIR
	sync
	umount $TESTDIR/tst 2>/dev/null || pdebug "umount $TESTDIR/tst failed"
	udevadm settle
}

# TESTS

# copy /usr to encrypted disk
# calculate and verify checksums per file
function c_usr_verify() {
	cmount $2 mkfs

	cd $TESTDIR
	test -d usr || tar xJf $ARCHIVE
	cp -r usr tst/
	cp $CHKSUMSREF tst
	cumount

	#cp -r $SOURCE/ $TESTDIR/tst/
	#cumount

	#cd $SOURCE/..
	#find $(basename $SOURCE)/ -type f -print0 | xargs -0 sha1sum | sort > $TESTDIR/checksums-$1.ref

	cmount $2
	cd $TESTDIR/tst
	find $(basename $SOURCE) -type f -print0 | xargs -0 sha1sum | sort > $TESTDIR/checksums-$1.tst
	diff -u $TESTDIR/tst/checksums.ref $TESTDIR/checksums-$1.tst 2>&1 > /dev/null || {
		echo "ERROR diffing files !" 
		return 1;
	}
	cumount
}

# FSX test
function cfsx() {
	if [ ! -x $START_DIR/fsx.bin ]; then
		echo "Compile fsx first."
		exit 100
	fi
	cmount $2 mkfs
	$START_DIR/fsx.bin -N 10000 $TESTDIR/tst/testfile
	cumount
}

# dt test
function cdt() {
	if [ ! -x $START_DIR/dt.bin ]; then
		echo "Compile dt first."
		exit 100
	fi
	cmount $2 mkfs

	pdebug "capacity=$DT_CAP, limit=$DT_LIMIT, if dt.bin fails, check your --dev size"
	$START_DIR/dt.bin of=$TESTDIR/tst/testfile iotype=random limit=$DT_LIMIT runtime=1m \
		enable=compare oncerr=abort errors=1 procs=4 disable=fsync \
		oflags=trunc incr=var min=2k max=64k dispose=keep pattern=iot \
		disable=noprog enable=stats disable=pstats disable=verbose \
		noprogt=120s noprogtt=120s alarm=3s capacity=$DT_CAP \
		log=$LOGDIR/dt_log_$1

	cumount
}

function run_test() { # name function alg
	echo "TEST: $1 ($3 on $4)"
	echo -e "START\t" $(date)
	$2 $3 $4
	echo -e "END\t" $(date)
}

function _cleanup() {
	cd $TESTDIR 2> /dev/null

	sync
	umount $TESTDIR/tst 2> /dev/null

	if [ -b $DM_PATH/$CDEV ]; then
		dmsetup remove -f $CDEV
	fi

	rm -r $TESTDIR/tst 2> /dev/null
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		"--archive")
			ARCHIVE="$2"
			shift
			;;
		"--checksums")
			CHKSUMSREF="$2"
			shift
			;;
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
		"--testdir")
			TESTDIR="$2"
			shift
			;;
		"--source")
			SOURCE="$2"
			shift
			;;
		"--log")
			LOGDIR="$2"
			shift
			;;
		"--dt-limit")
			# --limit 200m,20g...
			DT_LIMIT="$2"
			shift
			;;
		"--dt-capacity")
			# --dt-capacity 200m,20g...
			DT_CAP="$2"
			shift
			;;
		*)
			echo "Wrong parameter: $1" >&2
			usage
			exit 1;
	esac
	shift
done

if [ -n "$DEBUG" ]; then 
	[ "$DEBUG" -lt 2 ] || set -vx
fi

START_DIR=$(pwd)

check_params

MODELIST="null aes-cbc-essiv:sha256 aes-xts-plain64"
CRYPT_ARGS=$(echo "0" "1 same_cpu_crypt" "1 submit_from_crypt_cpus" "2 same_cpu_crypt submit_from_crypt_cpus")
FSLIST="xfs ext4 ext3"
CDEV=crypt
PASS=xxx

set_cleanup "_cleanup"

# $1 cipher
# $2 key
# $3 dm-crypt switches
function map_dmcrypt() {
	local table="0 `blockdev --getsz $DEV` crypt $1 $2 0 $DEV 0 $3"
	pdebug "creating dm-crypt device with table: $table"

	dmsetup create $CDEV --table "$table"
}

cumount

for switch in $CRYPT_ARGS ; do
	for i in $MODELIST
	do
		if [ "$i" = "null" ] ; then
			dd if=/dev/zero of=$DEV bs=1M count=4 2>/dev/null
			sync
			#dmsetup create $CDEV --table "0 `blockdev --getsz $DEV` crypt cipher_null-ecb-null - 0 $DEV 0 $switch"
			map_dmcrypt cipher_null-ecb-null "-" $switch
		else
			map_dmcrypt $i $KEY $switch
		fi

		for j in $FSLIST
		do
			run_test "USR COPY TEST" c_usr_verify $i $j
			run_test "FSX TEST" cfsx $i $j
			run_test "DT TEST" cdt $i $j
		done

		if [ -b $DM_PATH/$CDEV ]; then
			dmsetup remove -f $CDEV
		fi
	done
done
