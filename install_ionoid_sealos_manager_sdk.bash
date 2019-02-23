#!/bin/bash

# curl https://raw.githubusercontent.com/ionoid/install-ionoid/master/install_ionoid_sealos_manager_sdk.bash | bash

URL=https://raw.githubusercontent.com/opendevices/packages/master/sealos-manager/releases/
MANAGER_PACKAGE=sealos-manager

COMMAND=${0##*/}

usage() {
        echo "
$COMMAND [ --machine=ARCH ] [ --config=config.json ] [ --install-dir=DIRECTORY ] [ --install-image=IMAGE ]

Downloads Ionoid SealOS Manager '$MANAGER_PACKAGE' and then runs the
install.bash script included in the download.

--machine=ARCH
  Selects machine target. Supported values: arm6, arm7, amd64.
  As an example, for Raspberry PI 3 '--machine=arm7',
  for Raspberry PI Zero '--machine=arm6'.

--config=config.json
  Path of the Project's 'config.json' file. This file can be downloaded from
  your Ionoid IoT Projects, select add device to download it.

--install-dir=DIRECTORY
  Sets the installation root directory to DIRECTORY. The default is
  current '/' root filesystem.

--install-image=IMAGE
  Sets the installation target image to IMAGE. This option takes precendence on
  '--install-dir'. The image should be a supported Linux-IoT OS.
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
                --install-dir)
                shift
                case $# in
                        0)
                        echo "$COMMAND: --install-dir: DIRECTORY argument expected." >&2
                        exit 1
                        ;;
                esac
                DESTDIR=$1
                ;;
                --install-dir=*)
                DESTDIR=${1#*=}
                ;;
                --install-image)
                shift
                case $# in
                        0)
                        echo "$COMMAND: --install-image: IMAGE argument expected." >&2
                        exit 1
                        ;;
                esac
                DESTDIR=$1
                ;;
                --install-image=*)
                IMAGE=${1#*=}
                ;;

        *)
                usage
                ;;
        esac
        shift
done


MANAGER_FILE=sealos-manager-latest-${MACHINE}.zip
MANAGER_EXTRACT=sealos-manager-latest-${MACHINE}
download_src=$URL/${MANAGER_FILE}

trace() {
        echo "$@" >&2
        "$@"
}

download() {
        SRC=$1
        DST=$2
        if trace which curl >/dev/null; then
                trace curl -# -f "$SRC" > "$DST"
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

        install_dir=$DESTDIR
        export $DESTDIR
        download_dst=$scratch/${MANAGER_FILE}
        extract_dst=$scratch/${MANAGER_EXTRACT}

        # Download from github.
        download "$download_src" "$download_dst" || return
        echo

        trace mkdir -p "$install_dir" || return

        # Extract into destination.
        trace unzip "$download_dst" -d "${extract_dst}" || return
        echo

        # Install script.
        if [ "$UID" = "0" ]; then
                trace "${extract_dst}/install.bash" || return
        else
                trace sudo -E "$extract_dst/install.bash" || return
        fi

        echo
}

scratch=$(mktemp -d -t tmp.XXXXXXXXXX) && trap "command rm -rf $scratch" EXIT || exit 1

install
