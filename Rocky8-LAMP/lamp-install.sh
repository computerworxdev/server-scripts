#!/bin/sh

# LAMP v9
# (c) Computer-worx 2025

# Save everything that is shown on the screen to a file

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

banner() {
    local message="$1"
    local border_char="${2:-=}"
    local padding=4
    local border_length=$(( ${#message} + padding ))

    printf "\n"
    printf "%${border_length}s\n" | tr ' ' "$border_char"
    printf "%s%s%s\n" "$border_char" " $message " "$border_char"
    printf "%${border_length}s\n" | tr ' ' "$border_char"
    printf "\n"
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

get_input() {
  local prompt=" "
  local skip_confirm=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -y|--yes)
        skip_confirm=true
        shift
        ;;
      *)
        prompt="$1"
        shift
        ;;
    esac
  done

  local input=""
  while [[ -z "$input" ]]; do
    read -p "$prompt " input
    if [[ -z "$input" ]]; then
      alert "Input cannot be empty. Try again."
    fi
  done

  # Confirm if not skipping confirmation
  if ! $skip_confirm; then
    while true; do
	    read -p "you entered: '$input'. Confirm? (y/n): " confirm
      case "$confirm" in
        [Yy]*) break ;;
        [Nn]*) 
          input=""
          while [[ -z "$input" ]]; do
            read -p "$prompt " input
            if [[ -z "$input" ]]; then
              alert "Input cannot be empty. Try again."
            fi
          done
          ;;
        *) "Please answer y or n." ;;
      esac
    done
  fi
  echo "$input"
}


number_of_parameters() {
    local caller="${FUNCNAME[1]}"
    local expected="$1"
    local actual="$2"
    local help_text="$3"

    if [ "$actual" -ne "$expected" ]; then
        alert "error: $caller expected $expected parameters, but got $actual."
        echo "$help_text"
        return 1
    fi
}

# Checks if service is installed
is_service_installed() {
    local caller="${FUNCNAME[0]}"
    local help_text="Usage: $caller SERVICENAME"
    if ! number_of_parameters 1 $# "$help_text"; then
        return 1
    fi

	dnf list installed $1 &> /dev/null
}

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
    local caller="${FUNCNAME[0]}"
    local help_text="Usage: $caller SERVICE_NAME"
    if ! number_of_parameters 1 $# "$help_text"; then
        return 1
    fi

	local service=$1
	if firewall-cmd --permanent --add-service="$service"; then
        firewall-cmd --reload
		success "firewalld successfully added $service"
	else
		alert "firewalld failed to add $service"
		return 1
	fi
}

add_firewall_port() {
    local caller="${FUNCNAME[0]}"
    local help_text="Usage: $caller PORT_NUMBER/PROTOCOL"
    if ! number_of_parameters 1 $# "$help_text"; then
        return 1
    fi

    local port=$1
    if firewall-cmd --permanent --add-port="$port"; then
        firewall-cmd --reload
        success "firewalld successfully added port $port"
    else
        alert "firewalld failed to add port $port"
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

	# Create a backup of the httpd configuration file
	cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.bak

	# If a line to load the rewrite module doesn't exist, append it
	grep -q 'LoadModule rewrite_module' /etc/httpd/conf/httpd.conf \
	  || echo 'LoadModule rewrite_module modules/mod_rewrite.so' >> /etc/httpd/conf/httpd.conf

	# If a line to load the rewrite module exists but is commented, uncomment it
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
    local caller="${FUNCNAME[0]}"
    local help_text="Usage: $caller DOMAINNAME"
    if ! number_of_parameters 1 $# "$help_text"; then
        return 1
    fi

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
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40001
#Setting up SSL debug
debug_ssl=YES
EOF
)

install_vsftpd() {
    local SERVICE=vsftpd

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

create_vsftpd_certificate() {
    rm -rf /etc/ssl/vsftpd
    mkdir /etc/ssl/vsftpd
    openssl req -x509 -nodes \
        -keyout /etc/ssl/vsftpd/vsftpd-selfsigned.key \
        -out /etc/ssl/vsftpd/vsftpd-selfsigned.crt \
        -days 365 -newkey rsa:2048 \
        -subj "/C=US/ST=CA/L=SilliconValley/O=Organization/OU=OrgUnit/CN=localhost"
}

install_secure_vsftpd() {
    local SERVICE=vsftpd

    if is_service_installed $SERVICE; then
        alert "$SERVICE is already installed"
        return 1
    fi

    dnf install -y vsftpd
    create_vsftpd_certificate
    cp -f /etc/vsftpd/vsftpd.conf /etc/vsftpd/vsftpd.conf.bak
    echo "$FTPCONFIG_SSL" > /etc/vsftpd/vsftpd.conf
    
    setsebool -P ftpd_full_access 1
    systemctl enable vsftpd
    systemctl start vsftpd

    # Activating pasive ports
    local start="40000"
    local end="40001"
    for (( i=start; i<=end; i++ )); do
        add_firewall_port "$i/tcp"
    done

    if ! is_service_active $SERVICE; then
        alert "$SERVICE is not working properly"
        return 1
    fi
}

add_vsftpd_user() {
    local caller="${FUNCNAME[0]}"
    local help_text="Usage: $caller USERNAME"
    if ! number_of_parameters 1 $# "$help_text"; then
        return 1
    fi

    echo "$1" | tee -a /etc/vsftpd/user_list >/dev/null
}

is_vsftpd_active() {
    local caller="${FUNCNAME[0]}"
    local help_text="Usage: $caller USERNAME PASSWORD HOSTNAME"
    if ! number_of_parameters 3 $# "$help_text"; then
        return 1
    fi

    if ! is_service_installed lftp; then
        dnf -y install lftp
    fi

    echo "Trying to connect to the ftp server... (press Ctrl+c to abort)"
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

is_certbot_renew_scheduled() {
    if ! systemctl list-timers | grep certbot; then
        return 1
    fi
}

install_certbot() {
    local caller="${FUNCNAME[0]}"
    local help_text="Usage: $caller DOMAINNAME"
    if ! number_of_parameters 1 $# "$help_text"; then
        return 1
    fi

    if ! is_service_installed certbot; then
        dnf install -y certbot python3-certbot-apache
    fi

    certbot --apache -d $1 --agree-tos -m admin@$1 --non-interactive --redirect --dry-run
    
    if ! is_certbot_renew_scheduled; then
        echo "0 2 10 */1 * root certbot renew --quiet" > /etc/cron.d/certbot-renew
    fi
}

# Main script execution

banner "Server Configuration"

WEBDOMAIN="example.com"
USER="webadmin"
GROUP="webadmin"
PASSWORD="webadmin"

success "Default variables:"
echo "webdomain: $WEBDOMAIN"
echo "username: $USER"
echo "password: $PASSWORD"
echo "group: $GROUP"

if ! ask_yes_no "Do you like to use the default variables?"; then
    WEBDOMAIN=$(get_input "webdomain:")
    USER=$(get_input "username:")
    PASSWORD=$(get_input "password:")
    GROUP=$(get_input "group:")

    success "Defined variables:"
    echo "webdomain: $WEBDOMAIN"
    echo "username: $USER"
    echo "password: $PASSWORD"
    echo "group: $GROUP"
fi

{
    banner "Installing EPEL repository"
    safe_exec install_epel

    banner "Installing firewalld"
    safe_exec install_firewalld

    banner "Installing apache"
    safe_exec install_apache
    safe_exec is_apache_responding
    safe_exec create_apache_domain $WEBDOMAIN
    safe_exec create_group $GROUP
    safe_exec create_user $USER $PASSWORD $GROUP
    chown -R $USER:$GROUP /var/www

    banner "Installing php"
    safe_exec install_php

    banner "Installing mariadb"
    safe_exec install_mariadb

    banner "Installing phpmyadmin"
    safe_exec install_phpmyadmin

    banner "Installing vsftpd"
    safe_exec install_secure_vsftpd
    safe_exec add_vsftpd_user $USER

    banner "Installing fail2ban"
    safe_exec install_fail2ban

    banner "Installing mongodb"
    safe_exec install_mongodb
    safe_exec create_mongodb_root_user $USER $PASSWORD

    banner "Certbot configuration"
    safe_exec install_certbot $WEBDOMAIN

    banner "Summary"
    is_service_active firewalld
    is_service_active httpd
    is_service_active mariadb
    is_service_active vsftpd
    is_service_active fail2ban
    is_service_active mongod
} 2>&1 | tee -a output.log
