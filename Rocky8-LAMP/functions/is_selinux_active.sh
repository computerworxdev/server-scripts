#!/bin/sh

# pre-conditions
. messages.sh

is_selinux_active() {
    if ! command -v getenforce &> /dev/null; then
        alert "selinux is not installed"
        return 1
    fi

    local status
    status=$(getenforce)

    if [[ "$status" == "Enforcing" || "$status" == "Permissive" ]]; then
        success "selinux is installed and active"
        return 0
    else
        alert "selinux is installed but disabled$"
        return 2
    fi
}
