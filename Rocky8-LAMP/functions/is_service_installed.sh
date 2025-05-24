#!/bin/sh

# Checks if service is installed
is_service_installed() {
    local caller="${FUNCNAME[0]}"
    local help_text="Usage: $caller SERVICENAME"
    if ! number_of_parameters 1 $# "$help_text"; then
        return 1
    fi

	dnf list installed $1 &> /dev/null
}


