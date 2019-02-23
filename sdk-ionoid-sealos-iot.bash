#!/bin/bash

# curl https://raw.githubusercontent.com/ionoid/install-ionoid/master/sdk-ionoid-sealos-iot.bash | bash

URL=https://raw.githubusercontent.com/ionoid/install-ionoid/master/install_ionoid_sealos_manager_sdk.bash

function download {
        script_file="$scratch/install_ionoid_sealos_manager_sdk.bash"

        echo "Downloading Ionoid SealOS Manager install script: $URL"
        curl -# "$URL" > "$script_file" || exit
        chmod 775 "$script_file"

        echo "Running install script from: $script_file"
        "$script_file" "$@"
}

scratch=$(mktemp -d -t tmp.XXXXXXXXXX)
if [ "$?" -ne "0" ]; then
        echo "Error: failed to create temporary directory"
        exit 2
fi

download "$@"

exit 0
