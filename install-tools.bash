#!/bin/bash

#
# Copyright (2019) Open Devices
# Copyright (2019) Djalal Harouni
#

# curl https://raw.githubusercontent.com/ionoid/install-ionoid/master/sdk-ionoid-sealos-iot.bash | bash

bash=$(which bash)

URL=https://raw.githubusercontent.com/ionoid/install-ionoid/master/install_ionoid_sealos_manager_sdk.bash
BUILD_URL=https://raw.githubusercontent.com/ionoid/install-ionoid/master/build-os.bash

function download {
        script_file="$scratch/install_ionoid_sealos_manager_sdk.bash"
        build_os_file="$scratch/build-os.bash"

        echo "Downloading Ionoid SealOS Manager install script: $URL"
        curl -# "$URL" > "$script_file" || exit
        chmod 775 "$script_file"

        echo "Downloading Build OS script: $BUILD_URL"
        curl -# "$BUILD_URL" > "$build_os_file" || exit
        chmod 775 "$build_os_file"

        echo "Running install script from: $script_file"
        $bash -c "$script_file" "$@"
}

scratch=$(mktemp -d -t tmp.XXXXXXXXXX)
if [ "$?" -ne "0" ]; then
        echo "Error: failed to create temporary directory"
        exit 2
fi

trap "command rm -rf $scratch" EXIT || exit 1

download "$@"

exit 0
