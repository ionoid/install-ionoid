#!/bin/bash

#
# Copyright (2019) Nazim Djafar
# Copyright (2019) Djalal Harouni
# Copyright (2019) Open Devices
#

#
# This tool allows to add config.json and sealos manager into
# an OS image.
#
# It also allows to configure your OS Image
#
# Supported OSs:
#       raspbian
#

#
# Run with root as:
# OS="raspbian" CONFIG="config.json" \
#       IMAGE="image.zip" WORKDIR="path_where_mount_image" \
#       SEALOS_DIR="sealos-manager-version-path" \
#       ./build-os.bash
#

COMMAND=${0##*/}

OS=$OS
IMAGE=$IMAGE
WORKDIR=$WORKDIR
CONFIG_JSON=$CONFIG
SEALOS_DIR=$SEALOS_DIR

SEALOS_MANAGER_ZIPPED=$(grep -r --include 'sealos-manager*.zip' -le "$regexp" ./)

SEALOS_MANAGER_UNZIPPED="${SEALOS_MANAGER_ZIPPED%.*}/"
OSFILE=$(grep -r --include '${OS}*.zip' -le "$regexp" ./)


check_file() {
        if [ ! -e $1 ]; then
                echo "Error $1: file does not exist"
                exit 1
        fi
}

cp_config_to_sealos_manager() {
        if [ -z ${SEALOS_DIR} ]; then
                return
        fi

        if [ ! -z ${CONFIG_JSON} ] && [ -f $CONFIG_JSON ]; then
                echo "Install ${OS}: copy ${CONFIG_JSON} into $SEALOS_DIR/prod/"
                cp -t $SEALOS_DIR/prod/ $CONFIG_JSON
                chmod 0600 $SEALOS_DIR/prod/config.json
        fi
}

# Returns offset of classic Raspbian images
get_raspbian_classic_img_rootfs_offset() {
        __start=$(fdisk -l $IMAGE_DIR/$UNZIPPED_IMAGE | grep Linux | awk ' {print $2}')
        OFFSET=$(($__start * 512))

        echo "Install ${OS}: image rootfs found at offset $OFFSET"
}

mount_rootfs()
{
        if [ ! -d $ROOTFS ];then
                mkdir -p $ROOTFS
        fi

        mount -o loop,offset=$OFFSET $IMAGE_DIR/$UNZIPPED_IMAGE $ROOTFS || exit 2
        echo "Install ${OS}: mounted rootfs of ${IMAGE} at ${ROOTFS}"
}

umount_rootfs()
{
        sync;sync;
        umount $ROOTFS
        echo "Install ${OS}: umounted rootfs ${ROOTFS}"
}

install_sealos_manager()
{
        if [ -z $SEALOS_DIR ]; then
                echo "Install ${OS}: SEALOS_DIR variable not set, skipping sealos-manager install"
                return
        fi

        old_pwd=$(pwd)

        cd $SEALOS_DIR || exit 2


        echo "Install ${OS}: Installing sealos-manager into $ROOTFS"
        DESTDIR=$ROOTFS ./install.bash

        cd $old_pwd
}

zip_os_image()
{
        echo "Install ${OS}: compressing ${UNZIPPED_IMAGE} into ${IMAGE}"
        zip tmp$IMAGE $IMAGE_DIR/$UNZIPPED_IMAGE

        # then mv file
        echo "Install ${OS}: zip ${IMAGE} finishing"
        mv -f tmp$IMAGE $IMAGE || exit 1
}

unzip_os_image() {
        rm -f $IMAGE_DIR/$UNZIPPED_IMAGE

        # unzip in same directory for space storage
        echo "Install ${OS}: decompressing ${IMAGE} into ${IMAGE_DIR}"
        unzip "$IMAGE" -d "$IMAGE_DIR" || exit 1
}

prepare_raspbian_os() {
        echo "Start building ${OS}"

        cp_config_to_sealos_manager

        UNZIPPED_IMAGE=${IMAGE_NAME}.img
        unzip_os_image

        get_raspbian_classic_img_rootfs_offset
        mount_rootfs
        install_sealos_manager
        umount_rootfs

        zip_os_image

        return
}

main() {
        if [ "$UID" -ne "0" ]; then
                echo "Error: $COMMAND must be run as root"
                exit 2
        fi

        if [ -z ${IMAGE} ]; then
                echo "Error: needs an Image, run with: IMAGE=file $COMMAND"
                exit 2
        fi

        if [ ! -f ${IMAGE} ]; then
                echo "Error: Image file '${IMAGE} not valid"
                exit 2
        fi

        if [ -z ${WORKDIR} ]; then
                WORKDIR=$(mktemp -d -t tmp.XXXXXXXXXX) || exit 1
                trap "command umount ${WORKDIR}/${OS}/rootfs; command rm -rf $WORKDIR" EXIT || exit 1
        fi

        IMAGE_NAME=$(basename $IMAGE)
        IMAGE_NAME="${IMAGE_NAME%.*}"
        IMAGE_DIR=$(dirname $IMAGE)
        ROOTFS="${WORKDIR}/$OS/rootfs"

        # fix OS env
        if [ -z $OS ]; then
                if [[ $IMAGE == *"raspbian"* ]]; then
                        OS="raspbian"
                fi
        fi

        if [ "$OS" = "raspbian" ]; then
                prepare_raspbian_os
        else
                echo "Error: $OS not supported"
                exit 1
        fi

        echo "Build OS '${OS}' into '${IMAGE}' finished"

        exit 0
}

main $@
