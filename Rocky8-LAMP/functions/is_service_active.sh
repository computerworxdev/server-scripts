#!/bin/sh

# pre-conditions
. set_colors.sh

is_service_running() {
    local service="$1"
    if systemctl is-active --quiet "$service"; then
        echo -e "${COLOR_GREEN}$service is active${COLOR_NAN}"
        return 0
    else
        echo -e "${COLOR_RED}$service is inactive${COLOR_NAN}"
        return 1
    fi
}
