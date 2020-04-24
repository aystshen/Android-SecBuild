#!/bin/bash

PRODUCT=$1
TARGET=$2

CURDIR=$PWD
PRODUCT_DIR=$CURDIR/../product
TOPBAND_OUT_DIR=$CURDIR/../outputs
PLATFORM_DIR=$CURDIR/../platform
INTEGRATION_DIR=$TOPBAND_OUT_DIR/integration
PACKAGE_NAME=rom_*.tar.gz
PLATFORM_PACKAGE=$PLATFORM_DIR/$PACKAGE_NAME
PLATFORM_EXTRACT_PACKAGE=$INTEGRATION_DIR/package_src
TARGET_FILES_DIR=$INTEGRATION_DIR/target_files

DATE=`date +%Y-%m-%d`
GIT_COMMIT=`git log -1 |grep "^commit" |awk '{print $2}'`

myexit() {
	echo "error: mkproduct.sh error, exit at $1 !!!" && exit $1;
}

setup_env() {
	#set jdk version
	export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
	export PATH=$JAVA_HOME/bin:$PATH
	export CLASSPATH=.:$JAVA_HOME/lib:$JAVA_HOME/lib/tools.jar
}

checkFileAndExit() {
	if [ ! -e $1 ]; then
		echo "error: $1 not exist!!!" && myexit $LINENO
	fi
}

checkPlatformPkg() {
	echo "check extract platform package files"
	checkFileAndExit $PLATFORM_EXTRACT_PACKAGE
	checkFileAndExit $PLATFORM_EXTRACT_PACKAGE/image
	checkFileAndExit $PLATFORM_EXTRACT_PACKAGE/tools
	checkFileAndExit $PLATFORM_EXTRACT_PACKAGE/target_files.zip
}

extractPlatformPkg() {
	echo ""
	echo "tar xvf $PLATFORM_PACKAGE  $INTEGRATION_DIR/"
	
	tar xvf $PLATFORM_PACKAGE -C $INTEGRATION_DIR/ || myexit $LINENO
	checkPlatformPkg
	unzip $PLATFORM_EXTRACT_PACKAGE/target_files.zip -d $TARGET_FILES_DIR/ || myexit $LINENO
	
	checkFileAndExit $TARGET_FILES_DIR/BOOT
	checkFileAndExit $TARGET_FILES_DIR/RECOVERY
	checkFileAndExit $TARGET_FILES_DIR/SYSTEM
	
	echo "extract platform package ok!!!"
}

updateApk() {
	cd ${PLATFORM_DIR}
	
	if [ -d ${TARGET_FILES_DIR}/SYSTEM/lib64 ]; then
		lib64=true
	fi
	echo "update apk lib64: ${lib64}"
	
	for file in *
	do
		if [[ "${file}" == *.apk ]]; then
			echo "update apk: ${file}"
			name=`echo ${file} | awk -F"." '{print $1}'`
			suffix=`echo ${file} | awk -F"." '{print $2}'`
			echo "[name]: $name, [suffix]: $suffix"
			
			if [ -d ${TARGET_FILES_DIR}/SYSTEM/app/${name} ]; then
				rm -rf ${TARGET_FILES_DIR}/SYSTEM/app/${name}
			fi
			
			mkdir -p ${TARGET_FILES_DIR}/SYSTEM/app/${name} || myexit $LINENO
			mkdir -p ${TARGET_FILES_DIR}/SYSTEM/app/${name}/lib || myexit $LINENO
			mkdir -p ${TARGET_FILES_DIR}/SYSTEM/app/${name}/lib/arm || myexit $LINENO
			if [ "$lib64" = true ] ; then
				mkdir -p ${TARGET_FILES_DIR}/SYSTEM/app/${name}/lib/arm64 || myexit $LINENO
			fi
			
			cp -vf ${file} ${TARGET_FILES_DIR}/SYSTEM/app/${name}/ || myexit $LINENO
			
			unzip -o ${file} lib/*/*.so -d ./${name}
			
			if [ -d ${name}/lib/armeabi-v7a ]; then
				cp -vf ${name}/lib/armeabi-v7a/* ${TARGET_FILES_DIR}/SYSTEM/app/${name}/lib/arm/ || myexit $LINENO
			elif [ -d ${name}/lib/armeabi ]; then
				cp -vf ${name}/lib/armeabi/* ${TARGET_FILES_DIR}/SYSTEM/app/${name}/lib/arm/ || myexit $LINENO
			fi
			
			if [ "$lib64" = true ] && [ -d ${name}/lib/arm64-v8a ]; then
				cp -vf ${name}/lib/arm64-v8a/* ${TARGET_FILES_DIR}/SYSTEM/app/${name}/lib/arm64/ || myexit $LINENO
			elif [ "$lib64" = true ] && [ -d ${name}/lib/arm64 ]; then
				cp -vf ${name}/lib/arm64/* ${TARGET_FILES_DIR}/SYSTEM/app/${name}/lib/arm64/ || myexit $LINENO
			fi
			
			rm -rf ./${name}
		fi
	done
	
	cd -
}

#添加系统属性到build.prop文件中
updateProperty(){
	sed -i "s/ro.build.date=.*/ro.build.date=$(date)/g" $TARGET_FILES_DIR/SYSTEM/build.prop
	sed -i "s/ro.build.date.utc=.*/ro.build.date.utc=$(date +"%s")/g" $TARGET_FILES_DIR/SYSTEM/build.prop
}

parseConfig() {
	while read line
	do
		if [[ "${line}" == *=* ]]; then	
			key=`echo ${line} | awk -F"=" '{print $1}'`
			#value=`echo ${line} | awk -F"=" '{print $2}'`
			value=`echo ${line} | awk -F'=' '{s="";for(i=2;i<=NF;i++)s=s""(i==NF?$i:$i"=");print s}'`
			echo "[key]: $key, [value]: $value"
			
			if [ ${key} == PROP ]; then
				prop_key=`echo ${value} | awk -F"@" '{print $1}'`
				prop_value=`echo ${value} | awk -F"@" '{print $2}'`
				echo "updating prop ${value}"
				
				if [ ${prop_key} == ro.topband.sw.version ]; then
					prop_value=${prop_value}.${BUILD_NUMBER}
					VERSION=${prop_value}
				elif [ ${prop_key} == ro.topband.sw.versioncode ]; then
					let "prop_value+=BUILD_NUMBER"
					VERSION_CODE=${prop_value}
				fi
				
				grep -wq ${prop_key} ${TARGET_FILES_DIR}/SYSTEM/build.prop > /dev/null
				if [ $? -eq 0 ]; then
					sed -i "s/${prop_key}.*/${prop_key}=${prop_value}/g" $TARGET_FILES_DIR/SYSTEM/build.prop || myexit $LINENO
					sed -i "s/${prop_key}.*/${prop_key}=${prop_value}/g" $TARGET_FILES_DIR/RECOVERY/RAMDISK/default.prop || myexit $LINENO
					if [ -f $TARGET_FILES_DIR/RECOVERY/RAMDISK/prop.default ]; then
						sed -i "s/${prop_key}.*/${prop_key}=${prop_value}/g" $TARGET_FILES_DIR/RECOVERY/RAMDISK/prop.default || myexit $LINENO
					fi
					if [ ${prop_key} == ro.product.model ]; then
						sed -i "s/MACHINE:.*/MACHINE:${prop_value}/g" $TOPBAND_OUT_DIR/parameter* || myexit $LINENO
					fi
				elif [ -f ${TARGET_FILES_DIR}/VENDOR/build.prop ]; then
					grep -wq ${prop_key} ${TARGET_FILES_DIR}/VENDOR/build.prop > /dev/null
					if [ $? -eq 0 ]; then
						sed -i "s/${prop_key}.*/${prop_key}=${prop_value}/g" $TARGET_FILES_DIR/VENDOR/build.prop || myexit $LINENO
						sed -i "s/${prop_key}.*/${prop_key}=${prop_value}/g" $TARGET_FILES_DIR/RECOVERY/RAMDISK/default.prop || myexit $LINENO
						if [ -f $TARGET_FILES_DIR/RECOVERY/RAMDISK/prop.default ]; then
							sed -i "s/${prop_key}.*/${prop_key}=${prop_value}/g" $TARGET_FILES_DIR/RECOVERY/RAMDISK/prop.default || myexit $LINENO
						fi
					else
						echo "${prop_key}=${prop_value}" >> $TARGET_FILES_DIR/VENDOR/build.prop || myexit $LINENO
						echo "${prop_key}=${prop_value}" >> $TARGET_FILES_DIR/RECOVERY/RAMDISK/default.prop || myexit $LINENO
					fi
				else
					echo "${prop_key}=${prop_value}" >> $TARGET_FILES_DIR/SYSTEM/build.prop || myexit $LINENO
					echo "${prop_key}=${prop_value}" >> $TARGET_FILES_DIR/RECOVERY/RAMDISK/default.prop || myexit $LINENO
				fi
			elif [ ${key} == DEL ]; then
				echo "delete file ${value}"
				rm -rf ${TARGET_FILES_DIR}/${value}
			fi
		fi
	done < $PRODUCT_DIR/$PRODUCT/config.ini
}

parseTarget() {
	if [ $TARGET ];then
	return
	fi
	if [ -f ${TARGET_FILES_DIR}/VENDOR/build.prop ]; then
		line=`grep -i "ro.board.platform" ${TARGET_FILES_DIR}/VENDOR/build.prop`
	else
		line=`grep -i "ro.board.platform" ${TARGET_FILES_DIR}/SYSTEM/build.prop`
	fi
	if [[ "${line}" == *=* ]]; then	
		key=`echo ${line} | awk -F"=" '{print $1}'`
		value=`echo ${line} | awk -F"=" '{print $2}'`

		if [ ${key} == ro.board.platform ]; then
			export TARGET=${value}
		fi
		
		echo "Target: ${TARGET}"
		if [ ! ${TARGET} ]; then
			echo "Parse target failed!" && myexit $LINENO
		fi
	fi
}

parseExtends() {
	line=`grep -i "EXTENDS" $PRODUCT_DIR/$PRODUCT/config.ini`
	if [[ "${line}" == *=* ]]; then	
		key=`echo ${line} | awk -F"=" '{print $1}'`
		value=`echo ${line} | awk -F"=" '{print $2}'`

		if [ ${key} == EXTENDS ]; then
			if [ -d $PRODUCT_DIR/${value} ]; then
				EXTENDS_PRODUCT=${value}
				echo "Extends: ${EXTENDS_PRODUCT}"
			fi
		fi
	fi
}

updateFiles() {
	echo ""
	echo "update files in $INTEGRATION_DIR"

	cd $CURDIR

	if [ ! -e $TARGET_FILES_DIR ]; then
		echo "$TARGET_FILES_DIR not exist!!!" && myexit $LINENO
	fi
	
	echo "  parse target..."
	[ -f ${TARGET_FILES_DIR}/SYSTEM/build.prop ] && parseTarget
	
	echo "  parse extends..."
	[ -f $PRODUCT_DIR/$PRODUCT/config.ini ] && parseExtends
	
	echo "  copy extends system files..."
	[ -d $PRODUCT_DIR/$EXTENDS_PRODUCT/system ] && cp -rf $PRODUCT_DIR/$EXTENDS_PRODUCT/system/* $TARGET_FILES_DIR/SYSTEM

	echo "  copy system files..."
	[ -d $PRODUCT_DIR/$PRODUCT/system ] && cp -rf $PRODUCT_DIR/$PRODUCT/system/* $TARGET_FILES_DIR/SYSTEM
	
	echo "  copy vendor files..."
	[ -d $PRODUCT_DIR/$PRODUCT/vendor ] && cp -rf $PRODUCT_DIR/$PRODUCT/vendor/* $TARGET_FILES_DIR/VENDOR

	echo "  copy oem files..."
	[ -d $PRODUCT_DIR/$PRODUCT/oem ] && cp -rf $PRODUCT_DIR/$PRODUCT/oem/* $TARGET_FILES_DIR/OEM

	echo "  copy root files..."
	[ -d $PRODUCT_DIR/$PRODUCT/root ] && cp -rf $PRODUCT_DIR/$PRODUCT/root/* $TARGET_FILES_DIR/BOOT/RAMDISK
	
	echo "  copy recovery files..."
	[ -d $PRODUCT_DIR/$PRODUCT/recovery/root ] && cp -rf $PRODUCT_DIR/$PRODUCT/recovery/root/* $TARGET_FILES_DIR/RECOVERY/RAMDISK
	
	echo "  copy image files..."
	cp -rf $PLATFORM_EXTRACT_PACKAGE/image/* $TOPBAND_OUT_DIR || myexit $LINENO
	
	echo "  copy product image files..."
	cp -rf $PRODUCT_DIR/$PRODUCT/image/* $TOPBAND_OUT_DIR

	echo "  copy rom version files..."
	cp -rf $PLATFORM_EXTRACT_PACKAGE/rom_git_verson.* $TOPBAND_OUT_DIR/rom_git_verson.txt || myexit $LINENO
	
	echo "  copy platform tools files..."
	cp -rf $PLATFORM_EXTRACT_PACKAGE/tools $INTEGRATION_DIR || myexit $LINENO
	
	echo "  updating apk files..."
	updateApk
	
	echo "  updating build.prop files..."
	updateProperty
	
	echo "  parse config files..."
	[ -f $PRODUCT_DIR/$PRODUCT/config.ini ] && parseConfig
	
	echo "update files ok!!!"
	echo ""
	cd -
}

makeImage() {
	cd $CURDIR
	if [ -f $PRODUCT_DIR/$PRODUCT/*.dtb ]; then
		if [ -f $PRODUCT_DIR/$PRODUCT/logo.bmp ]; then
		
			cp -vf ${PRODUCT_DIR}/${PRODUCT}/logo.bmp ./logo.bmp
			
			if [ -f $PRODUCT_DIR/$PRODUCT/logo_kernel.bmp ]; then
				echo "make resource.img with logo.bmp logo_kernel.bmp..."
				cp -vf ${PRODUCT_DIR}/${PRODUCT}/logo_kernel.bmp ./logo_kernel.bmp
				./resource_tool ${PRODUCT_DIR}/${PRODUCT}/*.dtb logo.bmp logo_kernel.bmp || myexit $LINENO
				rm -f ./logo.bmp ./logo_kernel.bmp
			else
				echo "make resource.img with logo.bmp..."
				./resource_tool ${PRODUCT_DIR}/${PRODUCT}/*.dtb logo.bmp || myexit $LINENO
				rm -f ./logo.bmp
			fi
			
			cp -vf ./resource.img $TOPBAND_OUT_DIR/ && rm -f ./resource.img
			
		fi
	fi
	if [ $TARGET == "rk3288" ]; then
		./mkimage_o.sh -A || myexit $LINENO
		./mkimage_o.sh -A -t ota || myexit $LINENO
	elif [ $TARGET == "rk3326" ]; then
		./mkimage_o.sh -A -p rk3326 || myexit $LINENO
		./mkimage_o.sh -A -p rk3326 -t ota|| myexit $LINENO
	elif [ $TARGET == "px30" ]; then
		./mkimage_o.sh -A -p px30 || myexit $LINENO
		./mkimage_o.sh -A -p px30 -t ota|| myexit $LINENO
	elif [ $TARGET == "rk3399" ]; then
		./mkimage_o.sh -A -p rk3399 || myexit $LINENO
		./mkimage_o.sh -A -p rk3399 -t ota|| myexit $LINENO
	else
		./mkimage.sh || myexit $LINENO
		./mkimage.sh ota || myexit $LINENO
	fi
	cd -
}

makeUpdateImg() {
	cd $CURDIR
	./mkupdate_img.sh -t ${TARGET} -p $TOPBAND_OUT_DIR/package-file_normal -f ${TARGET}_update_${PRODUCT}_v${VERSION}\(${VERSION_CODE}\)_${GIT_COMMIT:0:7}_${DATE}.img || myexit $LINENO
	./mkupdate_img.sh -t ${TARGET} -p $TOPBAND_OUT_DIR/package-file_pcba_small -f ${TARGET}_pcba_test_small_${PRODUCT}_v${VERSION}\(${VERSION_CODE}\)_${GIT_COMMIT:0:7}_${DATE}.img || myexit $LINENO
	#./mkupdate_img.sh -t ${TARGET} -p $TOPBAND_OUT_DIR/package-file_pcba_whole -f ${TARGET}_pcba_test_whole_${PRODUCT}_v${VERSION}\(${VERSION_CODE}\)_${GIT_COMMIT:0:7}_${DATE}.img || myexit $LINENO
	cd -
}

makeUpdateZip() {
	cd $CURDIR
	if [ $TARGET == "rk3288" ]; then
		./mkupdate_zip_o.sh ${TARGET}_ota_${PRODUCT}_v${VERSION}\(${VERSION_CODE}\)_${GIT_COMMIT:0:7}_${DATE}.zip || myexit $LINENO
	elif [ $TARGET == "rk3326" ]; then
		./mkupdate_zip_o.sh ${TARGET}_ota_${PRODUCT}_v${VERSION}\(${VERSION_CODE}\)_${GIT_COMMIT:0:7}_${DATE}.zip || myexit $LINENO
	elif [ $TARGET == "px30" ]; then
		./mkupdate_zip_o.sh ${TARGET}_ota_${PRODUCT}_v${VERSION}\(${VERSION_CODE}\)_${GIT_COMMIT:0:7}_${DATE}.zip || myexit $LINENO
	elif [ $TARGET == "rk3399" ]; then
		./mkupdate_zip_o.sh ${TARGET}_ota_${PRODUCT}_v${VERSION}\(${VERSION_CODE}\)_${GIT_COMMIT:0:7}_${DATE}.zip || myexit $LINENO
	else
		./mkupdate_zip.sh ${TARGET}_ota_${PRODUCT}_v${VERSION}\(${VERSION_CODE}\)_${GIT_COMMIT:0:7}_${DATE}.zip || myexit $LINENO
	fi
	cd -
}

echo ""
echo "======= make product:$PRODUCT start ======"
startTime=`date`

if [ ! $PRODUCT ]; then
	echo "usage: "
	for file in $PRODUCT_DIR/*
	do
		if test -d ${file}
		then
			echo "	[mkproduct.sh ${file##*/}]"
		fi
	done
	echo ""
	myexit $LINENO
elif [ ! -d $PRODUCT_DIR/$PRODUCT ]; then
	echo "Device: $PRODUCT not exist!!!" && myexit $LINENO
fi

if [ -e $PLATFORM_PACKAGE ]; then
	echo "Use platform $PLATFORM_PACKAGE!!!"
else
	echo "error: $PLATFORM_PACKAGE not exist!!!" && myexit $LINENO
fi

if [ ! $BUILD_NUMBER ]; then
	BUILD_NUMBER=0
fi

rm -rf $TOPBAND_OUT_DIR && mkdir -p $TOPBAND_OUT_DIR
rm -rf $INTEGRATION_DIR && mkdir -p $INTEGRATION_DIR

echo ""
echo "----------- extract pkg start ------------"
extractPlatformPkg
echo "----------- extract pkg end --------------"

echo ""
echo "----------- update files start -----------"
updateFiles
echo "----------- update files end -------------"

if [ $TARGET == "rk3288" ]; then
	setup_env
elif [ $TARGET == "rk3399" ]; then
	setup_env
fi
makeImage
makeUpdateImg
makeUpdateZip

rm -rf $INTEGRATION_DIR
rm -rf $PLATFORM_DIR/*
rm -rf $TOPBAND_OUT_DIR/system.img

endTime=`date`
echo ""
echo "========= make product:$PRODUCT end ======"
echo ""
echo "=========================================="
echo "start make time:${startTime}"
echo "end make time:${endTime}"
echo "=========================================="
echo ""
