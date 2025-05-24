#!/bin/bash

# Bash Script for Setting Up a LAMP Stack with Additional Services
# This script installs and configures Apache, PHP, phpMyAdmin, vsftpd, MongoDB, and SSL certificates using Certbot.
# Applicable for RHEL/CentOS 8/9 and similar distributions.

# Exit immediately if a command exits with a non-zero status
set -e

# Enable debug mode (optional, uncomment for troubleshooting)
# set -x

#######################################
# Variables
#######################################
DOMAIN="domainname1.com"
DOMAIN2="test.domainname2.com"
WEB_USER="webadmin"
WEB_GROUP="apache"  # Changed from 'www' to 'apache' to match typical group name
WEB_PASS=$(openssl rand -base64 12)
MONGO_USER="mongoAdmin"
MONGO_PASS=$(openssl rand -base64 12)

#######################################
# Function Definitions
#######################################

# Function to check if a package is installed
is_installed() {
    dnf list installed "$1" &> /dev/null
}

# Function to install EPEL repository
install_epel() {
    echo "Installing EPEL repository..."
    if ! dnf repolist | grep -q "^epel/"; then
        dnf install -y epel-release || {
            echo "Failed to install epel-release via dnf. Attempting manual install..."
            # Determine OS version
            OS_VERSION=$(rpm -E %rhel)
            if [ "$OS_VERSION" -ge 9 ]; then
                dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
            elif [ "$OS_VERSION" -eq 8 ]; then
                dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
            else
                echo "Unsupported OS version. Please install EPEL repository manually."
                exit 1
            fi
        }
    else
        echo "EPEL repository is already installed."
    fi

    # Enable EPEL repository
    dnf config-manager --enable epel
}

# Function to install phpMyAdmin
install_phpmyadmin() {
    echo "Installing phpMyAdmin..."

    # Attempt to install phpMyAdmin via dnf
    if dnf install -y phpMyAdmin; then
        echo "phpMyAdmin installed successfully via dnf."
    else
        echo "phpMyAdmin package not found in repositories. Proceeding with manual installation..."

        # Install required PHP extensions
        dnf install -y php-mbstring php-zip php-gd php-json php-curl

        # Download the latest phpMyAdmin
        cd /tmp
        wget https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz

        # Extract the package
        tar xzf phpMyAdmin-latest-all-languages.tar.gz

        # Move phpMyAdmin to the web directory
        mv phpMyAdmin-*-all-languages /usr/share/phpmyadmin

        # Create a temporary directory for phpMyAdmin upload
        mkdir -p /usr/share/phpmyadmin/tmp
        chmod 777 /usr/share/phpmyadmin/tmp

        # Configure Apache to serve phpMyAdmin
        cat <<EOL >/etc/httpd/conf.d/phpmyadmin.conf
Alias /phpmyadmin /usr/share/phpmyadmin

<Directory /usr/share/phpmyadmin/>
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
        <RequireAll>
            Require ip 127.0.0.1
            Require ip ::1
            # Uncomment the line below to allow access from a specific IP
            # Require ip 192.168.1.0/24
        </RequireAll>
    </IfModule>

    <IfModule !mod_authz_core.c>
        Order Deny,Allow
        Deny from All
        Allow from 127.0.0.1
        Allow from ::1
    </IfModule>
</Directory>
EOL

        # Set proper permissions
        chown -R apache:apache /usr/share/phpmyadmin

        # Restart Apache to apply changes
        systemctl restart httpd

        echo "phpMyAdmin installed manually."
    fi
}

# Function to secure phpMyAdmin with .htaccess (Optional)
secure_phpmyadmin() {
    echo "Securing phpMyAdmin with additional authentication..."
    
    # Ensure .htaccess can be used
    sed -i '/<Directory \/usr\/share\/phpmyadmin\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/httpd/conf.d/phpmyadmin.conf

    # Create .htaccess file
    cat <<EOL >/usr/share/phpmyadmin/.htaccess
AuthType Basic
AuthName "Restricted Access"
AuthUserFile /etc/phpmyadmin/.htpasswd
Require valid-user
EOL

    # Install httpd-tools if not installed
    if ! is_installed httpd-tools; then
        dnf install -y httpd-tools
    fi

    # Create .htpasswd file and add a user
    if [ ! -f /etc/phpmyadmin/.htpasswd ]; then
        htpasswd -cb /etc/phpmyadmin/.htpasswd admin "$(openssl rand -base64 12)"
        echo ".htpasswd file created with user 'admin'."
    else
        echo ".htpasswd file already exists."
    fi

    # Set proper permissions
    chmod 640 /etc/phpmyadmin/.htpasswd
    chown root:apache /etc/phpmyadmin/.htpasswd

    # Restart Apache to apply changes
    systemctl restart httpd

    echo "phpMyAdmin additional authentication configured."
}

# Function to wait for MongoDB to be ready
wait_for_mongodb() {
    echo "Waiting for MongoDB to be ready..."
    local retries=30
    local wait=2
    for ((i=1;i<=retries;i++)); do
        if mongosh --eval "db.adminCommand('ping')" &>/dev/null; then
            echo "MongoDB is up and running."
            return 0
        else
            echo "Attempt $i/$retries: MongoDB not ready yet. Waiting for $wait seconds..."
            sleep $wait
        fi
    done
    echo "Error: MongoDB did not become ready in time."
    exit 1
}

#######################################
# Main Script Execution
#######################################

# Update and install prerequisites
echo "Updating system packages and installing prerequisites..."
dnf update -y
dnf install -y wget curl

# Install Apache
echo "Installing Apache..."
dnf install -y httpd
systemctl enable httpd

# Configure firewalld for necessary services
echo "Configuring firewalld..."
systemctl start firewalld
systemctl enable firewalld
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-service=ftp
firewall-cmd --permanent --add-service=ssh
firewall-cmd --reload

# Install mod_ssl and enable mod_rewrite
echo "Installing mod_ssl and enabling mod_rewrite for Apache..."
dnf install -y mod_ssl
# Create a backup of the httpd configuration file
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.bak

# If a line to load the rewrite module doesn't exist, append it
grep -q 'LoadModule rewrite_module' /etc/httpd/conf/httpd.conf \
  || echo 'LoadModule rewrite_module modules/mod_rewrite.so' >> /etc/httpd/conf/httpd.conf

# If a line to load the rewrite module exists but is commented, uncomment it
sed -i '/LoadModule rewrite_module/s/^#//g' /etc/httpd/conf/httpd.conf

# Create separate folders for each domain
echo "Creating directories for domain hosting..."
mkdir -p /var/www/${DOMAIN} /var/www/${DOMAIN2}

# Create a special user for web management with a random password
echo "Creating web user and group with permissions..."
# Check if group exists; if not, create it
if ! getent group $WEB_GROUP > /dev/null 2>&1; then
    groupadd $WEB_GROUP
    echo "Group '$WEB_GROUP' created."
else
    echo "Group '$WEB_GROUP' already exists."
fi

# Check if user exists; if not, create it
if ! id -u $WEB_USER > /dev/null 2>&1; then
    useradd -M -d /var/www -s /bin/bash -g $WEB_GROUP $WEB_USER
    echo "$WEB_USER:$WEB_PASS" | chpasswd
    echo "User '$WEB_USER' created with a random password."
else
    echo "User '$WEB_USER' already exists."
fi

# Set ownership of web directories
chown -R $WEB_USER:$WEB_GROUP /var/www

# Set up Apache configuration for the domains
echo "Setting up Apache virtual hosts..."
cat <<EOL >/etc/httpd/conf.d/${DOMAIN}.conf
<VirtualHost *:80>
    ServerName ${DOMAIN}
    DocumentRoot /var/www/${DOMAIN}
    <Directory /var/www/${DOMAIN}>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOL

cat <<EOL >/etc/httpd/conf.d/${DOMAIN2}.conf
<VirtualHost *:80>
    ServerName ${DOMAIN2}
    DocumentRoot /var/www/${DOMAIN2}
    <Directory /var/www/${DOMAIN2}>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOL

# Install PHP
echo "Installing the latest PHP version..."
echo "Resetting PHP module..."
dnf module reset php -y || true  # Reset PHP module without stopping the script

# Install the Remi repository
dnf install -y https://rpms.remirepo.net/enterprise/remi-release-$(rpm -E '%{rhel}').rpm
dnf module enable php:remi-8.2 -y
dnf install -y php php-mysqlnd

# Install EPEL repository
install_epel

# Install phpMyAdmin
install_phpmyadmin

# Optionally secure phpMyAdmin with additional authentication
# Uncomment the line below to enable
# secure_phpmyadmin

# Install vsftpd for FTP access
echo "Installing vsftpd..."
dnf install -y vsftpd
systemctl enable vsftpd

# Configure vsftpd
echo "Configuring vsftpd..."
cp /etc/vsftpd/vsftpd.conf /etc/vsftpd/vsftpd.conf.bak

cat <<EOL >/etc/vsftpd/vsftpd.conf
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
EOL

# Add the web user to vsftpd user list
echo "$WEB_USER" | tee -a /etc/vsftpd/user_list >/dev/null

# Set SELinux Boolean for FTP
setsebool -P ftpd_full_access 1

# Restart vsftpd to apply changes
systemctl restart vsftpd

# Install MongoDB
echo "Installing MongoDB..."

# Determine OS version
OS_VERSION=$(rpm -E %rhel)

if [ "$OS_VERSION" -ge 9 ]; then
    MONGO_VERSION="6.0"
    MONGO_REPO_BASEURL="https://repo.mongodb.org/yum/redhat/9/mongodb-org/${MONGO_VERSION}/x86_64/"
    MONGO_GPGKEY="https://pgp.mongodb.com/server-${MONGO_VERSION}.asc"
else
    MONGO_VERSION="6.0"
    MONGO_REPO_BASEURL="https://repo.mongodb.org/yum/redhat/8/mongodb-org/${MONGO_VERSION}/x86_64/"
    MONGO_GPGKEY="https://pgp.mongodb.com/server-${MONGO_VERSION}.asc"
fi

# Configure MongoDB repository
cat <<EOL >/etc/yum.repos.d/mongodb-org-${MONGO_VERSION}.repo
[mongodb-org-${MONGO_VERSION}]
name=MongoDB Repository
baseurl=${MONGO_REPO_BASEURL}
gpgcheck=1
enabled=1
gpgkey=${MONGO_GPGKEY}
EOL

# Refresh repository metadata
dnf makecache

# Install MongoDB packages
dnf install -y mongodb-org mongodb-shell

# Enable and start MongoDB service
systemctl enable mongod
systemctl start mongod

# Wait for MongoDB to be ready
wait_for_mongodb

# Add a 30-second delay to ensure MongoDB is fully operational
echo "Adding a 30-second delay to ensure MongoDB is fully operational..."
sleep 30

# Disable MongoDB telemetry
echo "Disabling MongoDB telemetry..."
mongosh <<EOF
disableTelemetry()
EOF

# Secure MongoDB with user authentication
echo "Creating MongoDB user..."
mongosh <<EOF
use admin
db.createUser({
  user: "${MONGO_USER}",
  pwd: "${MONGO_PASS}",
  roles: [{ role: "root", db: "admin" }]
})
EOF

# Configure MongoDB for authentication
echo "Enabling MongoDB authorization..."
sed -i '/^#security:/a \  authorization: enabled' /etc/mongod.conf
systemctl restart mongod

# Start Apache HTTP server
echo "Starting Apache HTTP server..."
systemctl start httpd

# Install Certbot for SSL setup
echo "Installing Certbot for SSL certificates..."
dnf install -y certbot python3-certbot-apache

# Obtain SSL certificates with Let's Encrypt
echo "Obtaining SSL certificates..."
certbot --apache -d ${DOMAIN} --agree-tos -m admin@${DOMAIN} --non-interactive --redirect
certbot --apache -d ${DOMAIN2} --agree-tos -m admin@${DOMAIN2} --non-interactive --redirect

# Set up automatic renewal for the certificates
echo "Setting up certificate renewal..."
echo "0 2 * * * root certbot renew --quiet" > /etc/cron.d/certbot-renew

# Output credentials
echo "========================================="
echo "Setup Completed Successfully!"
echo "========================================="

echo "MongoDB credentials:"
echo "Username: $MONGO_USER"
echo "Password: $MONGO_PASS"

echo ""
echo "Web user credentials:"
echo "Username: $WEB_USER"
echo "Password: $WEB_PASS"

echo ""
echo "You can access phpMyAdmin at: https://$DOMAIN/phpmyadmin"
echo "If secured with additional authentication, use the configured credentials."

echo ""
echo "LAMP stack with MongoDB and FTP setup is complete with SSL support for domains ${DOMAIN} and ${DOMAIN2}."
echo "========================================="
