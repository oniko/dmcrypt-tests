#!/bin/bash


if [ $# -lt 4 ]; then
	echo "$0 <path> <iterations> <\"module0 module1...\"> <\"bsize0 bsize1...\"> <\"seq0 seq1...\">" >&2
	exit 1
fi

INP_DIR=$1

RUNS=$2

MOD_LIST="$3"

BSIZE_LIST="$4"

SEQ_LIST="$5"

# compair each pair of modules
function generate_cmp() {
	local modules="$*"
	echo "Entering directory $DIR"
	for first in $modules ; do
		shift
		local modules_rest="$*"
		for second in $modules_rest ; do
			echo -n "comparing: 'log_$first/run_$run' with 'log_$second/run_$run'"
			./pstats.pl	$DIR/log_$first/run_$run/agg_1k_128k.log \
					$DIR/log_$second/run_$run/agg_1k_128k.log \
					> $res/"$first"-"$second".cmp 2> /dev/null || exit 1
			echo "...done"
		done
	done
}

run=0
while [ $run -lt $RUNS ]; do

	for seq in $SEQ_LIST ; do
		for bsize in $BSIZE_LIST ; do
			DIR=$INP_DIR/"$seq"_seq/bsize_$bsize
			res=$DIR/cmp/run_$run
			test -d $res || install -d $res || exit 1
			generate_cmp $MOD_LIST
		done
	done

	run=$[run+1]
done

