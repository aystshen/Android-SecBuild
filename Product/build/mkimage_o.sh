#!/bin/bash
set -

usage()
{
	echo "USAGE: [-Abrsvo] [-t target]"
	echo "No ARGS means use default make option"
	echo "WHERE: -A = make all"
	echo "       -b = make boot.img"
	echo "       -r = make recovery.img"
	echo "       -s = make system.img"
	echo "       -v = make vendor.img"
	echo "       -o = make oem.img"
	echo "       -t = set target: ota | withoutkernel"
	echo "       -p = platform rk3326, px30, rk3288, rk3399"
	exit 1
}

MAKE_ALL=false
MAKE_BOOT=false
MAKE_RECOVERY=false
MAKE_SYSTEM=false
MAKE_VENDOR=false
MAKE_OEM=false
TARGET="withoutkernel"
IMG_OTA="ota"
PLATFORM="rk3288"

while getopts "Abrsvot:p:" opt
do
	case $opt in
		A)
		MAKE_ALL=true
		;;
		b)
		MAKE_BOOT=true
		;;
		r)
		MAKE_RECOVERY=true
		;;
		s)
		MAKE_SYSTEM=true
		;;
		v)
		MAKE_VENDOR=true
		;;
		o)
		MAKE_OEM=true
		;;
		t)
		TARGET=$OPTARG
		if [ $TARGET != $IMG_OTA -a $TARGET != "withoutkernel" ]; then
			echo "unknow target[${TARGET}], exit!!!" && exit 1
		fi
		;;
		p)
		PLATFORM=$OPTARG
		;;
		h)
		usage ;;
		?)
		usage ;;
	esac
done

CURDIR=$PWD
PRODUCT_DIR=$CURDIR/../product
TOPBAND_OUT_DIR=$CURDIR/../outputs
PLATFORM_DIR=$CURDIR/../platform
INTEGRATION_DIR=$TOPBAND_OUT_DIR/integration
TARGET_FILES_DIR=$INTEGRATION_DIR/target_files
TOOLS_DIR=$INTEGRATION_DIR/tools

PLATFORM_VERSION="8.1.0"
PLATFORM_SECURITY_PATCH="2018-10-05"
TARGET_BUILD_VARIANT="userdebug"
BOARD_USE_SPARSE_SYSTEM_IMAGE="true"
FSTYPE="ext4"

export PATH=$TOOLS_DIR/bin:$PATH
export PATH=$TOOLS_DIR/releasetools:$PATH
export LD_LIBRARY_PATH=$TOOLS_DIR/lib64:$LD_LIBRARY_PATH

[ $(id -u) -eq 0 ] || FAKEROOT=fakeroot

if [ ! -d $TOPBAND_OUT_DIR ]; then
	mkdir $TOPBAND_OUT_DIR || myexit $LINENO
fi

myexit() {
	echo "mkimage.sh exit at $1" && exit $1;
}

show_variable() {
	echo ""
	echo "PLATFORM_VERSION=$PLATFORM_VERSION"
	echo "PLATFORM_SECURITY_PATCH=$PLATFORM_SECURITY_PATCH"
	echo "TARGET_BUILD_VARIANT=$TARGET_BUILD_VARIANT"
	echo "BOARD_USE_SPARSE_SYSTEM_IMAGE=$BOARD_USE_SPARSE_SYSTEM_IMAGE"
	echo ""
}

setup_env() {
	#set jdk version
	export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
	export PATH=$JAVA_HOME/bin:$PATH
	export CLASSPATH=.:$JAVA_HOME/lib:$JAVA_HOME/lib/tools.jar
}

make_bootimg () {
	echo "create boot.img... $TARGET"
	if [ -d $TARGET_FILES_DIR/BOOT/RAMDISK ]; then
		if [ $TARGET == $IMG_OTA ]; then
			echo "create boot_ota.img with kernel... "
			mkbootfs $TARGET_FILES_DIR/BOOT/RAMDISK | minigzip > $TOPBAND_OUT_DIR/ramdisk.img || myexit $LINENO
			truncate -s "%4" $TOPBAND_OUT_DIR/ramdisk.img || myexit $LINENO
			mkbootimg --kernel $TOPBAND_OUT_DIR/kernel --ramdisk $TOPBAND_OUT_DIR/ramdisk.img --second $TOPBAND_OUT_DIR/resource.img  --os_version $PLATFORM_VERSION --os_patch_level $PLATFORM_SECURITY_PATCH --cmdline buildvariant=$TARGET_BUILD_VARIANT --output $TOPBAND_OUT_DIR/boot_ota.img || myexit $LINENO
			echo "done."
		else
			echo "create boot.img without kernel... "
			mkbootfs $TARGET_FILES_DIR/BOOT/RAMDISK | minigzip > $TOPBAND_OUT_DIR/ramdisk.img  || myexit $LINENO
			truncate -s "%4" $TOPBAND_OUT_DIR/ramdisk.img || myexit $LINENO
			mkkrnlimg $TOPBAND_OUT_DIR/ramdisk.img $TOPBAND_OUT_DIR/boot.img || myexit $LINENO
		fi
	else
		echo "$TARGET_FILES_DIR/BOOT/RAMDISK directory not exist!" && myexit $LINENO
	fi
	echo "done."
}

make_recoveryimg () {
	echo "create recovery.img... "
	if [ -d $TARGET_FILES_DIR/RECOVERY/RAMDISK ]; then
		if [ $TARGET == $IMG_OTA ]; then
			echo "create recovery_ota.img with kernel and resource... "
			mkbootfs $TARGET_FILES_DIR/RECOVERY/RAMDISK | minigzip > $TOPBAND_OUT_DIR/ramdisk-recovery.img || myexit $LINENO
			truncate -s "%4" $TOPBAND_OUT_DIR/ramdisk-recovery.img || myexit $LINENO
			mkbootimg --kernel $TOPBAND_OUT_DIR/kernel --ramdisk $TOPBAND_OUT_DIR/ramdisk-recovery.img --second $TOPBAND_OUT_DIR/resource.img --os_version $PLATFORM_VERSION --os_patch_level $PLATFORM_SECURITY_PATCH --cmdline buildvariant=$TARGET_BUILD_VARIANT --output $TOPBAND_OUT_DIR/recovery_ota.img || myexit $LINENO
			echo "done."
		else
			echo "create recovery.img without resource... "
			mkbootfs $TARGET_FILES_DIR/RECOVERY/RAMDISK | minigzip > $TOPBAND_OUT_DIR/ramdisk-recovery.img || myexit $LINENO
			truncate -s "%4" $TOPBAND_OUT_DIR/ramdisk-recovery.img || myexit $LINENO
			mkkrnlimg $TOPBAND_OUT_DIR/ramdisk-recovery.img $TOPBAND_OUT_DIR/recovery.img || myexit $LINENO
		fi
	else
		echo "$TARGET_FILES_DIR/RECOVERY/RAMDISK directory not exist!" && myexit $LINENO
	fi
	echo "done."
}

make_systemimg () {
	echo "create system.img... "
	if [ -d $TARGET_FILES_DIR/SYSTEM ]; then
		if [ "$FSTYPE" = "cramfs" ]
		then
			chmod -R 777 $TARGET_FILES_DIR/SYSTEM || myexit $LINENO
			$FAKEROOT mkfs.cramfs $TARGET_FILES_DIR/SYSTEM $TOPBAND_OUT_DIR/system.img || myexit $LINENO
		elif [ "$FSTYPE" = "squashfs" ]
		then
			chmod -R 777 $TARGET_FILES_DIR/SYSTEM || myexit $LINENO
			mksquashfs $TARGET_FILES_DIR/SYSTEM $TOPBAND_OUT_DIR/system.img -all-root || myexit $LINENO
		elif [ "$FSTYPE" = "ext3" ] || [ "$FSTYPE" = "ext4" ]
		then
			if [ "$BOARD_USE_SPARSE_SYSTEM_IMAGE" = "true" ]; then
				if [ $TARGET != $IMG_OTA ]; then
					python $TOOLS_DIR/releasetools/build_image.py \
					$TARGET_FILES_DIR/SYSTEM $TOPBAND_OUT_DIR/system_image_info.txt \
					$TOPBAND_OUT_DIR/system.img $TARGET_FILES_DIR/SYSTEM || myexit $LINENO
				fi
				python $TOOLS_DIR/releasetools/sparse_tool.py $TOPBAND_OUT_DIR/system.img || myexit $LINENO
				mv $TOPBAND_OUT_DIR/system.img.out $TOPBAND_OUT_DIR/system.img || myexit $LINENO
			else
				system_size=`ls -l $TOPBAND_OUT_DIR/system.img | awk '{print $5;}'`
				[ $system_size -gt "0" ] || { echo "Please make first!!!" && myexit $LINENO; }
				
				ok=0
				while [ "$ok" = "0" ]; do
					make_ext4fs -l $system_size  -L system -S $TARGET_FILES_DIR/BOOT/RAMDISK/file_contexts -a system $TOPBAND_OUT_DIR/system.img $TARGET_FILES_DIR/SYSTEM && \
					tune2fs -c -1 -i 0 $TOPBAND_OUT_DIR/system.img && \
					ok=1 || system_size=$(($system_size + 5242880))
				done
				e2fsck -fyD $TOPBAND_OUT_DIR/system.img || true
			fi
		else
			mkdir -p $TOPBAND_OUT_DIR/2k $TOPBAND_OUT_DIR/4k
			mkyaffs2image -c 2032 -s 16 -f $TARGET_FILES_DIR/SYSTEM $TOPBAND_OUT_DIR/2k/system.img || myexit $LINENO
			mkyaffs2image -c 4080 -s 16 -f $TARGET_FILES_DIR/SYSTEM $TOPBAND_OUT_DIR/4k/system.img || myexit $LINENO
		fi
	else
		echo "$TARGET_FILES_DIR/SYSTEM directory not exist!" && myexit $LINENO
	fi
	
	echo "done."
}
	
make_vendor() {
	echo "create vendor.img... "
	if [ -d $TARGET_FILES_DIR/VENDOR  ]; then
		if [ $TARGET != $IMG_OTA ]; then
			python $TOOLS_DIR/releasetools/build_image.py \
			$TARGET_FILES_DIR/VENDOR $TOPBAND_OUT_DIR/system_image_info.txt \
			$TOPBAND_OUT_DIR/vendor.img $TARGET_FILES_DIR/SYSTEM || myexit $LINENO
		fi
		python $TOOLS_DIR/releasetools/sparse_tool.py $TOPBAND_OUT_DIR/vendor.img || myexit $LINENO
		mv $TOPBAND_OUT_DIR/vendor.img.out $TOPBAND_OUT_DIR/vendor.img || myexit $LINENO
	else
		echo "$TARGET_FILES_DIR/VENDOR directory not exist!" && myexit $LINENO
	fi
	echo "done."
}

make_oem() {
	echo "create oem.img..."
	if [ -d $TARGET_FILES_DIR/OEM ]; then
		if [ $TARGET != $IMG_OTA ]; then
			python $TOOLS_DIR/releasetools/build_image.py \
			$TARGET_FILES_DIR/OEM $TOPBAND_OUT_DIR/system_image_info.txt \
			$TOPBAND_OUT_DIR/oem.img $TARGET_FILES_DIR/SYSTEM || myexit $LINENO
		fi
		python $TOOLS_DIR/releasetools/sparse_tool.py $TOPBAND_OUT_DIR/oem.img || myexit $LINENO
		mv $TOPBAND_OUT_DIR/oem.img.out $TOPBAND_OUT_DIR/oem.img || myexit $LINENO
	else 
		echo "$TARGET_FILES_DIR/OEM directory not exist!" && myexit $LINENO
	fi
	echo "done."
}

make_start() {
	echo ""
	echo "================ make image start =============="
	
	grep -wq "system/extras/verity/build_verity_metadata.py" $TOOLS_DIR/releasetools/build_image.py > /dev/null
	if [ $? -eq 0 ]; then
		sed -i "s#system/extras/verity/build_verity_metadata.py#build_verity_metadata.py#g" $TOOLS_DIR/releasetools/build_image.py || myexit $LINENO
	fi
	
	grep -wq "build/target/product/security/verity" $TOPBAND_OUT_DIR/system_image_info.txt > /dev/null
	if [ $? -eq 0 ]; then
		sed -i "s#build/target/product/security/verity#${TOOLS_DIR}/bin/verity#g" $TOPBAND_OUT_DIR/system_image_info.txt || myexit $LINENO
		if [ $PLATFORM == "rk3326" ]; then
			sed -i "s#out/target/product/rk3326_mid/obj/ETC/file_contexts.bin_intermediates/file_contexts.bin#${TOPBAND_OUT_DIR}/file_contexts.bin#g" $TOPBAND_OUT_DIR/system_image_info.txt || myexit $LINENO
		elif [ $PLATFORM == "px30" ]; then
			sed -i "s#out/target/product/px30_evb/obj/ETC/file_contexts.bin_intermediates/file_contexts.bin#${TOPBAND_OUT_DIR}/file_contexts.bin#g" $TOPBAND_OUT_DIR/system_image_info.txt || myexit $LINENO
		elif [ $PLATFORM == "rk3399" ]; then
			sed -i "s#out/target/product/rk3399_mid/obj/ETC/file_contexts.bin_intermediates/file_contexts.bin#${TOPBAND_OUT_DIR}/file_contexts.bin#g" $TOPBAND_OUT_DIR/system_image_info.txt || myexit $LINENO
		else
			sed -i "s#out/target/product/rk3288/obj/ETC/file_contexts.bin_intermediates/file_contexts.bin#${TOPBAND_OUT_DIR}/file_contexts.bin#g" $TOPBAND_OUT_DIR/system_image_info.txt || myexit $LINENO
		fi
	fi

	if [ "$MAKE_ALL" = true ] || [ "$MAKE_BOOT" = true ] ; then
		make_bootimg
	fi
	
	if [ "$MAKE_ALL" = true ] || [ "$MAKE_RECOVERY" = true ] ; then
		make_recoveryimg
	fi
	
	if [ "$MAKE_ALL" = true ] || [ "$MAKE_SYSTEM" = true ] ; then
		make_systemimg
	fi
	
	if [ "$MAKE_ALL" = true ] || [ "$MAKE_VENDOR" = true ] ; then
		make_vendor
	fi
	
	if [ "$MAKE_ALL" = true ] || [ "$MAKE_OEM" = true ] ; then
		make_oem
	fi
	
	echo "================ make image end ================"
	echo ""
}

setup_env
show_variable
make_start
