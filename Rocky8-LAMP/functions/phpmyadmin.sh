#!/bin/sh

CURDIR=$PWD
PHPDIR=/opt/phpmyadmin
PHPURL=https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz
PHPCONFIG=$(cat <<EOF
Alias /phpmyadmin $PHPDIR
<Directory $PHPDIR>
    Options FollowSymLinks
    DirectoryIndex index.php
    <IfModule mod_php.c>
        AddType application/x-httpd-php .php
        php_flag magic_quotes_gpc Off
        php_flag track_vars On
        php_flag register_globals Off
        php_value include_path .
    </IfModule>

    <IfModule mod_authz_core.c>
        Require all granted
    </IfModule>

    <IfModule !mod_authz_core.c>
        Order Allow,Deny
        Allow from all
    </IfModule>
</Directory>
EOF
)

install_phpmyadmin() {
    dnf install -y php-mbstring php-zip php-gd php-json php-curl wget
    cd /tmp
    wget https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz
    tar xzf phpMyAdmin-latest-all-languages.tar.gz
    rm -fr $PHPDIR
    mv phpMyAdmin-*-all-languages $PHPDIR
    rm -f phpMyAdmin*
    mkdir -p $PHPDIR/tmp
    chmod 777 $PHPDIR/tmp
    echo "$PHPCONFIG" > /etc/httpd/conf.d/phpmyadmin.conf
    chown -R apache:apache $PHPDIR
    systemctl restart httpd
    cd $CURDIR

    if ! curl -s --head http://localhost/phpmyadmin | grep 301 > /dev/null; then
        alert "phpmyadmin is installed, but not working properly"
        return 1
    fi
}
