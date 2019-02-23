#!/bin/bash

#URL=

usage() {
        echo "
$COMMAND [ --machine=ARCH ] [ --config=config.json ] [ --install-dir=DIRECTORY ] [ --install-image=IMAGE ]

Downloads Ionoid SealOS Manager '$MANAGER_PACKAGE' and then runs the
install.bash script included in the download.

--help
  Display this help message and exit.

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

function download {
  scratch="$(mktemp -d -t tmp.XXXXXXXXXX)" || exit
  script_file="$scratch/install_ionoid_sealos_manager_sdk.bash"

  echo "Downloading Ionoid SealOS Manager install script: $URL"
  curl -# "$URL" > "$script_file" || exit
  chmod 775 "$script_file"

  echo "Running install script from: $script_file"
  "$script_file" "$@"
}

while true; do
        case $# in
                0)  break ;;
        esac
        case $1 in
                --help)
                usage
                ;;
        esac
        shift
done

download "$@"
