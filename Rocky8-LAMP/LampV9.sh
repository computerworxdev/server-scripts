#!/bin/sh

# LAMP v9
# (c) Computer-worx 2025

WEBDOMAIN="example.com"
USER="webadmin"
GROUP="webadmin"
PASSWORD="webadmin"

COLOR_GREEN="\033[0;32m"
COLOR_RED="\033[0;31m"
COLOR_NAN="\033[0m"
COLOR_YELLOW="\033[0;33m"

# Message Functions

alert() {
	echo -e "${COLOR_RED}$1${COLOR_NAN}"
}

success() {
	echo -e "${COLOR_GREEN}$1${COLOR_NAN}"
}

bold() {
	echo -e "${COLOR_YELLOW}$1${COLOR_NAN}"
}

# Utility function to ask yes/no questions
# It keeps asking until the user gives a valid answer
ask_yes_no() {
    local prompt="${1:-Are you sure?}"
    [[ "$2" == "-y" || "$2" == "--yes" ]] && return 0

    while true; do
        read -p "$prompt [y/n]: " answer
        case "$answer" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

# Checks if service is installed
is_service_installed() {
	dnf list installed $1 &> /dev/null
}

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

safe_exec() {
    local cmd="$*"
    while true; do
        eval "$cmd"
	result=$?
        if [[ $result -eq 0 ]]; then
            return 0
        fi

        alert "Command failed: $cmd"
        echo "Options: [r]etry, [c]ontinue anyway, [a]bort"
        read -rp "Choose an option (r/c/a): " choice
        case "$choice" in
            [Rr]) ;;
            [Cc]) return 0 ;;
            [Aa]) echo "Aborted."; return $result ;;
            *) echo "Invalid option. Please enter r, c, or a." ;;
        esac
    done
}

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

EPEL9=https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
EPEL8=https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm

install_epel() {
    if rpm -q epel-release &>/dev/null; then
	    success "EPEL is already installed."
	    return 0
    fi

    echo "Installing EPEL repository..."
    if ! dnf repolist | grep -q "^epel/"; then
        dnf install -y epel-release || {
            alert "Failed to install epel-release via dnf. Attempting manual install..."
            # Determine OS version
            OS_VERSION=$(rpm -E %rhel)
            if [ "$OS_VERSION" -ge 9 ]; then
                dnf install -y $EPEL9
            elif [ "$OS_VERSION" -eq 8 ]; then
                dnf install -y $EPEL8
            else
                alert "Unsupported OS version. Please install EPEL repository manually."
                return 1
            fi
        }
    else
        success "EPEL repository is already installed."
    fi

    # Enable EPEL repository
    dnf config-manager --enable epel
}

add_firewall_service() {
	local service=$1
	if firewall-cmd --permanent --add-service="$service"; then
		success "firewalld successfully added $service"
	else
		alert "firewalld failed to add $service"
		return 1
	fi
}

install_firewalld() {
	if is_service_installed firewalld ; then
		success "firewalld is already installed"
	else
		dnf -y install firewalld
	fi

	systemctl enable firewalld
	systemctl start firewalld

	if ! is_service_active firewalld; then
		alert "Failed to activate firewalld service"
		return 1
	fi

	add_firewall_service http
	add_firewall_service https
	add_firewall_service ftp
	add_firewall_service ssh

	if ! firewall-cmd --reload; then
		alert "Failed realoding firewalld"
		return 1
	fi
}

is_apache_responding() {
	curl -s --head "http://localhost/" | grep "HTTP" > /dev/null
}

install_mod_ssl() {
# Install mod_ssl and enable mod_rewrite
	dnf install -y mod_ssl

	cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.bak

	grep -q 'LoadModule rewrite_module' /etc/httpd/conf/httpd.conf \
	  || echo 'LoadModule rewrite_module modules/mod_rewrite.so' >> /etc/httpd/conf/httpd.conf

	sed -i '/LoadModule rewrite_module/s/^#//g' /etc/httpd/conf/httpd.conf
}

install_apache() {
	if is_service_installed httpd ; then
		success "Apache is already installed"
	else
		dnf -y install httpd
		install_mod_ssl
	fi

	systemctl enable httpd
	systemctl start httpd

	if ! is_service_active httpd; then
		alert "Failed to activate httpd service"
		return 1
	fi

	if ! is_apache_responding ; then
		alert "Apache is not responding to http requests"
		return 1
	fi
}

create_apache_domain() {
    if [ "$#" -ne 1 ]; then
        alert "Incorrect number of parameters"
        echo "Provide domain name"
        return 1
    fi

HTTPCONFIG=$(cat <<EOF
<VirtualHost *:80>
    ServerName $1
    DocumentRoot /var/www/$1
    <Directory /var/www/$1}>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
)
    rm -fr /var/www/$1
    mkdir /var/www/$1
    echo "$HTTPCONFIG" > /etc/httpd/conf.d/$1.conf
}

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

install_mariadb() {
SERVICE=mariadb
    if is_service_installed  $SERVICE-server; then
        alert "$SERVICE is already installed"
        return 1
    fi

    dnf -y install $SERVICE-server $SERVICE-server-utils expect

    systemctl enable $SERVICE
    systemctl start $SERVICE

	if ! is_service_active $SERVICE; then
		alert "Failed to activate $SERVICE service"
		return 1
	fi

    success "$SERVICE is installed and running"
    alert "You should run manually mysql_secure_installation to secure the setup"
    if ask_yes_no "Do you to run mysql_secure_installation now"; then
        mysql_secure_installation
    fi 
}

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

FTPCONFIG=$(cat <<EOF
anonymous_enable=NO
local_enable=YES
local_root=/var/www
write_enable=YES
chroot_local_user=YES
allow_writeable_chroot=YES
hide_ids=YES
local_umask=022
dirmessage_enable=YES
xferlog_enable=YES
connect_from_port_20=YES
xferlog_std_format=YES
listen=NO
listen_ipv6=YES
pam_service_name=vsftpd
userlist_enable=YES
userlist_deny=NO
EOF
)

FTPCONFIG_SSL=$(cat <<EOF
anonymous_enable=NO
local_enable=YES
local_root=/var/www
write_enable=YES
chroot_local_user=YES
allow_writeable_chroot=YES
hide_ids=YES
local_umask=022
dirmessage_enable=YES
xferlog_enable=YES
connect_from_port_20=YES
xferlog_std_format=YES
listen=NO
listen_ipv6=YES
pam_service_name=vsftpd
userlist_enable=YES
userlist_deny=NO
# SSL configuration (TLS v1.2)
ssl_enable=YES
ssl_tlsv1_2=YES
ssl_sslv2=NO
ssl_sslv3=NO
rsa_cert_file=/etc/ssl/vsftpd/vsftpd-selfsigned.crt
rsa_private_key_file=/etc/ssl/vsftpd/vsftpd-selfsigned.key
# Prevent anonymous users from using SSL
allow_anon_ssl=NO
# Force all non-anonymous logins to use SSL for data transfer
force_local_data_ssl=YES
# Force all non-anonymous logins to use SSL to send passwords
force_local_logins_ssl=YES
# Select the SSL ciphers VSFTPD will permit for encrypted SSL connections with the ssl_ciphers option.
ssl_ciphers=HIGH
# Turn off SSL reuse
require_ssl_reuse=NO
#Passive FTP ports can be allocated a minimum and maximum range for data connections.
pasv_min_port=40000
pasv_max_port=40001
#Setting up SSL debug
debug_ssl=YES
EOF
)


install_vsftpd() {
SERVICE=vsftpd
    if is_service_installed $SERVICE; then
        alert "$SERVICE is already installed"
        return 1
    fi
    
    dnf install -y vsftpd
    cp -f /etc/vsftpd/vsftpd.conf /etc/vsftpd/vsftpd.conf.bak
    echo "$FTPCONFIG" > /etc/vsftpd/vsftpd.conf
    setsebool -P ftpd_full_access 1
    systemctl enable vsftpd
    systemctl start vsftpd

    if ! is_service_active $SERVICE; then
        alert "$SERVICE is not working properly"
        return 1
    fi
}

add_vsftpd_user() {
    echo "$1" | tee -a /etc/vsftpd/user_list >/dev/null
}

is_vsftpd_active() {
    if [ "$#" -ne 3 ]; then
        alert "Incorrect number of parameters"
        echo "Provide: username password and host"
        return 1
    fi

    if ! is_service_installed lftp; then
        dnf -y install lftp
    fi

    if lftp -u "$1","$2" "$3" -e "ls; bye" >/dev/null 2>&1; then
        success "FTP server is responding"
    else
        alert "FTP server is not responding"
    fi
}

FAIL2BAN_SSH=$(cat <<EOF
[sshd]
enabled  = true
port     = 22
filter   = sshd
logpath  = /var/log/secure
maxretry = 2
bantime  = 5m
EOF
)

FAIL2BAN_VSFTPD=$(cat <<EOF
[vsftpd]
enabled  = true
port     = ftp
filter   = vsftpd
logpath  = /var/log/vsftpd.log
maxretry = 2
bantime  = 21600
EOF
)

install_fail2ban() {
    if is_service_installed fail2ban; then
        echo "Fail2ban is already installed."
        return 1
    fi

    dnf install -y fail2ban fail2ban-firewalld
    cp -f /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    [ -f /etc/fail2ban/jail.d/00-firewalld.conf ] && mv -f /etc/fail2ban/jail.d/00-firewalld.conf /etc/fail2ban/jail.d/00-firewalld.local
    echo "$FAIL2BAN_SSH" > /etc/fail2ban/jail.d/10-sshd.conf
    echo "$FAIL2BAN_VSFTPD" > /etc/fail2ban/jail.d/20-vsftpd.conf

    if [ ! -f /var/log/vsftpd.log ]; then
        touch /var/log/vsftpd.log
        chown root:root /var/log/vsftpd.log
        chmod 644 /var/log/vsftpd.log
    fi

    sed -i '/^[[:space:]]*banaction[[:space:]]*=[[:space:]]*iptables-multiport[[:space:]]*$/s/^/#/' /etc/fail2ban/jail.local
    sed -i '/^[[:space:]]*banaction_allports[[:space:]]*=[[:space:]]*iptables-allports[[:space:]]*$/s/^/#/' /etc/fail2ban/jail.local

    if ! grep -q '^banaction[[:space:]]*=' /etc/fail2ban/jail.local; then
        sed -i '/^\[DEFAULT\]/a banaction = firewallcmd-rich-rules\nbanaction_allports = firewallcmd-rich-rules' /etc/fail2ban/jail.local
    fi

    systemctl enable fail2ban
    systemctl restart fail2ban

    if ! is_service_active fail2ban; then
        alert "Fail2ban is not working properly"
        return 1
    fi
}

install_mongodb() {
OS_VERSION=$(rpm -E %rhel)
MONGO_VERSION="6.0"
MONGO_REPO_BASEURL="https://repo.mongodb.org/yum/redhat/$OS_VERSION/mongodb-org/${MONGO_VERSION}/x86_64/"
MONGO_GPGKEY="https://pgp.mongodb.com/server-${MONGO_VERSION}.asc"

MONGOCONFIG=$(cat <<EOF
[mongodb-org-${MONGO_VERSION}]
name=MongoDB Repository
baseurl=${MONGO_REPO_BASEURL}
gpgcheck=1
enabled=1
gpgkey=${MONGO_GPGKEY}
EOF
)

    echo "$MONGOCONFIG" > /etc/yum.repos.d/mongodb-org-${MONGO_VERSION}.repo
    dnf makecache
    dnf install -y mongodb-org mongodb-shell
    if [ ! -f "/etc/mongod.conf.bak" ]; then
        cp /etc/mongod.conf /etc/mongod.conf.bak
    fi
    sed -i '/^security:/a \ authorization: enabled' /etc/mongod.conf
    systemctl enable mongod
    systemctl start mongod
    sleep 30

mongosh <<EOF
disableTelemetry()
EOF
}

create_mongodb_root_user() {
    if [ "$#" -ne 2 ]; then
        alert "Incorrect number of parameters"
        echo "Provide: username and password"
        return 1
    fi
MONGOUSERCONFIG=$(cat <<EOF
use admin
db.createUser({
  user: "$1",
  pwd: "$2",
  roles: [{ role: "root", db: "admin" }]
})
EOF
)
    echo "$MONGOUSERCONFIG" | mongosh
}

safe_exec install_epel
safe_exec install_firewalld
safe_exec install_apache
safe_exec create_apache_domain $WEBDOMAIN
safe_exec create_group $GROUP
safe_exec create_user $USER $PASSWORD $GROUP
chown -R $USER:$GROUP /var/www
safe_exec install_php
safe_exec install_mariadb
safe_exec install_phpmyadmin
safe_exec install_vsftpd
safe_exec add_vsftpd_user $USER
is_vsftpd_active
safe_exec install_fail2ban
safe_exec install_mongodb
