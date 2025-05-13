#!/bin/sh

. messages.sh

create_group() {
    if getent group $1 > /dev/null; then
        alert "$1 group alread exists"
        return 1
    fi
    groupadd $1
}

create_user() {
    if [ "$#" -ne 3 ]; then
        alert "Incorrect number of parameters"
        echo "Provide: username password and group"
        return 1
    fi
    if id -u $1 > /dev/null; then
        alert "$1 user already exists"
        return 1
    fi
    useradd -M -d /var/www -s /bin/bash -g $3 $1
    echo "$1:$2" | chpasswd
}
