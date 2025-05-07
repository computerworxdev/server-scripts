#!/bin/sh

# pre-conditions
. messages.sh

is_service_running() {
    local service="$1"
    if systemctl is-active --quiet "$service"; then
        success "$service is active"
        return 0
    else
        alert "$service is inactive"
        return 1
    fi
}
