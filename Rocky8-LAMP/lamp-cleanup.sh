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
    certbot

userdel $USER
groupdel $GROUP

rm -fr /var/www
rm -fr /opt/phpmyadmin
