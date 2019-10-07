# Parse MACHINE bash helper

function validate_arch() {
        machine=$1

        # lets reset to empty
        MACHINE=""
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

        if [ -n ${MACHINE} ]; then
                validate_arch ${MACHINE}
                return
        fi

        if [ ! -z ${CONFIG} ] && [ -f ${CONFIG} ]; then
                arch=$(jq -r .API_PROJECT_DEVICE_ARCH ${CONFIG} | tr -d '\n')
                if [ "$arch" != "null" ]; then
                        validate_arch $arch
                fi
        fi
}
