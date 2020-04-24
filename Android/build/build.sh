#!/bin/bash
set -

usage()
{
	echo "USAGE: [-Aukaoi] [-t target] [-U uboot_defconfig] [-K kernel_defconfig] [-d dts]"
	echo "No ARGS means use default build option"
	echo "WHERE: -A = build all"
	echo "       -u = build u-boot"
	echo "       -k = build kernel"
	echo "       -a = build android"
	echo "       -o = generate ota package"
	echo "       -i = generate update.img"
	echo "       -t = set target"
	echo "       -U = build u-boot with u-boot defconfig"
	echo "       -K = build kernel with kernel defconfig"
	echo "       -d = set kernel dts"
	exit 1
}

BUILD_ALL=false
BUILD_UBOOT=false
BUILD_KERNEL=false
BUILD_ANDROID=false
BUILD_UPDATE_IMG=false
BUILD_OTA=false

TARGET="rk3288"
UBOOT_DEFCONFIG="rk3288_secure_defconfig"
KERNEL_DEFCONFIG="topband_pos_defconfig"
KERNEL_DTS="topband-pos-lvds-1280x800"

while getopts "Aukaoit:U:K:d:h" opt
do
	case $opt in
		A)
		BUILD_ALL=true
		;;
		u)
		BUILD_UBOOT=true
		;;
		k)
		BUILD_KERNEL=true
		;;
		a)
		BUILD_ANDROID=true
		;;
		o)
		BUILD_OTA=true
		;;
		i)
		BUILD_UPDATE_IMG=true
		;;
		t)
		TARGET=$OPTARG
		;;
		U)
		BUILD_UBOOT=true
		UBOOT_DEFCONFIG=$OPTARG
		;;
		K)
		BUILD_KERNEL=true
		KERNEL_DEFCONFIG=$OPTARG
		;;
		d)
		KERNEL_DTS=$OPTARG
		;;
		h)
		usage ;;
		?)
		usage ;;
	esac
done

CUR_DIR=$PWD
ANDROID_DIR=$CUR_DIR/../..
ANDROID_OUT_DIR=$ANDROID_DIR/out/target/product/${TARGET}
TOPBAND_OUT_DIR=$CUR_DIR/../outputs
PROCESSER=`grep 'processor' /proc/cpuinfo | wc -l`
JOBSS=$[$PROCESSER*2]

myexit() {
	echo "build.sh exit at $1" && exit $1;
}

setup_env() {
	#set jdk version
	export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
	export PATH=$JAVA_HOME/bin:$PATH
	export CLASSPATH=.:$JAVA_HOME/lib:$JAVA_HOME/lib/tools.jar
}

change_branch () {
	echo ""
	echo "---------------- change_branch start --------------"
	cd $ANDROID_DIR
	git checkout master || myexit $LINENO
	cd -
	echo "---------------- change_branch end ----------------"
	echo ""
}

build_uboot() {
	echo ""
	echo "---------------- build uboot start ----------------"
	cd u-boot && make distclean && make $UBOOT_DEFCONFIG && ./mkv7.sh && cd - || myexit $LINENO
	echo "---------------- build uboot end ------------------"
}

build_kernel() {
	echo ""
	echo "---------------- build kernel start ---------------"
	cd kernel && make ARCH=arm $KERNEL_DEFCONFIG && make ARCH=arm $KERNEL_DTS.img -j$JOBSS && cd - || myexit $LINENO
	echo "---------------- build kernel end -----------------"
}

build_android() {
	echo ""
	echo "---------------- build android start ---------------"
	make installclean || myexit $LINENO
	make -j$JOBSS || myexit $LINENO
	echo "---------------- build android end -----------------"
}

build_ota() {
echo ""
	echo "---------------- build otapackage start ---------------"
	make otapackage -j$JOBSS || myexit $LINENO
	echo "---------------- build otapackage end -----------------"
}

build () {
	echo ""
	echo "================ build start =============="
	cd $ANDROID_DIR
	
	source build/envsetup.sh || myexit $LINENO

	lunch ${TARGET}-userdebug || myexit $LINENO
	
	if [ "$BUILD_ALL" = true ] || [ "$BUILD_UBOOT" = true ] ; then
		build_uboot
		if [ "$BUILD_ALL" = false ] ; then
			cd topband/build && ./mkimage.sh -u && cd - || myexit $LINENO
		fi
	fi
	
	if [ "$BUILD_ALL" = true ] || [ "$BUILD_KERNEL" = true ] ; then
		build_kernel
		if [ "$BUILD_ALL" = false ] ; then
			cd topband/build && ./mkimage.sh -k && cd - || myexit $LINENO
		fi
	fi
	
	if [ "$BUILD_ALL" = true ] || [ "$BUILD_ANDROID" = true ] ; then
		build_android
		if [ "$BUILD_ALL" = false ] ; then
			cd topband/build && ./mkimage.sh -sv && cd - || myexit $LINENO
		fi
	fi
	
	if [ "$BUILD_ALL" = true ] || [ "$BUILD_OTA" = true ] ; then
		build_ota
		cp -vf $ANDROID_OUT_DIR/${TARGET}-ota*.zip $TOPBAND_OUT_DIR || myexit $LINENO
	fi
	
	if [ "$BUILD_ALL" = true ] ; then
		cd topband/build && ./mkimage.sh -A && cd - || myexit $LINENO
		
		cd topband/build && ./mkupdate.sh $TOPBAND_OUT_DIR/package-file_normal update.img && cd - || myexit $LINENO
	fi
	
	cd -
	echo "================ build end ================"
	echo ""
}

if [ ! -e $ANDROID_DIR/Makefile ]; then
	echo "android directory not exist!" && myexit $LINENO
fi

if [ ! -d $TOPBAND_OUT_DIR ]; then
	mkdir $TOPBAND_OUT_DIR || myexit $LINENO
elif [  "$BUILD_ALL" = true  ]; then
	rm -rf $TOPBAND_OUT_DIR/*
fi

echo ""
echo "======== build info =========="
echo "TARGET: ${TARGET}"
echo "UBOOT_DEFCONFIG: ${UBOOT_DEFCONFIG}"
echo "KERNEL_DEFCONFIG: ${KERNEL_DEFCONFIG}"
echo "KERNEL_DTS: ${KERNEL_DTS}"
echo "=============================="
echo ""

setup_env
build
