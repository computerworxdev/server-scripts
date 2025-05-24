#!/bin/sh

. messages.sh
. is_service_installed.sh
. is_service_active.sh
. number_of_parameters.sh
. firewalld.sh

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
