#!/bin/sh

. is_service_installed.sh

install_php() {
    if is_service_installed php ; then
        alert "php is already installed"
        return 1
    fi

    dnf module reset php -y || true
    dnf install -y https://rpms.remirepo.net/enterprise/remi-release-$(rpm -E '%{rhel}').rpm
    dnf module enable php:remi-8.2 -y
    dnf install -y php php-mysqlnd
}
