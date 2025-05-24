#!/bin/sh

# pre-conditions
. messages.sh

# Checks if service is active
is_service_active() {
    local caller="${FUNCNAME[0]}"
    local help_text="Usage: $caller SERVICENAME"
    if ! number_of_parameters 1 $# "$help_text"; then
        return 1
    fi

    local service="$1"
    if systemctl is-active --quiet "$service"; then
        success "$service is active"
        return 0
    else
        alert "$service is inactive"
        return 1
    fi
}
