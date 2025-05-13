#!/bin/sh

# pre-conditions
. messages.sh

# Checks if service is active
is_service_active() {
    local service="$1"
    if systemctl is-active --quiet "$service"; then
        success "$service is active"
        return 0
    else
        alert "$service is inactive"
        return 1
    fi
}
