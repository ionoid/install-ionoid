# Parse MACHINE bash helper

function validate_arch() {
        machine=$1

        # lets reset to empty
        MACHINE=""
        if [ "$machine" = "armv6" ] || [ "$machine" = "ARMv6" ]; then
                machine="arm6"
        elif [ "$machine" = "armv7" ] || [ "$machine" = "ARMv7" ] || [ "$machine" = "ARMv8-AArch32" ]; then
                machine="arm7"
        elif [ "$machine" = "arm8" ] || [ "$machine" = "ARMv8" ] || [ "$machine" = "ARMv8-AArch64" ]; then
                machine="arm64"
        elif [ "$machine" = "x86-64" ] || [ "$machine" = "x86_64" ]; then
                machine="amd64"
        fi

        if [ "$machine" != "arm6" ] && \
           [ "$machine" != "arm7" ] && \
           [ "$machine" != "arm64" ] && \
           [ "$machine" != "amd64" ] && \
           [ "$machine" != "x86" ]; then
                echo "$COMMAND: ARCH '$machine' value not supported." >&2
                return
        fi

        MACHINE=$machine
}

function parse_machine() {

        if [[ -n ${MACHINE} ]]; then
                validate_arch ${MACHINE}
                return
        fi

        if [[ ! -z ${CONFIG} ]] && [[ -f ${CONFIG} ]]; then
                arch=$(jq -r .API_PROJECT_DEVICE_ARCH ${CONFIG} | tr -d '\n')
                if [ "$arch" != "null" ]; then
                        validate_arch $arch
                fi
        fi
}
