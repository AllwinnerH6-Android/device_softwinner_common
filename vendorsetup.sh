#
# Copyright (C) 2012 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# This file is executed by build/envsetup.sh, and can use anything
# defined in envsetup.sh.
#
# In particular, you can add lunch options with the add_lunch_combo
# function: add_lunch_combo generic-eng

export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
export CLASSPATH=.:$JAVA_HOME/lib

android_top_path=$(cd $(dirname ${BASH_SOURCE[0]})/../../.. && pwd)
lichee_top_path=$(cd $android_top_path/../lichee && pwd)

function get_device_dir()
{
    local target_device=""
    if [ -n "$ANDROID_PRODUCT_OUT" ]; then
        target_device=$(basename $ANDROID_PRODUCT_OUT)
    else
        target_device=$(get_build_var TARGET_DEVICE)
    fi
    DEVICE=$(gettop)/device/softwinner/$target_device
}

function cdevice()
{
    get_device_dir
    cd $DEVICE
}

function cout()
{
    cd $OUT
}

function ca()
{
    cd $android_top_path
}

function com()
{
    cd $android_top_path/device/softwinner/common
}

function cl()
{
    cd $lichee_top_path
}

function ck()
{
    if [ ! -f $lichee_top_path/.buildconfig ]; then
        echo "Please run ./build.sh config first!"
        return 1
    fi
    kver=$(grep LICHEE_KERN_VER $lichee_top_path/.buildconfig | awk '{print $2}' | awk -F "=" '{print $2}')
    cd $lichee_top_path/$kver
}

function ct()
{
    cd $lichee_top_path/tools
}

function cbr()
{
    cd $lichee_top_path/brandy/u-boot-2014.07
}

function cbt()
{
    cd $lichee_top_path/bootloader/uboot_2014_sunxi_spl/sunxi_spl
}

function cbd()
{
    if [ ! -f $lichee_top_path/.buildconfig ]; then
        echo "Please run ./build.sh config first!"
        return 1
    fi
    chip=$(grep  LICHEE_CHIP  $lichee_top_path/.buildconfig | awk '{print $2}' | awk -F "=" '{print $2}')
    board=$(grep LICHEE_BOARD $lichee_top_path/.buildconfig | awk '{print $2}' | awk -F "=" '{print $2}')
    cd $lichee_top_path/tools/pack/chips/$chip/configs/$board
}

function get_lichee_out_dir()
{
    LICHEE_DIR=$ANDROID_BUILD_TOP/../lichee

    TARGET_BOARD_PLATFORM=$(get_build_var TARGET_BOARD_PLATFORM)
    TARGET_BOARD_CHIP=$(get_build_var TARGET_BOARD_CHIP)
    LINUXOUT_DIR=$LICHEE_DIR/out/$TARGET_BOARD_CHIP/android/common
    LINUXOUT_MODULE_DIR=$LINUXOUT_DIR/lib/modules/*/*
}

function extract-bsp()
{
    CURDIR=$PWD

    get_lichee_out_dir
    get_device_dir

    cd $DEVICE

    #extract kernel
    if [ -f kernel ] ; then
        rm kernel
    fi
    cp $LINUXOUT_DIR/bImage kernel
    echo "Copy $LINUXOUT_DIR/bImage to $DEVICE/kernel"

    #extract dtboimg
    if [ -f $DEVICE/dtbo.img ] ; then
        rm $DEVICE/dtbo.img
    fi
    cp $LINUXOUT_DIR/dtbo.img $DEVICE/dtbo.img
    echo "Copy $LINUXOUT_DIR/dtbo.img to $DEVICE/dtbo.img"

    #extract linux modules
    if [ -d modules ] ; then
        rm -rf modules
    fi
    mkdir -p modules/modules
    cp -rf $LINUXOUT_MODULE_DIR modules/modules
    echo "Copy $LINUXOUT_MODULE_DIR to $DEVICE/modules!"
    chmod 0755 modules/modules/*

# create modules.mk
(cat << EOF) > ./modules/modules.mk
# modules.mk generate by extract-files.sh, do not edit it.
PRODUCT_COPY_FILES += \\
    \$(call find-copy-subdir-files,*,\$(LOCAL_PATH)/modules,\$(TARGET_COPY_OUT_VENDOR)/modules)
EOF

    cd $CURDIR
}

function package_usage()
{
    printf "Usage: pack [-cCHIP] [-pPLATFORM] [-bBOARD] [-d] [-s] [-v] [-h]
    -c CHIP (default: $chip)
    -p PLATFORM (default: $platform)
    -b BOARD (default: $board)
    -d pack firmware with debug info output to card0
    -s pack firmware with signature
    -v pack firmware with secureboot
    -h print this help message
"
}

function package()
{
    chip=$(get_build_var TARGET_BOARD_CHIP)
    platform=android
    board=$(get_build_var PRODUCT_BOARD)
    debug=uart0
    sigmode=none
    securemode=none

    while getopts "c:p:b:dsvh" arg
    do
        case $arg in
            c)
                chip=$OPTARG
                ;;
            p)
                platform=$OPTARG
                ;;
            b)
                board=$OPTARG
                ;;
            d)
                debug=card0
                ;;
            s)
                sigmode=sig
                ;;
            v)
                securemode=secure
                ;;
            h)
                package_usage
                return 0
                ;;
            ?)
                return 1
                ;;
        esac
    done

    cd $PACKAGE
    ./pack -c $chip -p $platform -b $board -d $debug -s $sigmode -v $securemode
    cd -
}

function pack()
{
    if [ -f $DEVICE/package.sh ]; then
        T=$(gettop)
        get_device_dir
        export ANDROID_IMAGE_OUT=$OUT
        export PACKAGE=$T/../lichee/tools/pack
        sh $DEVICE/package.sh $*
    else
        T=$(gettop)
        get_device_dir
        export ANDROID_IMAGE_OUT=$OUT
        export PACKAGE=$T/../lichee/tools/pack

        #verity_data_init

        OPTIND=1
        package $@
        echo -e "\033[31muse pack4dist for release\033[0m"
    fi
}

function fex_copy()
{
    if [ -e $1 ]; then
        cp -vf $1 $2
    else
        echo $1" not exist"
    fi
}

function update_uboot()
{
    echo "copy fex into $1"
    mkdir ./IMAGES
    fex_copy $PACKAGE/out/boot-resource.fex ./IMAGES/boot-resource.fex
    fex_copy $PACKAGE/out/env.fex ./IMAGES/env.fex
    fex_copy $PACKAGE/out/boot0_nand.fex ./IMAGES/boot0_nand.fex
    fex_copy $PACKAGE/out/boot0_sdcard.fex ./IMAGES/boot0_sdcard.fex
    fex_copy $PACKAGE/out/boot_package.fex ./IMAGES/u-boot.fex
    fex_copy $PACKAGE/out/toc1.fex ./IMAGES/toc1.fex
    fex_copy $PACKAGE/out/toc0.fex ./IMAGES/toc0.fex
    zip -r -m $1 ./IMAGES
}

function pack4dist()
{
    # Found out the number of cores we can use
    cpu_cores=`cat /proc/cpuinfo | grep "processor" | wc -l`
    if [ ${cpu_cores} -le 8 ] ; then
        JOBS=${cpu_cores}
    else
        JOBS=`expr ${cpu_cores} / 2`
    fi
    make -j $JOBS target-files-package
    BUILD_NUMBER_OUT=$(get_build_var OUT_DIR)
    FILE_NAME=$(cat $BUILD_NUMBER_OUT/build_number.txt)
    DATE=$FILE_NAME
    keys_dir="./vendor/security"
    target_files="$OUT/obj/PACKAGING/target_files_intermediates/$TARGET_PRODUCT-target_files-$DATE.zip"
    signed_target_files="$OUT/$TARGET_PRODUCT-signed_target_files-$DATE.zip"
    full_ota="$OUT/$TARGET_PRODUCT-full_ota-$DATE.zip"
    target_images="$OUT/target_images.zip"

    if [ -d $keys_dir ] ; then
        ./build/tools/releasetools/sign_target_files_apks \
            -d $keys_dir $target_files $signed_target_files
        ./build/tools/releasetools/img_from_target_files \
            $signed_target_files $target_images
        final_target_files=$signed_target_files
    else
        ./build/tools/releasetools/img_from_target_files \
            $target_files $target_images
        final_target_files=$target_files
    fi

    unzip -o $target_images -d $OUT
    rm $target_images

    pack $@
    update_uboot $final_target_files
    ./build/tools/releasetools/ota_from_target_files --block $final_target_files $full_ota
    echo -e "target files package: \033[31m$final_target_files\033[0m"
    echo -e "full ota zip: \033[31m$full_ota\033[0m"
}

function read_var()
{
    read -p "please enter $1($2): " TMP
    eval $1="${TMP:=\"$2\"}"
}

function clone()
{
    if [ $# -ne 0 ]; then
        echo "don't enter any params"
        return
    fi
    source_device=$(get_build_var TARGET_DEVICE)
    source_product=$(get_build_var TARGET_PRODUCT)
    source_path=$(gettop)/device/softwinner/$source_device
    # PRODUCT_DEVICE
    read_var PRODUCT_DEVICE "$source_device"
    if [ $source_device == $PRODUCT_DEVICE ]; then
        echo "don't have the same device name!"
        return
    fi
    TARGET_PATH=$(gettop)/device/softwinner/$PRODUCT_DEVICE
    if [ -e $TARGET_PATH ]; then
        read -p "$PRODUCT_DEVICE is already exists, delete it?(y/n)"
        case $REPLY in
            [Yy])
                echo "delete"
                rm -rf $TARGET_PATH
                ;;
            [Nn])
                echo "do nothing"
                return
                ;;
            *)
                echo "do nothing"
                return
                ;;
        esac
    fi
    # copy device
    cp -r $source_path $TARGET_PATH
    rm -rf $TARGET_PATH/.git*
    sed -i "s/$source_device/$PRODUCT_DEVICE/g" `grep -rl $source_device $TARGET_PATH`
    # PRODUCT_NAME
    read_var PRODUCT_NAME "$source_product"
    if [ $source_product == $PRODUCT_NAME ]; then
        echo "don't have the same product name!"
        return
    fi
    mv $TARGET_PATH/$source_product.mk $TARGET_PATH/$PRODUCT_NAME.mk
    sed -i "s/$source_product/$PRODUCT_NAME/g" `grep -rl $source_product $TARGET_PATH`
    # config
    read_var PRODUCT_BOARD "$(get_build_var PRODUCT_BOARD)"
    sed -i "s/\(PRODUCT_BOARD := \).*/\1$PRODUCT_BOARD/g" $TARGET_PATH/$PRODUCT_NAME.mk
    read_var PRODUCT_MODEL "$(get_build_var PRODUCT_MODEL)"
    sed -i "s/\(PRODUCT_MODEL := \).*/\1$PRODUCT_MODEL/g" $TARGET_PATH/$PRODUCT_NAME.mk
    density=`sed -n 's/.*ro\.sf\.lcd_density=\([0-9]\+\).*/\1/p' $TARGET_PATH/$PRODUCT_NAME.mk`
    read_var DENSITY "$density"
    sed -i "s/\(ro\.sf\.lcd_density=\).*/\1$DENSITY/g" $TARGET_PATH/$PRODUCT_NAME.mk
    # 160(mdpi) 213(tvdpi) 240(hdpi) 320(xhdpi) 400(400dpi) 480(xxhdpi) 560(560dpi) 640(xxxhdpi)
    if [ $DENSITY -lt 186 ]; then
        PRODUCT_AAPT_PREF_CONFIG=mdpi
    elif [ $DENSITY -lt 226 ]; then
        PRODUCT_AAPT_PREF_CONFIG=tvdpi
    elif [ $DENSITY -lt 280 ]; then
        PRODUCT_AAPT_PREF_CONFIG=hdpi
    elif [ $DENSITY -lt 360 ]; then
        PRODUCT_AAPT_PREF_CONFIG=xhdpi
    elif [ $DENSITY -lt 440 ]; then
        PRODUCT_AAPT_PREF_CONFIG=400dpi
    elif [ $DENSITY -lt 520 ]; then
        PRODUCT_AAPT_PREF_CONFIG=xxhdpi
    elif [ $DENSITY -lt 600 ]; then
        PRODUCT_AAPT_PREF_CONFIG=560dpi
    else
        PRODUCT_AAPT_PREF_CONFIG=xxxhdpi
    fi
    sed -i "s/\(PRODUCT_AAPT_PREF_CONFIG := \).*/\1$PRODUCT_AAPT_PREF_CONFIG/g" $TARGET_PATH/$PRODUCT_NAME.mk
}


function awsync_dologin()
{
  AWSYNC_USERNAME=$(whoami)
  if [ -z ${AWSYNC_SERVER} ]; then
    AWSYNC_SERVER=192.168.95.10
  fi

  ssh-copy-id -o StrictHostKeyChecking=no ${AWSYNC_USERNAME}@${AWSYNC_SERVER} > $HOME/.ssh-copy-id.log 2>&1
  if [ $? -ne 0 ]; then
    cat $HOME/.ssh-copy-id.log
    if [ ! -f $HOME/.ssh/*.pub ]; then
      echo "ssh key not found, please run ssh-keygen then try again!"
    fi
    return 1
  fi
}

function awsync_dosync()
{
  declare OPT
  declare OPTARG
  declare OPTIND
  local src_arr=()
  while getopts ":s:" OPT
  do
    case $OPT in
      s)
        src_arr+=("$OPTARG")
        ;;
      ?)
        return 0
    esac
  done
  for src in ${src_arr[@]}; do
    absolute_path=$(readlink -f $src)
    if [ $? -ne 0 ]; then
      echo "## No such file or directory: $src"
      return 1
    fi
    cd $HOME
    local relative_path=${absolute_path#$HOME/}
    rsync -avzh --delete --exclude .git --relative ${relative_path} ${AWSYNC_USERNAME}@${AWSYNC_SERVER}:${HOME} && cd -
    if [ $? -ne 0 ]; then
      cd -
      return 1
    fi
  done
}

function awsync_dosyncpack()
{
  cd ${ANDROID_BUILD_TOP}
  source ../lichee/.buildconfig

  mkdir -p ${ANDROID_BUILD_TOP}/.tmp
  local suffix=$(cat "$ANDROID_BUILD_TOP/out/build_number.txt")
  local target_files=${OUT}/obj/PACKAGING/target_files_intermediates/${TARGET_PRODUCT}-target_files-${suffix}
  local target_files_remote=${ANDROID_BUILD_TOP}/.tmp/${TARGET_PRODUCT}-target_files

  if [ -d ${OUT}/obj/PACKAGING/target_files_intermediates ]; then
    cd ${OUT}/obj/PACKAGING/target_files_intermediates
    ls | grep -v "${TARGET_PRODUCT}-target_files-${suffix}" | xargs rm -rf
    cd -
  fi

cat>${ANDROID_BUILD_TOP}/.tmp/syncpack.sh<<EOF
cd ${ANDROID_BUILD_TOP}
source $(readlink -f "${ANDROID_BUILD_TOP}/build/envsetup.sh")
lunch ${TARGET_PRODUCT}-${TARGET_BUILD_VARIANT}
mkdir -p ${ANDROID_PRODUCT_OUT}
$(readlink -f "$ANDROID_BUILD_TOP/build/tools/releasetools")/add_img_to_target_files.py -a -v -p ${ANDROID_HOST_OUT} ${target_files_remote} && \
mv ${target_files_remote}/IMAGES/*.img ${ANDROID_PRODUCT_OUT}/
if [[ \$? -ne 0 ]]; then
  exit 1
fi
pack $*
EOF
  chmod u+x ${ANDROID_BUILD_TOP}/.tmp/syncpack.sh

  awsync_dosync -s ${ANDROID_BUILD_TOP}/out/host/linux-x86/bin/ \
	-s ${ANDROID_BUILD_TOP}/out/host/linux-x86/framework/ \
	-s ${ANDROID_BUILD_TOP}/out/host/linux-x86/lib/ \
	-s ${ANDROID_BUILD_TOP}/out/host/linux-x86/lib64/ \
	-s ${ANDROID_BUILD_TOP}/build/target/product/security/ \
	-s ${ANDROID_BUILD_TOP}/build/tools/releasetools/ \
	-s ${ANDROID_BUILD_TOP}/device/softwinner/ \
	-s ${ANDROID_BUILD_TOP}/sdk \
	-s ${ANDROID_BUILD_TOP}/system/extras/verity \
	-s ${ANDROID_BUILD_TOP}/build \
	-s ${ANDROID_BUILD_TOP}/prebuilts/build-tools/linux-x86 \
	-s ${ANDROID_BUILD_TOP}/prebuilts/go/linux-x86 \
	-s ${ANDROID_BUILD_TOP}/frameworks/av \
	-s ${ANDROID_BUILD_TOP}/vendor/aw \
	-s ${ANDROID_BUILD_TOP}/hardware \
	-s ${ANDROID_BUILD_TOP}/.tmp/syncpack.sh \
	-s ${ANDROID_BUILD_TOP}/../lichee/tools/pack/common/ \
	-s ${ANDROID_BUILD_TOP}/../lichee/tools/pack/pctools/ \
	-s ${ANDROID_BUILD_TOP}/../lichee/tools/pack/chips/${LICHEE_CHIP}/ \
	-s ${ANDROID_BUILD_TOP}/../lichee/tools/build/ \
	-s ${ANDROID_BUILD_TOP}/../lichee/tools/pack/pack \
	-s ${ANDROID_BUILD_TOP}/../lichee/tools/pack/createkeys \
	-s ${ANDROID_BUILD_TOP}/../lichee/.buildconfig \
	-s ${ANDROID_BUILD_TOP}/../lichee/build.sh \
	-s ${ANDROID_BUILD_TOP}/../lichee/out/${LICHEE_CHIP}/ \
	-s ${ANDROID_BUILD_TOP}/../lichee/${LICHEE_KERN_VER}/arch/arm/boot/dts/ \
	-s ${ANDROID_BUILD_TOP}/../lichee/${LICHEE_KERN_VER}/arch/arm64/boot/dts/sunxi/ \
	-s ${ANDROID_BUILD_TOP}/../lichee/${LICHEE_KERN_VER}/scripts/dtc/dtc && \
	rsync -avzh --delete ${target_files}/* --exclude IMAGES ${AWSYNC_USERNAME}@${AWSYNC_SERVER}:${target_files_remote}
  if [ $? -ne 0 ]; then
    echo "## sync failed！"
    return 1
  fi

  echo "## sync success，run pack ..."
  ssh ${AWSYNC_USERNAME}@${AWSYNC_SERVER} "${ANDROID_BUILD_TOP}/.tmp/syncpack.sh"
}

function syncpack()
{
  declare OPT
  declare OPTARG
  declare OPTIND
  while getopts ":hH" OPT
  do
    case $OPT in
      h|H)
        package_usage
        return 0
        ;;
      ?)
        ;;
    esac
  done

  if [ -z ${ANDROID_BUILD_TOP} ]; then
    echo "## Environment variable is not properly set: ANDROID_BUILD_TOP."
    return 1
  fi
  awsync_dologin && time awsync_dosyncpack $*
}

