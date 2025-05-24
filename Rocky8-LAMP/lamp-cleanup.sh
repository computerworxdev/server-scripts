#!/bin/sh

USER="webadmin"
GROUP="webadmin"

dnf remove -y \
    httpd \
    mod_ssl \
    php \
    mariadb-server \
    mongodb-org \
    mongodb-shell \
    fail2ban \
    vsftpd \
    lftp

userdel $USER
groupdel $GROUP
