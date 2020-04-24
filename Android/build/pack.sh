#!/bin/bash

TARGET=$1
if [ ! $TARGET ]; then
	TARGET="rk3288"
fi

CUR_DIR=$PWD
ANDROID_DIR=$CUR_DIR/../..
ANDROID_OUT_DIR=$ANDROID_DIR/out/target/product/$TARGET
TOPBAND_OUT_DIR=$CUR_DIR/../outputs

#version info
VER_PLATFORM=13		#平台号 11: RK3128 12: RK3368 13:RK3288
VER_ANDROID=81		#Android版本号 51: Android 5.1 60: Android 6.0 71: Android 7.1 81: Android 8.1		
VER_BASE=${VER_PLATFORM}${VER_ANDROID}
VER_MAJOR=1			#主版本号，递增
VER_GIT_CNT=`git rev-list HEAD | wc -l | awk '{print $1}'` #Git提交计数
VERSION=${VER_BASE}.${VER_MAJOR}.${VER_GIT_CNT} #例如：1151.1.60

#git info
GIT_REPO=`git remote -v |head -1 |awk '{print $2}'`
GIT_BRANCH=`git branch |grep "^*" |awk '{print $2}'`
GIT_COMMIT=`git log -1 |grep "^commit" |awk '{print $2}'`
GIT_VERSION=${GIT_REPO}[${GIT_BRANCH}]:${GIT_COMMIT}

DATE=`date +%Y-%m-%d`

myexit() {
	echo "pack.sh exit at $1" && exit $1;
}

createVersion() {
	echo ""
	echo "Create version"
	
	cd $TOPBAND_OUT_DIR/package_src
	
	mkdir -p SYSTEM
	mkdir -p BOOT/RAMDISK
	cp -f $ANDROID_OUT_DIR/system/build.prop ./SYSTEM/build.prop || myexit $LINENO
	echo "ro.topband.rom.version=${VERSION}" >> ./SYSTEM/build.prop
	echo "${GIT_VERSION}" > ./BOOT/RAMDISK/rom_git_verson.prop
	zip -r target_files.zip ./SYSTEM/build.prop ./BOOT/RAMDISK/rom_git_verson.prop
	
	cp -f ./BOOT/RAMDISK/rom_git_verson.prop .
	rm -rf SYSTEM BOOT
	
	cd -
	
	echo "  create version ok!!!"
}

createPackage() {
	echo ""
	echo "Create package"
	
	if [ ! -d $TOPBAND_OUT_DIR ]; then
		echo "$TOPBAND_OUT_DIR not exist!!!" && myexit $LINENO
	fi
	
	rm -rf $TOPBAND_OUT_DIR/package_src
	#rm -rf $TOPBAND_OUT_DIR/symbols
	rm -rf $TOPBAND_OUT_DIR/*.tar.gz

	echo "  copy files..."
	#--------clear-----------
	cd $TOPBAND_OUT_DIR
	mkdir -p package_src
	
	#------copy symbols to output/symbols path-----
	#cp -vrf $ANDROID_OUT_DIR/symbols ./
	
	#------copy original file to package_src path------
	cd $TOPBAND_OUT_DIR/package_src
	cp -vf $ANDROID_OUT_DIR/obj/PACKAGING/target_files_intermediates/$TARGET-target_files-*.zip ./target_files.zip || myexit $LINENO
	
	#------copy tool to package_src/tools path---------
	mkdir tools && cp -vrf $ANDROID_DIR/out/host/linux-x86/bin ./tools || myexit $LINENO
	rm -f ./tools/bin/clang
	rm -f ./tools/bin/clang++
	cp -vrf $ANDROID_DIR/out/host/linux-x86/lib64 ./tools || myexit $LINENO
	cp -vrf $ANDROID_DIR/out/host/linux-x86/framework ./tools || myexit $LINENO
	cp -vrf $ANDROID_DIR/build/tools/releasetools ./tools || myexit $LINENO
	cp -vf $ANDROID_DIR/out/host/linux-x86/framework/signapk.jar ./tools/bin || myexit $LINENO
	cp -vf $ANDROID_DIR/build/target/product/security/* ./tools/bin || myexit $LINENO
	cp -vf $ANDROID_DIR/rkst/mkkrnlimg ./tools/bin || myexit $LINENO
	cp -vf $ANDROID_DIR/device/rockchip/common/sparse_tool.py ./tools/releasetools || myexit $LINENO
	cp -vf $ANDROID_DIR/system/extras/verity/build_verity_metadata.py ./tools/releasetools || myexit $LINENO
	
	#------copy burn file to package_src/image path-----
	mkdir image
	cp -vf $TOPBAND_OUT_DIR/kernel.img ./image || myexit $LINENO
	cp -vf $TOPBAND_OUT_DIR/misc.img ./image || myexit $LINENO
	cp -vf $TOPBAND_OUT_DIR/pcba_small_misc.img ./image || myexit $LINENO
	cp -vf $TOPBAND_OUT_DIR/pcba_whole_misc.img ./image || myexit $LINENO
	cp -vf $TOPBAND_OUT_DIR/resource.img ./image || myexit $LINENO
	cp -vf $TOPBAND_OUT_DIR/MiniLoaderAll.bin ./image || myexit $LINENO
	cp -vf $TOPBAND_OUT_DIR/uboot.img ./image || myexit $LINENO
	cp -vf $TOPBAND_OUT_DIR/parameter.txt ./image || myexit $LINENO
	cp -vf $TOPBAND_OUT_DIR/package-file_normal ./image || myexit $LINENO
	cp -vf $TOPBAND_OUT_DIR/package-file_pcba_small ./image || myexit $LINENO
	cp -vf $TOPBAND_OUT_DIR/package-file_pcba_whole ./image || myexit $LINENO
	cp -vf $TOPBAND_OUT_DIR/trust.img ./image || myexit $LINENO
	cp -vf $TOPBAND_OUT_DIR/oem.img ./image || myexit $LINENO
	cp -vf $TOPBAND_OUT_DIR/lcdparam.img ./image || myexit $LINENO
	cp -vf $TOPBAND_OUT_DIR/baseparameter.img ./image || myexit $LINENO
	cp -vf $ANDROID_OUT_DIR/kernel ./image || myexit $LINENO
	cp -vf $ANDROID_OUT_DIR/obj/PACKAGING/systemimage_intermediates/system_image_info.txt ./image || myexit $LINENO
	cp -vf $ANDROID_OUT_DIR/obj/ETC/file_contexts.bin_intermediates/file_contexts.bin ./image || myexit $LINENO
	#cp -vf $ANDROID_OUT_DIR/obj/KERNEL_OBJ/vmlinux ./image || myexit $LINENO

	cd -
	
	createVersion
	
	cd $TOPBAND_OUT_DIR
	#echo "tar file:${TOPBAND_OUT_DIR}/symbols_${GIT_BRANCH}_${VERSION}_${GIT_COMMIT:0:7}_${DATE}.tar.gz"
	#tar zcf ./symbols_${GIT_BRANCH}_${VERSION}_${GIT_COMMIT:0:7}_${DATE}.tar.gz symbols
	
	echo "tar file:${TOPBAND_OUT_DIR}/rom_${GIT_BRANCH}_${VERSION}_${GIT_COMMIT:0:7}_${DATE}.tar.gz"
	tar zcf ./rom_${GIT_BRANCH}_${VERSION}_${GIT_COMMIT:0:7}_${DATE}.tar.gz package_src
	
	#rm -rf ./symbols
	rm -rf ./package_src
	cd -
	
	echo ""
	echo "======== package info ========"
	echo "android directory: ${ANDROID_DIR}"
	echo "out directory: ${TOPBAND_OUT_DIR}"
	echo "package: rom_${GIT_BRANCH}_${VERSION}_${GIT_COMMIT:0:7}_${DATE}.tar.gz"
	echo "git repository: ${GIT_REPO}"
	echo "git branch: ${GIT_BRANCH}"
	echo "git commit: ${GIT_COMMIT}"
	echo "version: ${VERSION}"
	echo "build time: ${DATE}"
	echo "=============================="
	echo ""
	
	echo "  create package ok!!!"
	echo ""
}

echo ""
echo "---------------- create package start -------------------"

createPackage

echo "---------------- create package end ---------------------"
echo ""
exit 0