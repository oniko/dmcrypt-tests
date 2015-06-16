#!/bin/bash


fail() {
	echo $@
	exit 1
}


# default chunksize is page size (expresed in 512B sectors)
TST_CHSIZE=${TST_CHSIZE:-8}
TST_TGT=${TST_TGT:-"striped"}
TST_DEV=${TST_DEV:-"tst_"$TST_TGT}

test $# -gt 1 || fail "Requires at least one device"

num_devs=$#

min_dev_size=$(blockdev --getsz $1)

table_args=""
offset=0

for i in $@; do
	tmp_size=$(blockdev --getsz $i)
	test $tmp_size -ge $min_dev_size || min_dev_size=$tmp_size
	table_args="$table_args $i $offset"
done

striped_dev_size=$[min_dev_size*num_devs]
striped_dev_size=$[striped_dev_size-(striped_dev_size%(TST_CHSIZE*num_devs))]

table="0 $striped_dev_size $TST_TGT $num_devs $TST_CHSIZE $table_args"

echo $table
dmsetup create $TST_DEV --table "$table"
