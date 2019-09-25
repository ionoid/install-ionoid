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
IMAGE_NAME=$IMAGE_NAME
IMAGE_DIR=$IMAGE_DIR

export STATUS_FILE=$STATUS_FILE

declare CLEANED=0
declare ROOTFS=""
declare BOOTFS=""
declare -a MAPPER_PARTITIONS
declare LOOP_DEVICE=""
declare LOCKFD=99
declare LOCKFILE=$BUILDOS_LOCK
declare CLEANED_LOCK=0

SEALOS_MANAGER_ZIPPED=$(grep -r --include 'sealos-manager*.zip' -le "$regexp" ./)

SEALOS_MANAGER_UNZIPPED="${SEALOS_MANAGER_ZIPPED%.*}/"
OSFILE=$(grep -r --include '${OS}*.zip' -le "$regexp" ./)

schedule_feedback() {

        if [ -z ${STATUS_FILE} ]; then
                return
        fi

        file=$STATUS_FILE
        percentage=$4
        status=$2
        message=$3
        image=$5

        PAYLOAD="{ \
                \"progress\": ${percentage}, \
                \"status\": \"${status}\", \
                \"message\": \"${message}\", \
                \"image\": \"${image}\" \
        }"

        echo $PAYLOAD | tee $file.tmp
        chown www-data.www-data ${file}.tmp
        mv -f ${file}.tmp ${file}
}

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

cp_config_to_bootfs() {
        if [ ! -z ${CONFIG_JSON} ] && [ -f $CONFIG_JSON ]; then
                schedule_feedback $STATUS_FILE "in_progress" \
                        "Configuring the ${IMAGE_NAME} image" 60 "null"
                echo "Install ${OS}: copy ${CONFIG_JSON} into $BOOTFS"
                cp -t $BOOTFS $CONFIG_JSON
                chmod 0600 $BOOTFS/config.json
        fi
}

# Returns offset of classic Raspbian images
get_raspbian_classic_img_rootfs_offset() {
        __start=$(fdisk -l $IMAGE_DIR/$UNZIPPED_IMAGE | grep FAT32 | awk ' {print $2}')
        OFFSET_BOOTFS=$(($__start * 512))
        __start=$(fdisk -l $IMAGE_DIR/$UNZIPPED_IMAGE | grep Linux | awk ' {print $2}')
        OFFSET_ROOTFS=$(($__start * 512))

        echo "Install ${OS}: image boot found at offset $OFFSET_BOOTFS"
        echo "Install ${OS}: image rootfs found at offset $OFFSET_ROOTFS"
}

mount_rootfs()
{
        if [ ! -d $ROOTFS ];then
                mkdir -p $ROOTFS
        fi

        mount ${MAPPER_PARTITIONS[1]} $ROOTFS || exit 2
        echo "Install ${OS}: mounted ${MAPPER_PARTITIONS[1]} at ${ROOTFS} of image ${UNZIPPED_IMAGE}"
}

mount_bootfs()
{
        if [ ! -d $BOOTFS ];then
                mkdir -p $BOOTFS
        fi

        mount ${MAPPER_PARTITIONS[0]} $BOOTFS || exit 2
        echo "Install ${OS}: mounted ${MAPPER_PARTITIONS[0]} at ${BOOTFS} of image ${UNZIPPED_IMAGE}"
}

umount_rootfs()
{
        sync;sync;

        umount $ROOTFS
        echo "Install ${OS}: umounted rootfs ${ROOTFS}"
}

umount_bootfs()
{
        sync;sync;

        umount $BOOTFS
        echo "Install ${OS}: umounted boot ${BOOTFS}"
}

install_sealos_manager()
{
        if [ -z $SEALOS_DIR ]; then
                echo "Install ${OS}: SEALOS_DIR variable not set, skipping sealos-manager install"
                return
        fi

        old_pwd=$(pwd)

        cd $SEALOS_DIR || exit 2

        schedule_feedback $STATUS_FILE "in_progress" \
                "Installing SealOS Manager tools on ${IMAGE_NAME} image" 50 "null"

        echo "Install ${OS}: Installing sealos-manager into $ROOTFS"
        DESTDIR=$ROOTFS ./install.bash

        cd $old_pwd
}

zip_os_image() {
        mkdir -p ${IMAGE_DIR}/output/ || exit 1
        echo "Install ${OS}: compressing ${UNZIPPED_IMAGE} into ${IMAGE_DIR}/output/${IMAGE_NAME}.zip.tmp"
        schedule_feedback $STATUS_FILE "in_progress" \
                "Compressing ${IMAGE_NAME} image into Zip file" 70 "null"
        zip -2 -q -j ${IMAGE_DIR}/output/${IMAGE_NAME}.zip.tmp $IMAGE_DIR/$UNZIPPED_IMAGE
        if [[ $? -ne 0 ]]; then
                echo "Install ${OS}: failed zip Image operation with: $?" >&2
                exit 2
        fi

        # then mv file
        echo "Install ${OS}: zip ${IMAGE_DIR}/output/${IMAGE_NAME}.zip finishing"
        mv -f ${IMAGE_DIR}/output/${IMAGE_NAME}.zip.tmp ${IMAGE_DIR}/output/${IMAGE_NAME}-ionoid.zip || exit 1

        # Clean after finishing
        rm -fr $IMAGE_DIR/$UNZIPPED_IMAGE
}

unzip_os_image() {
        # Check if the File already exists and is unzipped
        if [ -f "$IMAGE_DIR/$UNZIPPED_IMAGE" ]; then
                echo "Install ${OS}: found already raw '${IMAGE_DIR}/${UNZIPPED_IMAGE}' image, ignore unzip operation"
        else
                # unzip in same directory for space storage
                echo "Install ${OS}: decompressing ${IMAGE} into ${IMAGE_DIR}"
                unzip -q -j -o "$IMAGE" -d "$IMAGE_DIR" || exit 1
        fi
}

get_lock() {
        if [ -f "$LOCKFILE" ]; then
                flock -x -w 60 $LOCKFD;
        fi
}

clean_lock() {
        if [ -f "$LOCKFILE" ] || [ "${CLEANED_LOCK}" == 0 ]; then
                flock -u $LOCKFD > /dev/null 2>&1
                flock -xn $LOCKFD > /dev/null 2>&1

                rm -f $LOCKFILE > /dev/null 2>&1

                CLEANED_LOCK=1
        fi
}

init_lock() {
        if [ -n "$LOCKFILE" ]; then
                eval "exec $LOCKFD>\"$LOCKFILE\""
        fi
}

wait_for_loopdevices() {
        # Lets wait for loop devices to show up
        iter=0
        while [ ! -e ${MAPPER_PARTITIONS[1]} ]; do
                echo "Waiting for ${MAPPER_PARTITIONS[1]} to show up"
                sleep 1
                iter=$((${iter} + 1 ))
                if [ ${iter} -gt 5 ]; then
                        echo "Error: Timeout waiting for loop devices ${MAPPER_PARTITIONS[@]}"
                        exit 2
                fi
        done
}

setup_raspbian_filesystem() {
        echo "Install ${OS}: scanning ${UNZIPPED_IMAGE} for partitions"

        declare -a lines

        # Initialize lock
        init_lock

        # Get lock
        get_lock


        # Execute this under lock as we gonna probe for device loops
        # We make sure to use the same reported loop devices

        # IMPORTANT DO NOT REMOVE

        while IFS= read -r line; do
                lines+=($line)
        done < <(kpartx -v -l $IMAGE_DIR/$UNZIPPED_IMAGE)

        if [ "${#lines[@]}" == 16 ]; then
                # Get BOOTFS
                devline=${lines[0]}
                MAPPER_PARTITIONS+=("/dev/mapper/$devline")

                # Get ROOTFS
                devline=${lines[6]}
                MAPPER_PARTITIONS+=("/dev/mapper/$devline")

                loopline=${lines[15]}
                LOOP_DEVICE=$loopline
        else
                echo "Install ${OS}: Error unsupported partitions of ${UNZIPPED_IMAGE}" >&2
                exit 2
        fi

        kpartx -v -a $IMAGE_DIR/$UNZIPPED_IMAGE
        if [[ $? -ne 0 ]]; then
                echo "Install ${OS}: Error kpartx failed to add partitions of ${UNZIPPED_IMAGE}" >&2
                exit 2
        fi

        # Release device loops lock
        clean_lock

        # Wait outside of lock
        wait_for_loopdevices

        echo "Install ${OS}: Loop device attached at ${LOOP_DEVICE}"
        echo "Install ${OS}: Boot partitions prepared at ${MAPPER_PARTITIONS[0]}"
        echo "Install ${OS}: Root partitions prepared at ${MAPPER_PARTITIONS[1]}"
}

cleanup_raspbian_filesystem() {
        if [ "${CLEANED}" == 1 ]; then
                return
        fi

        clean_lock

        umount ${BOOTFS} > /dev/null 2>&1
        umount ${ROOTFS} > /dev/null 2>&1

        kpartx -v -d "$IMAGE_DIR/$UNZIPPED_IMAGE" > /dev/null 2>&1

        echo "install ${OS}: cleaning up ${MAPPER_PARTITIONS[@]} of ${LOOP_DEVICE}"
        kpartx -v -d ${LOOP_DEVICE} > /dev/null 2>&1
        losetup -d ${LOOP_DEVICE} > /dev/null 2>&1

        rm -fr $WORKDIR > /dev/null 2>&1

        CLEANED=1
}

prepare_raspbian_os() {
        echo "Start building ${OS}"

        # Lets set rootfs and bootfs filesystems paths
        ROOTFS="${WORKDIR}/$OS/rootfs"
        BOOTFS="${WORKDIR}/$OS/rootfs/boot"

        UNZIPPED_IMAGE=${IMAGE_NAME}.img

        # Make sure to clean $WORKDIR
        trap cleanup_raspbian_filesystem EXIT || exit 1

        mkdir -p ${WORKDIR}

        # Deprecated for security
        # cp_config_to_sealos_manager

        unzip_os_image

        setup_raspbian_filesystem

        mount_rootfs
        install_sealos_manager
        umount_rootfs

        mount_bootfs
        cp_config_to_bootfs
        umount_bootfs

        cleanup_raspbian_filesystem

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
        fi

        # Match and fix OS env
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

        echo "Build OS '${OS}' into '${IMAGE_DIR}/output/${IMAGE_NAME}-ionoid.zip' finished"

        schedule_feedback $STATUS_FILE "in_progress" \
                "Cleaning of installation tools on ${IMAGE_NAME} image" 85 "null"

        exit 0
}

main $@
