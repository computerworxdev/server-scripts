#!/bin/sh

. messages.sh
. number_of_parameters.sh

create_group() {
    local caller="${FUNCNAME[0]}"
    local help_text="Usage: $caller GROUPNAME"
    if ! number_of_parameters 1 $# "$help_text"; then
        return 1
    fi

    if getent group $1 > /dev/null; then
        alert "$1 group alread exists"
        return 1
    fi
    groupadd $1
}

create_user() {
    local caller="${FUNCNAME[0]}"
    local help_text="Usage: $caller USERNAME PASSWORD GROUPNAME"
    if ! number_of_parameters 3 $# "$help_text"; then
        return 1
    fi

    if id -u $1 > /dev/null; then
        alert "$1 user already exists"
        return 1
    fi
    useradd -M -d /var/www -s /bin/bash -g $3 $1
    echo "$1:$2" | chpasswd
}
