#!/bin/sh

# pre-conditions
. set_colors.sh

is_selinux_active() {
    if ! command -v getenforce &> /dev/null; then
        echo -e "${COLOR_RED}selinux is not installed${COLOR_NAN}"
        return 1
    fi

    local status
    status=$(getenforce)

    if [[ "$status" == "Enforcing" || "$status" == "Permissive" ]]; then
        echo -e "${COLOR_GREEN}selinux is installed and active${COLOR_NAN}"
        return 0
    else
        echo -e "${COLOR_RED}selinux is installed but disabled${COLOR_NAN}"
        return 2
    fi
}
