#!/bin/bash

usage()
{
    echo "USAGE: updatedtb.sh [a] [-p product] [-b board] [-d dtb directory]"
    echo "WHERE: -a = update all products dtb"
	echo "       -p = update the specified product dtb"
    echo "       -b = update the specified board product dtb, example: rk312x rk3368 rk30sdk"
    echo "       -d = set dtb directory"
    echo "       -h = help"
    exit 1
}

CUR_DIR=$PWD
PRODUCT_DIR=$CUR_DIR/../product
DTB_DIR=""
UPDATE_PRODUCT=""
UPDATE_BOARD=""
UPDATE_ALL=false

while getopts "ap:b:d:h" opt
do
    case $opt in
        a)
		UPDATE_ALL=true
        ;;
		p)
        UPDATE_PRODUCT=$OPTARG
        ;;
		b)
        UPDATE_BOARD=$OPTARG
        ;;
		d)
        DTB_DIR=$OPTARG
        ;;
        h)
        usage ;;
        ?)
        usage ;;
    esac
done

parseBoard() {
	while read line
	do
		if [[ "${line}" == *=* ]]; then	
			key=`echo ${line} | awk -F"=" '{print $1}'`
			value=`echo ${line} | awk -F"=" '{print $2}'`
			
			if [ ${key} == PROP ]; then
				prop_key=`echo ${value} | awk -F"@" '{print $1}'`
				prop_value=`echo ${value} | awk -F"@" '{print $2}'`
				
				if [ ${prop_key} == ro.product.board ]; then
					echo ${prop_value}
					return 0
				fi
			fi
		fi
	done < $1/config.ini
	
	return -1
}

update_single_product() {
	for filename in $1/*
	do  
		if [ "${filename##*.}" = "dtb" ]; then
			cp -vf $DTB_DIR/${filename##*/}  $1/${filename##*/} 
		fi
	done
}

update(){
	if [ -n "$UPDATE_PRODUCT" ]; then 
		echo "update product--> $UPDATE_PRODUCT" 
		update_single_product $PRODUCT_DIR/$UPDATE_PRODUCT
	elif [ -n "$UPDATE_BOARD" ]; then 
		echo "update board--> $UPDATE_BOARD"
		for product in $PRODUCT_DIR/*
		do  
			if [ -d $product ]; then 
				board=`parseBoard $product`
				if [ $? -eq 0 ]; then
					if [ "$board" = "$UPDATE_BOARD" ]; then
						update_single_product $product
					fi
				fi
			fi
		done
	elif [ $UPDATE_ALL = true ]; then
		echo "update all product-->" 
		for product in $PRODUCT_DIR/*
		do  
			if [ -d $product ]; then 
				update_single_product $product
			fi
		done
	else
		usage
	fi
}

if [ -n "$DTB_DIR" ]; then 
update
else
usage
fi