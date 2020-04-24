#!/bin/bash
set -e

CURDIR=$PWD
TOPBAND_OUT_DIR=$CURDIR/../outputs
INTEGRATION_DIR=$TOPBAND_OUT_DIR/integration
TARGET_FILES_DIR=$INTEGRATION_DIR/target_files
TOOLS_DIR=$INTEGRATION_DIR/tools
UPDATE_TMP=$INTEGRATION_DIR/update_tmp
FILENAME=$1

if [ ! $FILENAME ]; then
	FILENAME=update.zip
fi

export PATH=$TOOLS_DIR/bin:$PATH
export PATH=$TOOLS_DIR/releasetools:$PATH

myexit() {
	echo "error: mkupdate_zip_o.sh error, exit at $1 !!!" && exit $1;
}

prepare() {
	cd $TOPBAND_OUT_DIR
	cp -vf boot_ota.img ${TARGET_FILES_DIR}/IMAGES/boot.img || myexit $LINENO
	cp -vf recovery_ota.img ${TARGET_FILES_DIR}/IMAGES/recovery.img || myexit $LINENO
	cp -vf system.img ${TARGET_FILES_DIR}/IMAGES/system.img || myexit $LINENO
	cp -vf vendor.img ${TARGET_FILES_DIR}/IMAGES/vendor.img || myexit $LINENO
	cp -vf oem.img ${TARGET_FILES_DIR}/IMAGES/oem.img || myexit $LINENO
	cd -
}

mkUpdate() {
	cd $TARGET_FILES_DIR
	
	echo "package $TARGET_FILES_DIR ---> target_files.zip..."
	rm -f $INTEGRATION_DIR/target_files.zip && zip -qry $INTEGRATION_DIR/target_files.zip .
	zipinfo -1 $INTEGRATION_DIR/target_files.zip | awk 'BEGIN { FS="SYSTEM/" } /^SYSTEM\// {print "system/" $2}' | fs_config > ./META/filesystem_config.txt 
	zipinfo -1 $INTEGRATION_DIR/target_files.zip | awk 'BEGIN { FS="BOOT/RAMDISK/" } /^BOOT\/RAMDISK\// {print $2}' | fs_config > ./META/boot_filesystem_config.txt 
	zipinfo -1 $INTEGRATION_DIR/target_files.zip | awk 'BEGIN { FS="RECOVERY/RAMDISK/" } /^RECOVERY\/RAMDISK\// {print $2}' | fs_config > ./META/recovery_filesystem_config.txt 
	zip -q $INTEGRATION_DIR/target_files.zip ./META/*filesystem_config.txt || myexit $LINENO
	
	echo "make update.zip..."
	ota_from_target_files  -v --block --extracted_input_target_files $INTEGRATION_DIR/target_files -p $TOOLS_DIR -k $TOOLS_DIR/bin/testkey $INTEGRATION_DIR/target_files.zip $TOPBAND_OUT_DIR/$FILENAME || myexit $LINENO
	rm -f $INTEGRATION_DIR/target_files.zip 
	
	cd -

	echo "make update.zip ok!!!"
	echo ""
}

echo ""
echo "--------- make update.zip start ----------"
prepare
mkUpdate
echo "--------- make update.zip end ------------"
