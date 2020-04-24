#!/bin/bash

usage()
{
	echo "USAGE: [-Abrsvoulkpmc] [-t target]"
	echo "No ARGS means use default make option"
	echo "WHERE: -A = make all"
	echo "       -b = make boot.img"
	echo "       -r = make recovery.img"
	echo "       -s = make system.img"
	echo "       -v = make vendor.img"
	echo "       -o = make oem.img"
	echo "       -u = make u-boot.img"
	echo "       -l = make loader.bin"
	echo "       -k = make kernel.img"
	echo "       -p = make parameter.txt"
	echo "       -m = make misc.img"
	echo "       -c = make lcdparam.img"
	echo "       -t = set target: ota | withoutkernel"
	exit 1
}

MAKE_ALL=false
MAKE_BOOT=false
MAKE_RECOVERY=false
MAKE_SYSTEM=false
MAKE_VENDOR=false
MAKE_OEM=false
MAKE_UBOOT=false
MAKE_LOADER=false
MAKE_KERNEL=false
MAKE_PARAMETER=false
MAKE_MISC=false
MAKE_LCDPARAM=false
TARGET="withoutkernel"
IMG_OTA="ota"

while getopts "Abrsvoulkpmct:" opt
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
		u)
		MAKE_UBOOT=true
		;;
		l)
		MAKE_LOADER=true
		;;
		k)
		MAKE_KERNEL=true
		;;
		p)
		MAKE_PARAMETER=true
		;;
		m)
		MAKE_MISC=true
		;;
		c)
		MAKE_LCDPARAM=true
		;;
		t)
		TARGET=$OPTARG
		if [ $TARGET != $IMG_OTA -a $TARGET != "withoutkernel" ]; then
			echo "unknow target[${TARGET}], exit!!!" && exit 1
		fi
		;;
		h)
		usage ;;
		?)
		usage ;;
	esac
done

CUR_DIR=$PWD
ANDROID_DIR=$CUR_DIR/../..
TOPBAND_OUT_DIR=$CUR_DIR/../outputs
UBOOT_PATH=$ANDROID_DIR/u-boot
KERNEL_PATH=$ANDROID_DIR/kernel

source $ANDROID_DIR/build/envsetup.sh >/dev/null && setpaths

export PATH=$ANDROID_BUILD_PATHS:$PATH

TARGET_PRODUCT=`get_build_var TARGET_PRODUCT`
TARGET_HARDWARE=`get_build_var TARGET_BOARD_HARDWARE`
TARGET_BOARD_PLATFORM=`get_build_var TARGET_BOARD_PLATFORM`
TARGET_DEVICE_DIR=`get_build_var TARGET_DEVICE_DIR`
PLATFORM_VERSION=`get_build_var PLATFORM_VERSION`
PLATFORM_SECURITY_PATCH=`get_build_var PLATFORM_SECURITY_PATCH`
TARGET_BUILD_VARIANT=`get_build_var TARGET_BUILD_VARIANT`
BOARD_SYSTEMIMAGE_PARTITION_SIZE=`get_build_var BOARD_SYSTEMIMAGE_PARTITION_SIZE`
BOARD_USE_SPARSE_SYSTEM_IMAGE=`get_build_var BOARD_USE_SPARSE_SYSTEM_IMAGE`
TARGET_ARCH=`get_build_var TARGET_ARCH`
TARGET_OUT_VENDOR=`get_build_var TARGET_OUT_VENDOR`
TARGET_BASE_PARAMETER_IMAGE=`get_build_var TARGET_BASE_PARAMETER_IMAGE`
HIGH_RELIABLE_RECOVERY_OTA=`get_build_var HIGH_RELIABLE_RECOVERY_OTA`
FSTYPE="ext4"

[ $(id -u) -eq 0 ] || FAKEROOT=fakeroot

if [ ! -d $TOPBAND_OUT_DIR ]; then
	mkdir $TOPBAND_OUT_DIR || myexit $LINENO
elif [  "$MAKE_ALL" = true  ]; then
	rm -rf $TOPBAND_OUT_DIR/*
fi

myexit() {
	echo "mkimage.sh exit at $1" && exit $1;
}

show_variable() {
	echo ""
	echo "TARGET_PRODUCT=$TARGET_PRODUCT"
	echo "TARGET_HARDWARE=$TARGET_HARDWARE"
	echo "TARGET_BOARD_PLATFORM=$TARGET_BOARD_PLATFORM"
	echo "TARGET_DEVICE_DIR=$TARGET_DEVICE_DIR"
	echo "PLATFORM_VERSION=$PLATFORM_VERSION"
	echo "PLATFORM_SECURITY_PATCH=$PLATFORM_SECURITY_PATCH"
	echo "TARGET_BUILD_VARIANT=$TARGET_BUILD_VARIANT"
	echo "BOARD_SYSTEMIMAGE_PARTITION_SIZE=$BOARD_SYSTEMIMAGE_PARTITION_SIZE"
	echo "BOARD_USE_SPARSE_SYSTEM_IMAGE=$BOARD_USE_SPARSE_SYSTEM_IMAGE"
	echo "TARGET_ARCH=$TARGET_ARCH"
	echo "TARGET_OUT_VENDOR=$TARGET_OUT_VENDOR"
	echo "TARGET_BASE_PARAMETER_IMAGE=$TARGET_BASE_PARAMETER_IMAGE"
	echo "HIGH_RELIABLE_RECOVERY_OTA=$HIGH_RELIABLE_RECOVERY_OTA"
	echo ""
}

setup_env() {
	#set jdk version
	export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
	export PATH=$JAVA_HOME/bin:$PATH
	export CLASSPATH=.:$JAVA_HOME/lib:$JAVA_HOME/lib/tools.jar
}

check_kernel() {
	board_config=$ANDROID_DIR/device/rockchip/common/device.mk
	kernel_src_path=`grep TARGET_PREBUILT_KERNEL ${board_config} |grep "^\s*TARGET_PREBUILT_KERNEL *:= *[\w]*\s" |awk  '{print $3}'`
	
	if [ ! -f $OUT/kernel ]; then
		echo "$OUT/kernel not found!"
		read -p "Copy kernel from TARGET_PREBUILT_KERNEL[$kernel_src_path] (y/n) n to exit?"
		if [ "$REPLY" == "y" ]
		then
			[ -f $kernel_src_path ]  || \
				echo -n "Fatal! TARGET_PREBUILT_KERNEL not eixit! " || \
				echo -n "Check you configuration in [${board_config}] " || myexit $LINENO
			cp ${kernel_src_path} $OUT/kernel
		else
			myexit $LINENO
		fi
	fi
}

make_bootimg () {
	echo "create boot.img... "
	if [ -d $OUT/root ]; then
		if [ $TARGET == $IMG_OTA ]; then
			echo "create boot_ota.img with kernel... "
			mkbootfs $OUT/root | minigzip > $TOPBAND_OUT_DIR/ramdisk.img || myexit $LINENO
			truncate -s "%4" $TOPBAND_OUT_DIR/ramdisk.img || myexit $LINENO
			mkbootimg --kernel $OUT/kernel --ramdisk $TOPBAND_OUT_DIR/ramdisk.img --second kernel/resource.img  --os_version $PLATFORM_VERSION --os_patch_level $PLATFORM_SECURITY_PATCH --cmdline buildvariant=$TARGET_BUILD_VARIANT --output $TOPBAND_OUT_DIR/boot_ota.img || myexit $LINENO
			echo "done."
		else
			echo "create boot.img without kernel... "
			mkbootfs $OUT/root | minigzip > $TOPBAND_OUT_DIR/ramdisk.img  || myexit $LINENO
			truncate -s "%4" $TOPBAND_OUT_DIR/ramdisk.img || myexit $LINENO
			rkst/mkkrnlimg $TOPBAND_OUT_DIR/ramdisk.img $TOPBAND_OUT_DIR/boot.img || myexit $LINENO
		fi
	else
		echo "$OUT/root directory not exist!" && myexit $LINENO
	fi
	echo "done."
}

make_recoveryimg () {
	echo "create recovery.img... "
	if [ -d $OUT/recovery/root ]; then
		if [ $TARGET == $IMG_OTA ]; then
			echo "create recovery_ota.img with kernel and resource... "
			mkbootfs $OUT/recovery/root | minigzip > $TOPBAND_OUT_DIR/ramdisk-recovery.img || myexit $LINENO
			truncate -s "%4" $TOPBAND_OUT_DIR/ramdisk-recovery.img || myexit $LINENO
			mkbootimg --kernel $OUT/kernel --ramdisk $TOPBAND_OUT_DIR/ramdisk-recovery.img --second kernel/resource.img --os_version $PLATFORM_VERSION --os_patch_level $PLATFORM_SECURITY_PATCH --cmdline buildvariant=$TARGET_BUILD_VARIANT --output $TOPBAND_OUT_DIR/recovery_ota.img || myexit $LINENO
			echo "done."
		else
			echo "create recovery.img without resource... "
			mkbootfs $OUT/recovery/root | minigzip > $TOPBAND_OUT_DIR/ramdisk-recovery.img || myexit $LINENO
			truncate -s "%4" $TOPBAND_OUT_DIR/ramdisk-recovery.img || myexit $LINENO
			mkbootimg --kernel $OUT/kernel --ramdisk $TOPBAND_OUT_DIR/ramdisk-recovery.img --output $TOPBAND_OUT_DIR/recovery.img || myexit $LINENO
		fi
	else
		echo "$OUT/recovery/root directory not exist!" && myexit $LINENO
	fi
	echo "done."
}

make_systemimg () {
	echo "create system.img... "
	if [ -d $OUT/system ]; then
		if [ "$FSTYPE" = "cramfs" ]
		then
			chmod -R 777 $OUT/system || myexit $LINENO
			$FAKEROOT mkfs.cramfs $OUT/system $TOPBAND_OUT_DIR/system.img || myexit $LINENO
		elif [ "$FSTYPE" = "squashfs" ]
		then
			chmod -R 777 $OUT/system || myexit $LINENO
			mksquashfs $OUT/system $TOPBAND_OUT_DIR/system.img -all-root || myexit $LINENO
		elif [ "$FSTYPE" = "ext3" ] || [ "$FSTYPE" = "ext4" ]
		then
			if [ "$BOARD_USE_SPARSE_SYSTEM_IMAGE" = "true" ]; then
				if [ $TARGET != $IMG_OTA ]; then
					python build/tools/releasetools/build_image.py \
					$OUT/system $OUT/obj/PACKAGING/systemimage_intermediates/system_image_info.txt \
					$OUT/system.img $OUT/system || myexit $LINENO
				fi
				python device/rockchip/common/sparse_tool.py $OUT/system.img || myexit $LINENO
				mv $OUT/system.img.out $OUT/system.img || myexit $LINENO
				cp -f $OUT/system.img $TOPBAND_OUT_DIR/system.img || myexit $LINENO
			else
				system_size=`ls -l $OUT/system.img | awk '{print $5;}'`
				[ $system_size -gt "0" ] || { echo "Please make first!!!" && myexit $LINENO; }
				
				ok=0
				while [ "$ok" = "0" ]; do
					make_ext4fs -l $system_size  -L system -S $OUT/root/file_contexts -a system $TOPBAND_OUT_DIR/system.img $OUT/system && \
					tune2fs -c -1 -i 0 $TOPBAND_OUT_DIR/system.img && \
					ok=1 || system_size=$(($system_size + 5242880))
				done
				e2fsck -fyD $TOPBAND_OUT_DIR/system.img || true
			fi
		else
			mkdir -p $TOPBAND_OUT_DIR/2k $TOPBAND_OUT_DIR/4k
			mkyaffs2image -c 2032 -s 16 -f $OUT/system $TOPBAND_OUT_DIR/2k/system.img || myexit $LINENO
			mkyaffs2image -c 4080 -s 16 -f $OUT/system $TOPBAND_OUT_DIR/4k/system.img || myexit $LINENO
		fi
	else
		echo "$OUT/system directory not exist!" && myexit $LINENO
	fi
	
	echo "done."
}

make_misc() {
	echo -n "create misc.img.... "
	cp -a $ANDROID_DIR/rkst/Image/misc.img $TOPBAND_OUT_DIR/misc.img
	cp -a $ANDROID_DIR/rkst/Image/pcba_small_misc.img $TOPBAND_OUT_DIR/pcba_small_misc.img
	cp -a $ANDROID_DIR/rkst/Image/pcba_whole_misc.img $TOPBAND_OUT_DIR/pcba_whole_misc.img
	
	cp -vf $CUR_DIR/package-file_normal $TOPBAND_OUT_DIR || myexit $LINENO
	cp -vf $CUR_DIR/package-file_pcba_small $TOPBAND_OUT_DIR || myexit $LINENO
	cp -vf $CUR_DIR/package-file_pcba_whole $TOPBAND_OUT_DIR || myexit $LINENO
	echo "done."
}
	
make_vendor() {
	echo "create vendor.img... "
	if [ `grep "CONFIG_WIFI_BUILD_MODULE=y" $KERNEL_PATH/.config` ]; then
		echo "Install wifi ko to $TARGET_OUT_VENDOR/lib/modules/wifi/"
		mkdir -p $TARGET_OUT_VENDOR/lib/modules/wifi
		find $ANDROID_DIR/kernel/drivers/net/wireless/rockchip_wlan/*  -name "*.ko" | xargs -n1 -i cp {} $TARGET_OUT_VENDOR/lib/modules/wifi/
	fi
	
	if [ -d $OUT/vendor ]; then
		if [ $TARGET != $IMG_OTA ]; then
			python build/tools/releasetools/build_image.py \
			$OUT/vendor $OUT/obj/PACKAGING/systemimage_intermediates/system_image_info.txt \
			$OUT/vendor.img $OUT/system || myexit $LINENO
		fi
		python device/rockchip/common/sparse_tool.py $OUT/vendor.img || myexit $LINENO
		mv $OUT/vendor.img.out $OUT/vendor.img || myexit $LINENO
		cp -f $OUT/vendor.img $TOPBAND_OUT_DIR/vendor.img || myexit $LINENO
	else
		echo "$OUT/vendor directory not exist!" && myexit $LINENO
	fi
	echo "done."
}

make_oem() {
	echo "create oem.img..."
	if [ -d $OUT/oem ]; then
		if [ $TARGET != $IMG_OTA ]; then
		  python build/tools/releasetools/build_image.py \
		  $OUT/oem $OUT/obj/PACKAGING/systemimage_intermediates/system_image_info.txt \
		  $OUT/oem.img $OUT/system || myexit $LINENO
		fi
		python device/rockchip/common/sparse_tool.py $OUT/oem.img || myexit $LINENO
		mv $OUT/oem.img.out $OUT/oem.img || myexit $LINENO
		cp -f $OUT/oem.img $TOPBAND_OUT_DIR/oem.img || myexit $LINENO
	else 
		echo "$OUT/oem directory not exist!" && myexit $LINENO
	fi
	echo "done."
}

make_lcdparam() {
	echo "create lcdparam.img..."
	cp -vf $CUR_DIR/lcdparam.img $TOPBAND_OUT_DIR/lcdparam.img || myexit $LINENO
	echo "done."
}

make_uboot_trust() {
	echo "create uboot.img..."
	cp -vf $UBOOT_PATH/uboot.img $TOPBAND_OUT_DIR/uboot.img || myexit $LINENO
	echo "done."

	echo -n "create trust.img..."
	if [ -f $UBOOT_PATH/trust_nand.img ]
	then
		cp -vf $UBOOT_PATH/trust_nand.img $TOPBAND_OUT_DIR/trust.img || myexit $LINENO
	elif [ -f $UBOOT_PATH/trust_with_ta.img ]
	then
		cp -vf $UBOOT_PATH/trust_with_ta.img $TOPBAND_OUT_DIR/trust.img || myexit $LINENO
	elif [ -f $UBOOT_PATH/trust.img ]
	then
		cp -vf $UBOOT_PATH/trust.img $TOPBAND_OUT_DIR/trust.img || myexit $LINENO
	else    
		echo "$UBOOT_PATH/trust.img not found! Please make it from $UBOOT_PATH first!" && myexit $LINENO
	fi
	echo "done."

	if [ "$HIGH_RELIABLE_RECOVERY_OTA" = "true" ]; then
		echo "HIGH_RELIABLE_RECOVERY_OTA is true. create uboot_ro.img..."
		if [ -f $UBOOT_PATH/uboot_ro.img ]
		then
			cp -vf $UBOOT_PATH/uboot_ro.img $TOPBAND_OUT_DIR/uboot_ro.img || myexit $LINENO
			cp -vf $TOPBAND_OUT_DIR/trust.img $TOPBAND_OUT_DIR/trust_ro.img || myexit $LINENO
		else
			echo "$UBOOT_PATH/uboot_ro.img not found! Please make it from $UBOOT_PATH first!" && myexit $LINENO
		fi
		echo "done."
	fi
}

make_loader() {
	echo "create loader..."
	if [ -f $UBOOT_PATH/*_loader_*.bin ]; then
		cp -vf $UBOOT_PATH/*_loader_*.bin $TOPBAND_OUT_DIR/MiniLoaderAll.bin || myexit $LINENO
	else
		if [ -f $UBOOT_PATH/*loader*.bin ]; then
			cp -vf $UBOOT_PATH/*loader*.bin $TOPBAND_OUT_DIR/MiniLoaderAll.bin || myexit $LINENO
		elif [ "$TARGET_PRODUCT" == "px3" -a -f $UBOOT_PATH/RKPX3Loader_miniall.bin ]; then
			cp -vf $UBOOT_PATH/RKPX3Loader_miniall.bin $TOPBAND_OUT_DIR/MiniLoaderAll.bin || myexit $LINENO
		else
			echo "$UBOOT_PATH/*MiniLoaderAll_*.bin not found! Please make it from $UBOOT_PATH first!" && myexit $LINENO
		fi
	fi
	echo "done."
}

make_resource() {
	echo "create resource..."
	cp -vf $KERNEL_PATH/resource.img $TOPBAND_OUT_DIR/resource.img || myexit $LINENO
	echo "done."
}

make_kernel() {
	echo "create kernel..."
	cp -vf $KERNEL_PATH/kernel.img $TOPBAND_OUT_DIR/kernel.img || myexit $LINENO
	echo "done."
}

make_parameter() {
	echo "create parameter..."
	if [ -f $CUR_DIR/parameter.txt ]
	then
		if [ "$HIGH_RELIABLE_RECOVERY_OTA" = "true" ]; then
			echo -n "HIGH_RELIABLE_RECOVERY_OTA is true. create parameter from hrr..."
			cp -vf $CUR_DIR/parameter_hrr.txt $TOPBAND_OUT_DIR/parameter.txt || myexit $LINENO
		else		
			cp -vf $CUR_DIR/parameter.txt $TOPBAND_OUT_DIR/parameter.txt || myexit $LINENO
		fi
	else
		echo "$CUR_DIR/parameter.txt not found!" && myexit $LINENO
	fi
	echo "done."

	if [ "$TARGET_BASE_PARAMETER_IMAGE"x != ""x ]
	then
		echo -n "create baseparameter..."
		cp -vf $CUR_DIR/baseparameter.img $TOPBAND_OUT_DIR/baseparameter.img || myexit $LINENO
		#cp -vf $TARGET_BASE_PARAMETER_IMAGE $TOPBAND_OUT_DIR/baseparameter.img || myexit $LINENO
		echo "done."
	fi
}

make_start() {
	echo ""
	echo "================ make image start =============="
	cd $ANDROID_DIR

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
	
	if [ "$MAKE_ALL" = true ] || [ "$MAKE_UBOOT" = true ] ; then
		make_uboot_trust
	fi
	
	if [ "$MAKE_ALL" = true ] || [ "$MAKE_LOADER" = true ] ; then
		make_loader
	fi
	
	if [ "$MAKE_ALL" = true ] || [ "$MAKE_KERNEL" = true ] ; then
		make_kernel
		make_resource
	fi
	
	if [ "$MAKE_ALL" = true ] || [ "$MAKE_PARAMETER" = true ] ; then
		make_parameter
	fi
	
	if [ "$MAKE_ALL" = true ] || [ "$MAKE_MISC" = true ] ; then
		make_misc
	fi
	
	if [ "$MAKE_ALL" = true ] || [ "$MAKE_LCDPARAM" = true ] ; then
		make_lcdparam
	fi
	
	cd -
	
	echo "================ make image end ================"
	echo ""
}

setup_env
show_variable
make_start
