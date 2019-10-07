#!/bin/bash

#
# Copyright (2019) Open Devices
# Copyright (2019) Djalal Harouni
#

# curl https://raw.githubusercontent.com/ionoid/install-ionoid/master/install-ionoid-sealos-manager-sdk.bash | bash

URL=https://raw.githubusercontent.com/opendevices/packages/master/sealos-manager/releases/
BUILD_URL=https://build-os.ionoid.net/tools/install-ionoid/build-os.bash
PARSE_MACHINE_URL=https://build-os.ionoid.net/tools/install-ionoid/ionoid-parse-machine.bash
MANAGER_PACKAGE=sealos-manager
MANAGER_FILE=""
MANGER_URL=""

# STATUS FILE is used by our backend of automatic build-os
export STATUS_FILE=$STATUS_FILE
export BACKEND_BUILD=$BACKEND_BUILD
export BUILDOS_LOCK=$BUILDOS_LOCK
export OUTPUTDIR=$OUTPUTDIR

COMMAND=${0##*/}

usage() {
        echo "
$COMMAND [ --machine=ARCH ] [ --config=config.json ] [ --destdir=DIRECTORY ] [ --image=IMAGE ]

Downloads Ionoid SealOS Manager '$MANAGER_PACKAGE' and then runs the
install.bash script included in the download.

--help
  Print this help message.

--os=OS
  Selects the Operating System.

--machine=ARCH
  Selects machine target. Supported values: arm6, arm7, amd64.
  As an example, for Raspberry PI 3 '--machine=arm7',
  for Raspberry PI Zero '--machine=arm6'. The Machine can also be passed
  as an environment variable: 'MACHINE=arm6 $COMMAND'.

--config=config.json
  Path of the Project's 'config.json' file. This file can be downloaded from
  your Ionoid IoT Projects, select add device to download it.
  The config can also be passed as an envrionment variable:
  'CONFIG=config.json $COMMAND'

--destdir=DIRECTORY
  Sets the installation root directory to DIRECTORY. The default is
  current '/' root filesystem. The install directory can also be passed
  as an environment variable: 'DESTDIR=/install_dir $COMMAND'

--image=IMAGE
  Sets the installation target image to IMAGE. This option takes precendence on
  '--install-dir'. The image should be a supported Linux-IoT OS. The
  target image can also be as an environment variable:
  'IMAGE=/image.img $COMMAND'
" >&2
  exit 2
}

while true; do
        case $# in
                0)  break ;;
        esac
        case $1 in
                --machine)
                shift
                case $# in
                        0)
                        echo "$COMMAND: --machine: ARCH argument expected." >&2
                        exit 1
                        ;;
                esac
                m=$1
                ;;
                --machine=*)
                m=${1#*=}
                ;;
                --destdir)
                shift
                case $# in
                        0)
                        echo "$COMMAND: --destdir: DIRECTORY argument expected." >&2
                        exit 1
                        ;;
                esac
                DESTDIR=$1
                ;;
                --destdir=*)
                DESTDIR=${1#*=}
                ;;
                --image)
                shift
                case $# in
                        0)
                        echo "$COMMAND: --image: IMAGE argument expected." >&2
                        exit 1
                        ;;
                esac
                IMAGE=$1
                ;;
                --image=*)
                IMAGE=${1#*=}
                ;;
                --config)
                shift
                case $# in
                        0)
                        echo "$COMMAND: --config: CONFIG argument expected." >&2
                        exit 1
                        ;;
                esac
                CONFIG=$1
                ;;
                --image=*)
                CONFIG=${1#*=}
                ;;
                --help)
                usage
                ;;
        *)
                usage
                ;;
        esac
        shift
done

declare manager_dst="/run/install-ionoid/"

trace() {
        echo "$@" >&2
        "$@"
}

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

# Check if kpartx is installed first
check_for_necessary_tools() {
        which kpartx
        if [[ $? -ne 0 ]]; then
                echo "$COMMAND: Error: can not find 'kpartx', make sure to install it before" >&2
                echo "$COMMAND: for Debian based distos: sudo apt-get install kpartx" >&2
                echo "$COMMAND: for Fedora based distos: sudo dnf install kpartx" >&2
                exit 2
        fi

        which losetup
        if [[ $? -ne 0 ]]; then
                echo "$COMMAND: Error: can not find 'losetup', make sure to install it before" >&2
                echo "$COMMAND: for Debian based distos: sudo apt-get install util-linux" >&2
                echo "$COMMAND: for Fedora based distos: sudo dnf install fedora install util-linux" >&2
                exit 2
        fi

        which jq
        if [[ $? -ne 0 ]]; then
                echo "$COMMAND: Error: can not find 'jq (Command-line JSON processor)', make sure to install it before" >&2
                echo "$COMMAND: for Debian based distos: sudo apt-get install jq" >&2
                echo "$COMMAND: for Fedora based distos: sudo dnf install fedora install jq" >&2
                exit 2
        fi
}

download_parse_machine_helper() {
        parse_machine_script=$1

        if [ ! -f "$parse_machine_script" ]; then
                curl -o "$parse_machine_script" -s -C - -# -f "$PARSE_MACHINE_URL"
                if [[ $? -ne 0 ]]; then
                        schedule_feedback $STATUS_FILE "error" \
                                "Build OS: failed download $PARSE_MACHINE_URL" 0 "null"
                        exit 1
                fi
        fi

        source $parse_machine_script
}


# Downloads build-os script and save it if necessary
download_build_os_script() {
        build_os_file=$1

        if [ -f $build_os_file ]; then
                chmod 775 "$build_os_file"
                return
        fi

        if trace which curl >/dev/null; then
                echo "Downloading Build OS script: $BUILD_URL"
                curl -o "$build_os_file" -s -C - -# -f "$BUILD_URL" || exit 1
                chmod 775 "$build_os_file"
        else
                echo "Error: failed 'curl' must be installed to download files." >&2
                return 1
        fi
}

download_sealos_manager() {
        SRC=$1
        DST=$2

        MANAGER_URL=$(trace curl -s -# -f "$SRC")

        # already downloaded file ?
        if [ -f $DST ]; then
                size=$(stat -c%s "$DST")

                ret=$(curl --retry 2 -sI -S \
                                --output /dev/null \
                                --write-out "%{http_code}" -- $MANAGER_URL)

                if [ "$ret" -eq "200" ]; then
                        length=$(curl --retry 2 -sI -S \
                                        -- $MANAGER_URL 2>/dev/null | \
                                        grep -E -i "^(Content-Length:.*)|^(content-length:.*)" | \
                                        awk '{print $2}' | tr -d '\r')
                        if [ "${size}" -eq "${length}" ]; then
                                echo "Install: already found $DST size $size, do not download again"
                                        return
                        else
                                echo "Install: found $DST but seems invalid, scheduling download"
                        fi
                fi
        fi

        echo "Downloading SealOS Manager from: $MANAGER_URL"
        trace curl -o "$DST" -C - -# -f "$MANAGER_URL"
}

install() {
        check_for_necessary_tools

        # Download parse machine if it is not here
        download_parse_machine_helper "./ionoid-parse-machine.bash"

        # Parse machine
        parse_machine ${MACHINE}

        # Check again
        if [ -z ${MACHINE} ]; then
                echo "Error: machine arch is not set" >&2
                schedule_feedback $STATUS_FILE "error" \
                        "Build OS failed passed Architecture Machine not supported" 0 "null"
                exit 1
        fi

        export OS=$OS
        export DESTDIR=$DESTDIR


        export CONFIG=$(realpath $CONFIG)
        export MACHINE=$MACHINE
        export IMAGE=$(realpath $IMAGE)

        echo "$COMMAND: Working on Project MACHINE '${MACHINE}'" >&2
        MANAGER_FILE="sealos-manager-latest-${MACHINE}"

        # Lets create directories again anyway
        mkdir -p ${manager_dst}

        # if not able to create manager_dst lets just store it into tmp
        if [ ! -d ${manager_dst} ]; then
                manager_dst=$scratch
        fi

        download_src=$URL/${MANAGER_FILE}.link
        download_dst=${manager_dst}/${MANAGER_FILE}.zip
        extract_dst=$manager_dst/${MANAGER_FILE}

        schedule_feedback $STATUS_FILE "in_progress" \
                "Downloading build OS tools" 33 "null"

        # Download from github.
        echo "$COMMAND: Selected SealOS Manager version: $MANAGER_FILE" >&2
        schedule_feedback $STATUS_FILE "in_progress" \
                "Downloading SealOS Manager tools" 35 "null"

        # Download SealOS Manager has to be called to resolve manager version
        download_sealos_manager "$download_src" "$download_dst" || return
        echo

        # Get SealOS Manager Version into target_dir
        target_dir=$(basename -- $MANAGER_URL)
        target_dir="${target_dir%.*}"
        export SEALOS_DIR="${extract_dst}/${target_dir}"

        # Before unzip check if sealos-manager was already extracted
        if [ ! -f "${SEALOS_DIR}/prod/machine" ]; then
                trace unzip -q -o "$download_dst" -d "${extract_dst}" || return
                echo
        fi

        # SealOS Manager now is extracted at location $extract_dst/$target_dir

        export IMAGE_NAME=$(basename $IMAGE)
        export IMAGE_NAME="${IMAGE_NAME%.*}"

        schedule_feedback $STATUS_FILE "in_progress" \
                "Starting Intallation using ${IMAGE_NAME} OS" 40 "null"
        echo "Starting Installation ${target_dir}"

        #
        # Work on images and install from build-os.bash
        #
        if [ -n $IMAGE ]; then
                if [ ! -f $IMAGE ]; then
                        echo "Error: can not locate image ${IMAGE}"
                        exit 1
                fi
                echo "Using $IMAGE as a target image"

                # Lets get image name and directory
                export IMAGE_DIR=$(dirname $IMAGE)

                if [ "$BACKEND_BUILD" = "true" ]; then
                        # Download build os and store it into scratch $WORKDIR
                        download_build_os_script "./build-os.bash"

                        # Lets track mounts
                        export WORKDIR="/run/shm/${OUTPUTDIR}"
                else
                        download_build_os_script "$scratch/build-os.bash"
                        # If not a backend build then cd into $scratch
                        export WORKDIR=$scratch
                        trace cd "$scratch"
                fi

                if [ "$UID" = "0" ]; then
                        trace "./build-os.bash" || return
                else
                        trace sudo -E "./build-os.bash" || return
                fi
        else
                trace cd "$extract_dst/${target_dir}"

                # Install config.json to be put into production
                if [ ! -z ${CONFIG} ]; then
                        echo "Copying ${CONFIG} to ${extract_dst}/${target_dir}"
                        trace cp -t ./prod ${CONFIG} || true
                        trace chmod 0600 ./prod/${CONFIG}
                fi

                if [ "$UID" = "0" ]; then
                        trace "./install.bash" || return
                else
                        trace sudo -E "./install.bash" || return
                fi

                echo "Installing Ionoid Tools finished"
        fi

        schedule_feedback $STATUS_FILE "in_progress" \
                "Installation of tools on ${IMAGE_NAME} finished" 85 "null"

        echo
}

scratch=$(mktemp -d -t tmp.XXXXXXXXXX) || exit 1

trap "command rm -rf $scratch" EXIT || exit 1

install
