#!/bin/bash

#
# Copyright (2019) Open Devices
# Copyright (2019) Djalal Harouni
#

# curl https://raw.githubusercontent.com/ionoid/install-ionoid/master/install-ionoid-sealos-manager-sdk.bash | bash

URL=https://raw.githubusercontent.com/opendevices/packages/master/sealos-manager/releases/
MANAGER_PACKAGE=sealos-manager

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
                if [ "$m" = "arm6" ]; then
                        MACHINE=$m
                elif [ "$m" = "arm7" ]; then
                        MACHINE=$m
                elif [ "$m" = "amd64" ]; then
                        MACHINE=$m
                else
                        echo "$COMMAND: --machine: ARCH argument not supported." >&2
                        exit 1
                fi
                ;;
                --machine=*)
                m=${1#*=}
                if [ "$m" = "arm6" ]; then
                        MACHINE=$m
                elif [ "$m" = "arm7" ]; then
                        MACHINE=$m
                elif [ "$m" = "amd64" ]; then
                        MACHINE=$m
                else
                        echo "$COMMAND: --machine: ARCH argument not supported." >&2
                        exit 1
                fi
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


declare MANAGER_FILE=sealos-manager-latest-${MACHINE}
declare MANAGER_URL=""

trace() {
        echo "$@" >&2
        "$@"
}

download() {
        SRC=$1
        DST=$2
        if trace which curl >/dev/null; then
                MANAGER_URL=$(trace curl -# -f "$SRC")
                trace curl -# -f "$MANAGER_URL" > "$DST"
        else
                echo "Error: failed 'curl' must be installed to download files." >&2
                return 1
        fi
}

install() {
        if [ -z ${MACHINE} ]; then
                echo "Error: machine is not set" >&2
                usage
        fi

        export OS=$OS
        export CONFIG=$CONFIG
        export DESTDIR=$DESTDIR
        export MACHINE=$MACHINE
        export WORKDIR=$scratch
        export IMAGE=$IMAGE

        download_src=$URL/${MANAGER_FILE}.link
        download_dst=$scratch/${MANAGER_FILE}.zip
        extract_dst=$scratch/${MANAGER_FILE}

        # Download from github.
        download "$download_src" "$download_dst" || return
        echo

        trace unzip "$download_dst" -d "${extract_dst}" || return
        echo

        # Install script.
        echo "Starting Installation into $DESTDIR"
        target_dir=$(basename -- $MANAGER_URL)
        target_dir="${target_dir%.*}"

        if [ -f $IMAGE ]; then
                echo "Using $IMAGE as a target image"
                export SEALOS_DIR="${extract_dst}/${target_dir}"
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

        echo
}

scratch=$(mktemp -d -t tmp.XXXXXXXXXX) || exit 1

trap "command rm -rf $scratch" EXIT || exit 1

install
