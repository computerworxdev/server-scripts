#!/bin/bash

# Bash Script for Setting Up a LAMP Stack with Additional Services simple edition v1
# This script installs and configures Apache, PHP, vsftpd and SSL certificates using Certbot.
# Applicable for RHEL/CentOS 8/9 and similar distributions.

# Exit immediately if a command exits with a non-zero status
set -e

# Enable debug mode (optional, uncomment for troubleshooting)
# set -x

#######################################
# Variables
#######################################
PRIMARY_DOMAIN="yourdomainhere.com"
WEB_USER="webadmin"
WEB_GROUP="apache"  # Changed from 'www' to 'apache' to match typical group name
WEB_PASS=$(openssl rand -base64 12)

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

# Create a directory for the primary domain
echo "Creating directory for domain hosting..."
mkdir -p /var/www/${PRIMARY_DOMAIN}

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

# Set ownership of the web directory
chown -R $WEB_USER:$WEB_GROUP /var/www

# Set up Apache configuration for the primary domain
echo "Setting up Apache virtual host for $PRIMARY_DOMAIN..."
cat <<EOL >/etc/httpd/conf.d/${PRIMARY_DOMAIN}.conf
<VirtualHost *:80>
    ServerName ${PRIMARY_DOMAIN}
    DocumentRoot /var/www/${PRIMARY_DOMAIN}
    <Directory /var/www/${PRIMARY_DOMAIN}>
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


# Start Apache HTTP server
echo "Starting Apache HTTP server..."
systemctl start httpd

# Install Certbot for SSL setup
echo "Installing Certbot for SSL certificates..."
dnf install -y certbot python3-certbot-apache

# Obtain SSL certificates with Let's Encrypt
echo "Obtaining SSL certificates..."
certbot --apache -d ${PRIMARY_DOMAIN} --agree-tos -m admin@${PRIMARY_DOMAIN} --non-interactive --redirect

# Set up automatic renewal for the certificates
echo "Setting up certificate renewal..."
echo "0 2 * * * root certbot renew --quiet" > /etc/cron.d/certbot-renew

# Output credentials
echo "========================================="
echo "Setup Completed Successfully!"
echo "========================================="

echo ""
echo "Web user credentials:"
echo "Username: $WEB_USER"
echo "Password: $WEB_PASS"


echo ""
echo "LAMP stack with MongoDB and FTP setup is complete with SSL support for domain $PRIMARY_DOMAIN."
echo "========================================="
