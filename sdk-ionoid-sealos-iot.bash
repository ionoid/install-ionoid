#!/bin/bash

#URL=

function download {
  scratch="$(mktemp -d -t tmp.XXXXXXXXXX)" || exit
  script_file="$scratch/install_ionoid_sealos_manager_sdk.bash"

  echo "Downloading Ionoid SealOS Manager install script: $URL"
  curl -# "$URL" > "$script_file" || exit
  chmod 775 "$script_file"

  echo "Running install script from: $script_file"
  "$script_file" "$@"
}

download "$@"
