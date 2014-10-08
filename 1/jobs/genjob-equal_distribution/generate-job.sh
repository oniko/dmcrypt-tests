#!/bin/bash

TEMPLATE=generated_job_file.XXXXXX

ALIGNMENT=4096

function div_round_up() {
	echo $[($1+$2-1)/$2]
}

function div_round_up_modulo() {
	local tmp=$(div_round_up $1 $2)
	echo $[tmp*$2]
}

# #1 target dir
# $2 bdev size (in bytes)
# $3 jobs_per node
# $4 limit (use 0 when in doubt)
# $5 cpus_allowed_string
function generate_job() {
	local tmpdir=$1
	shift
	local bdev_size=$1
	shift
	local jobs_per_node=$1
	shift
	local io_limit_per_job=$1
	shift
	local cpus_allowed=$@

	local node_offset=$[bdev_size/$#]
	local job_offset=$[node_offset/jobs_per_node]
	test $job_offset -gt 0 || {
		echo "job_offset <= 0" >&2
		exit 1
	}

	test -d $tmpdir || mkdir -p $tmpdir

	test $io_limit_per_job -le $job_offset || io_limit_per_job=$job_offset

	TMPFILE=$(mktemp --tmpdir=$tmpdir $TEMPLATE)

	cat $(dirname $0)/0000_job_header >> $TMPFILE
	{
		echo "; generated part of file follows"
		echo ";"
		echo "; tmpdir=$tmpdir"
		echo "; bdev_size=$bdev_size"
		echo "; jobs_per_node=$jobs_per_node"
		echo "; io_limit_per_job=$io_limit_per_job"
		echo "; node_count=$#"
		echo ";"
		local node_n=0
		for cpus in $cpus_allowed ; do
			local job_on_node=0
			while [ $job_on_node -lt $jobs_per_node ] ; do

				# generated job content
				echo "[node_$[node_n]_job$job_on_node]"
				echo "cpus_allowed=$cpus"
				local tmp=$[(node_offset*node_n)+(job_offset*job_on_node)]
				tmp=$(div_round_up_modulo $tmp $ALIGNMENT)
				echo "offset=$tmp"
				echo "io_limit=$io_limit_per_job"
				echo

				job_on_node=$[job_on_node+1]
			done
			node_n=$[node_n+1]
		done
		echo "; -- end --"
	} >> $TMPFILE

	echo $TMPFILE
}

generate_job $@
