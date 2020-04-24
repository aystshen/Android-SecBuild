#!/bin/bash
set -e

CUR_DIR=$PWD
TOPBAND_OUT_DIR=$CUR_DIR/../outputs
PACKAGE_FILE=$TOPBAND_OUT_DIR/package-file_normal
FILENAME=update.img

myexit() {
	echo "mkupdate_img.sh exit at $1" && exit $1;
}

if [ $# == 2 ] ; then 
	PACKAGE_FILE=$1
	FILENAME=$2
fi

if [ -f ${PACKAGE_FILE} ]; then
	cp -vf ${PACKAGE_FILE} ./package-file
else
	echo "Error: No found ${PACKAGE_FILE}!!!" && myexit $LINENO
fi

echo ""
echo "--------- make update.img start ----------"
./afptool -pack ./ $TOPBAND_OUT_DIR/update.img
./rkImageMaker -RK32 $TOPBAND_OUT_DIR/MiniLoaderAll.bin $TOPBAND_OUT_DIR/update.img update.img -os_type:androidos
rm -rf $TOPBAND_OUT_DIR/update.img
mv -vf update.img $TOPBAND_OUT_DIR/$FILENAME
echo "--------- make update.img end ------------"
