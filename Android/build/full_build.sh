#!/bin/bash

usage()
{
	echo "USAGE: [h] [-t target] [-d device]"
	echo "No ARGS means use default build option"
	echo "WHERE: -t = set target"
	echo "       -d = set device"
	echo "       -h = help"
	exit 1
}

DEVICE="DEFAULT"
TARGET="rk3288"
CUR_DIR=$PWD
DEVICE_DIR=$CUR_DIR/../device

while getopts "t:d:" opt
do
	case $opt in
		t)
		TARGET=$OPTARG
		;;
		d)
		DEVICE=$OPTARG
		;;
		h)
		usage ;;
		?)
		usage ;;
	esac
done

myexit() {
	echo "full_build.sh exit at $1" && exit $1;
}

parse_config() {
	while read line
	do
		if [[ "${line}" == *=* ]]; then	
			key=`echo ${line} | awk -F"=" '{print $1}'`
			value=`echo ${line} | awk -F"=" '{print $2}'`
			echo "[key]: $key, [value]: $value"
			
			if [ ${key} == "UBOOT_DEFCONFIG" ]; then
				UBOOT_DEFCONFIG=${value}
			elif [ ${key} == "KERNEL_DEFCONFIG" ]; then
				KERNEL_DEFCONFIG=${value}
			elif [ ${key} == "KERNEL_DTS" ]; then
				KERNEL_DTS=${value}
			fi
		fi
	done < $DEVICE_DIR/$DEVICE/config.ini
	
	# 三者其中之一为空，解析失败，脚本终止
	if [ -z "$UBOOT_DEFCONFIG" ] || [ -z "$KERNEL_DEFCONFIG" ] || [ -z "$KERNEL_DTS" ]; then
		echo "Error: parse config.ini failed!" && myexit $LINENO
	fi
}

if [ ! $DEVICE ]; then
	echo "usage: "
	for file in $DEVICE_DIR/*
	do
		if test -d ${file}
		then
			echo "	[build.sh ${file##*/}]"
		fi
	done
	echo ""
	myexit $LINENO
elif [ ! -d $DEVICE_DIR/$DEVICE ]; then
	echo "Device: $DEVICE not exist!!!" && myexit $LINENO
fi

parse_config

echo ""
echo "================= full_build start ============="
echo ""
echo "================================================"
echo "TARGET=${TARGET}"
echo "UBOOT_DEFCONFIG=${UBOOT_DEFCONFIG}"
echo "KERNEL_DEFCONFIG=${KERNEL_DEFCONFIG}"
echo "KERNEL_DTS=${KERNEL_DTS}"
echo "================================================"
echo ""

startTime=`date` 

./build.sh -A -t ${TARGET} -U ${UBOOT_DEFCONFIG} -K ${KERNEL_DEFCONFIG} -d ${KERNEL_DTS} || myexit $LINENO
./pack.sh ${TARGET} || myexit $LINENO 

endTime=`date` 

echo "================= full_build end ==============="
echo ""
echo "================================================"
echo "start full_build time:${startTime}"
echo "end full_build time:${endTime}"
echo "================================================"
echo ""

