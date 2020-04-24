#!/bin/bash
set -e

CURDIR=$PWD
PRODUCT_DIR=$CURDIR/../product
TOPBAND_OUT_DIR=$CURDIR/../outputs
PLATFORM_DIR=$CURDIR/../platform
INTEGRATION_DIR=$TOPBAND_OUT_DIR/integration
TARGET_FILES_DIR=$INTEGRATION_DIR/target_files
TOOLS_DIR=$INTEGRATION_DIR/tools

TARGET="withoutkernel"
if [ "$1"x != ""x  ]; then
	TARGET=$1
fi
IMG_OTA="ota"
FSTYPE=ext4

export PATH=$TOOLS_DIR/bin:$PATH
export PATH=$TOOLS_DIR/releasetools:$PATH
export LD_LIBRARY_PATH=$TOOLS_DIR/lib64:$LD_LIBRARY_PATH

[ $(id -u) -eq 0 ] || FAKEROOT=fakeroot

if [ ! -d $TOPBAND_OUT_DIR ]; then
	mkdir $TOPBAND_OUT_DIR
fi

if [ $TARGET != $IMG_OTA -a $TARGET != "withoutkernel" ]; then
	echo "unknow target[${TARGET}], exit!!!" && myexit $LINENO
fi

myexit() {
	echo "mkimage.sh exit at $1" && exit $1;
}

make_bootimg () {
	if [ -d $TARGET_FILES_DIR/BOOT/RAMDISK ]; then
		if [ $TARGET == $IMG_OTA ]; then
			echo "create boot_ota.img with kernel... "
			mkbootfs $TARGET_FILES_DIR/BOOT/RAMDISK | minigzip > $TOPBAND_OUT_DIR/ramdisk.img
			truncate -s "%4" $TOPBAND_OUT_DIR/ramdisk.img
			mkbootimg --kernel $TOPBAND_OUT_DIR/kernel --ramdisk $TOPBAND_OUT_DIR/ramdisk.img --second $TOPBAND_OUT_DIR/resource.img --output $TOPBAND_OUT_DIR/boot_ota.img
			echo "done."
		else
			echo "create boot.img without kernel... "
			mkbootfs $TARGET_FILES_DIR/BOOT/RAMDISK | minigzip > $TOPBAND_OUT_DIR/ramdisk.img 
			truncate -s "%4" $TOPBAND_OUT_DIR/ramdisk.img
			mkkrnlimg $TOPBAND_OUT_DIR/ramdisk.img $TOPBAND_OUT_DIR/boot.img
			echo "done."
		fi
	else
		echo "$TARGET_FILES_DIR/RECOVERY/RAMDISK directory not exist!" && myexit $LINENO
	fi
}

make_recoveryimg () {
	if [ -d $TARGET_FILES_DIR/RECOVERY/RAMDISK ]; then
		if [ $TARGET == $IMG_OTA ]; then
			echo "create recovery_ota.img with kernel and resource... "
			mkbootfs $TARGET_FILES_DIR/RECOVERY/RAMDISK | minigzip > $TOPBAND_OUT_DIR/ramdisk-recovery.img
			truncate -s "%4" $TOPBAND_OUT_DIR/ramdisk-recovery.img
			mkbootimg --kernel $TOPBAND_OUT_DIR/kernel --ramdisk $TOPBAND_OUT_DIR/ramdisk-recovery.img --second $TOPBAND_OUT_DIR/resource.img  --output $TOPBAND_OUT_DIR/recovery_ota.img
			echo "done."
		else
			echo "create recovery.img without resource... "
			mkbootfs $TARGET_FILES_DIR/RECOVERY/RAMDISK | minigzip > $TOPBAND_OUT_DIR/ramdisk-recovery.img
			truncate -s "%4" $TOPBAND_OUT_DIR/ramdisk-recovery.img
			mkbootimg --kernel $TOPBAND_OUT_DIR/kernel --ramdisk $TOPBAND_OUT_DIR/ramdisk-recovery.img --output $TOPBAND_OUT_DIR/recovery.img
			echo "done."
		fi
	else
		echo "$TARGET_FILES_DIR/RECOVERY/RAMDISK directory not exist!" && myexit $LINENO
	fi
}

make_systemimg () {
	if [ -d $TARGET_FILES_DIR/SYSTEM ]; then
		echo "create system.img... "
		if [ "$FSTYPE" = "cramfs" ]
		then
			chmod -R 777 $TARGET_FILES_DIR/SYSTEM
			$FAKEROOT mkfs.cramfs $TARGET_FILES_DIR/SYSTEM $TOPBAND_OUT_DIR/system.img
		elif [ "$FSTYPE" = "squashfs" ]
		then
			chmod -R 777 $TARGET_FILES_DIR/SYSTEM
			mksquashfs $TARGET_FILES_DIR/SYSTEM $TOPBAND_OUT_DIR/system.img -all-root
		elif [ "$FSTYPE" = "ext3" ] || [ "$FSTYPE" = "ext4" ]
		then
			#size=`ls -l $ANDROID_OUT_DIR/system.img | awk '{print $5;}'`
			#[ $size -gt "0" ] || { echo "Please make first!!!" && myexit $LINENO; }
			
			size=419430400 #默认：400M
			OK=0
			while [ "$OK" = "0" ]; do
				make_ext4fs -l $size  -L system -S $TARGET_FILES_DIR/BOOT/RAMDISK/file_contexts -a system $TOPBAND_OUT_DIR/system.img $TARGET_FILES_DIR/SYSTEM && \
				tune2fs -c -1 -i 0 $TOPBAND_OUT_DIR/system.img && \
				OK=1 || size=$(($size + 5242880))
			done
			e2fsck -fyD $TOPBAND_OUT_DIR/system.img || true
		else
			mkdir -p $TOPBAND_OUT_DIR/2k $TOPBAND_OUT_DIR/4k
			mkyaffs2image -c 2032 -s 16 -f $TARGET_FILES_DIR/SYSTEM $TOPBAND_OUT_DIR/2k/system.img
			mkyaffs2image -c 4080 -s 16 -f $TARGET_FILES_DIR/SYSTEM $TOPBAND_OUT_DIR/4k/system.img
		fi
		echo "done."
	else
		echo "$TARGET_FILES_DIR/SYSTEM directory not exist!" && myexit $LINENO
	fi
}

echo ""
echo "----------- make bootimg start -----------"
make_bootimg
echo "----------- make bootimg end -------------"

echo ""
echo "----------- make recoveryimg start -------"
make_recoveryimg
echo "---------- make recoveryimg end ----------"

if [ $TARGET != $IMG_OTA ]; then
	echo ""
	echo "---------- make systemimg start ----------"
	make_systemimg
	echo "---------- make systemimg end ------------"
fi
