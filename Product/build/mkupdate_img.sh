#!/bin/bash
set -e

usage()
{
	echo "USAGE: [-t target] [-p package_file] [-f filename]"
	echo "No ARGS means use default make option"
	echo "WHERE: -t = set target"
	echo "       -p = set package_file"
	echo "       -f = set output filename"
	exit 1
}

CUR_DIR=$PWD
TOPBAND_OUT_DIR=$CUR_DIR/../outputs
TARGET="rk3128"
PACKAGE_FILE=$TOPBAND_OUT_DIR/package-file_normal
FILENAME=update.img

while getopts "t:p:f:" opt
do
	case $opt in
		t)
		TARGET=$OPTARG
		;;
		p)
		PACKAGE_FILE=$OPTARG
		;;
		f)
		FILENAME=$OPTARG
		;;
		h)
		usage ;;
		?)
		usage ;;
	esac
done

myexit() {
	echo "mkupdate_img.sh exit at $1" && exit $1;
}

if [ -f ${PACKAGE_FILE} ]; then
	cp -vf ${PACKAGE_FILE} ./package-file
else
	echo "Error: No found ${PACKAGE_FILE}!!!" && myexit $LINENO
fi

echo ""
echo "--------- make update.img start ----------"

./afptool -pack ./ $TOPBAND_OUT_DIR/update.img
if [ $TARGET == "rk3288" ]; then
	./rkImageMaker -RK32 $TOPBAND_OUT_DIR/MiniLoaderAll.bin $TOPBAND_OUT_DIR/update.img update.img -os_type:androidos
elif [ $TARGET == "rk3368" ]; then
	./rkImageMaker -RK330A $TOPBAND_OUT_DIR/RK3368MiniLoaderAll_V2.53.bin $TOPBAND_OUT_DIR/update.img update.img -os_type:androidos
elif [ $TARGET == "rk3326" ]; then
	./rkImageMaker -RK3326 $TOPBAND_OUT_DIR/MiniLoaderAll.bin $TOPBAND_OUT_DIR/update.img update.img -os_type:androidos
elif [ $TARGET == "px30" ]; then
	./rkImageMaker -RKPX30 $TOPBAND_OUT_DIR/MiniLoaderAll.bin $TOPBAND_OUT_DIR/update.img update.img -os_type:androidos
elif [ $TARGET == "rk3399" ]; then
	./rkImageMaker -RK330C $TOPBAND_OUT_DIR/MiniLoaderAll.bin $TOPBAND_OUT_DIR/update.img update.img -os_type:androidos
else
	./rkImageMaker -RK312A $TOPBAND_OUT_DIR/RK3128MiniLoaderAll.bin $TOPBAND_OUT_DIR/update.img update.img -os_type:androidos
fi

rm -rf $TOPBAND_OUT_DIR/update.img
mv -vf update.img $TOPBAND_OUT_DIR/$FILENAME

echo "--------- make update.img end ------------"
