#!/bin/bash

#
# Copyright (2019) Open Devices
# Copyright (2019) Djalal Harouni
#

# curl https://manager.services.ionoid.net/install-tools.bash | bash

bash=$(which bash)

URL=https://raw.githubusercontent.com/ionoid/install-ionoid/master/install-ionoid-sealos-manager-sdk.bash

function download {
        script_file="$scratch/install-ionoid-sealos-manager-sdk.bash"

        echo "Downloading Ionoid SealOS Manager install script: $URL"
        curl -# "$URL" > "$script_file" || exit
        chmod 775 "$script_file"

        echo "Running install script from: $script_file"
        cd $scratch
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
