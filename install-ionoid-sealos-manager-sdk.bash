#!/bin/bash

#
# Copyright (2019) Open Devices GmbH
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
export LOCAL_BUILD=$LOCAL_BUILD
export BUILDOS_LOCK=$BUILDOS_LOCK
export OUTPUTDIR=$OUTPUTDIR
export MACHINE=$MACHINE

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

declare manager_dst="/data/apps/download/"

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
        which kpartx > /dev/null 2>&1
        if [[ $? -ne 0 ]]; then
                echo "$COMMAND: Error: can not find 'kpartx (Create device maps from partition tables)', make sure to install it before" >&2
                echo "$COMMAND: for Debian based distos: sudo apt-get install kpartx" >&2
                echo "$COMMAND: for Fedora based distos: sudo dnf install kpartx" >&2
                exit 2
        fi

        which losetup > /dev/null 2>&1
        if [[ $? -ne 0 ]]; then
                echo "$COMMAND: Error: can not find 'losetup', make sure to install it before" >&2
                echo "$COMMAND: for Debian based distos: sudo apt-get install util-linux" >&2
                echo "$COMMAND: for Fedora based distos: sudo dnf install fedora install util-linux" >&2
                exit 2
        fi

        which jq > /dev/null 2>&1
        if [[ $? -ne 0 ]]; then
                echo "$COMMAND: Error: can not find 'jq (Command-line JSON processor)', make sure to install it before" >&2
                echo "$COMMAND: for Debian based distos: sudo apt-get install jq" >&2
                echo "$COMMAND: for Fedora based distos: sudo dnf install fedora install jq" >&2
                exit 2
        fi

        which zip > /dev/null 2>&1
        if [[ $? -ne 0 ]]; then
                echo "$COMMAND: Error: can not find 'zip (package and compress (archive) file)', make sure to install it before" >&2
                echo "$COMMAND: for Debian based distos: sudo apt-get install zip unzip" >&2
                echo "$COMMAND: for Fedora based distos: sudo dnf install fedora install zip unzip" >&2
                exit 2
        fi
}

download_script_helpers() {
        script=$1
        url=$2

        if [ "$LOCAL_BUILD" = "true" ] && [ -f $script ]; then
                source $script
                return
        fi

        mkdir -p $(dirname $script)

        # Always download cause we may update them later
        curl -o "$script" -L -s -# -f "$url"
        if [[ $? -ne 0 ]]; then
                echo "$COMMAND: Error: failed to download $url" >&2
                schedule_feedback $STATUS_FILE "error" \
                        "Build OS: failed download $url" 0 "null"
                exit 1
        fi

        source $script
}

download_post_install_scripts() {
        currentdir=$1
        scripts=(raspbian-post-install.bash)

        for script in "${scripts[@]}"; do
                target="$currentdir/post-build.d/$script"
                url="https://build-os.ionoid.net/tools/install-ionoid/post-build.d/$script"
                download_script_helpers $target $url
        done
}

# Downloads build-os script and save it if necessary
download_build_os_script() {
        build_os_file=$1

        if [ "$LOCAL_BUILD" = "true" ] && [ -f $build_os_file ]; then
                chmod 775 "$build_os_file"
                return
        fi

        if trace which curl >/dev/null; then
                echo "Installl: downloading Build OS script: $BUILD_URL"
                curl -o "$build_os_file" -L -s -# -f "$BUILD_URL" || exit 1
                chmod 775 "$build_os_file"
        else
                echo "Error: failed 'curl' must be installed to download files." >&2
                return 1
        fi
}

download_sealos_manager() {
        SRC=$1
        DST=$2

        MANAGER_RESOLVED_URL=$(trace curl -L -s -# -f "$SRC")

        if [[ $? -ne 0 ]]; then
                echo "Error: failed 'curl' to check sealos-manager URL '$SRC'." >&2
                exit 1
        fi

        # already downloaded file ?
        if [ -f $DST ]; then
                size=$(stat -c%s "$DST")

                ret=$(curl --retry 2 -L -sI -S \
                                --output /dev/null \
                                --write-out "%{http_code}" -- $MANAGER_RESOLVED_URL)

                if [ "$ret" -eq "200" ]; then
                        length=$(curl --retry 2 -L -sI -S \
                                        -- $MANAGER_RESOLVED_URL 2>/dev/null | \
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

        echo "Install: downloading SealOS Manager from: $MANAGER_RESOLVED_URL"
        trace curl -L -o "$DST" -# -f "$MANAGER_RESOLVED_URL"
}

install() {
        check_for_necessary_tools

        # Download parse machine if it is not here
        download_script_helpers "./ionoid-parse-machine.bash" $PARSE_MACHINE_URL

        # Parse machine
        parse_machine ${MACHINE}

        # Check again
        if [[ -z ${MACHINE} ]]; then
                echo "Error: variable MACHINE arch is not set or not able to determine" >&2
                schedule_feedback $STATUS_FILE "error" \
                        "Build OS failed passed Architecture Machine not supported" 0 "null"
                exit 1
        fi

        # Fail early
        if [ -n $IMAGE ] && [ ! -f $IMAGE ]; then
                echo "$COMMAND: Error: can not locate image ${IMAGE}"
                exit 1
        fi

        if [ -z $OS ]; then
                if [[ $IMAGE == *"raspbian"* ]]; then
                        OS="raspbian"
                elif [[ $IMAGE == *"sealos"* ]]; then
                        OS="sealos"
                fi
        fi

        export OS=$OS
        export DESTDIR=$DESTDIR

        export CONFIG=$(realpath $CONFIG)
        export IMAGE=$(realpath $IMAGE)

        # Special case for now and for backward
        # compatibility lets for use armv6
        export MACHINE="arm6"
        echo "Install: using Machine 'arm6' instead of '$MACHINE' for sealos-manager, you can ignore this"

        # create the target where to download manager file in case
        mkdir -p ${manager_dst} > /dev/null 2>&1

        # if not able to create manager_dst lets just store it into tmp
        if [ ! -d ${manager_dst} ]; then
                manager_dst=$scratch
        fi

        # IF not sealos download sealos manager
        if [ "$OS" != "sealos" ]; then
                # Set sealos manager file to be downloaded
                MANAGER_FILE="sealos-manager-latest-${MACHINE}"

                download_src=$URL/${MANAGER_FILE}.link
                download_dst=${manager_dst}/${MANAGER_FILE}.zip
                extract_dst=${manager_dst}/${MANAGER_FILE}

                schedule_feedback $STATUS_FILE "in_progress" \
                        "Downloading build OS tools" 33 "null"

                # Print the selected version to be downloaded
                echo "Install: Selected SealOS Manager version: $MANAGER_FILE" >&2
                schedule_feedback $STATUS_FILE "in_progress" \
                        "Downloading SealOS Manager tools" 35 "null"

                # Download SealOS Manager has to be called to resolve manager version
                download_sealos_manager "$download_src" "$download_dst" || return
                echo

                # Get SealOS Manager Version into target_dir based on dowloaded version
                target_dir=$(basename -- $MANAGER_RESOLVED_URL)
                target_dir="${target_dir%.*}"
                export SEALOS_DIR="${extract_dst}/${target_dir}"

                # Before unzip check if sealos-manager was already extracted before
                if [ ! -f "${SEALOS_DIR}/prod/machine" ]; then
                        trace unzip -q -o "$download_dst" -d "${extract_dst}" || return
                        echo
                fi
        fi

        # SealOS Manager now is extracted at location $extract_dst/$target_dir

        # Now start to handle OS image
        IMAGE_NAME=$(basename $IMAGE)
        export IMAGE_NAME="${IMAGE_NAME%.*}"

        schedule_feedback $STATUS_FILE "in_progress" \
                "Starting Intallation using ${IMAGE_NAME} OS" 40 "null"
        echo "Install: starting Installation ${target_dir}"

        #
        # Work on images and install from build-os.bash
        #
        if [ -n $IMAGE ]; then
                echo "Install: using $IMAGE as a target image"

                # Lets get image name and directory
                export IMAGE_DIR=$(dirname $IMAGE)

                if [ "$LOCAL_BUILD" = "true" ]; then
                        # Download raspbian post install script
                        download_post_install_scripts "."

                        # Download build os and store it into scratch $WORKDIR
                        download_build_os_script "./build-os.bash"

                        # Lets track mounts
                        export WORKDIR="/run/shm/${OUTPUTDIR}"
                else
                        # Download raspbian post install script
                        download_post_install_scripts "$scratch"

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
                trace cd "${extract_dst}/${target_dir}"

                # Install config.json to be put into production
                if [ ! -z ${CONFIG} ]; then
                        echo "Install: copying ${CONFIG} to ${extract_dst}/${target_dir}"
                        trace cp -t ./prod ${CONFIG} || true
                        trace chmod 0600 ./prod/${CONFIG}
                fi

                if [ "$UID" = "0" ]; then
                        trace "./install.bash" || return
                else
                        trace sudo -E "./install.bash" || return
                fi

                echo "Install: installing Ionoid Tools finished"
        fi

        schedule_feedback $STATUS_FILE "in_progress" \
                "Installation of tools on ${IMAGE_NAME} finished" 85 "null"

        echo
}

scratch=$(mktemp -d -t tmp.XXXXXXXXXX) || exit 1

# Some distros need to export this to access kpartx
OLD_PATH=$PATH
export PATH=$PATH:/usr/sbin

trap "command rm -rf $scratch; export PATH=$OLD_PATH" EXIT || exit 1

install
